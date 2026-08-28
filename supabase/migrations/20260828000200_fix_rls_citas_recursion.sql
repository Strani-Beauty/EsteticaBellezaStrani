-- =============================================================================
-- Fix: recursión RLS en `citas` (42P17) provocada por `cita_paciente_select`.
-- -----------------------------------------------------------------------------
-- La policy `cita_paciente_select` (20260821000100) usa una subquery inline que
-- desciende a `solicitudes`/`pacientes`. Al evaluarse, el RLS de `pacientes`
-- (`pacientes_especialista_cita`, 20260807000000) vuelve a consultar `citas` →
-- ciclo → PostgreSQL lanza "infinite recursion detected in policy for relation
-- citas". Ocurre, p. ej., al cargar la dirección del paciente tras seleccionar
-- puntos en el Face Map (consulta a `direcciones_paciente` → `citas` → ...).
--
-- Fix: misma lógica dentro de un helper SECURITY DEFINER (patrón
-- `especialista_tiene_cita_con` de 20260814000600). La policy pasa a ser un
-- simple `USING (public.paciente_auth_es_dueno_cita(id))` sin subquery, y el
-- helper corre como dueño de las tablas (elude RLS) → no se re-evalúan policies
-- anidadas ni se detecta recursión. Idempotente.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.paciente_auth_es_dueno_cita(p_cita_id uuid)
RETURNS boolean
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
        WHERE c.id = p_cita_id
          AND p.usuario_id = auth.uid()
    );
$$;

DROP POLICY IF EXISTS "cita_paciente_select" ON public.citas;
CREATE POLICY "cita_paciente_select"
    ON public.citas
    FOR SELECT TO authenticated
    USING (public.paciente_auth_es_dueno_cita(id));