-- =============================================================================
-- Migración: normaliza el CHECK de `transacciones.tipo_transaccion`.
-- -----------------------------------------------------------------------------
-- La restricción `transacciones_tipo_transaccion_check` fue creada directamente
-- en el SQL Editor (no existía en ninguna migración) con los valores
-- 'DEPÓSITO'/'PAGO_FINAL' (con tilde). La app y los RPCs usan los valores
-- canónicos ASCII: DEPOSITO, PAGO_TOTAL, SALDO, REEMBOLSO, AJUSTE. El INSERT de
-- la confirmación de depósito fallaba con 42P.. (check violation). Se alinea la
-- BD a la app (la tabla está vacía hoy). Idempotente.
-- =============================================================================

UPDATE public.transacciones
   SET tipo_transaccion = 'DEPOSITO'
 WHERE tipo_transaccion = 'DEPÓSITO';

UPDATE public.transacciones
   SET tipo_transaccion = 'PAGO_TOTAL'
 WHERE tipo_transaccion = 'PAGO_FINAL';

ALTER TABLE public.transacciones DROP CONSTRAINT IF EXISTS transacciones_tipo_transaccion_check;

ALTER TABLE public.transacciones ADD CONSTRAINT transacciones_tipo_transaccion_check
    CHECK (tipo_transaccion = ANY (ARRAY[
        'DEPOSITO'::text,
        'PAGO_TOTAL'::text,
        'SALDO'::text,
        'REEMBOLSO'::text,
        'AJUSTE'::text
    ]));
