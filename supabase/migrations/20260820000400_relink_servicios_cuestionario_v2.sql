-- =============================================================================
-- Re-linka al "Cuestionario de Salud" v2 (id=5, activa) los 5 servicios que
-- quedaron enlazados a la v1 (id=4, inactiva) por el flujo de compliance previo.
-- -----------------------------------------------------------------------------
-- Contexto (Nota 1 del plan de catálogo, 2026-08-19): `cuestionarios` tiene
-- "Cuestionario de Salud" v1 (id=4, inactiva) y v2 (id=5, activa). Los pacientes
-- responden la v2, por lo que `tieneEvaluacionAptaDeCuestionario(id=4)` nunca
-- encontraría una evaluación APTO → bloqueo falso de reserva si esos servicios
-- se activaran. Los 5 servicios afectados están inactivos hoy:
--   Toxina Botulínica (11111111), Ácido Hialurónico (22222222),
--   Peelings Médicos (33333333), Microneedling (44444444),
--   Lipólisis Alta Frecuencia (55555555).
-- Se re-enlazan conservando `obligatorio`/`orden`. El NOT EXISTS respeta el
-- constraint único `servicio_cuestionarios_servicio_cuestionario_idx`
-- (servicio_id, cuestionario_id): si un servicio ya tuviera fila hacia id=5
-- (no es el caso hoy), no se toca. Idempotente.
-- =============================================================================

UPDATE public.servicio_cuestionarios sc
SET cuestionario_id = 5
WHERE sc.cuestionario_id = 4
  AND NOT EXISTS (
    SELECT 1
    FROM public.servicio_cuestionarios sc2
    WHERE sc2.servicio_id = sc.servicio_id
      AND sc2.cuestionario_id = 5
  );