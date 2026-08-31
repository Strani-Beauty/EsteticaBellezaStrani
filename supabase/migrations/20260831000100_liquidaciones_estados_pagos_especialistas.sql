-- Liquidaciones y Pagos a Especialistas: estados, aprobación, pago externo y
-- comprobante en storage.
-- Idempotente. Aplicar en orden ascendente de nombre.
-- 1) CHECK de estado en liquidaciones_especialistas (5 valores).
-- 2) Trigger de transición de estado (solo admin, matriz definida).
-- 3) RPC cambiar_estado_liquidacion: cambia estado validando la transición.
-- 4) RPC registrar_pago_especialista: INSERT pagos_especialistas + marca PAGADA.
-- 5) Seed inicio_semana_liquidacion (período por defecto en la UI).
-- 6) Bucket privado comprobantes-pagos + policies de storage para admin.

-- ── 1. CHECK estado de liquidaciones_especialistas ───────────────────────────
ALTER TABLE public.liquidaciones_especialistas DROP CONSTRAINT IF EXISTS
    liquidaciones_especialistas_estado_check;
ALTER TABLE public.liquidaciones_especialistas ADD CONSTRAINT
    liquidaciones_especialistas_estado_check
    CHECK (estado = ANY (ARRAY['PENDIENTE'::text,'EN_REVISION'::text,
                            'APROBADA'::text,'PAGADA'::text,'ANULADA'::text]));

-- ── 2. Trigger de transición de estado ───────────────────────────────────────
-- Solo el administrador cambia estados; se respeta la matriz:
--   PENDIENTE  -> EN_REVISION | ANULADA
--   EN_REVISION-> APROBADA    | ANULADA
--   APROBADA   -> PAGADA      | ANULADA
--   PAGADA / ANULADA: estados terminales.
DROP TRIGGER IF EXISTS trg_validar_transicion_estado_liquidacion
    ON public.liquidaciones_especialistas;

CREATE OR REPLACE FUNCTION public.validar_transicion_estado_liquidacion()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_valido boolean;
BEGIN
    IF TG_OP = 'UPDATE' AND OLD.estado = NEW.estado THEN
        RETURN NEW;
    END IF;

    IF NOT public.is_administrador() THEN
        RAISE EXCEPTION 'Solo el administrador puede cambiar el estado de la liquidación';
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM (
            VALUES
                ('PENDIENTE',   'EN_REVISION'),
                ('PENDIENTE',   'ANULADA'),
                ('EN_REVISION', 'APROBADA'),
                ('EN_REVISION', 'ANULADA'),
                ('APROBADA',    'PAGADA'),
                ('APROBADA',    'ANULADA')
        ) AS t(origen, destino)
        WHERE t.origen = OLD.estado::text
          AND t.destino = NEW.estado::text
    ) INTO v_valido;

    IF NOT v_valido THEN
        RAISE EXCEPTION 'Transición de estado inválida: % -> %',
            OLD.estado, NEW.estado;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_validar_transicion_estado_liquidacion
    BEFORE UPDATE OF estado ON public.liquidaciones_especialistas
    FOR EACH ROW
    EXECUTE FUNCTION public.validar_transicion_estado_liquidacion();

-- ── 3. RPC cambiar_estado_liquidacion ────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.cambiar_estado_liquidacion(
    p_liquidacion_id uuid,
    p_nuevo_estado   text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_estado text;
BEGIN
    IF NOT public.is_administrador() THEN
        RETURN json_build_object('ok', false, 'motivo', 'NO_AUTORIZADO');
    END IF;

    IF p_nuevo_estado NOT IN ('EN_REVISION', 'APROBADA', 'PAGADA', 'ANULADA') THEN
        RETURN json_build_object('ok', false, 'motivo', 'ESTADO_INVALIDO');
    END IF;

    SELECT estado INTO v_estado
      FROM public.liquidaciones_especialistas
     WHERE id = p_liquidacion_id;

    IF v_estado IS NULL THEN
        RETURN json_build_object('ok', false, 'motivo', 'NO_ENCONTRADA');
    END IF;

    UPDATE public.liquidaciones_especialistas
       SET estado = p_nuevo_estado,
           fecha_pago = CASE
               WHEN p_nuevo_estado = 'PAGADA' THEN COALESCE(fecha_pago, now())
               ELSE fecha_pago
           END
     WHERE id = p_liquidacion_id;

    RETURN json_build_object('ok', true, 'motivo', 'OK',
                             'estado', p_nuevo_estado);
END;
$$;

GRANT EXECUTE ON FUNCTION public.cambiar_estado_liquidacion(uuid, text)
    TO authenticated;

-- ── 4. RPC registrar_pago_especialista ───────────────────────────────────────
CREATE OR REPLACE FUNCTION public.registrar_pago_especialista(
    p_liquidacion_id   uuid,
    p_metodo_pago      text,
    p_referencia_pago  text,
    p_comprobante_url  text,
    p_notas            text,
    p_monto_pagado     numeric DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_estado      text;
    v_especialista uuid;
    v_monto       numeric;
BEGIN
    IF NOT public.is_administrador() THEN
        RETURN json_build_object('ok', false, 'motivo', 'NO_AUTORIZADO');
    END IF;

    SELECT l.estado, l.especialista_id, l.monto_pagar
      INTO v_estado, v_especialista, v_monto
      FROM public.liquidaciones_especialistas l
     WHERE l.id = p_liquidacion_id;

    IF v_estado IS NULL THEN
        RETURN json_build_object('ok', false, 'motivo', 'NO_ENCONTRADA');
    END IF;

    IF v_estado = 'PAGADA' THEN
        RETURN json_build_object('ok', false, 'motivo', 'YA_PAGADA');
    END IF;

    IF v_estado <> 'APROBADA' THEN
        RETURN json_build_object('ok', false, 'motivo', 'ESTADO_INVALIDO');
    END IF;

    INSERT INTO public.pagos_especialistas
        (liquidacion_id, especialista_id, fecha_pago, monto_pagado,
         metodo_pago, referencia_pago, comprobante_url, notas)
    VALUES
        (p_liquidacion_id, v_especialista, now(),
         COALESCE(p_monto_pagado, v_monto),
         p_metodo_pago, p_referencia_pago, p_comprobante_url, p_notas);

    UPDATE public.liquidaciones_especialistas
       SET estado = 'PAGADA',
           fecha_pago = now()
     WHERE id = p_liquidacion_id;

    RETURN json_build_object('ok', true, 'motivo', 'OK',
                             'monto_pagado', COALESCE(p_monto_pagado, v_monto));
END;
$$;

GRANT EXECUTE ON FUNCTION public.registrar_pago_especialista(
    uuid, text, text, text, text, numeric)
    TO authenticated;

-- ── 5. Seed inicio_semana_liquidacion ────────────────────────────────────────
INSERT INTO public.configuracion_sistema
    (id, clave, valor, tipo_dato, descripcion, activo, updated_at)
VALUES
    (gen_random_uuid(), 'inicio_semana_liquidacion', '1', 'NUMERIC',
     'Día de inicio de la semana de liquidación (1=Lunes, 7=Domingo)', true, now())
ON CONFLICT (clave) DO UPDATE
    SET descripcion = EXCLUDED.descripcion, activo = true, updated_at = now();

-- ── 6. Bucket privado comprobantes-pagos ─────────────────────────────────────
DO $$
BEGIN
    INSERT INTO storage.buckets (id, name, public)
    VALUES ('comprobantes-pagos', 'comprobantes-pagos', FALSE)
    ON CONFLICT (id) DO UPDATE SET public = FALSE;
END $$;

-- INSERT/UPDATE/DELETE: solo admin.
DROP POLICY IF EXISTS "comprobante_storage_admin_insert" ON storage.objects;
CREATE POLICY "comprobante_storage_admin_insert"
    ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (
        bucket_id = 'comprobantes-pagos'
        AND (SELECT p.role FROM public.profiles p WHERE p.id = auth.uid()) = 'Administrador'
    );

DROP POLICY IF EXISTS "comprobante_storage_admin_select" ON storage.objects;
CREATE POLICY "comprobante_storage_admin_select"
    ON storage.objects
    FOR SELECT TO authenticated
    USING (
        bucket_id = 'comprobantes-pagos'
        AND (SELECT p.role FROM public.profiles p WHERE p.id = auth.uid()) = 'Administrador'
    );

DROP POLICY IF EXISTS "comprobante_storage_admin_update" ON storage.objects;
CREATE POLICY "comprobante_storage_admin_update"
    ON storage.objects
    FOR UPDATE TO authenticated
    USING (
        bucket_id = 'comprobantes-pagos'
        AND (SELECT p.role FROM public.profiles p WHERE p.id = auth.uid()) = 'Administrador'
    )
    WITH CHECK (
        bucket_id = 'comprobantes-pagos'
        AND (SELECT p.role FROM public.profiles p WHERE p.id = auth.uid()) = 'Administrador'
    );

DROP POLICY IF EXISTS "comprobante_storage_admin_delete" ON storage.objects;
CREATE POLICY "comprobante_storage_admin_delete"
    ON storage.objects
    FOR DELETE TO authenticated
    USING (
        bucket_id = 'comprobantes-pagos'
        AND (SELECT p.role FROM public.profiles p WHERE p.id = auth.uid()) = 'Administrador'
    );