-- =============================================================================
-- MIGRACIÓN: "Documento visto" antes de aprobar/rechazar (Verificación de
-- Licencias, panel admin).
-- -----------------------------------------------------------------------------
-- Hueco detectado: el administrador podía aprobar/rechazar un documento
-- (Diploma, Licencia, Identificación…) sin haber abierto el archivo adjunto.
-- Esta migración:
--   1) Añade `visto_por` / `visto_en` a `documentos_especialista`.
--   2) RPC `marcar_documento_visto(p_documento_id)`: solo el administrador
--      puede marcar un documento como visto (setea visto_por/visto_en con la
--      hora del servidor) y deja constancia en `auditoria`.
--   3) Extiende `proteger_revision_documento()`:
--        - el dueño (no-admin) no puede escribir visto_por/visto_en;
--        - el administrador no puede pasar a APROBADO/RECHAZADO si el
--          documento no fue marcado como visto (visto_en IS NULL).
--   4) Extiende el trigger de auditoría para trazar visto_por/visto_en.
-- Idempotente (ADD COLUMN IF NOT EXISTS / CREATE OR REPLACE / DROP TRIGGER IF EXISTS).
-- Aplicar en orden ascendente (crea la tabla/columnas antes de usarlas).
-- =============================================================================

-- ── 1. Columnas de visto ─────────────────────────────────────────────────────
ALTER TABLE public.documentos_especialista
    ADD COLUMN IF NOT EXISTS visto_por uuid REFERENCES public.profiles(id) ON DELETE SET NULL;

ALTER TABLE public.documentos_especialista
    ADD COLUMN IF NOT EXISTS visto_en timestamptz;

-- ── 2. RPC marcar_documento_visto ────────────────────────────────────────────
-- Solo el administrador puede marcar como visto. La hora la fija el servidor.
CREATE OR REPLACE FUNCTION public.marcar_documento_visto(p_documento_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NOT public.is_administrador() THEN
        RAISE EXCEPTION 'No autorizado';
    END IF;

    UPDATE public.documentos_especialista
       SET visto_por = auth.uid(),
           visto_en  = now(),
           updated_at = now()
     WHERE id = p_documento_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'RN: documento no encontrado';
    END IF;

    PERFORM public.registrar_auditoria(
        auth.uid(),
        'DOCUMENTO_VISTO',
        'documentos_especialista',
        p_documento_id::text,
        jsonb_build_object('visto_en', now())
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.marcar_documento_visto(uuid) TO authenticated;

-- ── 3. proteger_revision_documento: visto obligatorio + visto_* protegido ────
CREATE OR REPLACE FUNCTION public.proteger_revision_documento()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    es_admin BOOLEAN;
BEGIN
    SELECT (p.role = 'Administrador') INTO es_admin
    FROM public.profiles p
    WHERE p.id = auth.uid();

    IF es_admin THEN
        -- Un dictamen (APROBADO/RECHAZADO) exige haber abierto el documento antes.
        IF TG_OP = 'UPDATE'
           AND NEW.estado_revision IS DISTINCT FROM OLD.estado_revision
           AND NEW.estado_revision IN ('APROBADO', 'RECHAZADO')
           AND NEW.visto_en IS NULL THEN
            RAISE EXCEPTION 'Debes abrir y revisar el documento antes de aprobarlo o rechazarlo';
        END IF;

        RETURN NEW;
    END IF;

    IF TG_OP = 'INSERT' THEN
        IF NEW.estado_revision::text IS DISTINCT FROM 'PENDIENTE'
           OR NEW.activo IS DISTINCT FROM TRUE
           OR NEW.revisado_por IS NOT NULL
           OR NEW.fecha_revision IS NOT NULL
           OR NEW.visto_por IS NOT NULL
           OR NEW.visto_en IS NOT NULL THEN
            RAISE EXCEPTION 'Un documento solo puede registrarse pendiente de revisión';
        END IF;

        -- El especialista no puede duplicar un tipo aprobado ni apilar
        -- pendientes del mismo tipo; solo primera carga o re-subida de uno
        -- RECHAZADO (los documentos aprobados se conservan).
        IF EXISTS (
            SELECT 1 FROM public.documentos_especialista d
             WHERE d.especialista_id = NEW.especialista_id
               AND d.tipo_documento = NEW.tipo_documento
               AND d.estado_revision = 'APROBADO'
        ) THEN
            RAISE EXCEPTION 'El documento de este tipo ya fue aprobado; no puedes re-subirlo.';
        END IF;

        IF EXISTS (
            SELECT 1 FROM public.documentos_especialista d
             WHERE d.especialista_id = NEW.especialista_id
               AND d.tipo_documento = NEW.tipo_documento
               AND d.estado_revision = 'PENDIENTE'
        ) THEN
            RAISE EXCEPTION 'Ya tienes un documento de este tipo pendiente de revisión.';
        END IF;

        RETURN NEW;
    END IF;

    IF NEW.estado_revision IS DISTINCT FROM OLD.estado_revision
       OR NEW.observacion_revision IS DISTINCT FROM OLD.observacion_revision
       OR NEW.revisado_por IS DISTINCT FROM OLD.revisado_por
       OR NEW.fecha_revision IS DISTINCT FROM OLD.fecha_revision
       OR NEW.activo IS DISTINCT FROM OLD.activo
       OR NEW.visto_por IS DISTINCT FROM OLD.visto_por
       OR NEW.visto_en IS DISTINCT FROM OLD.visto_en THEN
        RAISE EXCEPTION 'Solo el administrador puede revisar documentos';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_proteger_revision_documento ON public.documentos_especialista;
CREATE TRIGGER trg_proteger_revision_documento
    BEFORE INSERT OR UPDATE ON public.documentos_especialista
    FOR EACH ROW EXECUTE FUNCTION public.proteger_revision_documento();

-- ── 4. Auditoría: trazar visto_por/visto_en ──────────────────────────────────
DROP TRIGGER IF EXISTS trg_auditoria_documentos_especialista ON public.documentos_especialista;
CREATE TRIGGER trg_auditoria_documentos_especialista
    AFTER INSERT OR UPDATE OR DELETE ON public.documentos_especialista
    FOR EACH ROW
    EXECUTE FUNCTION public.auditar_entidad(
        'estado_revision', 'observacion_revision', 'revisado_por',
        'fecha_revision', 'activo', 'visto_por', 'visto_en'
    );
