-- =============================================================================
-- Migración: Feedback de verificación de especialistas.
-- -----------------------------------------------------------------------------
--   * agrega `especialistas.observacion` (motivo de rechazo/bloqueo visible
--     para el especialista)
--   * agrega policy de UPDATE para administradores sobre `especialistas`
--     (hoy solo existe admin SELECT; sin esta policy el admin no puede
--      aprobar/rechazar/bloquear licencias porque RLS filtra el UPDATE)
-- Aplicar con `supabase db push` o desde el SQL Editor del dashboard.
-- =============================================================================

-- 1. Columna `observacion` para feedback del admin ----------------------------
ALTER TABLE public.especialistas
    ADD COLUMN IF NOT EXISTS observacion TEXT;

-- 2. RLS: el administrador puede actualizar el estado de verificación ---------
DROP POLICY IF EXISTS "especialista_admin_update" ON public.especialistas;
CREATE POLICY "especialista_admin_update"
    ON public.especialistas
    FOR UPDATE TO authenticated
    USING ((SELECT p.role FROM public.profiles p WHERE p.id = auth.uid()) = 'Administrador')
    WITH CHECK ((SELECT p.role FROM public.profiles p WHERE p.id = auth.uid()) = 'Administrador');

-- 3. Protección: solo el admin cambia la verificación --------------------------
-- La policy "especialista_own_access" permite al dueño UPDATE de su fila, con lo
-- que un especialista podría auto-cambiarse estado/activo. Estos triggers cierran
-- ese hueco: para quien no es admin, INSERT solo con estado PENDIENTE (especialista)
-- / PENDIENTE (documento) y UPDATE únicamente de sus datos, quedando los estados de
-- verificación y revisión reservados al administrador. El especialista conserva la
-- posibilidad de solicitar revisión (PENDIENTE/RECHAZADO -> EN_REVISION).

CREATE OR REPLACE FUNCTION public.proteger_verificacion_especialista()
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
        RETURN NEW;
    END IF;

    IF TG_OP = 'INSERT' THEN
        IF NEW.estado_verificacion IS DISTINCT FROM 'PENDIENTE'
           OR NEW.activo IS DISTINCT FROM FALSE
           OR NEW.disponible IS DISTINCT FROM FALSE
           OR NEW.aprobado_por IS NOT NULL THEN
            RAISE EXCEPTION 'La solicitud de especialista solo puede crearse en estado PENDIENTE';
        END IF;
        RETURN NEW;
    END IF;

    IF ((NEW.estado_verificacion IS DISTINCT FROM OLD.estado_verificacion
         AND NOT (OLD.estado_verificacion IN ('PENDIENTE', 'RECHAZADO')
                  AND NEW.estado_verificacion = 'EN_REVISION'))
        OR NEW.activo IS DISTINCT FROM OLD.activo
        OR NEW.disponible IS DISTINCT FROM OLD.disponible
        OR NEW.aprobado_por IS DISTINCT FROM OLD.aprobado_por
        OR NEW.fecha_verificacion IS DISTINCT FROM OLD.fecha_verificacion
        OR NEW.fecha_aprobacion IS DISTINCT FROM OLD.fecha_aprobacion
        OR NEW.observacion IS DISTINCT FROM OLD.observacion) THEN
        RAISE EXCEPTION 'Solo el administrador puede modificar el estado de verificación';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_proteger_verificacion_especialista ON public.especialistas;
CREATE TRIGGER trg_proteger_verificacion_especialista
    BEFORE INSERT OR UPDATE ON public.especialistas
    FOR EACH ROW EXECUTE FUNCTION public.proteger_verificacion_especialista();

-- 4. Protección de revisión de documentos (misma regla) ------------------------
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
        RETURN NEW;
    END IF;

    IF TG_OP = 'INSERT' THEN
        IF NEW.estado_revision::text IS DISTINCT FROM 'PENDIENTE'
           OR NEW.activo IS DISTINCT FROM TRUE
           OR NEW.revisado_por IS NOT NULL
           OR NEW.fecha_revision IS NOT NULL THEN
            RAISE EXCEPTION 'Un documento solo puede registrarse pendiente de revisión';
        END IF;
        RETURN NEW;
    END IF;

    IF NEW.estado_revision IS DISTINCT FROM OLD.estado_revision
       OR NEW.observacion_revision IS DISTINCT FROM OLD.observacion_revision
       OR NEW.revisado_por IS DISTINCT FROM OLD.revisado_por
       OR NEW.fecha_revision IS DISTINCT FROM OLD.fecha_revision
       OR NEW.activo IS DISTINCT FROM OLD.activo THEN
        RAISE EXCEPTION 'Solo el administrador puede revisar documentos';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_proteger_revision_documento ON public.documentos_especialista;
CREATE TRIGGER trg_proteger_revision_documento
    BEFORE INSERT OR UPDATE ON public.documentos_especialista
    FOR EACH ROW EXECUTE FUNCTION public.proteger_revision_documento();