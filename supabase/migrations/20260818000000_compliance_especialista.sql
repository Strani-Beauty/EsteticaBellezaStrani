-- =============================================================================
-- Migración: Compliance de especialistas — expediente completo, habilitación
-- gated y notificaciones in-app.
-- -----------------------------------------------------------------------------
--   * RLS para `notificaciones` (el especialista lee/actualiza las suyas; el
--     administrador gestiona todas).
--   * Función `cumple_requisitos_habilitacion(especialista_id)` que define el
--     expediente habilitante: 3 documentos APROBADOS (identificación, licencia
--     y formación = diploma|certificación) + datos profesionales (médico
--     regente activo + ≥1 especialidad) + contrato firmado.
--   * Trigger `trg_validar_habilitacion_especialista`: solo se puede pasar a
--     estado_verificacion='APROBADO' si el expediente está completo (aunque lo
--     haga un administrador). Ítem 10.
--   * Extiende `proteger_verificacion_especialista`: el especialista solo puede
--     activar su `disponible` si está APROBADO y activo. Ítem 14.
--   * Extiende `proteger_revision_documento`: el especialista solo puede subir
--     la primera versión de un tipo o re-subir un documento RECHAZADO; no puede
--     duplicar un APROBADO ni apilar PENDIENTES del mismo tipo. Ítem 8.
--   * Triggers de notificación in-app: documento RECHAZADO y verificación
--     APROBADA insertan en `notificaciones`. Ítem 13.
--   * Endurece `aceptar_solicitud` con el chequeo de expediente. Ítems 12/14.
-- Idempotente: CREATE OR REPLACE FUNCTION + DROP TRIGGER/POLICY IF EXISTS +
-- CREATE INDEX IF NOT EXISTS.
-- =============================================================================

-- ── 1. RLS `notificaciones` ────────────────────────────────────────────────
ALTER TABLE public.notificaciones ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "notificacion_own_select" ON public.notificaciones;
CREATE POLICY "notificacion_own_select"
    ON public.notificaciones
    FOR SELECT TO authenticated
    USING (auth.uid() = usuario_id);

DROP POLICY IF EXISTS "notificacion_own_update" ON public.notificaciones;
CREATE POLICY "notificacion_own_update"
    ON public.notificaciones
    FOR UPDATE TO authenticated
    USING (auth.uid() = usuario_id)
    WITH CHECK (auth.uid() = usuario_id);

DROP POLICY IF EXISTS "notificacion_admin_all" ON public.notificaciones;
CREATE POLICY "notificacion_admin_all"
    ON public.notificaciones
    FOR ALL TO authenticated
    USING (public.is_administrador())
    WITH CHECK (public.is_administrador());

CREATE INDEX IF NOT EXISTS idx_notificaciones_usuario_leida
    ON public.notificaciones (usuario_id, leida);

-- ── 2. Función de expediente habilitante ──────────────────────────────────
CREATE OR REPLACE FUNCTION public.cumple_requisitos_habilitacion(
    p_especialista uuid
)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
DECLARE
    v_ok_docs       boolean;
    v_ok_profesional boolean;
    v_ok_contrato   boolean;
BEGIN
    -- Documentos obligatorios APROBADOS (formación = diploma O certificación).
    SELECT
        EXISTS (
            SELECT 1 FROM public.documentos_especialista d
             WHERE d.especialista_id = p_especialista
               AND d.tipo_documento = 'IDENTIFICACION'
               AND d.estado_revision = 'APROBADO'
               AND d.activo = TRUE
        )
        AND EXISTS (
            SELECT 1 FROM public.documentos_especialista d
             WHERE d.especialista_id = p_especialista
               AND d.tipo_documento = 'LICENCIA'
               AND d.estado_revision = 'APROBADO'
               AND d.activo = TRUE
        )
        AND EXISTS (
            SELECT 1 FROM public.documentos_especialista d
             WHERE d.especialista_id = p_especialista
               AND d.tipo_documento IN ('DIPLOMA', 'CERTIFICACION')
               AND d.estado_revision = 'APROBADO'
               AND d.activo = TRUE
        )
    INTO v_ok_docs;

    -- Datos profesionales: médico regente activo + al menos una especialidad.
    SELECT
        EXISTS (
            SELECT 1 FROM public.especialistas e
              JOIN public.medicos_regentes m ON m.id = e.medico_regente_id
             WHERE e.id = p_especialista
               AND m.activo = TRUE
        )
        AND EXISTS (
            SELECT 1 FROM public.especialista_especialidades ee
             WHERE ee.especialista_id = p_especialista
        )
    INTO v_ok_profesional;

    -- Contrato firmado.
    SELECT EXISTS (
        SELECT 1 FROM public.contratos c
         WHERE c.especialista_id = p_especialista
           AND c.firmado = TRUE
    ) INTO v_ok_contrato;

    RETURN v_ok_docs AND v_ok_profesional AND v_ok_contrato;
END;
$$;

-- ── 3. Trigger: Verificado solo con expediente completo (ítem 10) ─────────
CREATE OR REPLACE FUNCTION public.validar_habilitacion_especialista()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
    IF NEW.estado_verificacion = 'APROBADO'
       AND NOT public.cumple_requisitos_habilitacion(NEW.id) THEN
        RAISE EXCEPTION
            'No se puede aprobar: el expediente no está completo (documentos aprobados, datos profesionales y contrato firmado).';
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validar_habilitacion_especialista ON public.especialistas;
CREATE TRIGGER trg_validar_habilitacion_especialista
    BEFORE UPDATE OF estado_verificacion ON public.especialistas
    FOR EACH ROW EXECUTE FUNCTION public.validar_habilitacion_especialista();

-- ── 4. `proteger_verificacion_especialista`: disponible solo si verificado ─
-- El dueño sigue pudiendo alternar su `disponible`, pero solo puede activarlo
-- (true) si ya está APROBADO y activo. Ítem 14.
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

    -- Activar disponibilidad exige estar verificado (y activo).
    IF NEW.disponible
       AND NOT (NEW.estado_verificacion = 'APROBADO' AND NEW.activo) THEN
        RAISE EXCEPTION 'Debes estar verificado para activar tu disponibilidad';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_proteger_verificacion_especialista ON public.especialistas;
CREATE TRIGGER trg_proteger_verificacion_especialista
    BEFORE INSERT OR UPDATE ON public.especialistas
    FOR EACH ROW EXECUTE FUNCTION public.proteger_verificacion_especialista();

-- ── 5. `proteger_revision_documento`: re-subida solo de RECHAZADO (ítem 8) ─
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

-- ── 6. Notificaciones in-app (ítem 13) ────────────────────────────────────
-- Documento rechazado → notificar al especialista dueño.
CREATE OR REPLACE FUNCTION public.notificar_documento_rechazado()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_usuario      uuid;
    v_nombre_tipo  text;
BEGIN
    IF TG_OP = 'UPDATE'
       AND NEW.estado_revision = 'RECHAZADO'
       AND OLD.estado_revision IS DISTINCT FROM 'RECHAZADO' THEN
        SELECT e.usuario_id INTO v_usuario
          FROM public.especialistas e
         WHERE e.id = NEW.especialista_id;

        IF v_usuario IS NULL THEN
            RETURN NEW;
        END IF;

        v_nombre_tipo := replace(NEW.tipo_documento::text, '_', ' ');

        INSERT INTO public.notificaciones (usuario_id, titulo, mensaje, tipo, fecha_envio)
        VALUES (
            v_usuario,
            'Documento rechazado',
            'Tu ' || lower(v_nombre_tipo) || ' (versión ' || NEW.version_documento || ') fue rechazado'
            || CASE WHEN NEW.observacion_revision IS NOT NULL AND NEW.observacion_revision <> ''
                    THEN ': ' || NEW.observacion_revision
                    ELSE '' END
            || '. Puedes corregirlo y reenviarlo desde Documentos.',
            'DOCUMENTO_RECHAZADO',
            now()
        );
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notificar_documento_rechazado ON public.documentos_especialista;
CREATE TRIGGER trg_notificar_documento_rechazado
    AFTER UPDATE ON public.documentos_especialista
    FOR EACH ROW EXECUTE FUNCTION public.notificar_documento_rechazado();

-- Verificación aprobada → notificar al especialista.
CREATE OR REPLACE FUNCTION public.notificar_verificacion_aprobada()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF TG_OP = 'UPDATE'
       AND NEW.estado_verificacion = 'APROBADO'
       AND OLD.estado_verificacion IS DISTINCT FROM 'APROBADO' THEN
        INSERT INTO public.notificaciones (usuario_id, titulo, mensaje, tipo, fecha_envio)
        VALUES (
            NEW.usuario_id,
            'Verificación aprobada',
            'Tu expediente fue aprobado. Ya puedes activar tu disponibilidad y operar en el marketplace.',
            'VERIFICACION_APROBADA',
            now()
        );
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notificar_verificacion_aprobada ON public.especialistas;
CREATE TRIGGER trg_notificar_verificacion_aprobada
    AFTER UPDATE ON public.especialistas
    FOR EACH ROW EXECUTE FUNCTION public.notificar_verificacion_aprobada();

-- ── 7. Endurecer `aceptar_solicitud` (ítems 12/14, defensa en profundidad) ─
CREATE OR REPLACE FUNCTION public.aceptar_solicitud(
  p_solicitud_id uuid,
  p_especialista_id uuid
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_estado              text;
  v_claim               int;
  v_cita_id             uuid;
  v_especialista_valido boolean;
begin
  select estado into v_estado
    from public.solicitudes
   where id = p_solicitud_id;

  if v_estado is null then
    return json_build_object('aceptada', false, 'cita_id', null, 'motivo', 'NO_ENCONTRADA');
  end if;

  if v_estado not in ('PUBLICADA', 'BUSCANDO_ESPECIALISTA') then
    return json_build_object('aceptada', false, 'cita_id', null, 'motivo', 'ASIGNADA');
  end if;

  -- Validación de habilitación: APROBADO, activo y expediente completo.
  select exists (
    select 1 from public.especialistas
     where id = p_especialista_id
       and estado_verificacion = 'APROBADO'
       and activo = true
       and public.cumple_requisitos_habilitacion(id)
  ) into v_especialista_valido;

  if not v_especialista_valido then
    return json_build_object('aceptada', false, 'cita_id', null, 'motivo', 'NO_APROBADO');
  end if;

  -- Claim atómico: solo cambia si sigue publicada/buscando y no expirada.
  update public.solicitudes
     set estado     = 'ACEPTADA',
         updated_at = now()
   where id = p_solicitud_id
     and estado in ('PUBLICADA', 'BUSCANDO_ESPECIALISTA')
     and (fecha_expiracion is null or now() < fecha_expiracion);

  get diagnostics v_claim = row_count;

  if v_claim = 0 then
    -- Expiró o fue tomada entre la lectura y el update.
    return json_build_object('aceptada', false, 'cita_id', null, 'motivo', 'EXPIRADA');
  end if;

  insert into public.citas (solicitud_id, especialista_id, estado, fecha_aceptacion)
  values (p_solicitud_id, p_especialista_id, 'PROGRAMADA', now())
  returning id into v_cita_id;

  return json_build_object('aceptada', true, 'cita_id', v_cita_id, 'motivo', 'OK');
end;
$$;

grant execute on function public.aceptar_solicitud(uuid, uuid) to authenticated;