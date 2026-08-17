-- =============================================================================
-- MIGRACIÓN: Face map reutilizable por servicio.
-- Al re-seleccionar un servicio inyectable con tratamiento aún no cerrado, la app
-- muestra los puntos ya seleccionados por el paciente. Para soportarlo:
--   * face_maps.servicio_id vincula el mapa al servicio del catálogo (el mapa se
--     guarda ANTES de que exista solicitud/tratamiento).
--   * face_map_puntos.punto_id / vista guardan el id del punto predefinido y la
--     vista (izq/frente/der) para reconstruir exactamente el mapa al re-mostrarlo.
-- Idempotente (ADD COLUMN IF NOT EXISTS / CREATE INDEX IF NOT EXISTS).
-- =============================================================================

-- ── 1. face_maps: vínculo al servicio ───────────────────────────────────────
ALTER TABLE public.face_maps
    ADD COLUMN IF NOT EXISTS servicio_id uuid
    REFERENCES public.servicios (id);

CREATE INDEX IF NOT EXISTS face_maps_paciente_servicio_idx
    ON public.face_maps (paciente_id, servicio_id);

-- ── 2. face_map_puntos: identidad del punto + vista ─────────────────────────
ALTER TABLE public.face_map_puntos
    ADD COLUMN IF NOT EXISTS punto_id text;

ALTER TABLE public.face_map_puntos
    ADD COLUMN IF NOT EXISTS vista text;

CREATE INDEX IF NOT EXISTS face_map_puntos_face_map_id_idx
    ON public.face_map_puntos (face_map_id);
