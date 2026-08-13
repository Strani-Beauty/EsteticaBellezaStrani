-- =============================================================================
-- Migración: restringe `obtener_solicitudes_publicadas_geo` a especialistas
-- APROBADOS y activos (defensa en profundidad).
-- -----------------------------------------------------------------------------
-- El RPC devolvía las solicitudes publicadas a CUALQUIER usuario autenticado,
-- así que un especialista PENDIENTE/EN_REVISION/RECHAZADO podía visualizar el
-- Marketplace (aunque ya no podía aceptarlas gracias al refuerzo de
-- `aceptar_solicitud`). Ahora la función no devuelve filas a menos que
-- `auth.uid()` corresponda a un especialista `estado_verificacion = 'APROBADO'`
-- y `activo = true`.
-- Idempotente: CREATE OR REPLACE FUNCTION + GRANT repetible.
-- =============================================================================

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
      AND EXISTS (
          SELECT 1
            FROM public.especialistas e
           WHERE e.usuario_id = auth.uid()
             AND e.estado_verificacion = 'APROBADO'
             AND e.activo = TRUE
      )
    ORDER BY s.fecha_solicitud ASC;
$$;

GRANT EXECUTE ON FUNCTION public.obtener_solicitudes_publicadas_geo()
    TO authenticated;
