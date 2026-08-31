-- =============================================================================
-- Migración: lectura (SELECT) de administrador en pagos, solicitud_detalles y
-- pacientes para la conciliación financiera.
-- -----------------------------------------------------------------------------
-- La vista admin "Conciliación de Pagos" (transacciones + detalle por cita +
-- citas terminadas) embebe `pagos`, `solicitud_detalles(servicios)` y
-- `pacientes(profiles)` desde `citas`/`solicitudes`, pero estas tres tablas
-- solo tenían policies de paciente/especialista (no de admin):
--   * `pagos`: sin policy admin → el embed devolvía null → montos en 0 y el
--     filtro de "cita terminada" (estado PAGADO) descartaba todas las citas.
--   * `solicitud_detalles` / `pacientes`: sin policy admin → la lista no
--     mostraba servicios ni nombre del paciente.
-- Se agregan policies SELECT admin-only (mismo patrón de
-- `20260822000100_admin_dashboard_rls.sql`: citas/solicitudes/transacciones).
-- Solo lectura; no se otorgan INSERT/UPDATE/DELETE.
-- Idempotente (DROP POLICY IF EXISTS).
-- =============================================================================

DROP POLICY IF EXISTS pagos_admin_select ON public.pagos;
CREATE POLICY pagos_admin_select
    ON public.pagos
    FOR SELECT TO authenticated
    USING (public.is_administrador());

DROP POLICY IF EXISTS solicitud_detalles_admin_select ON public.solicitud_detalles;
CREATE POLICY solicitud_detalles_admin_select
    ON public.solicitud_detalles
    FOR SELECT TO authenticated
    USING (public.is_administrador());

DROP POLICY IF EXISTS pacientes_admin_select ON public.pacientes;
CREATE POLICY pacientes_admin_select
    ON public.pacientes
    FOR SELECT TO authenticated
    USING (public.is_administrador());