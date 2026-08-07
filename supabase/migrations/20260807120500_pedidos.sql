-- =============================================================================
-- Fase 2 — Pedidos do cliente e fila da TV
--
-- Mesma disciplina do ADR-003: o cliente NAO escolhe preco nem senha. Ele manda
-- o token da mesa e uma lista de {produto_id, quantidade}; o resto o banco monta.
-- Aqui isso importa ainda mais, porque quem chama e um usuario ANONIMO.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Senha do pedido: sequencia curta, reiniciada por dia e por ministerio.
--
-- O voluntario grita "senha 12", nao um UUID. Reiniciar por dia mantem o numero
-- pequeno; o escopo por ministerio evita dois cafes disputando a mesma senha.
-- -----------------------------------------------------------------------------

create or replace function public.fn_proxima_senha(p_ministerio_id uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select lpad(
    (
      coalesce(
        max(nullif(regexp_replace(senha, '\D', '', 'g'), '')::int),
        0
      ) + 1
    )::text,
    2, '0'
  )
  from public.pedido
  where ministerio_id = p_ministerio_id
    and (criado_em at time zone 'America/Recife')::date
        = (now() at time zone 'America/Recife')::date;
$$;

-- -----------------------------------------------------------------------------
-- fn_criar_pedido — chamada pelo CLIENTE ANONIMO via QR da mesa.
--
-- A mesa e identificada pelo qr_token impresso no adesivo. Isso substitui o
-- login: quem tem o token esta fisicamente no salao.
-- -----------------------------------------------------------------------------

create or replace function public.fn_criar_pedido(
  p_qr_token     text,
  p_itens        jsonb,
  p_cliente_nome text default null,
  p_observacao   text default null
)
returns table (pedido_id uuid, senha text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_mesa      public.mesa%rowtype;
  v_pedido_id uuid;
  v_senha     text;
  v_item      jsonb;
  v_produto   public.produto%rowtype;
  v_qtd       integer;
  v_total_itens integer := 0;
begin
  select * into v_mesa
  from public.mesa
  where qr_token = p_qr_token and ativo;

  if not found then
    raise exception 'mesa_invalida' using errcode = 'P0001';
  end if;

  if p_itens is null or jsonb_array_length(p_itens) = 0 then
    raise exception 'pedido_sem_itens' using errcode = 'P0001';
  end if;

  -- Teto defensivo: o endpoint e anonimo. Sem isso, alguem com o token de uma
  -- mesa poderia inundar a TV com um pedido de 10 mil itens.
  if jsonb_array_length(p_itens) > 30 then
    raise exception 'pedido_muito_grande' using errcode = 'P0001';
  end if;

  v_senha := public.fn_proxima_senha(v_mesa.ministerio_id);

  insert into public.pedido (
    ministerio_id, mesa_id, senha, status, cliente_nome, observacao
  )
  values (
    v_mesa.ministerio_id, v_mesa.id, v_senha, 'recebido',
    nullif(trim(p_cliente_nome), ''), nullif(trim(p_observacao), '')
  )
  returning id into v_pedido_id;

  for v_item in select * from jsonb_array_elements(p_itens)
  loop
    v_qtd := (v_item->>'quantidade')::integer;

    if v_qtd is null or v_qtd <= 0 or v_qtd > 50 then
      raise exception 'quantidade_invalida' using errcode = 'P0001';
    end if;

    select * into v_produto
    from public.produto
    where id = (v_item->>'produto_id')::uuid
      and ministerio_id = v_mesa.ministerio_id
      and ativo;

    if not found then
      raise exception 'produto_nao_encontrado' using errcode = 'P0001';
    end if;

    -- Preco lido do banco, nunca do request.
    insert into public.pedido_item (
      pedido_id, produto_id, produto_nome, quantidade, preco_unitario
    )
    values (
      v_pedido_id, v_produto.id, v_produto.nome, v_qtd, v_produto.preco_venda
    );

    v_total_itens := v_total_itens + v_qtd;
  end loop;

  -- Pedido NAO baixa estoque. A baixa acontece quando o caixa converte em
  -- venda (fn_converter_pedido_em_venda) — senao um pedido abandonado no salao
  -- seguraria estoque que nunca foi vendido.
  return query select v_pedido_id, v_senha;
end;
$$;

comment on function public.fn_criar_pedido is
  'Cliente anonimo cria pedido pelo qr_token da mesa. Precos vem do banco. '
  'Nao movimenta estoque — isso e da conversao em venda.';

-- -----------------------------------------------------------------------------
-- fn_fila_tv — o que a TV mostra, a partir do token de uma mesa do ministerio.
--
-- Devolve so senha e status: nenhum valor monetario chega ao telao.
-- -----------------------------------------------------------------------------

create or replace function public.fn_fila_tv(p_qr_token text)
returns table (
  pedido_id     uuid,
  ministerio_id uuid,
  senha         text,
  status        public.status_pedido,
  cliente_nome  text,
  qtd_itens     bigint,
  criado_em     timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select p.id, p.ministerio_id, p.senha, p.status, p.cliente_nome,
         coalesce(sum(pi.quantidade), 0) as qtd_itens,
         p.criado_em
    from public.mesa m
    join public.pedido p on p.ministerio_id = m.ministerio_id
    left join public.pedido_item pi on pi.pedido_id = p.id
   where m.qr_token = p_qr_token
     and m.ativo
     and p.status in ('recebido', 'preparando', 'pronto')
     and p.criado_em > now() - interval '12 hours'
   group by p.id
   order by p.criado_em;
$$;

-- Consulta do proprio pedido pelo cliente ("minha senha ja saiu?").
create or replace function public.fn_status_pedido(p_pedido_id uuid)
returns table (senha text, status public.status_pedido)
language sql
stable
security definer
set search_path = public
as $$
  select senha, status from public.pedido where id = p_pedido_id;
$$;

-- -----------------------------------------------------------------------------
-- fn_converter_pedido_em_venda — o caixa cobra o pedido.
--
-- Reaproveita fn_registrar_venda, entao ganha de graca a transacao, o
-- FOR UPDATE e a validacao de estoque do ADR-003.
-- -----------------------------------------------------------------------------

create or replace function public.fn_converter_pedido_em_venda(
  p_pedido_id uuid,
  p_tipo      public.tipo_venda,
  p_desconto  numeric default 0
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_pedido   public.pedido%rowtype;
  v_itens    jsonb;
  v_venda_id uuid;
begin
  if auth.uid() is null then
    raise exception 'nao_autenticado' using errcode = '28000';
  end if;

  select * into v_pedido from public.pedido where id = p_pedido_id for update;
  if not found then
    raise exception 'pedido_nao_encontrado' using errcode = 'P0001';
  end if;

  if not public.fn_e_admin()
     and public.fn_ministerio_atual() is distinct from v_pedido.ministerio_id then
    raise exception 'sem_permissao_neste_ministerio' using errcode = '42501';
  end if;

  if v_pedido.venda_id is not null then
    raise exception 'pedido_ja_cobrado' using errcode = 'P0001';
  end if;

  select jsonb_agg(
           jsonb_build_object('produto_id', produto_id, 'quantidade', quantidade)
         )
    into v_itens
    from public.pedido_item
   where pedido_id = p_pedido_id;

  v_venda_id := public.fn_registrar_venda(
    v_pedido.ministerio_id, p_tipo, v_itens, p_desconto,
    'Pedido ' || v_pedido.senha
  );

  update public.pedido
     set venda_id = v_venda_id,
         status = 'entregue'
   where id = p_pedido_id;

  return v_venda_id;
end;
$$;

-- -----------------------------------------------------------------------------
-- Permissoes
-- -----------------------------------------------------------------------------

-- O cliente anonimo cria pedido SO por esta funcao. As policies de INSERT
-- diretas em pedido/pedido_item sao removidas: com elas, o cliente escolheria o
-- proprio preco em pedido_item — mesmo furo que o ADR-003 fecha na venda.
drop policy if exists pedido_insert_cliente on public.pedido;
drop policy if exists pedido_item_insert_cliente on public.pedido_item;

revoke all on function public.fn_criar_pedido              from public;
revoke all on function public.fn_converter_pedido_em_venda from public, anon;

grant execute on function public.fn_criar_pedido    to anon, authenticated;
grant execute on function public.fn_fila_tv         to anon, authenticated;
grant execute on function public.fn_status_pedido   to anon, authenticated;
grant execute on function public.fn_proxima_senha   to authenticated;
grant execute on function public.fn_converter_pedido_em_venda to authenticated;
