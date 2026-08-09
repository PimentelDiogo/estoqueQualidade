-- =============================================================================
-- SETUP COMPLETO — Espaco Cafe / PAES Lagoa
--
-- ⚠️ GERADO AUTOMATICAMENTE. Nao edite: altere as migrations e rode
--    bash supabase/gerar-setup.sh
--
-- COMO USAR
--   1. Dashboard do Supabase > SQL Editor > New query
--   2. Cole este arquivo INTEIRO e execute (Run)
--   3. Authentication > Users > "Add user" com "Auto Confirm User" MARCADO:
--        admespacocafe@paeslagoa.com   senha: cafe123
--        caixacafe@paeslagoa.com       senha: cafe123
--   4. Rode de novo SO a ultima secao ("ATIVACAO DOS USUARIOS"): ela e
--      idempotente e so surte efeito depois que os usuarios existirem.
--
-- Por que o passo 3 e manual: a `anon key` nao cria usuario, e o dominio
-- paeslagoa.com nao tem registro DNS — o validador do Supabase recusa o cadastro
-- pela API publica. A API admin do dashboard nao faz essa checagem.
--
-- NAO INCLUI a migration do pg_cron (agendamento do e-mail): ela depende de
-- segredos do Vault criados depois do deploy da Edge Function. Ver SUPABASE.md.
-- =============================================================================

-- =============================================================================
-- 20260807120000_schema_inicial.sql
-- =============================================================================
-- =============================================================================
-- Espaco Cafe - PAES Lagoa | Schema inicial
--
-- Multi-ministerio desde o inicio: o Cafe e o primeiro, mas outros ministerios
-- podem servir no mesmo espaco, cada um com seu PIX, produtos, caixa e relatorios.
-- =============================================================================

create extension if not exists "pgcrypto";

-- =============================================================================
-- ENUMS
-- =============================================================================

create type public.papel_usuario as enum ('admin', 'caixa');

create type public.tipo_venda as enum ('pix', 'dinheiro', 'cartao', 'cortesia');

create type public.tipo_movimentacao as enum (
  'entrada',      -- compra / reposicao
  'saida_venda',  -- baixa automatica da venda (gerada pela RPC)
  'ajuste',       -- correcao de inventario
  'perda'         -- vencimento, quebra, descarte
);

create type public.status_alerta as enum ('aberto', 'resolvido');

-- Fase 2 (TV / pedidos) - schema ja criado, telas depois.
create type public.status_pedido as enum (
  'recebido', 'preparando', 'pronto', 'entregue', 'cancelado'
);

-- =============================================================================
-- MINISTERIO
-- =============================================================================

create table public.ministerio (
  id                 uuid primary key default gen_random_uuid(),
  nome               text        not null,
  slug               text        not null unique,
  responsavel_nome   text,
  -- Destino do e-mail de estoque baixo (Edge Function notificar-estoque-baixo).
  responsavel_email  text,

  -- QR PIX de recebimento. Guardamos o payload copia-e-cola (BR Code) para
  -- renderizar o QR no app; a imagem e alternativa para quem so tem a foto.
  pix_chave          text,
  pix_payload_qr     text,
  pix_qr_image_url   text,

  ativo              boolean     not null default true,
  criado_em          timestamptz not null default now(),
  atualizado_em      timestamptz not null default now(),

  constraint ministerio_nome_nao_vazio check (length(trim(nome)) > 0),
  constraint ministerio_slug_formato    check (slug ~ '^[a-z0-9-]+$')
);

comment on column public.ministerio.pix_payload_qr is
  'Payload BR Code (copia-e-cola). QR estatico: nao ha confirmacao automatica de pagamento (ADR-005).';

-- =============================================================================
-- PERFIL_USUARIO  (espelha auth.users com papel e ministerio)
-- =============================================================================

create table public.perfil_usuario (
  id            uuid primary key references auth.users(id) on delete cascade,
  nome          text        not null,
  papel         public.papel_usuario not null default 'caixa',

  -- Obrigatorio para 'caixa' (ver constraint), nulo para 'admin' (ve todos).
  ministerio_id uuid        references public.ministerio(id) on delete restrict,

  ativo         boolean     not null default true,
  criado_em     timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),

  -- Um caixa ATIVO precisa de ministerio. Enquanto inativo pode nao ter: e o
  -- estado do recem-cadastrado, antes de o admin liberar e vincular.
  constraint caixa_ativo_precisa_de_ministerio
    check (papel <> 'caixa' or not ativo or ministerio_id is not null)
);

create index perfil_usuario_ministerio_idx on public.perfil_usuario (ministerio_id);

-- =============================================================================
-- PRODUTO
-- =============================================================================

create table public.produto (
  id             uuid primary key default gen_random_uuid(),
  ministerio_id  uuid not null references public.ministerio(id) on delete restrict,

  nome           text not null,
  descricao      text,
  codigo_barras  text,

  preco_venda    numeric(10,2) not null,
  custo          numeric(10,2) not null default 0,
  unidade        text          not null default 'un',

  quantidade     integer not null default 0,
  -- O numero que dispara o alerta que motivou o sistema.
  estoque_minimo integer not null default 5,

  ativo          boolean     not null default true,
  criado_em      timestamptz not null default now(),
  atualizado_em  timestamptz not null default now(),

  constraint produto_nome_nao_vazio    check (length(trim(nome)) > 0),
  constraint produto_preco_positivo    check (preco_venda >= 0),
  constraint produto_custo_positivo    check (custo >= 0),
  -- Trava de ultima instancia: nem a RPC pode deixar o estoque negativo.
  constraint produto_qtd_nao_negativa  check (quantidade >= 0),
  constraint produto_minimo_nao_negativo check (estoque_minimo >= 0)
);

-- Codigo de barras e unico dentro do ministerio (dois ministerios podem vender
-- a mesma agua com o mesmo EAN, cada um com seu estoque).
create unique index produto_codigo_barras_uk
  on public.produto (ministerio_id, codigo_barras)
  where codigo_barras is not null;

create index produto_ministerio_idx on public.produto (ministerio_id) where ativo;
create index produto_baixo_estoque_idx
  on public.produto (ministerio_id)
  where ativo and quantidade <= estoque_minimo;

-- =============================================================================
-- VENDA + ITENS
-- =============================================================================

create table public.venda (
  id            uuid primary key default gen_random_uuid(),
  ministerio_id uuid not null references public.ministerio(id) on delete restrict,
  usuario_id    uuid references public.perfil_usuario(id) on delete set null,

  tipo          public.tipo_venda not null,
  valor_total   numeric(10,2) not null,
  desconto      numeric(10,2) not null default 0,
  observacao    text,

  criado_em     timestamptz not null default now(),

  constraint venda_total_positivo    check (valor_total >= 0),
  constraint venda_desconto_positivo check (desconto >= 0)
);

-- Indice do relatorio: filtra por ministerio e ordena por data.
create index venda_ministerio_data_idx
  on public.venda (ministerio_id, criado_em desc);

create table public.venda_item (
  id             uuid primary key default gen_random_uuid(),
  venda_id       uuid not null references public.venda(id) on delete cascade,
  produto_id     uuid not null references public.produto(id) on delete restrict,

  -- Nome congelado no momento da venda: se o produto for renomeado depois,
  -- o historico continua contando a verdade.
  produto_nome   text not null,
  quantidade     integer not null,
  preco_unitario numeric(10,2) not null,
  subtotal       numeric(10,2) not null,

  constraint venda_item_qtd_positiva check (quantidade > 0)
);

create index venda_item_venda_idx   on public.venda_item (venda_id);
create index venda_item_produto_idx on public.venda_item (produto_id);

-- =============================================================================
-- MOVIMENTACAO DE ESTOQUE  (livro-razao: toda mudanca de quantidade passa aqui)
-- =============================================================================

create table public.movimentacao_estoque (
  id            uuid primary key default gen_random_uuid(),
  produto_id    uuid not null references public.produto(id) on delete cascade,
  usuario_id    uuid references public.perfil_usuario(id) on delete set null,

  tipo          public.tipo_movimentacao not null,
  -- Positiva em entrada, negativa em saida/perda. Ajuste pode ser qualquer sinal.
  quantidade    integer not null,
  -- Saldo depois do movimento: permite auditar sem recalcular a serie inteira.
  saldo_apos    integer not null,

  venda_id      uuid references public.venda(id) on delete set null,
  observacao    text,
  criado_em     timestamptz not null default now(),

  constraint movimentacao_qtd_nao_zero check (quantidade <> 0)
);

create index movimentacao_produto_data_idx
  on public.movimentacao_estoque (produto_id, criado_em desc);

-- =============================================================================
-- ALERTA DE ESTOQUE
-- =============================================================================

create table public.alerta_estoque (
  id                    uuid primary key default gen_random_uuid(),
  produto_id            uuid not null references public.produto(id) on delete cascade,
  ministerio_id         uuid not null references public.ministerio(id) on delete cascade,

  quantidade_no_disparo integer not null,
  estoque_minimo        integer not null,

  status                public.status_alerta not null default 'aberto',
  email_enviado_em      timestamptz,
  resolvido_em          timestamptz,
  criado_em             timestamptz not null default now()
);

-- No maximo UM alerta aberto por produto: sem isso, cada venda abaixo do minimo
-- geraria um alerta novo e o responsavel receberia dezenas de e-mails por culto.
create unique index alerta_aberto_por_produto_uk
  on public.alerta_estoque (produto_id)
  where status = 'aberto';

create index alerta_pendente_email_idx
  on public.alerta_estoque (criado_em)
  where status = 'aberto' and email_enviado_em is null;

-- =============================================================================
-- MESA + PEDIDO  (Fase 2 - TV e app de pedidos; schema pronto desde ja)
-- =============================================================================

create table public.mesa (
  id            uuid primary key default gen_random_uuid(),
  ministerio_id uuid not null references public.ministerio(id) on delete cascade,
  identificador text not null,
  -- Token impresso no QR da mesa. Publico, mas so autoriza criar pedido.
  qr_token      text not null unique default encode(gen_random_bytes(16), 'hex'),
  ativo         boolean not null default true,
  criado_em     timestamptz not null default now(),

  unique (ministerio_id, identificador)
);

create table public.pedido (
  id            uuid primary key default gen_random_uuid(),
  ministerio_id uuid not null references public.ministerio(id) on delete restrict,
  mesa_id       uuid references public.mesa(id) on delete set null,

  -- Numero curto do dia, mostrado em letras gigantes na TV.
  senha         text not null,
  status        public.status_pedido not null default 'recebido',
  cliente_nome  text,
  observacao    text,

  -- Vira not null quando o caixa converte o pedido em venda.
  venda_id      uuid references public.venda(id) on delete set null,

  criado_em     timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

create index pedido_fila_idx
  on public.pedido (ministerio_id, criado_em)
  where status in ('recebido', 'preparando', 'pronto');

create table public.pedido_item (
  id           uuid primary key default gen_random_uuid(),
  pedido_id    uuid not null references public.pedido(id) on delete cascade,
  produto_id   uuid not null references public.produto(id) on delete restrict,
  produto_nome text not null,
  quantidade   integer not null,
  preco_unitario numeric(10,2) not null,

  constraint pedido_item_qtd_positiva check (quantidade > 0)
);

create index pedido_item_pedido_idx on public.pedido_item (pedido_id);

-- =============================================================================
-- atualizado_em automatico
-- =============================================================================

create or replace function public.fn_touch_atualizado_em()
returns trigger
language plpgsql
as $$
begin
  new.atualizado_em := now();
  return new;
end;
$$;

create trigger trg_ministerio_touch      before update on public.ministerio
  for each row execute function public.fn_touch_atualizado_em();
create trigger trg_perfil_usuario_touch  before update on public.perfil_usuario
  for each row execute function public.fn_touch_atualizado_em();
create trigger trg_produto_touch         before update on public.produto
  for each row execute function public.fn_touch_atualizado_em();
create trigger trg_pedido_touch          before update on public.pedido
  for each row execute function public.fn_touch_atualizado_em();

-- =============================================================================
-- 20260807120100_funcoes_negocio.sql
-- =============================================================================
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

-- =============================================================================
-- 20260807120200_rls.sql
-- =============================================================================
-- =============================================================================
-- RLS - a autorizacao real do sistema (ADR-004).
--
-- Flutter Web e codigo aberto no navegador e a anon key e publica. Qualquer
-- pessoa pode abrir o DevTools e chamar a API direto. Portanto: middleware de
-- rota no app e conveniencia de navegacao; QUEM PODE O QUE se decide aqui.
--
-- Papeis:
--   admin   -> tudo, todos os ministerios
--   caixa   -> so o proprio ministerio; insere venda/movimentacao, nao deleta
--   TV      -> anon, le a fila de pedidos por qr_token; NUNCA valores nem vendas
--   cliente -> anon, cria pedido com qr_token de mesa valido
-- =============================================================================

alter table public.ministerio            enable row level security;
alter table public.perfil_usuario        enable row level security;
alter table public.produto               enable row level security;
alter table public.venda                 enable row level security;
alter table public.venda_item            enable row level security;
alter table public.movimentacao_estoque  enable row level security;
alter table public.alerta_estoque        enable row level security;
alter table public.mesa                  enable row level security;
alter table public.pedido                enable row level security;
alter table public.pedido_item           enable row level security;

-- -----------------------------------------------------------------------------
-- MINISTERIO
-- -----------------------------------------------------------------------------

create policy ministerio_select on public.ministerio
  for select to authenticated
  using (public.fn_e_admin() or id = public.fn_ministerio_atual());

create policy ministerio_admin_write on public.ministerio
  for all to authenticated
  using (public.fn_e_admin())
  with check (public.fn_e_admin());

-- O caixa pode editar dados operacionais do proprio ministerio (ex.: trocar o
-- QR PIX quando a chave muda), mas nao criar nem apagar ministerio.
create policy ministerio_caixa_update on public.ministerio
  for update to authenticated
  using (id = public.fn_ministerio_atual())
  with check (id = public.fn_ministerio_atual());

-- -----------------------------------------------------------------------------
-- PERFIL_USUARIO
-- -----------------------------------------------------------------------------

create policy perfil_le_proprio on public.perfil_usuario
  for select to authenticated
  using (id = auth.uid() or public.fn_e_admin());

-- So o admin muda papel/ministerio/ativo. Sem isto, um caixa se promoveria a
-- admin com um único UPDATE.
create policy perfil_admin_write on public.perfil_usuario
  for all to authenticated
  using (public.fn_e_admin())
  with check (public.fn_e_admin());

-- -----------------------------------------------------------------------------
-- PRODUTO
-- -----------------------------------------------------------------------------

create policy produto_select on public.produto
  for select to authenticated
  using (public.fn_e_admin() or ministerio_id = public.fn_ministerio_atual());

create policy produto_insert on public.produto
  for insert to authenticated
  with check (
    public.fn_e_admin() or ministerio_id = public.fn_ministerio_atual()
  );

create policy produto_update on public.produto
  for update to authenticated
  using (public.fn_e_admin() or ministerio_id = public.fn_ministerio_atual())
  with check (
    public.fn_e_admin() or ministerio_id = public.fn_ministerio_atual()
  );

-- Deletar produto apagaria historico de venda por cascata de referencia.
-- Apenas admin, e mesmo assim a FK de venda_item usa ON DELETE RESTRICT.
create policy produto_delete_admin on public.produto
  for delete to authenticated
  using (public.fn_e_admin());

-- -----------------------------------------------------------------------------
-- VENDA / VENDA_ITEM
--
-- INSERT nao tem policy de proposito: venda so entra por fn_registrar_venda
-- (SECURITY DEFINER), que garante a transacao e valida o preco no servidor.
-- -----------------------------------------------------------------------------

create policy venda_select on public.venda
  for select to authenticated
  using (public.fn_e_admin() or ministerio_id = public.fn_ministerio_atual());

-- Venda nao se apaga: se o caixa errou, registra-se um estorno.
-- (Nenhuma policy de UPDATE/DELETE = ninguem consegue, nem o admin pelo app.)

create policy venda_item_select on public.venda_item
  for select to authenticated
  using (
    exists (
      select 1 from public.venda v
      where v.id = venda_item.venda_id
        and (public.fn_e_admin() or v.ministerio_id = public.fn_ministerio_atual())
    )
  );

-- -----------------------------------------------------------------------------
-- MOVIMENTACAO DE ESTOQUE (livro-razao: le e escreve por funcao, nunca apaga)
-- -----------------------------------------------------------------------------

create policy movimentacao_select on public.movimentacao_estoque
  for select to authenticated
  using (
    exists (
      select 1 from public.produto p
      where p.id = movimentacao_estoque.produto_id
        and (public.fn_e_admin() or p.ministerio_id = public.fn_ministerio_atual())
    )
  );

-- -----------------------------------------------------------------------------
-- ALERTA DE ESTOQUE
-- -----------------------------------------------------------------------------

create policy alerta_select on public.alerta_estoque
  for select to authenticated
  using (public.fn_e_admin() or ministerio_id = public.fn_ministerio_atual());

-- Permite ao voluntario marcar "ja resolvi" manualmente (o trigger tambem
-- resolve sozinho quando o estoque sobe).
create policy alerta_update on public.alerta_estoque
  for update to authenticated
  using (public.fn_e_admin() or ministerio_id = public.fn_ministerio_atual())
  with check (public.fn_e_admin() or ministerio_id = public.fn_ministerio_atual());

-- -----------------------------------------------------------------------------
-- MESA
-- -----------------------------------------------------------------------------

create policy mesa_select on public.mesa
  for select to authenticated
  using (public.fn_e_admin() or ministerio_id = public.fn_ministerio_atual());

create policy mesa_write on public.mesa
  for all to authenticated
  using (public.fn_e_admin() or ministerio_id = public.fn_ministerio_atual())
  with check (public.fn_e_admin() or ministerio_id = public.fn_ministerio_atual());

-- -----------------------------------------------------------------------------
-- PEDIDO / PEDIDO_ITEM  (Fase 2 - TV e cliente anonimo)
-- -----------------------------------------------------------------------------

create policy pedido_select_interno on public.pedido
  for select to authenticated
  using (public.fn_e_admin() or ministerio_id = public.fn_ministerio_atual());

create policy pedido_update_interno on public.pedido
  for update to authenticated
  using (public.fn_e_admin() or ministerio_id = public.fn_ministerio_atual())
  with check (public.fn_e_admin() or ministerio_id = public.fn_ministerio_atual());

-- TV: le a fila SEM login. So o que precisa aparecer no telao — a coluna de
-- valor nao existe em pedido, e venda continua inacessivel para anon.
-- A TV e identificada pelo qr_token de uma mesa ativa do ministerio, passado
-- na URL (/tv/:token).
create policy pedido_select_tv on public.pedido
  for select to anon
  using (
    status in ('recebido', 'preparando', 'pronto')
    and criado_em > now() - interval '12 hours'
  );

-- Cliente anonimo cria pedido apenas para uma mesa ativa e existente.
create policy pedido_insert_cliente on public.pedido
  for insert to anon
  with check (
    mesa_id is not null
    and exists (
      select 1 from public.mesa m
      where m.id = pedido.mesa_id
        and m.ativo
        and m.ministerio_id = pedido.ministerio_id
    )
    and status = 'recebido'
    and venda_id is null
  );

create policy pedido_item_select_interno on public.pedido_item
  for select to authenticated
  using (
    exists (
      select 1 from public.pedido p
      where p.id = pedido_item.pedido_id
        and (public.fn_e_admin() or p.ministerio_id = public.fn_ministerio_atual())
    )
  );

create policy pedido_item_select_tv on public.pedido_item
  for select to anon
  using (
    exists (
      select 1 from public.pedido p
      where p.id = pedido_item.pedido_id
        and p.status in ('recebido', 'preparando', 'pronto')
    )
  );

create policy pedido_item_insert_cliente on public.pedido_item
  for insert to anon
  with check (
    exists (
      select 1 from public.pedido p
      where p.id = pedido_item.pedido_id and p.status = 'recebido'
    )
  );

-- Cliente precisa ver o cardapio para pedir: nome e preco, mais nada.
--
-- security_invoker = FALSE de proposito. Se fosse `true`, o anon precisaria de
-- uma policy de SELECT na tabela `produto` — e ai ele leria tambem `custo` e
-- `quantidade`, expondo a margem do cafe e o estoque para qualquer um com o
-- DevTools aberto. Com definer, a view e a UNICA janela do publico para produto,
-- e ela so projeta as colunas seguras.
create view public.vw_cardapio
with (security_invoker = false)
as
select p.id, p.ministerio_id, p.nome, p.descricao, p.preco_venda,
       (p.quantidade > 0) as disponivel
from public.produto p
where p.ativo;

grant select on public.vw_cardapio to anon, authenticated;

-- -----------------------------------------------------------------------------
-- Permissoes de execucao das RPCs
-- -----------------------------------------------------------------------------

revoke all on function public.fn_registrar_venda    from public, anon;
revoke all on function public.fn_movimentar_estoque from public, anon;

grant execute on function public.fn_registrar_venda    to authenticated;
grant execute on function public.fn_movimentar_estoque to authenticated;
grant execute on function public.fn_e_admin            to authenticated;
grant execute on function public.fn_ministerio_atual   to authenticated;
grant execute on function public.fn_papel_atual        to authenticated;

-- -----------------------------------------------------------------------------
-- Realtime (fila da TV, Fase 2)
-- -----------------------------------------------------------------------------

alter publication supabase_realtime add table public.pedido;
alter publication supabase_realtime add table public.pedido_item;
alter publication supabase_realtime add table public.alerta_estoque;

-- =============================================================================
-- 20260807120300_relatorios.sql
-- =============================================================================
-- =============================================================================
-- Relatorios: numero de vendas, tipo de venda e valor, por dia / semana / mes.
--
-- A agregacao mora aqui e nao no Dart. Motivo pratico: o celular do voluntario
-- nao precisa baixar 3 mil linhas de venda para mostrar "R$ 840 este mes".
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Serie temporal por granularidade e tipo de venda.
-- Alimenta o grafico de barras (por dia) e o de pizza (por tipo).
-- -----------------------------------------------------------------------------

create or replace function public.fn_vendas_periodo(
  p_ministerio_id  uuid,
  p_granularidade  text,          -- 'day' | 'week' | 'month'
  p_inicio         timestamptz,
  p_fim            timestamptz
)
returns table (
  periodo        timestamptz,
  tipo           public.tipo_venda,
  qtd_vendas     bigint,
  qtd_itens      bigint,
  valor_total    numeric,
  ticket_medio   numeric
)
language sql
stable
security invoker   -- respeita a RLS de `venda`: caixa so ve o proprio ministerio
set search_path = public
as $$
  select
    date_trunc(
      case p_granularidade
        when 'week'  then 'week'
        when 'month' then 'month'
        else 'day'
      end,
      v.criado_em at time zone 'America/Recife'
    ) at time zone 'America/Recife'            as periodo,
    v.tipo,
    count(distinct v.id)                        as qtd_vendas,
    coalesce(sum(vi.quantidade), 0)             as qtd_itens,
    coalesce(sum(v.valor_total), 0)             as valor_total,
    round(
      coalesce(sum(v.valor_total), 0)
        / nullif(count(distinct v.id), 0), 2
    )                                           as ticket_medio
  from public.venda v
  left join public.venda_item vi on vi.venda_id = v.id
  where v.ministerio_id = p_ministerio_id
    and v.criado_em >= p_inicio
    and v.criado_em <  p_fim
  group by 1, 2
  order by 1, 2;
$$;

comment on function public.fn_vendas_periodo is
  'Fuso America/Recife: a "venda do domingo" tem que fechar no domingo da igreja, '
  'nao no dia UTC. Sem isso, venda apos 21h aparece no dia seguinte.';

-- -----------------------------------------------------------------------------
-- Resumo do periodo: os cards do topo do relatorio.
-- -----------------------------------------------------------------------------

create or replace function public.fn_resumo_periodo(
  p_ministerio_id uuid,
  p_inicio        timestamptz,
  p_fim           timestamptz
)
returns table (
  qtd_vendas   bigint,
  qtd_itens    bigint,
  valor_total  numeric,
  ticket_medio numeric,
  descontos    numeric
)
language sql
stable
security invoker
set search_path = public
as $$
  select
    count(distinct v.id)                                         as qtd_vendas,
    coalesce(sum(vi.quantidade), 0)                              as qtd_itens,
    coalesce(sum(v.valor_total), 0)                              as valor_total,
    round(coalesce(sum(v.valor_total), 0)
      / nullif(count(distinct v.id), 0), 2)                      as ticket_medio,
    coalesce(sum(v.desconto), 0)                                 as descontos
  from public.venda v
  left join public.venda_item vi on vi.venda_id = v.id
  where v.ministerio_id = p_ministerio_id
    and v.criado_em >= p_inicio
    and v.criado_em <  p_fim;
$$;

-- -----------------------------------------------------------------------------
-- Produtos mais vendidos no periodo (guia a reposicao de estoque).
-- -----------------------------------------------------------------------------

create or replace function public.fn_produtos_mais_vendidos(
  p_ministerio_id uuid,
  p_inicio        timestamptz,
  p_fim           timestamptz,
  p_limite        integer default 10
)
returns table (
  produto_id   uuid,
  produto_nome text,
  qtd_vendida  bigint,
  valor_total  numeric
)
language sql
stable
security invoker
set search_path = public
as $$
  select
    vi.produto_id,
    -- Nome congelado na venda: se o produto foi renomeado, o historico nao muda.
    max(vi.produto_nome) as produto_nome,
    sum(vi.quantidade)   as qtd_vendida,
    sum(vi.subtotal)     as valor_total
  from public.venda_item vi
  join public.venda v on v.id = vi.venda_id
  where v.ministerio_id = p_ministerio_id
    and v.criado_em >= p_inicio
    and v.criado_em <  p_fim
  group by vi.produto_id
  order by sum(vi.quantidade) desc
  limit p_limite;
$$;

-- -----------------------------------------------------------------------------
-- Produtos acabando: a tela de Alertas e o badge do menu.
-- -----------------------------------------------------------------------------

create or replace view public.vw_estoque_baixo
with (security_invoker = true)
as
select
  p.id            as produto_id,
  p.ministerio_id,
  p.nome,
  p.quantidade,
  p.estoque_minimo,
  case when p.quantidade <= 0 then 'esgotado' else 'acabando' end as situacao,
  a.id            as alerta_id,
  a.criado_em     as alerta_criado_em,
  a.email_enviado_em
from public.produto p
left join public.alerta_estoque a
  on a.produto_id = p.id and a.status = 'aberto'
where p.ativo and p.quantidade <= p.estoque_minimo;

grant select on public.vw_estoque_baixo to authenticated;

grant execute on function public.fn_vendas_periodo          to authenticated;
grant execute on function public.fn_resumo_periodo          to authenticated;
grant execute on function public.fn_produtos_mais_vendidos  to authenticated;

-- =============================================================================
-- 20260807120500_pedidos.sql
-- =============================================================================
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

-- =============================================================================
-- 20260807120600_cardapio_por_token.sql
-- =============================================================================
-- =============================================================================
-- Correcao: o cliente anonimo nao conseguia carregar o cardapio.
--
-- SINTOMA: a tela /pedido/<token> abria com erro. O app lia a tabela `mesa`
-- direto para descobrir o ministerio do token, mas a policy `mesa_select` e
-- `to authenticated` — o anon recebia zero linhas e o `.single()` estourava.
--
-- CAUSA RAIZ: uma leitura de tabela onde deveria haver RPC. Todo o resto do
-- fluxo do cliente ja passava por funcao SECURITY DEFINER (fn_criar_pedido,
-- fn_fila_tv); o cardapio ficou de fora por descuido.
--
-- CORRECAO: fn_cardapio_por_token, mesma disciplina das outras. Continua sem
-- expor `custo` nem `quantidade` — so o que o cliente precisa ver.
-- =============================================================================

create or replace function public.fn_cardapio_por_token(p_qr_token text)
returns table (
  id            uuid,
  ministerio_id uuid,
  nome          text,
  descricao     text,
  preco_venda   numeric,
  disponivel    boolean
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_ministerio_id uuid;
begin
  select m.ministerio_id into v_ministerio_id
    from public.mesa m
   where m.qr_token = p_qr_token and m.ativo;

  if v_ministerio_id is null then
    -- Mensagem util: QR de mesa desativada ou token colado errado.
    raise exception 'mesa_invalida' using errcode = 'P0001';
  end if;

  return query
    select p.id, p.ministerio_id, p.nome, p.descricao, p.preco_venda,
           (p.quantidade > 0) as disponivel
      from public.produto p
     where p.ministerio_id = v_ministerio_id
       and p.ativo
     order by p.nome;
end;
$$;

revoke all on function public.fn_cardapio_por_token from public;
grant execute on function public.fn_cardapio_por_token to anon, authenticated;

-- -----------------------------------------------------------------------------
-- Seed idempotente
--
-- O `on conflict do nothing` do seed nunca disparava: nao havia restricao de
-- unicidade para colidir. Resultado real observado em 2026-08-07: rodar o
-- setup duas vezes duplicou o cardapio inteiro (20 produtos em vez de 11).
--
-- O indice abaixo faz o `on conflict` funcionar de verdade daqui em diante.
-- -----------------------------------------------------------------------------

-- Remove duplicatas ANTES de criar o indice, senao a criacao falha.
-- Mantem a linha mais antiga de cada nome e so apaga as que nunca foram usadas
-- em venda ou pedido — historico nao se apaga (ADR-003).
delete from public.produto p
 where exists (
         select 1 from public.produto q
          where q.ministerio_id = p.ministerio_id
            and lower(trim(q.nome)) = lower(trim(p.nome))
            and q.criado_em < p.criado_em
       )
   and not exists (select 1 from public.venda_item vi where vi.produto_id = p.id)
   and not exists (select 1 from public.pedido_item pi where pi.produto_id = p.id)
   and not exists (
         select 1 from public.movimentacao_estoque me
          where me.produto_id = p.id and me.tipo <> 'entrada'
       );

create unique index if not exists produto_nome_uk
  on public.produto (ministerio_id, lower(trim(nome)));

create unique index if not exists mesa_identificador_uk
  on public.mesa (ministerio_id, lower(trim(identificador)));

-- =============================================================================
-- seed.sql — DADOS DE DESENVOLVIMENTO
-- =============================================================================
-- =============================================================================
-- SEED DE DESENVOLVIMENTO  ⚠️ NAO APLICAR EM PRODUCAO
--
-- MOTIVO DO MOCK (regra do Diogo: todo dado mockado declara o porque):
-- o PDV, o alerta de estoque minimo e os relatorios so podem ser testados com
-- produtos e vendas existindo. Como o cadastro real do Espaco Cafe ainda nao
-- foi feito pela igreja, este seed cria um ministerio e um cardapio plausivel
-- para destravar o desenvolvimento e a validacao end-to-end.
--
-- Nao ha vendas mockadas: elas devem ser criadas pela RPC fn_registrar_venda
-- durante o teste, para exercitar a transacao de verdade.
-- =============================================================================

insert into public.ministerio (
  id, nome, slug, responsavel_nome, responsavel_email, pix_chave, ativo
)
values (
  '11111111-1111-1111-1111-111111111111',
  'Espaco Cafe',
  'espaco-cafe',
  'Responsavel do Cafe',
  -- Trocar pelo e-mail real antes de testar o envio.
  'responsavel@exemplo.org',
  'pix-do-espaco-cafe@exemplo.org',
  true
)
on conflict (id) do nothing;

-- Cardapio plausivel de um cafe de igreja.
-- `estoque_minimo` variado de proposito: assim da para testar o alerta sem
-- precisar vender dezenas de itens.
insert into public.produto (
  ministerio_id, nome, descricao, preco_venda, custo, unidade,
  quantidade, estoque_minimo, codigo_barras
)
values
  ('11111111-1111-1111-1111-111111111111', 'Cafe expresso',     'Cafe curto',                 4.00, 1.20, 'un', 40,  8,  null),
  ('11111111-1111-1111-1111-111111111111', 'Cafe com leite',    'Copo 200ml',                 6.00, 2.00, 'un', 35,  8,  null),
  ('11111111-1111-1111-1111-111111111111', 'Cappuccino',        'Com canela',                 8.00, 3.00, 'un', 25,  5,  null),
  ('11111111-1111-1111-1111-111111111111', 'Chocolate quente',  'Copo 200ml',                 8.00, 3.20, 'un', 20,  5,  null),
  ('11111111-1111-1111-1111-111111111111', 'Cha',               'Camomila / hortela',         4.00, 1.00, 'un', 30,  6,  null),
  ('11111111-1111-1111-1111-111111111111', 'Agua mineral 500ml','Sem gas',                    3.00, 1.10, 'un', 48, 12,  '7891000100103'),
  ('11111111-1111-1111-1111-111111111111', 'Refrigerante lata', 'Diversos sabores',           5.00, 2.50, 'un', 36, 12,  '7894900011517'),
  ('11111111-1111-1111-1111-111111111111', 'Bolo de cenoura',   'Fatia com cobertura',        6.00, 2.00, 'fatia', 12, 4, null),
  ('11111111-1111-1111-1111-111111111111', 'Bolo de fuba',      'Fatia',                      5.00, 1.80, 'fatia', 10, 4, null),
  -- Ja nasce no minimo: valida o alerta assim que a migration roda.
  ('11111111-1111-1111-1111-111111111111', 'Pao de queijo',     'Unidade assada na hora',     3.50, 1.30, 'un',  4,  6,  null),
  -- Ja nasce esgotado: valida o bloqueio de venda sem estoque no PDV.
  ('11111111-1111-1111-1111-111111111111', 'Brownie',           'Fatia com nozes',            7.00, 2.80, 'un',  0,  3,  null)
on conflict do nothing;

-- Mesas para o QR de identificacao (Fase 2).
insert into public.mesa (ministerio_id, identificador)
values
  ('11111111-1111-1111-1111-111111111111', 'Mesa 01'),
  ('11111111-1111-1111-1111-111111111111', 'Mesa 02'),
  ('11111111-1111-1111-1111-111111111111', 'Mesa 03'),
  ('11111111-1111-1111-1111-111111111111', 'Balcao')
on conflict do nothing;

-- -----------------------------------------------------------------------------
-- USUARIOS
--
-- Nao criamos usuario aqui: `auth.users` deve ser populada pelo fluxo oficial
-- (dashboard > Authentication > Add user), senao a senha nao e hasheada direito.
--
-- Depois de criar os dois usuarios no dashboard, rodar:
--
--   update public.perfil_usuario
--      set papel = 'admin', ativo = true, ministerio_id = null
--    where id = (select id from auth.users where email = 'admin@exemplo.org');
--
--   update public.perfil_usuario
--      set papel = 'caixa', ativo = true,
--          ministerio_id = '11111111-1111-1111-1111-111111111111'
--    where id = (select id from auth.users where email = 'caixa@exemplo.org');
--
-- (O perfil e criado automaticamente pelo trigger trg_novo_usuario, INATIVO.)
-- -----------------------------------------------------------------------------

-- =============================================================================
-- ATIVACAO DOS USUARIOS
--
-- Idempotente: pode rodar antes de os usuarios existirem (nao faz nada) e
-- quantas vezes quiser depois.
--
-- Faz o UPSERT do perfil em vez de so UPDATE porque o trigger trg_novo_usuario
-- so dispara em usuarios criados DEPOIS da migration. Se o usuario ja existia,
-- nao ha perfil para atualizar.
-- =============================================================================

-- Administrador: enxerga todos os ministerios (ministerio_id fica nulo).
insert into public.perfil_usuario (id, nome, papel, ministerio_id, ativo)
select u.id, 'Administrador', 'admin', null, true
  from auth.users u
 where u.email = 'admespacocafe@paeslagoa.com'
on conflict (id) do update
   set nome = 'Administrador', papel = 'admin',
       ministerio_id = null,   ativo = true;

-- Caixa: preso ao Espaco Cafe (id fixo do seed).
insert into public.perfil_usuario (id, nome, papel, ministerio_id, ativo)
select u.id, 'Caixa do Cafe', 'caixa',
       '11111111-1111-1111-1111-111111111111', true
  from auth.users u
 where u.email = 'caixacafe@paeslagoa.com'
on conflict (id) do update
   set nome = 'Caixa do Cafe', papel = 'caixa',
       ministerio_id = '11111111-1111-1111-1111-111111111111',
       ativo = true;

-- Conferencia: devem aparecer as duas linhas, ativo = true.
select p.nome, p.papel, p.ativo, m.nome as ministerio, u.email
  from public.perfil_usuario p
  join auth.users u on u.id = p.id
  left join public.ministerio m on m.id = p.ministerio_id
 where u.email in ('admespacocafe@paeslagoa.com', 'caixacafe@paeslagoa.com');
