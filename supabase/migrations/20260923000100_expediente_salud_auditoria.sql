-- =============================================================================
-- MIGRACIÓN: Auditoría de acceso/exportación del expediente de salud (ePHI).
-- -----------------------------------------------------------------------------
-- En el ámbito HIPAA / ePHI, el acceso a los datos de salud del paciente por el
-- administrador debe quedar trazado. `registrar_auditoria` está revocado al
-- cliente (solo triggers SECURITY DEFINER), así que se expone un RPC acotado
-- para registrar eventos de expediente (VISTO / PDF) verificando que el
-- llamador sea administrador.
--   * accion: 'EXPEDIENTE_SALUD_VISTO' | 'EXPEDIENTE_SALUD_PDF' (u otras).
--   * entidad: 'pacientes'; entidad_id: paciente_id (uuid::text).
-- Idempotente (CREATE OR REPLACE FUNCTION).
-- Aplicar con `supabase db push` o desde el SQL Editor del dashboard.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.registrar_auditoria_expediente(
    p_paciente_id uuid,
    p_accion      text,
    p_detalle     jsonb DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NOT public.is_administrador() THEN
        RAISE EXCEPTION 'No autorizado';
    END IF;

    PERFORM public.registrar_auditoria(
        auth.uid(),
        p_accion,
        'pacientes',
        p_paciente_id::text,
        p_detalle
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.registrar_auditoria_expediente(uuid, text, jsonb)
    TO authenticated;