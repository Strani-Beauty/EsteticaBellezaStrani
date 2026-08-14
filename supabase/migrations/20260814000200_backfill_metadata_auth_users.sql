-- =============================================================================
-- Migración: backfill de metadata en auth.users (providers + phone) y cleanup.
-- -----------------------------------------------------------------------------
-- 1) Borra cuentas de la matriz de pruebas que quedaron rotas por AU-H-02
--    (creadas por la app sin provider ni phone, sin confirmar): al no poder
--    el seed re-insertarlas (WHERE NOT EXISTS), se eliminan para poder
--    re-probar AU-H-02 desde cero.
-- 2) Backfill de `raw_app_meta_data` con provider/providers email en todos los
--    auth.users que no lo tengan.
-- 3) Backfill de `phone` en `raw_user_meta_data` desde `profiles.phone` donde
--    falte (cuentas manuales con perfil).
-- 4) Sincronización inversa `profiles.phone` desde metadata (complementa el
--    paso 4 de la migración 20260814000000).
-- Idempotente: UPDATE con guardas, DELETE acotado a la matriz rota.
-- =============================================================================

-- 1. Cleanup: cuentas matriz rotas (sin confirmar) ---------------------------------
-- El seed (20260814000100) siempre inserta con `email_confirmed_at = now()`;
-- cualquier cuenta matriz con email sin confirmar es un duplicado del test manual
-- que no tiene provider/phone y no deja re-probar AU-H-02. Se elimina (cascada
-- a profiles/pacientes/auth.identities).
DELETE FROM auth.users u
WHERE u.email IN (
    'admin@test',
    'esp.nuevo@test',
    'esp.revision@test',
    'esp.aprobado@test',
    'esp.rechazado@test',
    'esp.bloqueado@test',
    'esp.desactivado@test',
    'pac.nuevo@test',
    'pac.activo@test',
    'pac.vencido@test',
    'pac.rechazado@test',
    'pac.desactivado@test'
  )
  AND u.email_confirmed_at IS NULL;

-- 2. Backfill de providers en raw_app_meta_data ------------------------------------
UPDATE auth.users
SET raw_app_meta_data = COALESCE(raw_app_meta_data, '{}'::jsonb)
    || '{"provider":"email","providers":["email"]}'::jsonb
WHERE raw_app_meta_data IS NULL
   OR NOT raw_app_meta_data ? 'provider';

-- 3. Backfill de phone en metadata desde profiles ----------------------------------
UPDATE auth.users u
SET raw_user_meta_data = COALESCE(raw_user_meta_data, '{}'::jsonb)
    || jsonb_build_object('phone', p.phone)
FROM public.profiles p
WHERE p.id = u.id
  AND p.phone IS NOT NULL AND p.phone <> ''
  AND (raw_user_meta_data IS NULL OR NOT raw_user_meta_data ? 'phone');

-- 4. Sincronizar profiles.phone desde metadata -------------------------------------
UPDATE public.profiles p
SET phone = NULLIF(TRIM(u.raw_user_meta_data ->> 'phone'), ''),
    updated_at = NOW()
FROM auth.users u
WHERE p.id = u.id
  AND (p.phone IS NULL OR p.phone = '')
  AND NULLIF(TRIM(u.raw_user_meta_data ->> 'phone'), '') IS NOT NULL;

-- 5. Resumen ------------------------------------------------------------------------
SELECT email, COALESCE(raw_app_meta_data ->> 'provider', 'SIN_PROVIDER') AS provider,
       raw_user_meta_data ->> 'phone' AS meta_phone, email_confirmed_at
FROM auth.users WHERE email LIKE '%@test' ORDER BY email;
