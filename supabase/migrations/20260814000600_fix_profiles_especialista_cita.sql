-- =============================================================================
-- Fix: recursión RLS en `profiles` (42P17) provocada por `profiles_especialista_cita`.
-- -----------------------------------------------------------------------------
-- La policy original (20260807000000) usaba una subquery inline que desciende a
-- `especialistas`/`citas`/`solicitudes`/`pacientes`. Las policies de SELECT de
-- esas tablas usan `(SELECT p.role FROM profiles p WHERE p.id = auth.uid())`
-- inline, así que al evaluar la subquery se re-entra en el RLS de `profiles`
-- → PostgreSQL lanza "infinite recursion detected in policy for relation profiles".
--
-- Fix: misma lógica dentro de un helper SECURITY DEFINER (patrón `is_administrador()`).
-- La policy pasa a ser un simple `USING (public.especialista_tiene_cita_con(id))`
-- sin subquery, y el helper corre como `postgres` (dueño de las tablas, elude RLS)
-- → no se re-evalúan policies anidadas ni se detecta recursión.
-- Idempotente.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.especialista_tiene_cita_con(target_profile_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.citas c
        JOIN public.solicitudes s ON s.id = c.solicitud_id
        JOIN public.pacientes p    ON p.id = s.paciente_id
        WHERE c.especialista_id = (
            SELECT id FROM public.especialistas WHERE usuario_id = auth.uid() LIMIT 1
        )
          AND p.usuario_id = target_profile_id
    );
$$;

DROP POLICY IF EXISTS "profiles_especialista_cita" ON public.profiles;
CREATE POLICY "profiles_especialista_cita"
    ON public.profiles
    FOR SELECT TO authenticated
    USING (public.especialista_tiene_cita_con(id));

-- Limpieza de funciones de diagnóstico temporales.
DROP FUNCTION IF EXISTS public._diag_profiles();
