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
