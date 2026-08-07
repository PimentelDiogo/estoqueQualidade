-- =============================================================================
-- Regra de negocio no banco (ADR-003).
--
-- Por que aqui e nao no Flutter: dois voluntarios podem estar vendendo o ultimo
-- bolo no mesmo segundo, em celulares diferentes. Se o cliente fizesse
-- "le estoque -> decide -> grava", os dois leriam 1 e os dois venderiam.
-- Aqui a leitura e feita com FOR UPDATE dentro da transacao da funcao.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Helpers de sessao (usados tambem pelas policies de RLS)
-- -----------------------------------------------------------------------------

create or replace function public.fn_papel_atual()
returns public.papel_usuario
language sql
stable
security definer
set search_path = public
as $$
  select papel from public.perfil_usuario where id = auth.uid() and ativo;
$$;

create or replace function public.fn_ministerio_atual()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select ministerio_id from public.perfil_usuario where id = auth.uid() and ativo;
$$;

create or replace function public.fn_e_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.perfil_usuario
    where id = auth.uid() and ativo and papel = 'admin'
  );
$$;

-- -----------------------------------------------------------------------------
-- fn_registrar_venda: UMA chamada, UMA transacao.
--
-- itens: jsonb array [{"produto_id": uuid, "quantidade": int}, ...]
-- O preco NAO vem do cliente: e lido da tabela produto. Assim ninguem consegue
-- forjar um request e registrar um cafe por R$ 0,01.
-- -----------------------------------------------------------------------------

create or replace function public.fn_registrar_venda(
  p_ministerio_id uuid,
  p_tipo          public.tipo_venda,
  p_itens         jsonb,
  p_desconto      numeric default 0,
  p_observacao    text    default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_venda_id     uuid;
  v_usuario_id   uuid := auth.uid();
  v_total        numeric(10,2) := 0;
  v_item         jsonb;
  v_produto      public.produto%rowtype;
  v_quantidade   integer;
  v_subtotal     numeric(10,2);
  v_saldo        integer;
begin
  -- --- Autorizacao ---------------------------------------------------------
  -- A RLS nao cobre SECURITY DEFINER, entao a checagem e explicita aqui.
  if v_usuario_id is null then
    raise exception 'nao_autenticado' using errcode = '28000';
  end if;

  if not public.fn_e_admin()
     and public.fn_ministerio_atual() is distinct from p_ministerio_id then
    raise exception 'sem_permissao_neste_ministerio' using errcode = '42501';
  end if;

  if p_itens is null or jsonb_array_length(p_itens) = 0 then
    raise exception 'venda_sem_itens' using errcode = 'P0001';
  end if;

  if p_desconto < 0 then
    raise exception 'desconto_invalido' using errcode = 'P0001';
  end if;

  -- --- Cabecalho (total ajustado no fim) -----------------------------------
  insert into public.venda (
    ministerio_id, usuario_id, tipo, valor_total, desconto, observacao
  )
  values (p_ministerio_id, v_usuario_id, p_tipo, 0, p_desconto, p_observacao)
  returning id into v_venda_id;

  -- --- Itens ---------------------------------------------------------------
  for v_item in select * from jsonb_array_elements(p_itens)
  loop
    v_quantidade := (v_item->>'quantidade')::integer;

    if v_quantidade is null or v_quantidade <= 0 then
      raise exception 'quantidade_invalida' using errcode = 'P0001';
    end if;

    -- FOR UPDATE: serializa o acesso a esta linha ate o fim da transacao.
    -- E isto que impede a venda dupla do ultimo item.
    select * into v_produto
    from public.produto
    where id = (v_item->>'produto_id')::uuid
    for update;

    if not found then
      raise exception 'produto_nao_encontrado' using errcode = 'P0001';
    end if;

    if v_produto.ministerio_id <> p_ministerio_id then
      raise exception 'produto_de_outro_ministerio' using errcode = '42501';
    end if;

    if not v_produto.ativo then
      raise exception 'produto_inativo: %', v_produto.nome using errcode = 'P0001';
    end if;

    if v_produto.quantidade < v_quantidade then
      -- Mensagem util para o voluntario, com o numero real disponivel.
      raise exception 'estoque_insuficiente: % (disponivel: %, pedido: %)',
        v_produto.nome, v_produto.quantidade, v_quantidade
        using errcode = 'P0001';
    end if;

    v_subtotal := round(v_produto.preco_venda * v_quantidade, 2);
    v_total := v_total + v_subtotal;
    v_saldo := v_produto.quantidade - v_quantidade;

    insert into public.venda_item (
      venda_id, produto_id, produto_nome, quantidade, preco_unitario, subtotal
    )
    values (
      v_venda_id, v_produto.id, v_produto.nome,
      v_quantidade, v_produto.preco_venda, v_subtotal
    );

    update public.produto set quantidade = v_saldo where id = v_produto.id;

    insert into public.movimentacao_estoque (
      produto_id, usuario_id, tipo, quantidade, saldo_apos, venda_id
    )
    values (
      v_produto.id, v_usuario_id, 'saida_venda', -v_quantidade, v_saldo, v_venda_id
    );
  end loop;

  -- --- Fecha o total -------------------------------------------------------
  v_total := greatest(v_total - p_desconto, 0);
  update public.venda set valor_total = v_total where id = v_venda_id;

  return v_venda_id;
end;
$$;

comment on function public.fn_registrar_venda is
  'Registra venda + itens + baixa de estoque + movimentacao numa unica transacao. '
  'Precos vem do banco, nunca do cliente. Ver ADR-003.';

-- -----------------------------------------------------------------------------
-- fn_movimentar_estoque: entrada, ajuste e perda (a saida por venda e da RPC acima)
-- -----------------------------------------------------------------------------

create or replace function public.fn_movimentar_estoque(
  p_produto_id uuid,
  p_tipo       public.tipo_movimentacao,
  p_quantidade integer,
  p_observacao text default null
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_produto public.produto%rowtype;
  v_delta   integer;
  v_saldo   integer;
begin
  if auth.uid() is null then
    raise exception 'nao_autenticado' using errcode = '28000';
  end if;

  if p_tipo = 'saida_venda' then
    raise exception 'use_fn_registrar_venda_para_vendas' using errcode = 'P0001';
  end if;

  if p_quantidade = 0 then
    raise exception 'quantidade_invalida' using errcode = 'P0001';
  end if;

  select * into v_produto from public.produto where id = p_produto_id for update;
  if not found then
    raise exception 'produto_nao_encontrado' using errcode = 'P0001';
  end if;

  if not public.fn_e_admin()
     and public.fn_ministerio_atual() is distinct from v_produto.ministerio_id then
    raise exception 'sem_permissao_neste_ministerio' using errcode = '42501';
  end if;

  -- Entrada soma; perda subtrai; ajuste aceita o sinal que o usuario mandou
  -- (ex.: -3 quando o inventario fisico deu menos que o sistema).
  v_delta := case p_tipo
    when 'entrada' then abs(p_quantidade)
    when 'perda'   then -abs(p_quantidade)
    else p_quantidade
  end;

  v_saldo := v_produto.quantidade + v_delta;

  if v_saldo < 0 then
    raise exception 'estoque_insuficiente: % (disponivel: %)',
      v_produto.nome, v_produto.quantidade using errcode = 'P0001';
  end if;

  update public.produto set quantidade = v_saldo where id = p_produto_id;

  insert into public.movimentacao_estoque (
    produto_id, usuario_id, tipo, quantidade, saldo_apos, observacao
  )
  values (p_produto_id, auth.uid(), p_tipo, v_delta, v_saldo, p_observacao);

  return v_saldo;
end;
$$;

-- -----------------------------------------------------------------------------
-- Trigger de alerta de estoque minimo
-- -----------------------------------------------------------------------------

create or replace function public.fn_checar_estoque_minimo()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.quantidade <= new.estoque_minimo and new.ativo then
    -- O indice parcial alerta_aberto_por_produto_uk garante 1 alerta aberto por
    -- produto; o ON CONFLICT evita spam de e-mail a cada venda subsequente.
    insert into public.alerta_estoque (
      produto_id, ministerio_id, quantidade_no_disparo, estoque_minimo
    )
    values (new.id, new.ministerio_id, new.quantidade, new.estoque_minimo)
    on conflict do nothing;

  elsif new.quantidade > new.estoque_minimo then
    -- Reposicao resolve o alerta sozinha.
    update public.alerta_estoque
       set status = 'resolvido', resolvido_em = now()
     where produto_id = new.id and status = 'aberto';
  end if;

  return new;
end;
$$;

create trigger trg_alerta_estoque
  after insert or update of quantidade, estoque_minimo, ativo on public.produto
  for each row execute function public.fn_checar_estoque_minimo();

-- -----------------------------------------------------------------------------
-- Perfil automatico no cadastro (papel real e ajustado depois pelo admin)
-- -----------------------------------------------------------------------------

create or replace function public.fn_criar_perfil_novo_usuario()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.perfil_usuario (id, nome, papel, ministerio_id, ativo)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'nome', split_part(new.email, '@', 1)),
    'caixa',
    (new.raw_user_meta_data->>'ministerio_id')::uuid,
    -- Nasce INATIVO de proposito: ninguem entra no sistema da igreja sem um
    -- admin liberar. Cadastro aberto sem isso seria porta destrancada.
    false
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger trg_novo_usuario
  after insert on auth.users
  for each row execute function public.fn_criar_perfil_novo_usuario();
