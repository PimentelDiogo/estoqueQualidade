# Espaço Café Lagoa (PAES) — Contexto

> Herda: global (`~/.claude/CLAUDE.md`) → `Projetos/CLAUDE.md` → este arquivo.
> Hub de conhecimento no vault: `Diogo-VAULT/Projetos/` · backup deste arquivo em
> `Diogo-VAULT/Projetos/_config-backup/code-claude-md/estoqueQualidade-CLAUDE.md`.

## Visão geral

Sistema de **vendas, estoque e (futuramente) pedidos** do **Espaço Café** da
**Igreja Anglicana PAES Lagoa**. Antes disso o café operava sem nada: nenhum registro de
venda, nenhum controle de estoque, nenhum aviso de produto acabando.

**Multi-ministério desde o schema** — o Café é o primeiro, mas outros ministérios podem
servir no mesmo espaço, cada um com seu QR PIX, produtos, caixa e relatórios.

Quem usa: **voluntários da igreja, no celular**, durante o culto. Isso manda em tudo —
poucos toques, alvo grande, erro honesto na tela.

### Escopo por fase
- **F1:** PDV + Estoque + Relatórios (dia/semana/mês) + alerta de estoque mínimo.
- **F2 (atual):** TV com fila em tempo real · pedido do cliente pelo QR da mesa ·
  gestão da fila pelo caixa (avançar status e cobrar).

## Stack

- **Flutter Web** · SDK Dart `^3.12.2` · **FVM `3.44.9`** (pinado em `.fvmrc`) —
  sempre `fvm flutter ...`, nunca `flutter` puro.
- **GetX** (`get`) — estado, DI e rotas. `shared_preferences` para preferência local
  (**não** `get_storage`: ele usa `dart:html` e bloqueia o build wasm — ADR-006).
- **Supabase** (`supabase_flutter`) — Postgres + Auth + Realtime + Storage.
- `qr_flutter` (QR PIX / QR de mesa) · `mobile_scanner` (código de barras) ·
  `fl_chart` (relatórios) · `intl` (moeda pt_BR).
- **Sem backend próprio.** A regra de negócio crítica mora no Postgres (RPC + trigger + RLS).

## Arquitetura — MVVM + GetX (ADR-001)

```
View (Widget) → ViewModel (GetxController) → Repository (contrato) → Service → Supabase
```

Deliberadamente **não é Clean Architecture** como o `englishIA` — sem camada `usecases`,
que aqui viraria boilerplate. Ver `ADR/001-mvvm-getx.md`.

```
lib/
├── core/
│   ├── theme/        tokens (cores, spacing, tipografia) + app_theme
│   ├── widgets/      responsive_layout + componentes reutilizáveis
│   ├── utils/        money_formatter · date_range · result
│   ├── routes/       app_routes · app_pages · rbac_middleware
│   └── config/       env.dart (dart-define)
├── data/
│   ├── models/       ministerio · produto · venda · venda_item · movimentacao_estoque
│   │                 pedido · pedido_item · perfil_usuario · alerta_estoque · mesa
│   ├── services/     supabase · auth · session · preferencias · contexto_operacional
│   └── repositories/ contrato abstrato + impl `*_repository_supabase.dart`
└── modules/          auth · pdv · estoque · ministerios · relatorios
                      pedido (cliente) · pedidos (caixa) · tv · showcase
                      (cada um: view/ · viewmodel/ · binding/)
```

### ⚠️ Regras invioláveis

1. **View nunca chama `Supabase.instance`** — só ViewModel → Repository.
2. **ViewModel nunca importa `package:supabase_flutter`** — só o contrato do Repository.
   Vale também para a sessão: as ViewModels recebem `ContextoOperacional` (interface), não o
   `SessionService` concreto, que arrastaria `AuthService` → `SupabaseService` para o teste.
3. **DI por rota** via `Bindings` do GetX (um binding por feature). Nada de `Get.put` solto.
4. **Zero cor/spacing/fonte hardcoded na View.** `Color(0xFF…)` inline é **proibido** —
   só tokens de `core/theme/`. *(Este é exatamente o erro que o `englishIA` cometeu.)*
5. **Antes de criar widget novo:** olhar `core/widgets/`. Não duplicar componente.
6. **Nenhuma tela lê `MediaQuery.size.width` direto** — só os helpers de responsividade.

## Responsividade — padrão único

`lib/core/widgets/responsive_layout.dart`. Portado do `englishIA` com um breakpoint a mais.

| Breakpoint | Largura | Uso |
|---|---|---|
| `mobile`  | `< 768`     | **foco principal** — voluntário no celular, alvo ≥48dp, uma coluna |
| `tablet`  | `768–1279`  | caixa em tablet, duas colunas (lista + carrinho) |
| `desktop` | `1280–1919` | painel do adm, relatórios lado a lado |
| `tv`      | `≥ 1920`    | fila de pedidos, tipografia ~1.8×, sem interação |

Helpers: `ResponsiveBody` · `ResponsiveGrid` · `ResponsiveValue<T>` · `context.breakpoint`.

## Reaproveitamento

Componentes compartilhados vivem **só** em `core/widgets/`:
`AppScaffold` · `AppButton` · `AppTextField` · `MoneyText` · `EmptyState` · `AppCard`.
Rota `/showcase` (dev) renderiza todos nos 4 breakpoints — usar para validar antes de criar
qualquer coisa nova.

## Regra de negócio no banco (não no cliente)

- **`fn_registrar_venda(...)`** — RPC **transacional**: cria venda + itens, baixa o estoque e
  grava a movimentação numa chamada só. Impede estoque negativo com dois caixas simultâneos
  (ADR-003). **Nunca** fazer inserts separados a partir do Flutter.
- **`trg_alerta_estoque`** — dispara `alerta_estoque` quando `quantidade <= estoque_minimo`.
- **`vw_vendas_periodo`** — agregação por dia/semana/mês. **Relatório não soma no Dart.**
- **Edge Function `notificar-estoque-baixo`** — e-mail ao responsável (Resend), via `pg_cron`.
- **`fn_criar_pedido(...)`** — cliente **anônimo** cria pedido pelo `qr_token` da mesa.
  Preço e senha vêm do banco; o cliente só manda `{produto_id, quantidade}`. Teto de 30
  itens/pedido porque o endpoint é público.
- **`fn_converter_pedido_em_venda(...)`** — o caixa cobra: chama `fn_registrar_venda` por
  dentro, então herda a transação e a validação de estoque do ADR-003.

⚠️ **Pedido NÃO baixa estoque.** A baixa só acontece na cobrança — senão um pedido
abandonado no salão seguraria estoque que nunca foi vendido.

## RBAC — a autorização mora na RLS (ADR-004)

Flutter Web é código aberto no browser, então **a UI só esconde rota**; a garantia é o Postgres.

| Papel | Entra como | Enxerga |
|---|---|---|
| `admin` | e-mail + senha | tudo, todos os ministérios |
| `caixa` | e-mail + senha | **só o próprio `ministerio_id`**; insere venda/movimentação, não deleta |
| **TV** | token de device na URL (`/tv/:token`), sem login | fila de pedidos read-only — **nunca** valores nem vendas |
| **cliente** | anônimo via QR de mesa | insere pedido com `qr_token` válido |

`RbacMiddleware` (GetX) é conveniência de navegação — não é controle de acesso.

As rotas `/tv/:token` e `/pedido/:token` **não têm middleware de propósito**: são públicas por
design. Quem protege são as RPCs `SECURITY DEFINER`, que só devolvem o que aquele token
autoriza. A TV nunca recebe valor monetário — `fn_fila_tv` projeta apenas senha e status.

## Como rodar / testar

```bash
fvm flutter pub get
cp env.example.json env.json      # preencher com as chaves do Supabase (env.json é gitignored)
fvm flutter run -d chrome --dart-define-from-file=env.json

fvm flutter analyze
fvm flutter test
```

Supabase: passo a passo de criar projeto e aplicar migrations em `SUPABASE.md`.

## Segurança

- **Nenhuma chave no código.** Só `--dart-define-from-file=env.json` (gitignored).
- A `anon key` é pública por natureza — por isso a RLS é obrigatória em toda tabela.
- **PIX sem confirmação automática na F1** (ADR-005): o QR é estático e a conferência do
  recebimento é manual pelo caixa. Não prometer baixa automática de pagamento.

## Testes

Testes unitários de ViewModel com repositories fake (sem rede, sem mock framework) —
`test/fakes/`. Rodar com `fvm flutter test` (40 testes na Fase 1).

Regra do Diogo: **não subir código sem teste sem perguntar antes**.

⚠️ **Antes de adicionar qualquer pacote novo:** rodar `fvm flutter build web --wasm` e checar o
*dry run*. Uma dependência transitiva com `dart:html` bloqueia o wasm do app inteiro, e o aviso
passa despercebido no meio do log (ADR-006).

## Documentos

- `PRD/` — requisitos do produto.
- `ADR/` — 001 MVVM+GetX · 002 Realtime vs Valkey · 003 RPC transacional ·
  004 RBAC na RLS · 005 PIX sem webhook · 006 shared_preferences/wasm.
- `SUPABASE.md` — setup do backend.

## Manutenção deste arquivo

Toda alteração aqui (ou em `.claude/agents/`) deve ser **espelhada no vault**:
`Diogo-VAULT/Projetos/_config-backup/code-claude-md/estoqueQualidade-CLAUDE.md`.
