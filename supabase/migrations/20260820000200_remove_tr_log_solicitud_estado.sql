-- =============================================================================
-- Elimina el trigger huérfano `tr_log_solicitud_estado` (AFTER INSERT en
-- `solicitudes`).
-- -----------------------------------------------------------------------------
-- El trigger fue creado directamente en el SQL Editor (no existía en ninguna
-- migración) y su función `log_solicitud_estado_change()` inserta en
-- `historial_estados` con `tipo_entidad='SOLICITUD'` usando los permisos del
-- llamante (paciente). La única policy de `historial_estados`
-- (`historial_cita_own`) solo cubre `tipo_entidad='CITA'` de especialistas,
-- por lo que el INSERT de solicitudes fallaba con 42501
-- ("new row violates row-level security policy for table historial_estados").
-- La app nunca lee ni inserta historial_estados para SOLICITUD (solo CITA vía
-- treatment_execution). Se elimina la deuda técnica y se desbloquea el flujo.
-- Idempotente: DROP ... IF EXISTS.
-- =============================================================================

DROP TRIGGER IF EXISTS tr_log_solicitud_estado ON public.solicitudes;
DROP FUNCTION IF EXISTS public.log_solicitud_estado_change();