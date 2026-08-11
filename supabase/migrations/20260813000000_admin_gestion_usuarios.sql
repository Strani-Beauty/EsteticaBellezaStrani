-- =============================================================================
-- Migración: Acceso administrativo a gestionar usuarios (`profiles`).
-- -----------------------------------------------------------------------------
-- El panel admin necesita:
--   1) Listar/consultar todos los perfiles de usuario (hoy solo existe
--      `own_profile_access`, que limita SELECT/UPDATE al dueño).
--   2) Activar/desactivar cuentas (interruptor `activo` en `profiles`).
--
-- Se agregan dos policies SOLO para el rol `Administrador` (mismo patrón que
-- `especialista_admin_select` / `documento_admin_review`). El dueño conserva
-- su acceso propio vía `own_profile_access`.
--
-- IMPORTANTE: las policies usan la función `public.is_administrador()` con
-- SECURITY DEFINER. No usar `(SELECT p.role FROM public.profiles p WHERE
-- p.id = auth.uid())` dentro de una policy sobre `profiles` porque PostgreSQL
-- detecta recursión infinita en el policy de la misma tabla.
-- Idempotente: DROP POLICY IF EXISTS + CREATE POLICY, CREATE OR REPLACE FUNCTION.
-- =============================================================================

-- 0. Helper de rol administrador (evita recursión RLS sobre `profiles`) -------
CREATE OR REPLACE FUNCTION public.is_administrador()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.profiles p
        WHERE p.id = auth.uid()
          AND p.role = 'Administrador'
    );
$$;

-- 1. El administrador puede LEER todos los perfiles --------------------------
DROP POLICY IF EXISTS "profiles_admin_select" ON public.profiles;
CREATE POLICY "profiles_admin_select"
    ON public.profiles
    FOR SELECT TO authenticated
    USING (public.is_administrador());

-- 2. El administrador puede ACTUALIZAR cualquier perfil (activar/desactivar) --
DROP POLICY IF EXISTS "profiles_admin_update" ON public.profiles;
CREATE POLICY "profiles_admin_update"
    ON public.profiles
    FOR UPDATE TO authenticated
    USING (public.is_administrador())
    WITH CHECK (public.is_administrador());

-- 3. Semántica de `activo` por rol -------------------------------------------
-- `profiles.activo` significa "cuenta autorizada para usar la app":
--   * Paciente       → arranca en false y pasa a true cuando su onboarding
--                       (dirección + cuota + evaluación) se completa.
--   * Especialista   → arranca en true (su habilitación clínica se gobierna
--                       con `especialistas.estado_verificacion`); el admin lo
--                       desactiva/apaga con el interruptor del panel.
--   * Administrador  → arranca en true.
-- El trigger `handle_new_user` crea el perfil; aquí se ajusta para que solo el
-- paciente nazca inactivo. Backfill idempotente para cuentas ya existentes.

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
BEGIN
    v_role := COALESCE(NULLIF(TRIM(new.raw_user_meta_data ->> 'role'), ''), 'Paciente');
    v_role := CASE WHEN lower(v_role) IN ('paciente', 'cliente') THEN 'Paciente'
                   WHEN lower(v_role) IN ('especialista')        THEN 'Especialista'
                   WHEN lower(v_role) IN ('administrador', 'admin') THEN 'Administrador'
                   ELSE 'Paciente'
              END;

    -- Solo el Paciente nace inactivo (debe completar su onboarding).
    v_activo := v_role <> 'Paciente';

    SELECT id INTO v_role_id FROM public.roles WHERE name = v_role LIMIT 1;

    INSERT INTO public.profiles (id, email, full_name, role, role_id, activo, payment_completed, evaluation_passed)
    VALUES (new.id,
            new.email,
            COALESCE(new.raw_user_meta_data ->> 'full_name', ''),
            v_role,
            v_role_id,
            v_activo, false, false)
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

-- Backfill: cuentas de especialista/admin existentes se consideran autorizadas.
UPDATE public.profiles
SET activo = true
WHERE role IN ('Especialista', 'Administrador')
  AND activo IS DISTINCT FROM true;