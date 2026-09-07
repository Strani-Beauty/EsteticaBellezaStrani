-- =============================================================================
-- Migración: Endurecimiento de seguridad previo a pruebas manuales.
-- -----------------------------------------------------------------------------
--   * REVOKE de EXECUTE a `authenticated`/`anon` en funciones SECURITY DEFINER
--     con escalada de privilegios (solo service_role y triggers las invocan).
--   * Elimina policies "blanket" (USING true) que anulaban las policies
--     restrictivas en datos clínicos, direcciones y catálogo de cuestionarios.
--   * Restringe la lectura de solicitudes publicadas a especialistas APROBADOS
--     y activos (RN-018: un paciente NO debe ver solicitudes de otros).
--   * `medicos_regentes`: lectura completa solo para administradores; los
--     especialistas ven una vista pública sin teléfono/correo.
--   * Bucket `contratos` (firmas manuscritas): pasa a PRIVADO con lectura por
--     URL firmada (dueño y admin), migrando `url_documento` a path.
--   * `respuestas_salud`: el paciente solo SELECT/INSERT (sin UPDATE/DELETE).
--   * `registrar_validacion_telemedicina`: el dictamen clínico ya no marca
--     `payment_completed`; solo el pago real de la cuota inicial lo registra.
-- Idempotente (DROP POLICY IF EXISTS / CREATE OR REPLACE / REVOKE no-op).
-- Aplicar con `supabase db push` o desde el SQL Editor del dashboard.
-- =============================================================================

-- ── 1. Revocar EXECUTE de funciones SECURITY DEFINER a roles de cliente ──────
-- La escritura de auditoría, las notificaciones/push y los recordatorios se
-- disparan SOLO desde triggers SECURITY DEFINER (owner = postgres) o desde
-- service_role. `authenticated`/`anon` no deben poder forzarlas.
REVOKE EXECUTE ON FUNCTION public.registrar_auditoria(uuid, text, text, text, jsonb)
    FROM anon, authenticated, PUBLIC;

REVOKE EXECUTE ON FUNCTION public.notificar_usuario_push(uuid, text, text, text, jsonb)
    FROM anon, authenticated, PUBLIC;

REVOKE EXECUTE ON FUNCTION public.enviar_recordatorios_cita()
    FROM anon, authenticated, PUBLIC;

-- ── 2. Eliminar policies "blanket" que anulan las restrictivas ───────────────
-- Estas policies (USING true / WITH CHECK true) exponen datos clínicos y
-- direcciones de TODOS los pacientes a cualquier usuario autenticado. Las
-- policies correctas ya existen por tabla y vuelven a ser efectivas al quitarlas.
DROP POLICY IF EXISTS "Permitir todo a usuarios autenticados en direcciones"
    ON public.direcciones_paciente;
DROP POLICY IF EXISTS "Permitir todo a usuarios autenticados en evaluaciones"
    ON public.evaluaciones_salud;
DROP POLICY IF EXISTS "Permitir todo a usuarios autenticados en respuestas"
    ON public.respuestas_salud;
DROP POLICY IF EXISTS "Permitir todo a usuarios autenticados en validaciones"
    ON public.validaciones_telemedicina;
DROP POLICY IF EXISTS "Permitir todo a usuarios autenticados en preguntas"
    ON public.preguntas;
DROP POLICY IF EXISTS "Permitir todo a usuarios autenticados en cuestionarios"
    ON public.cuestionarios;

-- ── 3. Solicitudes publicadas: solo especialistas APROBADOS y activos ────────
DROP POLICY IF EXISTS "solicitud_especialista_select_publicada" ON public.solicitudes;
CREATE POLICY "solicitud_especialista_select_publicada"
    ON public.solicitudes
    FOR SELECT TO authenticated
    USING (
        estado = ANY (ARRAY['PUBLICADA'::estado_solicitud_enum, 'BUSCANDO_ESPECIALISTA'::estado_solicitud_enum])
        AND EXISTS (
            SELECT 1 FROM public.especialistas e
            WHERE e.usuario_id = auth.uid()
              AND e.estado_verificacion = 'APROBADO'
              AND e.activo = true
        )
    );

-- ── 4. Médicos regentes: contacto solo para administradores ─────────────────
-- 4.1 El admin lee la tabla completa (incluye teléfono/correo/licencia).
DROP POLICY IF EXISTS "medicos_regentes_select" ON public.medicos_regentes;
DROP POLICY IF EXISTS "medicos_regentes_admin_select" ON public.medicos_regentes;
CREATE POLICY "medicos_regentes_admin_select"
    ON public.medicos_regentes
    FOR SELECT TO authenticated
    USING (public.is_administrador());

-- 4.2 Los especialistas (y demás autenticados) leen una vista pública SIN
--     teléfono ni correo. La vista es owner=postgres; RLS de la tabla base no
--     se aplica al propietario (confirmar con sondeo post-aplicación).
CREATE OR REPLACE VIEW public.medicos_regentes_publico AS
SELECT id, nombre, numero_licencia, estado, activo, created_at, updated_at
FROM public.medicos_regentes;

REVOKE ALL ON public.medicos_regentes_publico FROM anon, authenticated, public;
GRANT SELECT ON public.medicos_regentes_publico TO authenticated;

-- ── 5. Bucket `contratos` (firmas manuscritas): PRIVADO + URLs firmadas ──────
-- 5.1 El bucket deja de ser público.
UPDATE storage.buckets SET public = false WHERE id = 'contratos';

-- 5.2 Se elimina la lectura pública de objetos del bucket.
DROP POLICY IF EXISTS "contrato_storage_public_select" ON storage.objects;

-- 5.3 SELECT: el especialista dueño lee sus propias firmas. Soporta tanto el
--     path nuevo '<especialistaId>/firma_*.png' (foldername[1]) como el path
--     histórico 'contratos/<especialistaId>/firma_*.png' (foldername[2]).
DROP POLICY IF EXISTS "contrato_storage_own_select" ON storage.objects;
CREATE POLICY "contrato_storage_own_select"
    ON storage.objects
    FOR SELECT TO authenticated
    USING (
        bucket_id = 'contratos'
        AND (
            (storage.foldername(name))[1] = (
                SELECT id::text FROM public.especialistas
                WHERE usuario_id = auth.uid() LIMIT 1
            )
            OR (storage.foldername(name))[2] = (
                SELECT id::text FROM public.especialistas
                WHERE usuario_id = auth.uid() LIMIT 1
            )
        )
    );

-- 5.4 SELECT: el administrador lee las firmas de todos.
DROP POLICY IF EXISTS "contrato_storage_admin_select" ON storage.objects;
CREATE POLICY "contrato_storage_admin_select"
    ON storage.objects
    FOR SELECT TO authenticated
    USING (
        bucket_id = 'contratos'
        AND (SELECT p.role FROM public.profiles p WHERE p.id = auth.uid()) = 'Administrador'
    );

-- 5.5 Migrar `url_documento` de URL pública a path de storage (createSignedUrl).
UPDATE public.contratos
SET url_documento = regexp_replace(
        url_documento,
        '^.*/object/public/contratos/',
        ''
    ),
    updated_at = NOW()
WHERE url_documento LIKE '%/object/public/contratos/%';

-- ── 6. respuestas_salud: el paciente solo SELECT/INSERT (sin UPDATE/DELETE) ──
DROP POLICY IF EXISTS "respuesta_salud_paciente_own" ON public.respuestas_salud;
DROP POLICY IF EXISTS "respuesta_salud_paciente_select" ON public.respuestas_salud;
DROP POLICY IF EXISTS "respuesta_salud_paciente_insert" ON public.respuestas_salud;

CREATE POLICY "respuesta_salud_paciente_select"
    ON public.respuestas_salud
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.evaluaciones_salud ev
            JOIN public.pacientes p ON p.id = ev.paciente_id
            WHERE ev.id = respuestas_salud.evaluacion_id
              AND p.usuario_id = auth.uid()
        )
    );

CREATE POLICY "respuesta_salud_paciente_insert"
    ON public.respuestas_salud
    FOR INSERT TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.evaluaciones_salud ev
            JOIN public.pacientes p ON p.id = ev.paciente_id
            WHERE ev.id = respuestas_salud.evaluacion_id
              AND p.usuario_id = auth.uid()
        )
    );

-- ── 7. Qualify: el dictamen ya no marca payment_completed ────────────────────
-- El issue conocido (docs/2026-08-14, ítem 6): la RPC marcaba
-- `payment_completed = true` aunque el paciente pospusiera el pago de la cuota
-- inicial ($30). El dictamen clínico sigue activando el perfil (`activo`) y
-- marcando la evaluación (`evaluation_passed`), pero el pago real solo lo
-- registra `registerInitialPayment`. El pago es prerrequisito del flujo
-- (complete_profile bloquea con el modal de Stripe si `!paymentCompleted`), así
-- que un paciente APTO ya pagó y conserva `payment_completed = true`.
CREATE OR REPLACE FUNCTION public.registrar_validacion_telemedicina(
    p_aprobado BOOLEAN,
    p_proveedor TEXT,
    p_codigo_referencia TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_paciente_id UUID;
    v_fecha_validacion TIMESTAMPTZ := now();
    v_fecha_vencimiento TIMESTAMPTZ := now() + interval '365 days';
    v_estado TEXT := CASE WHEN p_aprobado THEN 'APROBADA' ELSE 'RECHAZADA' END;
    v_codigo TEXT := coalesce(
        p_codigo_referencia,
        upper(regexp_replace(p_proveedor, '[^A-Za-z0-9]', '_', 'g')) || '_VAL_' || extract(epoch from now())::BIGINT::TEXT
    );
    v_observaciones TEXT := 'Evaluación clínica aprobada por ' || p_proveedor || ' (válida por 1 año)';
    v_id UUID;
BEGIN
    SELECT p.id INTO v_paciente_id
    FROM public.pacientes p
    WHERE p.usuario_id = auth.uid()
    LIMIT 1;
    IF v_paciente_id IS NULL THEN
        RAISE EXCEPTION 'RN: no se encontró un paciente para el usuario actual';
    END IF;

    SELECT id INTO v_id
    FROM public.validaciones_telemedicina
    WHERE paciente_id = v_paciente_id
    ORDER BY created_at DESC
    LIMIT 1;

    IF v_id IS NOT NULL THEN
        UPDATE public.validaciones_telemedicina
        SET proveedor = p_proveedor,
            estado = v_estado,
            codigo_referencia = v_codigo,
            fecha_validacion = v_fecha_validacion,
            fecha_vencimiento = v_fecha_vencimiento,
            observaciones = v_observaciones,
            updated_at = now()
        WHERE id = v_id
        RETURNING id INTO v_id;
    ELSE
        INSERT INTO public.validaciones_telemedicina (
            paciente_id, proveedor, estado, codigo_referencia,
            fecha_validacion, fecha_vencimiento, observaciones,
            created_at, updated_at
        ) VALUES (
            v_paciente_id, p_proveedor, v_estado, v_codigo,
            v_fecha_validacion, v_fecha_vencimiento, v_observaciones,
            now(), now()
        )
        RETURNING id INTO v_id;
    END IF;

    -- El dictamen activa el perfil y marca la evaluación; el pago real
    -- (payment_completed) solo lo registra el pago de la cuota inicial.
    UPDATE public.profiles
    SET activo = p_aprobado,
        evaluation_passed = p_aprobado,
        updated_at = now()
    WHERE id = auth.uid();

    RETURN jsonb_build_object(
        'id', v_id,
        'estado', v_estado,
        'fecha_validacion', v_fecha_validacion,
        'fecha_vencimiento', v_fecha_vencimiento,
        'proveedor', p_proveedor,
        'codigo_referencia', v_codigo
    );
END;
$$;