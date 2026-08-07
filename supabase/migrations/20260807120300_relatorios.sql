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
