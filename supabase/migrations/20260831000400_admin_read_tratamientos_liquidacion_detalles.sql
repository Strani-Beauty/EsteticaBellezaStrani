-- =============================================================================
-- Migración: lectura (SELECT) de administrador en tratamientos y
-- liquidacion_detalles para el corte semanal y el detalle por cita.
-- -----------------------------------------------------------------------------
-- `fetchCitasFinalizadasAdmin` (corte semanal + lista "Citas terminadas")
-- consulta dos tablas que quedaron sin acceso admin:
--   * `tratamientos`: solo tenía `tratamiento_especialista_own` (20260807000000)
--     → el admin no veía qué citas tienen tratamiento COMPLETADO y descartaba
--     todas las citas de la lista.
--   * `liquidacion_detalles`: RLS habilitada pero SIN ninguna policy
--     (creada por SQL Editor) → el admin no podía consultar la idempotencia
--     (citas ya liquidadas) ni el detalle por liquidación.
-- Se agregan policies SELECT admin-only (mismo patrón de
-- `20260831000300_admin_read_pagos.sql` y `20260822000100_admin_dashboard_rls.sql`).
-- Solo lectura; no se otorgan INSERT/UPDATE/DELETE.
-- Idempotente (DROP POLICY IF EXISTS).
-- =============================================================================

DROP POLICY IF EXISTS tratamientos_admin_select ON public.tratamientos;
CREATE POLICY tratamientos_admin_select
    ON public.tratamientos
    FOR SELECT TO authenticated
    USING (public.is_administrador());

DROP POLICY IF EXISTS liquidacion_detalles_admin_select ON public.liquidacion_detalles;
CREATE POLICY liquidacion_detalles_admin_select
    ON public.liquidacion_detalles
    FOR SELECT TO authenticated
    USING (public.is_administrador());