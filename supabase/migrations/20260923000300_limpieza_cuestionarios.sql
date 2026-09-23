-- =============================================================================
-- MIGRACIÓN: Limpieza de cuestionarios (borrado de la v3 vacía + desactivación).
-- -----------------------------------------------------------------------------
-- Tras la consulta del usuario quedan cuestionarios sobrantes:
--   * id 6 'Cuestionario de Salud' v3: 0 evaluaciones -> se borra físicamente
--     (con sus vínculos en cuestionario_preguntas / servicio_cuestionarios).
--   * id 1 'Estética y Belleza General' v1: 7 evaluaciones -> no borrable (ePHI),
--     se desactiva.
--   * id 4 'Cuestionario de Salud' v1: 2 evaluaciones -> no borrable, se desactiva.
--   * id 3 'Evaluación Clínica General' v1: 0 evaluaciones, queda como borrador
--     inactivo hasta decidir el modelo de evaluación (pendiente del usuario final).
-- Resultado: único cuestionario activo = id 5 'Cuestionario de Salud' v2.
-- No se re-vinculan servicios (decisión del usuario: "vamos sólo a limpiar").
-- Idempotente (DELETE por id / UPDATE por id).
-- =============================================================================

-- ── 1. Borrar físicamente la v3 vacía (id 6) ────────────────────────────────
DELETE FROM public.cuestionario_preguntas WHERE cuestionario_id = 6;
DELETE FROM public.servicio_cuestionarios WHERE cuestionario_id = 6;
DELETE FROM public.cuestionarios WHERE id = 6;

-- ── 2. Desactivar los cuestionarios con evaluaciones o en espera ────────────
UPDATE public.cuestionarios
   SET activo = false, updated_at = now()
 WHERE id IN (1, 3, 4);
