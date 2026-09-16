-- =============================================================================
-- MIGRACIÓN: Backfill de `direcciones_paciente` desde `profiles.address`.
-- -----------------------------------------------------------------------------
-- La app guardaba la dirección del paciente en `profiles` (address, latitude,
-- longitude) y solo creaba la fila espejo en `direcciones_paciente` al pagar la
-- cuota de $30. Resultado: el Resumen de la solicitud no encontraba dirección
-- ("Debes registrar una dirección antes de continuar").
-- Este backfill crea la fila principal para los pacientes que tienen dirección
-- en `profiles` y aún no tienen ninguna en `direcciones_paciente`.
--
-- Además alinea el esquema con lo que ya asume el código (`savePatientAddress`
-- inserta solo paciente_id/direccion/latitud/longitud/es_principal): ciudad,
-- estado y codigo_postal pasan a nullable. Sin este ALTER, cualquier guardado de
-- dirección desde la app fallaba silenciosamente por el NOT NULL.
--
-- * RLS: `direccion_paciente_own` (FOR ALL TO authenticated) ya permite al
--   paciente gestionar sus propias direcciones; no se requieren policies nuevas.
-- Aplicar con `supabase db push` o desde el SQL Editor del dashboard.
-- Idempotente (DROP NOT NULL / WHERE NOT EXISTS).
-- =============================================================================

-- ── 1. ciudad / estado / codigo_postal nullable (alinear con el código) ──────
ALTER TABLE public.direcciones_paciente ALTER COLUMN ciudad DROP NOT NULL;
ALTER TABLE public.direcciones_paciente ALTER COLUMN estado DROP NOT NULL;
ALTER TABLE public.direcciones_paciente ALTER COLUMN codigo_postal DROP NOT NULL;

-- ── 2. Backfill desde profiles ───────────────────────────────────────────────
INSERT INTO public.direcciones_paciente (paciente_id, direccion, latitud, longitud, es_principal)
SELECT pc.id, p.address, p.latitude, p.longitude, TRUE
  FROM public.profiles p
  JOIN public.pacientes pc ON pc.usuario_id = p.id
 WHERE p.address IS NOT NULL
   AND btrim(p.address) <> ''
   AND NOT EXISTS (
       SELECT 1 FROM public.direcciones_paciente dp
        WHERE dp.paciente_id = pc.id
   );
