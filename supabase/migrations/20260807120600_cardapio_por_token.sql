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
