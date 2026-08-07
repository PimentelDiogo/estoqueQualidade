# Supabase — setup do backend

> Backend do Espaço Café. Não há servidor próprio: Postgres + Auth + Realtime +
> Storage do Supabase, com a regra de negócio dentro do banco.

## 1. Criar o projeto

1. [supabase.com/dashboard](https://supabase.com/dashboard) → **New project**
2. Região: **South America (São Paulo)** — menor latência para Recife.
3. Guardar a senha do banco (não vai para o git).
4. Em **Project Settings → API**, copiar `Project URL` e `anon public`.

```bash
cp env.example.json env.json   # env.json é gitignored
```

> A `anon key` é pública por natureza — vai no bundle do Flutter Web e qualquer um
> lê no navegador. É exatamente por isso que a autorização mora na RLS (ADR-004).
> A `service_role key` **nunca** entra no app; só na Edge Function.

## 2. Aplicar tudo de uma vez ⚡

> **Estado atual (2026-08-07): o banco está VAZIO.** O projeto Supabase existe, mas nenhuma
> migration foi aplicada — todas as tabelas retornam 404. Os passos 2 e 3 são obrigatórios
> antes de o app funcionar.

**SQL Editor → New query → colar `supabase/setup-completo.sql` inteiro → Run.**

Esse arquivo é **gerado** a partir das migrations versionadas:

```bash
bash supabase/gerar-setup.sh      # regenera após alterar qualquer migration
```

Ele traz schema, RPCs, triggers, RLS, relatórios, pedidos (Fase 2) e o seed de
desenvolvimento. Fica de fora só o `pg_cron`, que depende de segredos criados no passo 4.

<details>
<summary>Alternativa: CLI do Supabase</summary>

```bash
brew install supabase/tap/supabase
supabase login
supabase link --project-ref tezyxlbkjjktppityyfg
supabase db push
```
</details>

## 3. Criar os dois usuários

**Authentication → Users → Add user**, com **“Auto Confirm User” marcado**:

| E-mail | Senha | Papel |
|---|---|---|
| `admespacocafe@paeslagoa.com` | `cafe123` | admin — vê todos os ministérios |
| `caixacafe@paeslagoa.com` | `cafe123` | caixa — preso ao Espaço Café |

> **Por que isto não é automatizável com a `anon key`:** ela não cria usuário. E a API pública
> de signup recusa esses e-mails porque **`paeslagoa.com` não tem registro DNS** — sem MX e sem
> A, o validador do Supabase trata como endereço inválido. A API admin do dashboard não faz essa
> checagem, então pelo painel funciona.
>
> ⚠️ `cafe123` é senha de desenvolvimento (7 caracteres, dicionário). Antes de usar com dinheiro
> real na igreja, troque — principalmente a do **admin**, que enxerga todos os ministérios.
> Se o domínio real da igreja for outro (`.org.br`?), vale criar os usuários já com ele.

Depois de criar os dois, volte ao SQL Editor e rode **a última seção** de
`setup-completo.sql` (“ATIVAÇÃO DOS USUÁRIOS”). Ela é idempotente e faz `upsert` do perfil —
necessário porque o trigger `trg_novo_usuario` só dispara em usuários criados *depois* da
migration. A query final lista os dois perfis para conferência.

O perfil nasce **inativo** de propósito: ninguém entra no sistema da igreja sem um admin
liberar. É essa seção que ativa.

## 4. Edge Function — e-mail de estoque baixo

```bash
# 1. Conta no resend.com → API key → verificar o domínio da igreja
supabase secrets set RESEND_API_KEY=re_xxx
supabase secrets set EMAIL_REMETENTE="Espaco Cafe <cafe@paeslagoa.org>"

# 2. Deploy (sem JWT: quem chama é o pg_cron com a service_role key)
supabase functions deploy notificar-estoque-baixo --no-verify-jwt

# 3. Testar na mão
supabase functions invoke notificar-estoque-baixo
```

Depois, no SQL Editor, gravar os segredos do Vault e rodar a migration do cron:

```sql
select vault.create_secret('https://SEU-PROJETO.supabase.co', 'project_url');
select vault.create_secret('SUA_SERVICE_ROLE_KEY',            'service_role_key');
```

> Sem `RESEND_API_KEY`, a função devolve **erro 500 e não marca o alerta como
> enviado**. É deliberado: melhor falhar visível do que fingir que avisou.
> O alerta in-app continua funcionando normalmente, sem depender de e-mail.

## 5. Storage (opcional — imagem do QR PIX)

**Storage → New bucket** → nome `pix-qr`, **público**.
Só é necessário para ministérios que preferem subir a foto do QR em vez de
cadastrar o payload copia-e-cola.

## 6. Verificar que a RLS está de pé

Este teste é o que separa "parece seguro" de "é seguro":

```sql
-- Como caixa do Espaço Café: deve retornar SÓ os produtos do Espaço Café
select set_config('request.jwt.claims',
  json_build_object('sub', (select id from auth.users where email='caixa@exemplo.org'))::text,
  true);
select count(*) from public.produto;

-- Como anônimo (a TV): deve retornar ZERO linhas
select set_config('request.jwt.claims', null, true);
set role anon;
select count(*) from public.venda;   -- esperado: 0
reset role;
```

## 7. Testar a Fase 2 (TV e pedidos)

O seed já cria 4 mesas. Pegue o token de uma delas:

```sql
select identificador, qr_token from public.mesa order by identificador;
```

Com o app rodando:

| Papel | URL |
|---|---|
| **Cliente** | `/#/pedido/<qr_token>` — cardápio, sem login |
| **TV** | `/#/tv/<qr_token>` — telão, sem login |
| **Caixa** | `/#/pedidos` — logado como `caixacafe@paeslagoa.com` |

Fluxo completo: cliente pede → senha aparece na TV em “PREPARANDO” → caixa avança para
“PRONTO” (a TV atualiza sozinha) → caixa clica **Cobrar** → a venda é registrada, o estoque
baixa e o pedido sai da fila.

> Em Ministérios → **Mesas / QR** você imprime os QR já apontando para a URL certa.

## Notas de arquitetura

- **Venda só entra pela RPC `fn_registrar_venda`.** Não existe policy de INSERT em
  `venda` — inserir direto do app é impossível por construção (ADR-003).
- **Venda não se apaga.** Sem policy de UPDATE/DELETE: caixa errado se corrige com
  estorno, não com exclusão de histórico.
- **Fuso `America/Recife`** nas funções de relatório: a venda das 21h de domingo
  tem que fechar no domingo da igreja, não no dia UTC seguinte.
- **Alerta:** índice parcial garante no máximo **um** alerta aberto por produto —
  sem isso o responsável receberia um e-mail por venda abaixo do mínimo.
- **Pedido não baixa estoque; a cobrança baixa.** `fn_converter_pedido_em_venda` chama
  `fn_registrar_venda` por dentro, herdando transação e validação de estoque. Se o pedido
  baixasse na criação, um cliente que desiste seguraria estoque que nunca foi vendido.
- **Cliente anônimo não escolhe preço.** As policies de INSERT direto em `pedido`/`pedido_item`
  foram **removidas** na migration de pedidos: a única porta é `fn_criar_pedido`, que lê o preço
  da tabela `produto`. Mesma disciplina do ADR-003 aplicada a um endpoint público.
