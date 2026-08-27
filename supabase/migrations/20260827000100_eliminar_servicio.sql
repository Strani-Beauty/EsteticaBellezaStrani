-- =============================================================================
-- MIGRACIÓN: Eliminar servicio del catálogo (admin) de forma segura.
-- -----------------------------------------------------------------------------
-- El admin necesita eliminar un servicio. Un DELETE directo a `servicios`
-- fallaría por las FKs sin ON DELETE CASCADE:
--   * solicitud_detalles.servicio_id (historial de negocio — NO se borra)
--   * solicitudes.servicio_id (columna legacy)
--   * servicio_especialidades.servicio_id
--   * servicio_cuestionarios.servicio_id
--   * face_maps.servicio_id (20260817010000, FK sin ON DELETE)
-- Esta función:
--   1. Si el servicio está referenciado en solicitudes/solicitud_detalles →
--      devuelve {ok:false, motivo:'REFERENCIADO'} (el historial es inmutable).
--   2. Borra sus relaciones servicio_especialidades y servicio_cuestionarios.
--   3. Pone face_maps.servicio_id = NULL en los mapas que lo referencien.
--   4. Borra la fila de servicios.
-- Idempotente (DROP FUNCTION IF EXISTS / CREATE OR REPLACE).
-- Aplicar desde el SQL Editor del Dashboard (o `supabase db push`).
-- =============================================================================

CREATE OR REPLACE FUNCTION public.eliminar_servicio(
    p_servicio_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
    v_referenciado boolean;
BEGIN
    -- 1. Historial de negocio: solicitudes y sus detalles no se tocan.
    SELECT EXISTS (
        SELECT 1 FROM public.solicitud_detalles sd
        WHERE sd.servicio_id = p_servicio_id
    ) OR EXISTS (
        SELECT 1 FROM public.solicitudes s
        WHERE s.servicio_id = p_servicio_id
    ) INTO v_referenciado;

    IF v_referenciado THEN
        RETURN json_build_object('ok', false, 'motivo', 'REFERENCIADO');
    END IF;

    -- 2. Relaciones del servicio (configuración, no historial).
    DELETE FROM public.servicio_especialidades
    WHERE servicio_id = p_servicio_id;

    DELETE FROM public.servicio_cuestionarios
    WHERE servicio_id = p_servicio_id;

    -- 3. Face maps que apuntaban al servicio: se desvinculan (no se borran).
    UPDATE public.face_maps
    SET servicio_id = NULL, updated_at = now()
    WHERE servicio_id = p_servicio_id;

    -- 4. Eliminar el servicio.
    DELETE FROM public.servicios
    WHERE id = p_servicio_id;

    RETURN json_build_object('ok', true, 'motivo', 'OK');
END;
$$;

GRANT EXECUTE ON FUNCTION public.eliminar_servicio(uuid) TO authenticated;