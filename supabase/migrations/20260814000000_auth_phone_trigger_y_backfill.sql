-- =============================================================================
-- Migración: phone en el registro + backfill de perfiles huérfanos.
-- -----------------------------------------------------------------------------
-- 1) El trigger `handle_new_user` ahora guarda `profiles.phone` desde el
--    `raw_user_meta_data` que envía la app (fix AU-H-02).
-- 2) Backfill idempotente: crea `profiles` (y `pacientes` si rol Paciente) para
--    los auth.users que quedaron huérfanos (cuentas creadas a mano sin trigger).
-- 3) Backfill de `phone` desde metadata en perfiles existentes.
-- Idempotente (CREATE OR REPLACE, INSERT ... SELECT con anti-join, ON CONFLICT).
-- =============================================================================

-- 1. Trigger actualizado: incluye phone ----------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_role      TEXT;
    v_role_id   BIGINT;
    v_activo    BOOLEAN;
    v_phone     TEXT;
BEGIN
    v_role := COALESCE(NULLIF(TRIM(new.raw_user_meta_data ->> 'role'), ''), 'Paciente');
    v_role := CASE WHEN lower(v_role) IN ('paciente', 'cliente') THEN 'Paciente'
                   WHEN lower(v_role) IN ('especialista')        THEN 'Especialista'
                   WHEN lower(v_role) IN ('administrador', 'admin') THEN 'Administrador'
                   ELSE 'Paciente'
              END;
    v_activo := v_role <> 'Paciente';
    v_phone  := NULLIF(TRIM(new.raw_user_meta_data ->> 'phone'), '');

    SELECT id INTO v_role_id FROM public.roles WHERE name = v_role LIMIT 1;

    INSERT INTO public.profiles (id, email, full_name, role, role_id, activo, payment_completed, evaluation_passed, phone)
    VALUES (new.id,
            new.email,
            COALESCE(new.raw_user_meta_data ->> 'full_name', ''),
            v_role,
            v_role_id,
            v_activo, false, false,
            v_phone)
    ON CONFLICT (id) DO NOTHING;

    IF v_role = 'Paciente' THEN
        INSERT INTO public.pacientes (usuario_id, activo, created_at, updated_at)
        VALUES (new.id, false, NOW(), NOW())
        ON CONFLICT (usuario_id) DO NOTHING;
    END IF;

    RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 2. Backfill: perfiles huérfanos (auth.users sin fila en profiles) ------------
INSERT INTO public.profiles (id, email, full_name, role, role_id, activo, payment_completed, evaluation_passed, phone)
SELECT
    u.id,
    u.email,
    COALESCE(NULLIF(TRIM(u.raw_user_meta_data ->> 'full_name'), ''), split_part(u.email, '@', 1)),
    x.v_role,
    r.id,
    x.v_role <> 'Paciente',
    FALSE,
    FALSE,
    NULLIF(TRIM(u.raw_user_meta_data ->> 'phone'), '')
FROM auth.users u
LEFT JOIN public.profiles p ON p.id = u.id
CROSS JOIN LATERAL (
    SELECT CASE
        WHEN lower(COALESCE(NULLIF(TRIM(u.raw_user_meta_data ->> 'role'), ''), 'Paciente'))
             IN ('paciente', 'cliente') THEN 'Paciente'
        WHEN lower(COALESCE(NULLIF(TRIM(u.raw_user_meta_data ->> 'role'), ''), 'Paciente'))
             IN ('especialista') THEN 'Especialista'
        WHEN lower(COALESCE(NULLIF(TRIM(u.raw_user_meta_data ->> 'role'), ''), 'Paciente'))
             IN ('administrador', 'admin') THEN 'Administrador'
        ELSE 'Paciente'
    END AS v_role
) x
JOIN public.roles r ON r.name = x.v_role
WHERE p.id IS NULL;

-- 3. Backfill: pacientes para perfiles Paciente recién creados ------------------
INSERT INTO public.pacientes (usuario_id, activo, created_at, updated_at)
SELECT p.id, p.activo, NOW(), NOW()
FROM public.profiles p
LEFT JOIN public.pacientes pac ON pac.usuario_id = p.id
WHERE p.role = 'Paciente' AND pac.usuario_id IS NULL
ON CONFLICT (usuario_id) DO NOTHING;

-- 4. Backfill: phone desde metadata en perfiles existentes ----------------------
UPDATE public.profiles p
SET phone = NULLIF(TRIM(u.raw_user_meta_data ->> 'phone'), ''),
    updated_at = NOW()
FROM auth.users u
WHERE p.id = u.id
  AND (p.phone IS NULL OR p.phone = '')
  AND NULLIF(TRIM(u.raw_user_meta_data ->> 'phone'), '') IS NOT NULL;
