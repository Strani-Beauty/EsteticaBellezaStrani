-- =============================================================================
-- Migración: limpieza de constraints legacy de `evaluaciones_servicio`.
-- -----------------------------------------------------------------------------
-- La tabla existía en el remoto (SQL Editor) con constraints sin nombre fijo:
--   * fk_evaluaciones_servicio_cita / fk_evaluaciones_servicio_paciente (FK)
--   * evaluaciones_servicio_cita_id_key (UNIQUE en cita_id)
--   * chk_evaluaciones_puntuacion_rango (CHECK de puntuación)
-- La migración 20260901000400 añadió sus propias constraints con nombres
-- explícitos, pero las legacy quedaron. La UNIQUE en `cita_id` es bloqueante:
-- impediría 2 evaluaciones por cita (paciente→especialista y especialista→
-- paciente). Se eliminan aquí. Idempotente (DROP CONSTRAINT IF EXISTS).
-- =============================================================================

ALTER TABLE public.evaluaciones_servicio
    DROP CONSTRAINT IF EXISTS fk_evaluaciones_servicio_cita;

ALTER TABLE public.evaluaciones_servicio
    DROP CONSTRAINT IF EXISTS fk_evaluaciones_servicio_paciente;

ALTER TABLE public.evaluaciones_servicio
    DROP CONSTRAINT IF EXISTS evaluaciones_servicio_cita_id_key;

ALTER TABLE public.evaluaciones_servicio
    DROP CONSTRAINT IF EXISTS chk_evaluaciones_puntuacion_rango;