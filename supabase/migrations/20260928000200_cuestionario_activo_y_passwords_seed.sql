-- =============================================================================
-- MIGRACIÓN: Ajustes de datos de prueba (cuestionario activo + passwords seed).
-- -----------------------------------------------------------------------------
-- 1. Deja como ÚNICO cuestionario activo "Evaluación Clínica General" (v1).
--    El datasource de la app resuelve el cuestionario con
--    `order by created_at desc limit 1`, así que con dos activos (v1 y la v2
--    "Cuestionario de Salud") el resultado depende de fechas. Esta migración
--    normaliza el estado para que las pruebas sean deterministas.
--    Nota: el panel admin hoy solo permite eliminar o activar cuestionarios,
--    no desactivarlos; por eso este ajuste va por migración (idempotente).
-- 2. Restablece la contraseña de las cuentas seed `*@test.com` a `Test1234!`
--    (para poder iniciar sesión en las pruebas manuales sin leer el archivo
--    temporal de contraseñas rotadas).
-- Idempotente. Aplicar en orden ascendente.
-- =============================================================================

-- ── 1. Cuestionario activo ───────────────────────────────────────────────────
-- Activa "Evaluación Clínica General"...
UPDATE public.cuestionarios
   SET activo = true
 WHERE nombre = 'Evaluación Clínica General'
   AND activo IS DISTINCT FROM true;

-- ...y desactiva cualquier otro que hubiera quedado activo.
UPDATE public.cuestionarios
   SET activo = false
 WHERE activo = true
   AND nombre <> 'Evaluación Clínica General';

-- ── 2. Passwords de las cuentas seed ─────────────────────────────────────────
-- goTrue almacena bcrypt; pgcrypto vive en el esquema `extensions` en Supabase.
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

UPDATE auth.users
   SET encrypted_password = extensions.crypt('Test1234!', extensions.gen_salt('bf')),
       updated_at         = now()
 WHERE email LIKE '%@test.com';
