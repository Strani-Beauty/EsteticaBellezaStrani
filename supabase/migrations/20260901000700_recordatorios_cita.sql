-- =============================================================================
-- Migración: Recordatorio previo a cita (P6 de las pruebas de control).
-- -----------------------------------------------------------------------------
-- Actividad 7 del módulo "Notificaciones Push y Sistema de Calificaciones":
-- recordatorio push previo a la cita según config del sistema. Se implementa
-- con pg_cron (extensión disponible en el remoto, versión 1.6.4):
--   * Clave `recordatorio_horas_previas` (NUMERIC, por defecto 2): horas antes
--     de `citas.fecha_inicio` en las que se dispara el recordatorio.
--   * Tabla `recordatorios_cita` (cita_id PK, fecha_envio): idempotencia — solo
--     se notifica una vez por cita aunque el job corra varias veces en la ventana.
--   * Función `enviar_recordatorios_cita()` SECURITY DEFINER: busca citas
--     PROGRAMADAS con fecha_inicio en (now(), now()+horas) sin recordatorio ya
--     enviado y notifica al paciente vía `notificar_usuario_push` (in-app + push
--     FCM, tipo `RECORDATORIO_CITA`).
--   * Job `recordatorios-cita` cada 15 minutos.
-- Idempotente (DROP ... IF EXISTS + cron.unschedule + CREATE OR REPLACE).
-- =============================================================================

-- ── 1. Seed de configuración ────────────────────────────────────────────────
INSERT INTO public.configuracion_sistema
    (id, clave, valor, tipo_dato, descripcion, activo, updated_at)
VALUES
    (gen_random_uuid(), 'recordatorio_horas_previas', '2', 'NUMERIC',
     'Horas previas a la cita en las que se envía el recordatorio', true, now())
ON CONFLICT (clave) DO UPDATE
    SET descripcion = EXCLUDED.descripcion, activo = true, updated_at = now();

-- ── 2. Tabla de recordatorios enviados (idempotencia) ──────────────────────
CREATE TABLE IF NOT EXISTS public.recordatorios_cita (
    cita_id     uuid PRIMARY KEY REFERENCES public.citas(id) ON DELETE CASCADE,
    fecha_envio timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.recordatorios_cita ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS recordatorio_cita_admin_select ON public.recordatorios_cita;
CREATE POLICY recordatorio_cita_admin_select
    ON public.recordatorios_cita
    FOR SELECT TO authenticated
    USING (public.is_administrador());

-- ── 3. Función que envía los recordatorios ─────────────────────────────────
CREATE OR REPLACE FUNCTION public.enviar_recordatorios_cita()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
    v_horas_previas numeric;
    v_cita          record;
    v_usuario       uuid;
BEGIN
    SELECT COALESCE(valor::numeric, 2) INTO v_horas_previas
      FROM public.configuracion_sistema
     WHERE clave = 'recordatorio_horas_previas' AND activo = true;

    IF v_horas_previas IS NULL OR v_horas_previas <= 0 THEN
        v_horas_previas := 2;
    END IF;

    FOR v_cita IN
        SELECT c.id, c.fecha_inicio, s.paciente_id
          FROM public.citas c
          JOIN public.solicitudes s ON s.id = c.solicitud_id
         WHERE c.estado = 'PROGRAMADA'
           AND c.fecha_inicio IS NOT NULL
           AND c.fecha_inicio > now()
           AND c.fecha_inicio <= now() + (v_horas_previas * interval '1 hour')
           AND NOT EXISTS (
               SELECT 1 FROM public.recordatorios_cita rc
                WHERE rc.cita_id = c.id
           )
    LOOP
        SELECT pa.usuario_id INTO v_usuario
          FROM public.pacientes pa
         WHERE pa.id = v_cita.paciente_id;

        IF v_usuario IS NOT NULL THEN
            PERFORM public.notificar_usuario_push(
                v_usuario,
                'Recordatorio de cita',
                'Tu cita está programada para el '
                || to_char(v_cita.fecha_inicio AT TIME ZONE 'UTC', 'YYYY-MM-DD HH24:MI')
                || '. Recuerda tener todo listo.',
                'RECORDATORIO_CITA',
                jsonb_build_object('cita_id', v_cita.id, 'fecha_inicio', v_cita.fecha_inicio)
            );
        END IF;

        INSERT INTO public.recordatorios_cita (cita_id, fecha_envio)
        VALUES (v_cita.id, now())
        ON CONFLICT (cita_id) DO NOTHING;
    END LOOP;
END;
$$;

GRANT EXECUTE ON FUNCTION public.enviar_recordatorios_cita() TO authenticated;

-- ── 4. pg_cron: job cada 15 minutos ─────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS pg_cron;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'recordatorios-cita') THEN
        PERFORM cron.unschedule('recordatorios-cita');
    END IF;
END $$;

SELECT cron.schedule(
    'recordatorios-cita',
    '*/15 * * * *',
    $$ SELECT public.enviar_recordatorios_cita(); $$
);