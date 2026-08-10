-- =============================================================================
-- MIGRACIÓN: Pagos Stripe — RLS para el cobro del saldo al finalizar y seeds.
--  * El especialista asignado a la cita lee el pago de la solicitud y puede
--    marcarlo PAGADO al cobrar el saldo final (transacción SALDO vinculada).
--  * Seeds idempotentes de configuracion_sistema (deposito_reserva y la
--    comisión para la futura liquidación de especialistas).
-- Idempotente (DROP POLICY IF EXISTS / ON CONFLICT).
-- =============================================================================

-- ── 1. Seeds de configuracion_sistema ──────────────────────────────────────
CREATE UNIQUE INDEX IF NOT EXISTS configuracion_sistema_clave_idx
    ON public.configuracion_sistema (clave);

INSERT INTO public.configuracion_sistema
    (id, clave, valor, tipo_dato, descripcion, activo, updated_at)
VALUES
    (gen_random_uuid(), 'deposito_reserva', '30.00', 'NUMERIC',
     'Depósito de reserva en USD', true, now()),
    (gen_random_uuid(), 'comision_porcentaje', '20', 'NUMERIC',
     'Porcentaje de comisión de la plataforma (%)', true, now())
ON CONFLICT (clave) DO UPDATE
    SET valor = EXCLUDED.valor,
        updated_at = now();

-- ── 2. RLS: `pagos` (especialista lee y marca PAGADO) ─────────────────────
ALTER TABLE public.pagos ENABLE ROW LEVEL SECURITY;

-- El especialista asignado a la cita lee el pago de su solicitud.
DROP POLICY IF EXISTS "pago_especialista_cita_read" ON public.pagos;
CREATE POLICY "pago_especialista_cita_read"
    ON public.pagos
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.citas c
            WHERE c.solicitud_id = pagos.solicitud_id
              AND c.especialista_id = (
                    SELECT id FROM public.especialistas
                    WHERE usuario_id = auth.uid() LIMIT 1
                )
        )
    );

-- El especialista marca el pago PAGADO al cobrar el saldo final.
DROP POLICY IF EXISTS "pago_especialista_cita_update" ON public.pagos;
CREATE POLICY "pago_especialista_cita_update"
    ON public.pagos
    FOR UPDATE TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.citas c
            WHERE c.solicitud_id = pagos.solicitud_id
              AND c.especialista_id = (
                    SELECT id FROM public.especialistas
                    WHERE usuario_id = auth.uid() LIMIT 1
                )
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.citas c
            WHERE c.solicitud_id = pagos.solicitud_id
              AND c.especialista_id = (
                    SELECT id FROM public.especialistas
                    WHERE usuario_id = auth.uid() LIMIT 1
                )
        )
    );

-- ── 3. RLS: `transacciones` (especialista inserta SALDO y lee) ──────────────
ALTER TABLE public.transacciones ENABLE ROW LEVEL SECURITY;

-- El especialista registra la transacción SALDO al cobrar al finalizar la cita.
DROP POLICY IF EXISTS "transaccion_especialista_cita_insert" ON public.transacciones;
CREATE POLICY "transaccion_especialista_cita_insert"
    ON public.transacciones
    FOR INSERT TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.citas c
            WHERE c.id = transacciones.cita_id
              AND c.especialista_id = (
                    SELECT id FROM public.especialistas
                    WHERE usuario_id = auth.uid() LIMIT 1
                )
        )
    );

-- El especialista lee las transacciones de sus citas.
DROP POLICY IF EXISTS "transaccion_especialista_cita_read" ON public.transacciones;
CREATE POLICY "transaccion_especialista_cita_read"
    ON public.transacciones
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.citas c
            WHERE c.id = transacciones.cita_id
              AND c.especialista_id = (
                    SELECT id FROM public.especialistas
                    WHERE usuario_id = auth.uid() LIMIT 1
                )
        )
    );