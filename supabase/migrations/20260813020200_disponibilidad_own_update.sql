-- =============================================================================
-- Migración: permite al especialista (dueño) actualizar su propio `disponible`.
-- -----------------------------------------------------------------------------
-- El trigger `proteger_verificacion_especialista` bloqueaba cualquier cambio de
-- `disponible` por parte del dueño (lo trataba como columna de verificación).
-- El especialista debe poder alternar su disponibilidad sin pasar por un admin,
-- así que se quita `disponible` de la lista protegida en UPDATE, manteniendo
-- protegidos estado_verificacion, activo, aprobado_por, fechas y observacion.
-- En INSERT se conserva la regla: la solicitud solo nace PENDIENTE/activo=false/
-- disponible=false.
-- Idempotente: CREATE OR REPLACE FUNCTION + DROP TRIGGER + CREATE TRIGGER.
-- =============================================================================

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
