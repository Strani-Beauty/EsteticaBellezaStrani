-- =============================================================================
-- MIGRACIÓN: emails y teléfonos de las cuentas seed con formato válido.
-- -----------------------------------------------------------------------------
-- La app ahora valida correo (regex con dominio con punto) y teléfono
-- (E.164 flexible `^\+?\d{10,15}$`). Las cuentas de la matriz de pruebas
-- usaban `*@test` (dominio sin punto) y teléfonos `+1 555 01NN` (con espacios
-- y 8 dígitos), lo que las dejaría bloqueadas al iniciar sesión.
--
-- Se aplica SOLO a las cuentas existentes en remoto; los seeds locales
-- (20260814000100/200/300) ya quedaron corregidos para entornos frescos.
-- Idempotente (WHERE acotados; re-ejecutar no altera nada).
-- Aplicar con `supabase db push` o desde el SQL Editor del dashboard.
-- =============================================================================

-- ── 1. Emails: dominio `@test` → `@test.com` ─────────────────────────────────
UPDATE auth.users
   SET email = regexp_replace(email, '@test$', '@test.com'),
       updated_at = now()
 WHERE email LIKE '%@test';

UPDATE public.profiles
   SET email = regexp_replace(email, '@test$', '@test.com'),
       updated_at = now()
 WHERE email LIKE '%@test';

-- auth.identities: gotrue guarda el email en identity_data (login con email).
UPDATE auth.identities
   SET identity_data = jsonb_set(
         identity_data,
         '{email}',
         to_jsonb(regexp_replace(identity_data ->> 'email', '@test$', '@test.com'))
       ),
       updated_at = now()
 WHERE identity_data ->> 'email' LIKE '%@test';

-- ── 2. Teléfonos de la matriz: `+1 555 01NN` → `+15550100NN` ────────────────
UPDATE public.profiles
   SET phone = '+15550100' || right(phone, 2),
       updated_at = now()
 WHERE phone LIKE '+1 555 01%';

UPDATE auth.users
   SET raw_user_meta_data = COALESCE(raw_user_meta_data, '{}'::jsonb)
         || jsonb_build_object('phone', '+15550100' || right((raw_user_meta_data ->> 'phone'), 2)),
       updated_at = now()
 WHERE raw_user_meta_data ->> 'phone' LIKE '+1 555 01%';