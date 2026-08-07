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
