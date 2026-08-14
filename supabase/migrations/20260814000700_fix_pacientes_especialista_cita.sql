-- =============================================================================
-- Fix: recursión RLS en `pacientes` (42P17) provocada por `pacientes_especialista_cita`.
-- -----------------------------------------------------------------------------
-- Mismo problema que en `profiles`: la policy usaba subquery inline que desciende
-- a `solicitudes`/`citas`/`especialistas`; `solicitud_paciente_own` hace subquery
-- inline a `pacientes` → bucle → "infinite recursion detected in policy for relation
-- 'pacientes'". Se reutiliza el helper SECURITY DEFINER `especialista_tiene_cita_con`
-- (corre como postgres, elude RLS; la policy queda como llamada a función, sin subquery).
-- Idempotente.
-- =============================================================================

DROP POLICY IF EXISTS "pacientes_especialista_cita" ON public.pacientes;
CREATE POLICY "pacientes_especialista_cita"
    ON public.pacientes
    FOR SELECT TO authenticated
    USING (public.especialista_tiene_cita_con(usuario_id));
