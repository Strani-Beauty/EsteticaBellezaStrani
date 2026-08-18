-- =============================================================================
-- Migración: Salud, Cuestionario y Validación del Paciente
-- -----------------------------------------------------------------------------
--  1. RLS en las tablas de salud (cuestionarios, preguntas, cuestionario_preguntas,
--     servicio_cuestionarios, evaluaciones_salud, respuestas_salud,
--     validaciones_telemedicina). Hoy están abiertas (sin policies).
--  2. Columnas nuevas: preguntas.opciones / preguntas.riesgo (sentinelas),
--     respuestas_salud.pregunta_texto (snapshot de la pregunta respondida),
--     pacientes.fecha_nacimiento/genero/grupo_sanguineo/alergias/antecedentes,
--     evaluaciones_salud.resultado + riesgos.
--  3. RPCs SECURITY DEFINER: guardar_respuestas_evaluacion (autoridad de la
--     evaluación: computa sentinelas -> riesgos/resultado) y
--     registrar_validacion_telemedicina (fechas de aprobación/vencimiento).
--  4. Trigger RN-020 en solicitudes (config-gated via enforce_rn020).
--  5. Seed del cuestionario real de salud (v1) con sus preguntas médicas.
-- Idempotente (ADD COLUMN IF NOT EXISTS / DROP POLICY IF EXISTS / ON CONFLICT).
-- =============================================================================

-- ── 0. Helper de rol administrador -------------------------------------------
CREATE OR REPLACE FUNCTION public.es_administrador()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid() AND role = 'Administrador'
    );
$$;

-- ── 1. Columnas nuevas --------------------------------------------------------

-- Catálogo de preguntas: opciones (LISTA/MULTIPLE) y regla de riesgo (sentinel).
ALTER TABLE public.preguntas
    ADD COLUMN IF NOT EXISTS opciones JSONB;
ALTER TABLE public.preguntas
    ADD COLUMN IF NOT EXISTS riesgo JSONB;

-- Snapshot del texto de la pregunta para conservar la versión respondida.
ALTER TABLE public.respuestas_salud
    ADD COLUMN IF NOT EXISTS pregunta_texto TEXT;

-- Info básica/clínica del paciente (revive PacienteEntity).
ALTER TABLE public.pacientes
    ADD COLUMN IF NOT EXISTS fecha_nacimiento DATE;
ALTER TABLE public.pacientes
    ADD COLUMN IF NOT EXISTS genero TEXT;
ALTER TABLE public.pacientes
    ADD COLUMN IF NOT EXISTS grupo_sanguineo TEXT;
ALTER TABLE public.pacientes
    ADD COLUMN IF NOT EXISTS alergias TEXT;
ALTER TABLE public.pacientes
    ADD COLUMN IF NOT EXISTS antecedentes TEXT;

-- Resultado de la evaluación sobre las respuestas (autoridad: RPC).
ALTER TABLE public.evaluaciones_salud
    ADD COLUMN IF NOT EXISTS resultado TEXT;
ALTER TABLE public.evaluaciones_salud
    ADD COLUMN IF NOT EXISTS riesgos JSONB;

-- Versiones de cuestionario: unique (nombre, version) tras deduplicar.
DO $$
DECLARE v_dup RECORD;
BEGIN
    FOR v_dup IN
        SELECT nombre, version, count(*) AS cnt
        FROM public.cuestionarios
        GROUP BY nombre, version
        HAVING count(*) > 1
    LOOP
        DELETE FROM public.cuestionarios c
        WHERE c.nombre = v_dup.nombre
          AND c.version = v_dup.version
          AND c.id NOT IN (
              SELECT id FROM public.cuestionarios
              WHERE nombre = v_dup.nombre AND version = v_dup.version
              ORDER BY activo DESC, created_at DESC
              LIMIT 1
          );
    END LOOP;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS cuestionarios_nombre_version_idx
    ON public.cuestionarios (nombre, version);

-- Tablas puente: dedupe + unique para que ON CONFLICT DO NOTHING sea idempotente.
DO $$
DECLARE v_dup RECORD;
BEGIN
    FOR v_dup IN
        SELECT cuestionario_id, pregunta_id, count(*) AS cnt
        FROM public.cuestionario_preguntas
        GROUP BY cuestionario_id, pregunta_id
        HAVING count(*) > 1
    LOOP
        DELETE FROM public.cuestionario_preguntas
        WHERE cuestionario_id = v_dup.cuestionario_id
          AND pregunta_id = v_dup.pregunta_id
          AND id NOT IN (
              SELECT id FROM public.cuestionario_preguntas
              WHERE cuestionario_id = v_dup.cuestionario_id
                AND pregunta_id = v_dup.pregunta_id
              ORDER BY id
              LIMIT 1
          );
    END LOOP;
END $$;
CREATE UNIQUE INDEX IF NOT EXISTS cuestionario_preguntas_cuestionario_pregunta_idx
    ON public.cuestionario_preguntas (cuestionario_id, pregunta_id);

DO $$
DECLARE v_dup RECORD;
BEGIN
    FOR v_dup IN
        SELECT servicio_id, cuestionario_id, count(*) AS cnt
        FROM public.servicio_cuestionarios
        GROUP BY servicio_id, cuestionario_id
        HAVING count(*) > 1
    LOOP
        DELETE FROM public.servicio_cuestionarios
        WHERE servicio_id = v_dup.servicio_id
          AND cuestionario_id = v_dup.cuestionario_id
          AND id NOT IN (
              SELECT id FROM public.servicio_cuestionarios
              WHERE servicio_id = v_dup.servicio_id
                AND cuestionario_id = v_dup.cuestionario_id
              ORDER BY id
              LIMIT 1
          );
    END LOOP;
END $$;
CREATE UNIQUE INDEX IF NOT EXISTS servicio_cuestionarios_servicio_cuestionario_idx
    ON public.servicio_cuestionarios (servicio_id, cuestionario_id);

-- Índices de las consultas calientes del flujo del paciente.
CREATE INDEX IF NOT EXISTS evaluaciones_salud_paciente_created_idx
    ON public.evaluaciones_salud (paciente_id, created_at DESC);
CREATE INDEX IF NOT EXISTS validaciones_telemedicina_paciente_created_idx
    ON public.validaciones_telemedicina (paciente_id, created_at DESC);
CREATE INDEX IF NOT EXISTS respuestas_salud_evaluacion_idx
    ON public.respuestas_salud (evaluacion_id);
CREATE INDEX IF NOT EXISTS cuestionario_preguntas_cuestionario_idx
    ON public.cuestionario_preguntas (cuestionario_id, orden);

-- ── 2. RLS -------------------------------------------------------------------

-- 2.1 Cuestionarios: catálogo legible por autenticados; CRUD solo admin.
ALTER TABLE public.cuestionarios ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "cuestionario_read" ON public.cuestionarios;
CREATE POLICY "cuestionario_read"
    ON public.cuestionarios FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "cuestionario_admin_write" ON public.cuestionarios;
CREATE POLICY "cuestionario_admin_write"
    ON public.cuestionarios FOR ALL TO authenticated
    USING (public.es_administrador())
    WITH CHECK (public.es_administrador());

-- 2.2 Preguntas: catálogo legible por autenticados; CRUD solo admin.
ALTER TABLE public.preguntas ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "pregunta_read" ON public.preguntas;
CREATE POLICY "pregunta_read"
    ON public.preguntas FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "pregunta_admin_write" ON public.preguntas;
CREATE POLICY "pregunta_admin_write"
    ON public.preguntas FOR ALL TO authenticated
    USING (public.es_administrador())
    WITH CHECK (public.es_administrador());

-- 2.3 Cuestionario-preguntas: relación legible; CRUD solo admin.
ALTER TABLE public.cuestionario_preguntas ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "cuestionario_pregunta_read" ON public.cuestionario_preguntas;
CREATE POLICY "cuestionario_pregunta_read"
    ON public.cuestionario_preguntas FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "cuestionario_pregunta_admin_write" ON public.cuestionario_preguntas;
CREATE POLICY "cuestionario_pregunta_admin_write"
    ON public.cuestionario_preguntas FOR ALL TO authenticated
    USING (public.es_administrador())
    WITH CHECK (public.es_administrador());

-- 2.4 Servicio-cuestionarios: relación legible; CRUD solo admin.
ALTER TABLE public.servicio_cuestionarios ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "servicio_cuestionario_read" ON public.servicio_cuestionarios;
CREATE POLICY "servicio_cuestionario_read"
    ON public.servicio_cuestionarios FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "servicio_cuestionario_admin_write" ON public.servicio_cuestionarios;
CREATE POLICY "servicio_cuestionario_admin_write"
    ON public.servicio_cuestionarios FOR ALL TO authenticated
    USING (public.es_administrador())
    WITH CHECK (public.es_administrador());

-- 2.5 Evaluaciones de salud: paciente propio (INSERT restringido + SELECT);
-- admin todo. El paciente NO edita estado/resultado (lo computa la RPC).
ALTER TABLE public.evaluaciones_salud ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "evaluacion_salud_admin_all" ON public.evaluaciones_salud;
CREATE POLICY "evaluacion_salud_admin_all"
    ON public.evaluaciones_salud FOR ALL TO authenticated
    USING (public.es_administrador())
    WITH CHECK (public.es_administrador());
DROP POLICY IF EXISTS "evaluacion_salud_paciente_read" ON public.evaluaciones_salud;
CREATE POLICY "evaluacion_salud_paciente_read"
    ON public.evaluaciones_salud FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.pacientes p
            WHERE p.id = evaluaciones_salud.paciente_id AND p.usuario_id = auth.uid()
        )
    );
DROP POLICY IF EXISTS "evaluacion_salud_paciente_insert" ON public.evaluaciones_salud;
CREATE POLICY "evaluacion_salud_paciente_insert"
    ON public.evaluaciones_salud FOR INSERT TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.pacientes p
            WHERE p.id = evaluaciones_salud.paciente_id AND p.usuario_id = auth.uid()
        )
        AND evaluaciones_salud.estado = 'Completado'
        AND evaluaciones_salud.resultado IS NULL
        AND evaluaciones_salud.riesgos IS NULL
    );

-- 2.6 Respuestas de salud: paciente propio; admin todo. Sin UPDATE/DELETE.
ALTER TABLE public.respuestas_salud ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "respuesta_salud_admin_all" ON public.respuestas_salud;
CREATE POLICY "respuesta_salud_admin_all"
    ON public.respuestas_salud FOR ALL TO authenticated
    USING (public.es_administrador())
    WITH CHECK (public.es_administrador());
DROP POLICY IF EXISTS "respuesta_salud_paciente_own" ON public.respuestas_salud;
CREATE POLICY "respuesta_salud_paciente_own"
    ON public.respuestas_salud FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.evaluaciones_salud ev
            JOIN public.pacientes p ON p.id = ev.paciente_id
            WHERE ev.id = respuestas_salud.evaluacion_id AND p.usuario_id = auth.uid()
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.evaluaciones_salud ev
            JOIN public.pacientes p ON p.id = ev.paciente_id
            WHERE ev.id = respuestas_salud.evaluacion_id AND p.usuario_id = auth.uid()
        )
    );

-- 2.7 Validaciones de telemedicina: paciente lee su propia y solo puede insertar
-- en PENDIENTE (el estado APROBADA/RECHAZADA y las fechas las escribe la RPC).
ALTER TABLE public.validaciones_telemedicina ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "validacion_telemedicina_admin_all" ON public.validaciones_telemedicina;
CREATE POLICY "validacion_telemedicina_admin_all"
    ON public.validaciones_telemedicina FOR ALL TO authenticated
    USING (public.es_administrador())
    WITH CHECK (public.es_administrador());
DROP POLICY IF EXISTS "validacion_telemedicina_paciente_read" ON public.validaciones_telemedicina;
CREATE POLICY "validacion_telemedicina_paciente_read"
    ON public.validaciones_telemedicina FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.pacientes p
            WHERE p.id = validaciones_telemedicina.paciente_id AND p.usuario_id = auth.uid()
        )
    );
DROP POLICY IF EXISTS "validacion_telemedicina_paciente_insert" ON public.validaciones_telemedicina;
CREATE POLICY "validacion_telemedicina_paciente_insert"
    ON public.validaciones_telemedicina FOR INSERT TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.pacientes p
            WHERE p.id = validaciones_telemedicina.paciente_id AND p.usuario_id = auth.uid()
        )
        AND validaciones_telemedicina.estado = 'PENDIENTE'
    );

-- ── 3. RPC: guardar_respuestas_evaluacion ------------------------------------
-- Autoridad de la evaluación: valida que las preguntas pertenezcan al cuestionario,
-- mapea cada valor al campo tipado según tipo_respuesta, conserva la versión y un
-- snapshot del texto, y computa sentinelas (preguntas.riesgo) -> riesgos/resultado.
CREATE OR REPLACE FUNCTION public.guardar_respuestas_evaluacion(
    p_cuestionario_id BIGINT,
    p_respuestas JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_paciente_id  UUID;
    v_cuestionario public.cuestionarios%ROWTYPE;
    v_evaluacion_id UUID;
    v_eval_estado   TEXT;
    v_riesgos       JSONB := '[]'::jsonb;
    v_respuesta     JSONB;
    v_pregunta_id   BIGINT;
    v_valor         TEXT;
    v_pregunta      public.preguntas%ROWTYPE;
    v_es_valida     BOOLEAN;
    v_detonante     TEXT;
    v_patron        TEXT;
    v_etiqueta      TEXT;
    v_critico       BOOLEAN;
    v_match         BOOLEAN;
    v_numero        NUMERIC;
    v_fecha         DATE;
    v_json          JSONB;
BEGIN
    SELECT p.id INTO v_paciente_id
    FROM public.pacientes p
    WHERE p.usuario_id = auth.uid()
    LIMIT 1;
    IF v_paciente_id IS NULL THEN
        RAISE EXCEPTION 'RN: no se encontró un paciente para el usuario actual';
    END IF;

    SELECT * INTO v_cuestionario
    FROM public.cuestionarios
    WHERE id = p_cuestionario_id AND activo = true
    LIMIT 1;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'RN: el cuestionario no existe o no está activo';
    END IF;

    -- Inserta la evaluación en Completado (resultado/riesgos se setean aquí mismo).
    INSERT INTO public.evaluaciones_salud (
        paciente_id, cuestionario_id, version_cuestionario,
        fecha_evaluacion, estado, created_at, updated_at
    ) VALUES (
        v_paciente_id, v_cuestionario.id, v_cuestionario.version,
        now(), 'Completado', now(), now()
    )
    RETURNING id INTO v_evaluacion_id;

    FOR v_respuesta IN SELECT * FROM jsonb_array_elements(p_respuestas)
    LOOP
        v_pregunta_id := (v_respuesta->>'pregunta_id')::BIGINT;
        v_valor := v_respuesta->>'valor';

        -- La pregunta debe pertenecer a este cuestionario (evita inyección de ids).
        SELECT p.* INTO v_pregunta
        FROM public.preguntas p
        JOIN public.cuestionario_preguntas cp ON cp.pregunta_id = p.id
        WHERE cp.cuestionario_id = v_cuestionario.id AND p.id = v_pregunta_id
        LIMIT 1;

        IF NOT FOUND THEN
            CONTINUE;
        END IF;

        -- Mapeo tipado según tipo_respuesta.
        v_numero := NULL;
        v_fecha := NULL;
        v_json := NULL;
        v_eval_estado := NULL;

        CASE v_pregunta.tipo_respuesta
            WHEN 'SI_NO' THEN
                IF lower(coalesce(v_valor, '')) IN ('true', 'sí', 'si', 'yes', '1') THEN
                    v_valor := 'Sí';
                ELSIF lower(coalesce(v_valor, '')) IN ('false', 'no', 'n', '0') THEN
                    v_valor := 'No';
                ELSE
                    v_valor := NULL;
                END IF;
            WHEN 'NUMERO', 'DECIMAL' THEN
                v_numero := NULLIF(v_valor, '')::NUMERIC;
            WHEN 'FECHA' THEN
                v_fecha := NULLIF(v_valor, '')::DATE;
            WHEN 'MULTIPLE', 'ARCHIVO', 'IMAGEN' THEN
                BEGIN
                    v_json := v_valor::JSONB;
                EXCEPTION WHEN others THEN
                    v_json := to_jsonb(v_valor);
                END;
            ELSE
                NULL;
        END CASE;

        INSERT INTO public.respuestas_salud (
            evaluacion_id, pregunta_id, pregunta_texto,
            respuesta_texto, respuesta_boolean, respuesta_numero,
            respuesta_fecha, respuesta_json, created_at
        ) VALUES (
            v_evaluacion_id, v_pregunta.id, v_pregunta.pregunta,
            NULLIF(v_valor, ''),
            CASE WHEN v_pregunta.tipo_respuesta = 'SI_NO'
                 THEN (lower(coalesce(v_valor, '')) IN ('sí', 'si', 'true', 'yes', '1'))
                 ELSE NULL END,
            v_numero, v_fecha, v_json, now()
        );

        -- Sentinela de riesgo configurable (preguntas.riesgo).
        IF v_pregunta.riesgo IS NOT NULL THEN
            v_detonante := v_pregunta.riesgo->>'detonante';
            v_patron    := v_pregunta.riesgo->>'patron';
            v_etiqueta  := v_pregunta.riesgo->>'etiqueta';
            v_critico   := coalesce((v_pregunta.riesgo->>'critico')::BOOLEAN, false);
            v_match     := false;

            IF v_pregunta.tipo_respuesta = 'SI_NO' THEN
                v_match := lower(coalesce(v_detonante, '')) IN ('si', 'sí', 'true', 'yes', '1')
                           AND coalesce(v_valor, '') = 'Sí';
            ELSIF v_patron IS NOT NULL AND length(v_patron) > 0 THEN
                v_match := coalesce(v_valor, '') ~* v_patron;
            ELSE
                v_match := lower(coalesce(v_valor, '')) = lower(coalesce(v_detonante, ''));
            END IF;

            IF v_match THEN
                v_riesgos := v_riesgos || jsonb_build_object(
                    'pregunta_id', v_pregunta.id,
                    'etiqueta', coalesce(v_etiqueta, 'Riesgo'),
                    'critico', v_critico
                );
            END IF;
        END IF;
    END LOOP;

    -- Resultado de la evaluación según sentinelas.
    IF EXISTS (SELECT 1 FROM jsonb_array_elements(v_riesgos) r WHERE (r->>'critico')::BOOLEAN) THEN
        v_eval_estado := 'NO_APTO';
    ELSIF jsonb_array_length(v_riesgos) > 0 THEN
        v_eval_estado := 'REQUIERE_REVISION';
    ELSE
        v_eval_estado := 'APTO';
    END IF;

    UPDATE public.evaluaciones_salud
    SET resultado = v_eval_estado,
        riesgos   = v_riesgos,
        updated_at = now()
    WHERE id = v_evaluacion_id;

    RETURN jsonb_build_object(
        'id', v_evaluacion_id,
        'resultado', v_eval_estado,
        'riesgos', v_riesgos,
        'version_cuestionario', v_cuestionario.version,
        'fecha_evaluacion', to_char(now(), 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')
    );
END;
$$;

-- ── 4. RPC: registrar_validacion_telemedicina ---------------------------------
-- Registra la validación con fecha de aprobación (now) y vencimiento (+365 días).
-- Solo la RPC (SECURITY DEFINER) puede escribir APROBADA/RECHAZADA con fechas.
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

    -- Conserva el comportamiento legacy: activo/evaluación/pago ligados al dictamen.
    UPDATE public.profiles
    SET activo = p_aprobado,
        evaluation_passed = p_aprobado,
        payment_completed = p_aprobado,
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

-- ── 5. Trigger RN-020 en solicitudes ------------------------------------------
-- Bloquea el INSERT de una solicitud si el servicio requiere telemedicina y el
-- paciente no tiene una validación APROBADA vigente. Desactivable vía
-- configuracion_sistema.enforce_rn020 = 'false' (para desarrollo/pruebas).
CREATE OR REPLACE FUNCTION public.validar_rn020_solicitud()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
    v_enforce  TEXT;
    v_requiere BOOLEAN;
BEGIN
    SELECT COALESCE(valor, 'true') INTO v_enforce
    FROM public.configuracion_sistema
    WHERE clave = 'enforce_rn020'
    LIMIT 1;

    IF lower(v_enforce) = 'false' THEN
        RETURN NEW;
    END IF;

    IF NEW.servicio_id IS NOT NULL THEN
        SELECT requiere_telemedicina INTO v_requiere
        FROM public.servicios
        WHERE id = NEW.servicio_id
        LIMIT 1;

        IF v_requiere THEN
            IF NOT EXISTS (
                SELECT 1 FROM public.validaciones_telemedicina v
                WHERE v.paciente_id = NEW.paciente_id
                  AND v.estado = 'APROBADA'
                  AND v.fecha_vencimiento IS NOT NULL
                  AND v.fecha_vencimiento > now()
            ) THEN
                RAISE EXCEPTION 'RN-020: El servicio requiere validación de telemedicina vigente (APROBADA, sin vencer).';
            END IF;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_rn020_solicitud ON public.solicitudes;
CREATE TRIGGER trg_rn020_solicitud
    BEFORE INSERT ON public.solicitudes
    FOR EACH ROW EXECUTE FUNCTION public.validar_rn020_solicitud();

-- ── 6. Seed: config RN-020 + cuestionario real de salud -----------------------
INSERT INTO public.configuracion_sistema
    (id, clave, valor, tipo_dato, descripcion, activo, updated_at)
VALUES
    (gen_random_uuid(), 'enforce_rn020', 'true', 'BOOLEAN',
     'Bloquea solicitudes de servicios con requiere_telemedicina sin validación vigente', true, now())
ON CONFLICT (clave) DO UPDATE
    SET valor = EXCLUDED.valor,
        updated_at = now();

-- Helper de seed de preguntas (solo usa si no existe por (texto, tipo)).
CREATE OR REPLACE FUNCTION public._seed_pregunta(
    p_cuest_id BIGINT,
    p_texto TEXT,
    p_tipo public.tipo_respuesta_enum,
    p_obligatoria BOOLEAN,
    p_opciones JSONB,
    p_riesgo JSONB,
    p_orden INTEGER
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_preg_id BIGINT;
BEGIN
    SELECT id INTO v_preg_id
    FROM public.preguntas
    WHERE pregunta = p_texto AND tipo_respuesta = p_tipo
    LIMIT 1;

    IF v_preg_id IS NULL THEN
        INSERT INTO public.preguntas (pregunta, tipo_respuesta, obligatoria, opciones, riesgo, activo, created_at, updated_at)
        VALUES (p_texto, p_tipo, p_obligatoria, p_opciones, p_riesgo, true, now(), now())
        RETURNING id INTO v_preg_id;
    END IF;

    INSERT INTO public.cuestionario_preguntas (cuestionario_id, pregunta_id, orden, activo, created_at)
    VALUES (p_cuest_id, v_preg_id, p_orden, true, now())
    ON CONFLICT DO NOTHING;
END;
$$;

DO $$
DECLARE
    v_cuest_id BIGINT;
    v_preg_id  BIGINT;
    v_servicio UUID;
    v_nombre   CONSTANT TEXT := 'Cuestionario de Salud';
    v_version  CONSTANT INTEGER := 1;
BEGIN
    -- Cuestionario v1 (idempotente).
    SELECT id INTO v_cuest_id
    FROM public.cuestionarios
    WHERE nombre = v_nombre AND version = v_version
    LIMIT 1;

    IF v_cuest_id IS NULL THEN
        INSERT INTO public.cuestionarios (nombre, descripcion, activo, version, created_at, updated_at)
        VALUES (v_nombre, 'Cuestionario de salud pre-tratamiento (evalúa condiciones relevantes)', true, v_version, now(), now())
        RETURNING id INTO v_cuest_id;
    END IF;

    -- Pregunta idempotente por texto + tipo; inserta si no existe.
    PERFORM public._seed_pregunta(v_cuest_id, '¿Tienes alergia conocida a la lidocaína, anestésicos locales o ácido hialurónico?', 'SI_NO', true,
        '["Sí","No"]', '{"detonante":"SI","etiqueta":"Alergia a anestésicos/lidocaína","critico":false}', 1);
    PERFORM public._seed_pregunta(v_cuest_id, '¿Estás embarazada, en período de lactancia o planeas embarazo en los próximos 3 meses?', 'SI_NO', true,
        '["Sí","No"]', '{"detonante":"SI","etiqueta":"Embarazo o lactancia","critico":true}', 2);
    PERFORM public._seed_pregunta(v_cuest_id, '¿Padeces alguna enfermedad autoinmune, diabetes no controlada o trastorno de coagulación?', 'SI_NO', true,
        '["Sí","No"]', '{"detonante":"SI","etiqueta":"Condición médica relevante","critico":true}', 3);
    PERFORM public._seed_pregunta(v_cuest_id, 'Menciona cualquier medicamento o suplemento que tomes actualmente (anticoagulantes, aspirina, etc.).', 'TEXTO', false,
        NULL, '{"patron":"coagul|aspirina|warfarina|plaqueta","etiqueta":"Medicación anticoagulante","critico":false}', 4);
    PERFORM public._seed_pregunta(v_cuest_id, '¿Has recibido tratamientos estéticos faciales o inyectables en los últimos 6 meses?', 'LISTA', true,
        '["Bótox / Toxina Botulínica","Ácido Hialurónico","Peeling Químico","Hilos Tensores","Ninguno"]', NULL, 5);
    PERFORM public._seed_pregunta(v_cuest_id, '¿Cuántos tratamientos estéticos recibiste en el último año?', 'NUMERO', false,
        NULL, NULL, 6);
    PERFORM public._seed_pregunta(v_cuest_id, 'Fecha de tu último chequeo médico general (si aplica).', 'FECHA', false,
        NULL, NULL, 7);
    PERFORM public._seed_pregunta(v_cuest_id, '¿Fumas?', 'SI_NO', false,
        '["Sí","No"]', '{"detonante":"SI","etiqueta":"Tabaquismo","critico":false}', 8);
    PERFORM public._seed_pregunta(v_cuest_id, '¿Tienes antecedentes de cicatrización queloidal o hipertrófica?', 'SI_NO', true,
        '["Sí","No"]', '{"detonante":"SI","etiqueta":"Cicatrización queloidal","critico":false}', 9);
    PERFORM public._seed_pregunta(v_cuest_id, 'Selecciona los síntomas que presentas con frecuencia', 'MULTIPLE', false,
        '["Dolor de cabeza","Dermatitis","Acné activo","Rosácea","Ninguno"]', NULL, 10);

    -- Vínculo con los servicios médicos/inyectables del seed de catálogo.
    FOR v_servicio IN
        SELECT id FROM public.servicios
        WHERE id IN ('11111111-1111-1111-1111-111111111111','22222222-2222-2222-2222-222222222222',
                     '33333333-3333-3333-3333-333333333333','44444444-4444-4444-4444-444444444444',
                     '55555555-5555-5555-5555-555555555555')
    LOOP
        INSERT INTO public.servicio_cuestionarios (servicio_id, cuestionario_id, obligatorio, orden, activo, created_at)
        VALUES (v_servicio, v_cuest_id, true, 1, true, now())
        ON CONFLICT DO NOTHING;
    END LOOP;
END $$;