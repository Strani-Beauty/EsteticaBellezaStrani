-- =============================================================================
-- MIGRACIÓN: Backfill de `ubicaciones_especialista` desde `profiles`.
-- -----------------------------------------------------------------------------
-- La dirección del especialista se guarda en `profiles` (address, latitude,
-- longitude), pero el mapa del Marketplace y el RPC `obtener_solicitudes_
-- publicadas_geo` leen `ubicaciones_especialista` (geography PostGIS). No hay
-- trigger que sincronice ambas tablas, así que los especialistas que guardaron
-- Datos personales pero nunca la pestaña Profesional quedan sin fila geo y el
-- RPC (que exige `u.ubicacion IS NOT NULL`) nunca los devuelve.
--
-- Este backfill inserta la ubicación base desde `profiles` para especialistas
-- APROBADOS y activos con coordenadas válidas que aún no tienen fila en
-- `ubicaciones_especialista`. El flujo normal (guardar Datos personales en el
-- perfil) queda sincronizado por la app.
--
-- Aplicar con `supabase db push` o desde el SQL Editor del dashboard.
-- Idempotente (INSERT ... SELECT ... WHERE NOT EXISTS).
-- =============================================================================

INSERT INTO public.ubicaciones_especialista
    (especialista_id, latitud, longitud, ubicacion, precision_metros, fecha_actualizacion, created_at)
SELECT e.id,
       p.latitude,
       p.longitude,
       ('SRID=4326;POINT(' || p.longitude || ' ' || p.latitude || ')')::geography,
       0,
       now(),
       now()
  FROM public.profiles p
  JOIN public.especialistas e ON e.usuario_id = p.id
 WHERE p.latitude IS NOT NULL
   AND p.longitude IS NOT NULL
   AND e.estado_verificacion = 'APROBADO'
   AND e.activo = true
   AND NOT EXISTS (
       SELECT 1 FROM public.ubicaciones_especialista ue
        WHERE ue.especialista_id = e.id
   );