-- =============================================================================
-- Migración: RLS para el flujo de onboarding (solicitud → pago → transacción).
-- El paciente autenticado crea su solicitud BORRADOR tras abonar la cuota
-- inicial; luego se registran el pago y la transacción vinculados.
-- Sin estas políticas el INSERT obtenía 42501 ("row-level security policy").
-- Idempotente (DROP POLICY IF EXISTS).
-- =============================================================================

-- ── 1. `solicitudes`: el paciente gestiona sus propias solicitudes ─────────
ALTER TABLE public.solicitudes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "solicitud_paciente_own" ON public.solicitudes;
CREATE POLICY "solicitud_paciente_own"
    ON public.solicitudes
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.pacientes p
            WHERE p.id = solicitudes.paciente_id AND p.usuario_id = auth.uid()
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.pacientes p
            WHERE p.id = solicitudes.paciente_id AND p.usuario_id = auth.uid()
        )
    );

-- El especialista lee las solicitudes publicadas/buscando especialista (mapa).
DROP POLICY IF EXISTS "solicitud_especialista_select_publicada" ON public.solicitudes;
CREATE POLICY "solicitud_especialista_select_publicada"
    ON public.solicitudes
    FOR SELECT TO authenticated
    USING (estado IN ('PUBLICADA', 'BUSCANDO_ESPECIALISTA'));

-- ── 2. `pagos`: el paciente ve/registra pagos de sus solicitudes ───────────
ALTER TABLE public.pagos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "pago_solicitud_own" ON public.pagos;
CREATE POLICY "pago_solicitud_own"
    ON public.pagos
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.solicitudes s
            JOIN public.pacientes p ON p.id = s.paciente_id
            WHERE s.id = pagos.solicitud_id AND p.usuario_id = auth.uid()
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.solicitudes s
            JOIN public.pacientes p ON p.id = s.paciente_id
            WHERE s.id = pagos.solicitud_id AND p.usuario_id = auth.uid()
        )
    );

-- ── 3. `transacciones`: el paciente ve/registra sus movimientos ─────────────
ALTER TABLE public.transacciones ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "transaccion_paciente_own" ON public.transacciones;
CREATE POLICY "transaccion_paciente_own"
    ON public.transacciones
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.pacientes p
            WHERE p.id = transacciones.paciente_id AND p.usuario_id = auth.uid()
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.pacientes p
            WHERE p.id = transacciones.paciente_id AND p.usuario_id = auth.uid()
        )
    );