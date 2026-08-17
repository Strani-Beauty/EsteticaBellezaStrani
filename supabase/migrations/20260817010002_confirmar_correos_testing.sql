-- =============================================================================
-- MIGRACIÓN (TEMPORAL — PRUEBAS): Confirma los correos pendientes de auth.users.
-- -----------------------------------------------------------------------------
-- Contexto: el toggle "Confirm email" de Supabase se apagó para pruebas, pero
-- las cuentas creadas ANTES quedaron con `email_confirmed_at = null` en
-- `auth.users` y la app sigue mostrando "Confirma tu correo" al intentar entrar.
-- Esta migración las confirma y deja una snapshot en
-- `public.mig_20260817010002_confirmados` (user_id, email) para revertir.
--
-- REVERT (para volver a dejarlas NO confirmadas cuando termine la prueba):
--   update auth.users u
--   set email_confirmed_at = null
--   from public.mig_20260817010002_confirmados m
--   where u.id = m.user_id;
--   -- opcional, limpiar la snapshot:
--   drop table public.mig_20260817010002_confirmados;
--
-- Idempotente (ON CONFLICT DO NOTHING; el update no re-confirma a los que ya
-- tienen email_confirmed_at).
-- =============================================================================

create table if not exists public.mig_20260817010002_confirmados (
  user_id       uuid primary key,
  email         text,
  confirmado_en timestamptz
);

insert into public.mig_20260817010002_confirmados (user_id, email, confirmado_en)
select id, email, now()
from auth.users
where email_confirmed_at is null
on conflict (user_id) do nothing;

update auth.users u
set email_confirmed_at = m.confirmado_en
from public.mig_20260817010002_confirmados m
where u.id = m.user_id
  and u.email_confirmed_at is null;