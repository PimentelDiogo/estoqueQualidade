-- =============================================================================
-- Agendamento do aviso de estoque baixo.
--
-- ATENCAO: rodar DEPOIS de fazer o deploy da Edge Function e de gravar os
-- segredos no Vault. Se rodar antes, o cron so vai registrar erro no log.
-- Passo a passo em SUPABASE.md.
-- =============================================================================

create extension if not exists pg_cron  with schema extensions;
create extension if not exists pg_net   with schema extensions;

-- Os segredos ficam no Vault do Supabase, nunca em texto puro na migration.
-- Gravar uma vez pelo SQL Editor do dashboard:
--
--   select vault.create_secret('https://SEU-PROJETO.supabase.co', 'project_url');
--   select vault.create_secret('SUA_SERVICE_ROLE_KEY',            'service_role_key');

create or replace function public.fn_disparar_notificacao_estoque()
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_url  text;
  v_key  text;
begin
  select decrypted_secret into v_url
    from vault.decrypted_secrets where name = 'project_url';
  select decrypted_secret into v_key
    from vault.decrypted_secrets where name = 'service_role_key';

  if v_url is null or v_key is null then
    raise notice 'Segredos do Vault ausentes - notificacao de estoque nao enviada.';
    return;
  end if;

  perform net.http_post(
    url     := v_url || '/functions/v1/notificar-estoque-baixo',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || v_key
    ),
    body    := '{}'::jsonb
  );
end;
$$;

-- A cada 30 minutos. Cadencia escolhida para o contexto: o culto dura ~2h, entao
-- o responsavel e avisado ainda a tempo de repor, sem virar spam.
select cron.schedule(
  'notificar-estoque-baixo',
  '*/30 * * * *',
  $$ select public.fn_disparar_notificacao_estoque(); $$
);

-- Para desagendar:  select cron.unschedule('notificar-estoque-baixo');
