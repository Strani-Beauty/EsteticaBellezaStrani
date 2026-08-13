-- =============================================================================
-- Migración: Presencia online/offline, índices PostGIS y RPCs de proximidad.
-- -----------------------------------------------------------------------------
-- Objetivos:
--   1. Presencia online/offline de especialistas (heartbeat en BD).
--   2. Índices espaciales GIST para futuras búsquedas por proximidad.
--   3. RPC `buscar_especialistas_cercanos` (lista para búsqueda por proximidad).
--   4. RPC `obtener_solicitudes_publicadas_geo` que devuelve a especialistas
--      SOLO ubicación aproximada del paciente (truncada a 3 decimales ~110 m)
--      y `ciudad`, sin `direccion` ni coordenadas exactas (RN-018). La dirección
--      exacta queda exclusivamente en la policy `direccion_paciente_especialista_cita`
--      (solo tras asignación de la cita).
-- Idempotente (ADD COLUMN IF NOT EXISTS, CREATE INDEX IF NOT EXISTS,
-- CREATE OR REPLACE FUNCTION, DROP/GRANT repetibles).
-- =============================================================================

-- ── 1. Presencia en `especialistas` ──────────────────────────────────────────
-- El dueño puede actualizar estas columnas (el trigger
-- `proteger_verificacion_especialista` solo protege columnas de verificación,
-- no `en_linea`/`ultima_conexion`).
ALTER TABLE public.especialistas
    ADD COLUMN IF NOT EXISTS en_linea        BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS ultima_conexion TIMESTAMPTZ;

-- ── 2. Índices espaciales GIST (PostGIS) ─────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_ubicaciones_especialista_ubicacion
    ON public.ubicaciones_especialista USING GIST (ubicacion);

CREATE INDEX IF NOT EXISTS idx_direcciones_paciente_ubicacion
    ON public.direcciones_paciente USING GIST (ubicacion);

-- ── 3. RPC: búsqueda de especialistas cercanos (proximidad) ─────────────────
-- Security definer: puede leer `ubicaciones_especialista` sin exponer una policy
-- de lectura abierta. Devuelve solo especialistas elegibles y con presencia.
CREATE OR REPLACE FUNCTION public.buscar_especialistas_cercanos(
    p_lat           NUMERIC,
    p_lng           NUMERIC,
    p_radio_metros  NUMERIC,
    p_limit         INTEGER DEFAULT 20
)
RETURNS TABLE (
    especialista_id  UUID,
    nombre           TEXT,
    latitud          NUMERIC,
    longitud         NUMERIC,
    distancia_metros DOUBLE PRECISION
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, extensions
AS $$
    SELECT e.id,
           p.full_name,
           u.latitud,
           u.longitud,
           ST_Distance(
               u.ubicacion,
               ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::extensions.geography
           ) AS distancia_metros
    FROM public.especialistas e
    JOIN LATERAL (
        SELECT ue.latitud, ue.longitud, ue.ubicacion
        FROM public.ubicaciones_especialista ue
        WHERE ue.especialista_id = e.id
        ORDER BY ue.created_at DESC
        LIMIT 1
    ) u ON TRUE
    JOIN public.profiles p ON p.id = e.usuario_id
    WHERE e.estado_verificacion = 'APROBADO'
      AND e.activo              = TRUE
      AND e.disponible          = TRUE
      AND e.en_linea            = TRUE
      AND e.ultima_conexion     > now() - interval '3 minutes'
      AND ST_DWithin(
            u.ubicacion,
            ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::extensions.geography,
            p_radio_metros
          )
    ORDER BY u.ubicacion <-> ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::extensions.geography
    LIMIT p_limit;
$$;

GRANT EXECUTE ON FUNCTION public.buscar_especialistas_cercanos(NUMERIC, NUMERIC, NUMERIC, INTEGER)
    TO authenticated;

-- ── 4. RPC: solicitudes publicadas con ubicación aproximada del paciente ────
-- Devuelve al especialista la posición truncada (~110 m) y la ciudad, nunca la
-- dirección exacta. La dirección exacta se revela solo tras asignación.
CREATE OR REPLACE FUNCTION public.obtener_solicitudes_publicadas_geo()
RETURNS TABLE (
    solicitud_id    UUID,
    paciente_nombre TEXT,
    servicio_nombre TEXT,
    precio          NUMERIC,
    latitud_aprox   NUMERIC,
    longitud_aprox  NUMERIC,
    ciudad          TEXT,
    radio_busqueda  NUMERIC,
    fecha_expiracion TIMESTAMPTZ,
    estado          TEXT
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, extensions
AS $$
    SELECT s.id,
           pf.full_name,
           sv.nombre,
           sv.precio_base,
           round(dp.latitud::numeric, 3),
           round(dp.longitud::numeric, 3),
           dp.ciudad,
           s.radio_busqueda,
           s.fecha_expiracion,
           s.estado
    FROM public.solicitudes s
    JOIN public.direcciones_paciente dp ON dp.id = s.direccion_id
    JOIN public.pacientes p            ON p.id  = s.paciente_id
    JOIN public.profiles pf            ON pf.id = p.usuario_id
    JOIN public.servicios sv           ON sv.id = s.servicio_id
    WHERE s.estado IN ('PUBLICADA', 'BUSCANDO_ESPECIALISTA')
    ORDER BY s.fecha_solicitud ASC;
$$;

GRANT EXECUTE ON FUNCTION public.obtener_solicitudes_publicadas_geo()
    TO authenticated;
