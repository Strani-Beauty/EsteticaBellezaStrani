-- =============================================================================
-- Migración: corrige el login de las cuentas del seed de la matriz.
-- -----------------------------------------------------------------------------
-- Síntoma: POST /auth/v1/token?grant_type=password devuelve 500
--   "Database error querying schema" para las cuentas @test del seed.
-- Causa raíz (supabase/auth#1940 + troubleshooting oficial):
--   1) El INSERT directo en `auth.users` dejó NULL en columnas token que gotrue
--      espera como string vacío (confirmation_token, recovery_token, email_change,
--      email_change_token_new) -> error de scan al encontrar el usuario.
--   2) Las cuentas no tienen fila en `auth.identities`; gotrue v2 exige la
--      identidad del provider 'email' para autenticar por contraseña.
-- También se aplican las mismas correcciones al seed 20260814000100 para que un
-- entorno fresco no reproduzca el problema.
-- Idempotente (COALESCE + anti-join). No toca cuentas fuera de la matriz salvo
-- la limpieza de cuentas de diagnóstico (@test creadas por verificación).
-- =============================================================================

-- 1. Columnas token en NULL -> '' (gotrue no puede escanear NULL) ----------------
UPDATE auth.users
SET confirmation_token     = COALESCE(confirmation_token, ''),
    recovery_token         = COALESCE(recovery_token, ''),
    email_change           = COALESCE(email_change, ''),
    email_change_token_new = COALESCE(email_change_token_new, '')
WHERE confirmation_token IS NULL
   OR recovery_token IS NULL
   OR email_change IS NULL
   OR email_change_token_new IS NULL;

-- 2. Identidades faltantes (login con contraseña requiere auth.identities) --------
INSERT INTO auth.identities (
  id, provider_id, user_id, identity_data, provider,
  last_sign_in_at, created_at, updated_at
)
SELECT gen_random_uuid(), u.id::text, u.id,
       jsonb_build_object('sub', u.id::text, 'email', u.email, 'email_verified', TRUE, 'phone_verified', FALSE),
       'email', now(), now(), now()
FROM auth.users u
WHERE u.email LIKE '%@test'
  AND NOT EXISTS (SELECT 1 FROM auth.identities i WHERE i.user_id = u.id);

-- 3. Limpieza de cuentas de diagnóstico creadas durante la verificación -----------
DELETE FROM auth.users WHERE email LIKE 'diag.%@test';
