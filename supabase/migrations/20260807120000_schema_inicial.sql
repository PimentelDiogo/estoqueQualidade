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
