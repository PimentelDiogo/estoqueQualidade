#!/usr/bin/env bash
# Gera supabase/setup-completo.sql a partir das migrations + seed.
#
# Existe porque o projeto nao usa a CLI do Supabase: o setup e feito colando um
# arquivo unico no SQL Editor do dashboard. Gerar em vez de manter a mao evita
# que o arquivo colado divirja das migrations versionadas.
#
# A migration do pg_cron fica DE FORA de proposito: ela depende de segredos no
# Vault que so existem depois do deploy da Edge Function. Rodar antes disso faria
# o script inteiro falhar. Ver SUPABASE.md, secao 4.
set -euo pipefail
cd "$(dirname "$0")/.."

SAIDA=supabase/setup-completo.sql

{
cat <<'HDR'
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
HDR

for f in supabase/migrations/*.sql; do
  case "$(basename "$f")" in
    *_cron.sql) continue ;;
  esac
  printf '\n-- =============================================================================\n'
  printf -- '-- %s\n' "$(basename "$f")"
  printf -- '-- =============================================================================\n'
  cat "$f"
done

printf '\n-- =============================================================================\n'
printf -- '-- seed.sql — DADOS DE DESENVOLVIMENTO\n'
printf -- '-- =============================================================================\n'
cat supabase/seed.sql

cat <<'RODAPE'

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
RODAPE
} > "$SAIDA"

echo "Gerado: $SAIDA ($(wc -l < "$SAIDA" | tr -d ' ') linhas)"
