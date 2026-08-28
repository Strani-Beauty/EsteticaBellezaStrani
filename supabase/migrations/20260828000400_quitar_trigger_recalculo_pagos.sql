-- =============================================================================
-- MIGRACIÓN: quita el trigger legacy `tr_recalcular_pagos_saldo` de `pagos`.
-- -----------------------------------------------------------------------------
-- El trigger (creado en el SQL Editor, fuera de migraciones) recalculaba en
-- cada INSERT/UPDATE:
--   saldo_pendiente = GREATEST(0, monto_total - deposito)
-- y forzaba estado PARCIAL/PAGADO a partir de esa fórmula. Eso SOBRESCRIBE lo
-- que hace el RPC SECURITY DEFINER `confirmar_pago_saldo` (migración
-- 20260828000100): al cobrar el saldo final el RPC pone estado='PAGADO' y
-- saldo_pendiente=0, pero el trigger lo revertía a PARCIAL con el saldo
-- recalculado → `generar_liquidaciones` (que exige p.estado='PAGADO' AND
-- saldo_pendiente<=0) excluía la cita de la liquidación y del detalle por cita.
--
-- El cálculo del saldo ahora vive exclusivamente en los RPC:
--   * crear_solicitud_reserva       (depósito = total * adelanto_porcentaje %)
--   * confirmar_deposito_solicitud  (saldo_pendiente = GREATEST(0, total - p_monto))
--   * confirmar_pago_saldo          (saldo_pendiente = 0, estado = PAGADO)
-- Por eso el trigger es redundante y dañino y se elimina.
-- Idempotente (DROP ... IF EXISTS). Aplicar en orden ascendente de nombre.
-- =============================================================================

-- ── 1. Eliminar el trigger y su función ──────────────────────────────────────
DROP TRIGGER IF EXISTS tr_recalcular_pagos_saldo ON public.pagos;
DROP FUNCTION IF EXISTS public.recalcular_pagos_saldo_and_updated_at();

-- ── 2. Backfill: marcar PAGADO las solicitudes que ya tienen el saldo cobrado ─
-- Cualquier `pagos` cuya solicitud tenga una transacción SALDO APROBADA debió
-- quedar PAGADO/saldo 0; el trigger legacy lo dejó PARCIAL. Se corrige la data
-- para que `generar_liquidaciones` incluya esas citas.
UPDATE public.pagos p
   SET estado          = 'PAGADO'::estado_pago_enum,
       saldo_pendiente = 0,
       updated_at      = now()
 WHERE p.estado <> 'PAGADO'
   AND EXISTS (
       SELECT 1
         FROM public.transacciones t
        WHERE t.solicitud_id = p.solicitud_id
          AND t.tipo_transaccion = 'SALDO'
          AND t.estado = 'APROBADO'
   );