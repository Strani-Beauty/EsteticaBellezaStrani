-- =============================================================================
-- Fix: CHECK de `pagos_especialistas.metodo_pago` alineado a los métodos de
-- pago definidos en la app (administración → Registrar pago).
-- -----------------------------------------------------------------------------
-- El constraint original (creado en el SQL Editor junto a la tabla) solo
-- aceptaba 'ACH'|'ZELLE'|'TRANSFERENCIA'|'OTRO', pero la app envía
-- 'Transferencia'|'Efectivo'|'Cheque'|'Otro' (métodos confirmados por el
-- usuario al aprobar el plan de liquidaciones). El RPC `registrar_pago_especialista`
-- fallaba con 23514 al insertar 'Transferencia'.
-- Se reemplaza el CHECK con los valores canónicos de la app.
-- Idempotente: DROP CONSTRAINT IF EXISTS + ADD CONSTRAINT.
-- =============================================================================

ALTER TABLE public.pagos_especialistas
    DROP CONSTRAINT IF EXISTS pagos_especialistas_metodo_pago_check;

ALTER TABLE public.pagos_especialistas
    ADD CONSTRAINT pagos_especialistas_metodo_pago_check
    CHECK (metodo_pago = ANY (ARRAY[
        'Transferencia'::text,
        'Efectivo'::text,
        'Cheque'::text,
        'Otro'::text
    ]));