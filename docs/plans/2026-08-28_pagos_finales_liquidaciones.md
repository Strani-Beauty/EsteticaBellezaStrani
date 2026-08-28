# Plan: Pagos finales, transacciones y conciliación (Stripe + liquidaciones)

| | |
|---|---|
| **Fecha** | 2026-08-28 |
| **Estado** | APROBADO por el usuario (2026-08-28) |
| **Decisiones tomadas** | (1) Pago de saldo fallido → registrar transacción FALLIDA y finalizar el tratamiento/cita igual (el servicio ya se prestó; el saldo queda pendiente). (2) `transacciones.estado` pasa a CHECK `PENDIENTE,PROCESADA,APROBADO,FALLIDA,REEMBOLSADA` (se conserva 'APROBADO' para no romper RPC/trigger/webhook/KPI existentes). (3) Liquidaciones semanales por botón admin con rango de fechas vía RPC `generar_liquidaciones` idempotente. (4) Se cierran huecos RLS: se eliminan las policies `pago_especialista_cita_update` y `transaccion_especialista_cita_insert`; el cobro de saldo pasa por RPC SECURITY DEFINER `confirmar_pago_saldo` (valida monto == saldo_pendiente). |

## Contexto

El flujo de depósito/adelanto con Stripe ya está implementado de punta a punta
(RPC `crear_solicitud_reserva` + `confirmar_deposito_solicitud` + webhook + trigger
`trg_proteger_publicacion_solicitud`). El cobro del saldo final existe pero:

- `comisiones`, `liquidaciones_especialistas` y `liquidacion_detalles` **no los puebla
  nada** (la pantalla admin de liquidaciones es solo lectura).
- No hay estados de transacción pendiente/fallida/reembolsada (`estado` es text sin CHECK,
  solo 'APROBADO').
- Si el pago del saldo falla o se cancela, `revision_final_screen._pagarSaldoPendiente`
  aborta todo el cierre sin registrar nada.
- RLS: un especialista asignado a una cita puede UPDATE cualquier columna de `pagos` e
  INSERT cualquier `transacciones` arbitraria.
- El webhook SALDO no valida que el monto pagado coincida con `saldo_pendiente` (pone 0
  a ciegas).

## Actividades → implementación

### A. Migración BD `supabase/migrations/20260828000100_pagos_finales_liquidaciones.sql`

- [x] A1. CHECK en `transacciones.estado`:
  `CHECK (estado = ANY (ARRAY['PENDIENTE','PROCESADA','APROBADO','FALLIDA','REEMBOLSADA']))`.
- [x] A2. Cerrar huecos RLS:
  - `DROP POLICY IF EXISTS pago_especialista_cita_update ON pagos;` (UPDATE directo).
  - `DROP POLICY IF EXISTS transaccion_especialista_cita_insert ON transacciones;` (INSERT directo).
  - Se mantienen las read policies del especialista (`pago_especialista_cita_read`,
    `transaccion_especialista_cita_read`).
- [x] A3. RPC `confirmar_pago_saldo(p_solicitud_id uuid, p_cita_id uuid, p_monto numeric,
  p_stripe_payment_id text)` RETURNS json, SECURITY DEFINER, admin/especialista dueño/
  service_role:
  1. Carga `pagos.saldo_pendiente` + `solicitudes.paciente_id`.
  2. Autorización: especialista dueño de la cita, `is_administrador()` o `service_role`.
  3. Idempotente: si ya hay transacción SALDO para la cita → `{ok:false, motivo:'YA_REGISTRADA'}`.
  4. Si `round(p_monto,2) <> round(saldo,2)` → inserta transacción FALLIDA
     (`p_stripe_payment_id`) y devuelve `{ok:false, motivo:'MONTO_INCORRECTO'}`.
  5. `UPDATE pagos SET estado='PAGADO', saldo_pendiente=0`.
  6. INSERT transacción SALDO APROBADA con refs Stripe.
  7. Devuelve `{ok:true, motivo:'OK'}`. GRANT a `authenticated` y `service_role`.
- [x] A4. RPC `registrar_pago_fallido(p_solicitud_id uuid, p_cita_id uuid, p_monto numeric,
  p_stripe_payment_id text, p_motivo text, p_tipo text DEFAULT 'SALDO')` RETURNS json,
  SECURITY DEFINER: inserta transacción FALLIDA (sin tocar `pagos`), idempotente por
  ref/estado; `p_tipo` permite registrar DEPOSITO/PAGO_TOTAL con `cita_id` NULL (fallo
  de depósito). GRANT a `authenticated` y `service_role`.
- [x] A5. RPC `generar_liquidaciones(p_fecha_inicio date, p_fecha_fin date)` RETURNS json,
  SECURITY DEFINER admin-only (`is_administrador()`):
  - Selecciona citas elegibles: `citas.estado='FINALIZADA'`, existe `tratamientos` con
    `cita_id` y `estado='COMPLETADO'`, `pagos` (vía solicitud) `estado='PAGADO'` y
    `saldo_pendiente=0`, `citas.fecha_finalizacion` en la ventana, y cita **sin** fila en
    `liquidacion_detalles` (idempotente).
  - Agrupa por `citas.especialista_id`; por grupo inserta `liquidaciones_especialistas`
    (`fecha_inicio`, `fecha_fin`, `monto_total_servicios`, `monto_comision`,
    `monto_pagar = total - comision`) con `comision_porcentaje` de `configuracion_sistema`.
  - Por cada cita inserta `liquidacion_detalles` (monto_servicio, comision_aplicada,
    monto_especialista) y `comisiones` (cita_id, porcentaje, monto_comision,
    monto_especialista).
  - Devuelve `{ok, especialistas, citas, monto_total, monto_comision, monto_pagar}`.
    GRANT a `authenticated` (la función valida admin).

### B. Edge function `supabase/functions/stripe-webhook/index.ts`

- [x] B1. Ruta SALDO: sustituir el UPDATE+INSERT manual por
  `rpc('confirmar_pago_saldo', {p_solicitud_id, p_cita_id, p_monto, p_stripe_payment_id: pi.id})`.
  (La idempotencia y validación de monto quedan en la BD.)
- [x] B2. Nuevo evento `payment_intent.payment_failed`: extrae metadata concepto/solicitud_id/
  cita_id y monto; llama `rpc('registrar_pago_fallido', ...)` mapeando concepto→`p_tipo`
  (SALDO→SALDO, ADELANTO/DEPOSITO→DEPOSITO, PAGO_TOTAL→PAGO_TOTAL).

### C. Capa de datos/dominio `payments_stripe`

- [x] C1. `data/models/transaccion_model.dart`: parsea columnas de `transacciones`.
- [x] C2. `transaccion_entity.dart`: ampliar `TransaccionEntity` (estado `EstadoTransaccion`
  con `toDb/fromDb`, `stripePaymentId`, `stripePaymentIntent`, `moneda`) y añadir
  `AJUSTE` a `TipoTransaccion`.
- [x] C3. `comision_entity.dart`: `ComisionEntity{id, citaId, porcentaje, montoComision, montoEspecialista}`.
- [x] C4. `detalle_financiero_entity.dart`: `DetalleFinancieroCitaEntity` (depósito, pago
  final, saldo, comisión %, monto comisión y neto especialista) y `GenerarLiquidacionesEntity`.
- [x] C5. Datasource: `confirmarPagoSaldo` (RPC, reemplaza el UPDATE+INSERT de
  `registrarPagoSaldo`), `registrarPagoFallido` (RPC), `fetchTransaccionesAdmin`
  (filtros estado/tipo/fechas, join paciente + solicitud), `fetchComisionesAdmin`,
  `fetchDetalleFinancieroCita(citaId)` (join citas→solicitudes→pagos + comision_porcentaje),
  `generarLiquidaciones({fechaInicio, fechaFin})`.
- [x] C6. `i_payments_repository.dart` + impl: sustituir `registrarPagoSaldo` por
  `confirmarPagoSaldo` (devuelve el `motivo` del RPC como String) y `registrarPagoFallido`;
  añadir `getTransaccionesAdmin`, `getComisionesAdmin`, `getDetalleFinancieroCita`,
  `generarLiquidaciones`. (Siguiendo el patrón del código: el repositorio devuelve tipos
  crudos y los usecases envuelven en `Either<Failure, T>`.)
- [x] C7. Usecases: `ConfirmarPagoSaldo`, `RegistrarPagoFallido`, `GetTransaccionesAdmin`,
  `GetComisionesAdmin`, `GetDetalleFinancieroCita`, `GenerarLiquidaciones`.

### D. Flujo de cierre `treatment_execution`

- [x] D1. `revision_final_screen.dart` `_pagarSaldoPendiente`:
  - Éxito → `confirmarPagoSaldo` (RPC). Si `MONTO_INCORRECTO` → tratar como fallo.
  - Stripe cancelado/fallido → `registrarPagoFallido(...)` (no fatal), aviso «saldo
    quedará pendiente» y **continuar** el cierre (tratamiento COMPLETADO + cita FINALIZADA).
  - Se añadió helper `_registrarFalloSaldo` (cliente canceló / confirmación rechazada).

### E. Vista admin de conciliación

- [x] E1. `admin_conciliacion_screen.dart` en `/admin/conciliacion` (ruta `adminConciliacion`
  + tile en `admin_dashboard_screen`): tabs **Transacciones** (chips de estado, listado con
  concepto/monto/fecha/estado/ref Stripe copiable) y **Detalle financiero por cita**
  (depósito, pago final, saldo, comisión %, neto especialista).
- [x] E2. Cubit `AdminConciliacionCubit` (GetTransaccionesAdmin, GetComisionesAdmin,
  GetDetalleFinancieroCita, GenerarLiquidaciones) + registro en DI.
- [x] E3. Botón **«Generar liquidación»** (rango semanal por defecto vía date pickers) en
  `admin_comisiones_screen.dart` + recarga tras generar.

### F. Constantes + DI

- [x] F1. `app_constants.dart`: estados de transacción (`txEstado*`), `txPagoTotal`,
  `txAjuste`, `rpcConfirmarPagoSaldo`, `rpcRegistrarPagoFallido`, `rpcGenerarLiquidaciones`.
- [x] F2. `injection.dart`: registrar usecases nuevos y `AdminConciliacionCubit`;
  `PaymentsCubit` dejó de inyectar `RegistrarSaldo` (usecase eliminado).

### G. Verificación

- [x] G1. `flutter analyze` 0 issues; `flutter test` 366/366.
- [x] G2. Revisar migración (idempotente, grants, RLS).
- [ ] G3. Checklist manual (Stripe test keys): depósito → pago final OK → generar
  liquidación semanal; pago saldo cancelado → FALLIDA registrada + cita FINALIZADA +
  saldo pendiente; conciliación por ref Stripe. (Pendiente de aplicar la migración
  en el remoto y probar con claves de prueba.)
- [x] G4. Plan actualizado con checkpoints `[x]`.

## Notas

- La migración la aplica el usuario (SQL Editor o `supabase db push`, orden ascendente).
  Pendiente: `supabase migration list` + `supabase db push`.
- `transaccion_paciente_own FOR ALL` (onboarding) se mantiene: el paciente debe poder
  insertar sus transacciones de cuota inicial/depósito legacy; documentado como riesgo
  residual acotado.
- El dead code de `PaymentsCubit` y el onboarding legacy de `supabase_service.dart` quedan
  fuera de alcance (documentado, sin tocar).
- El botón «Generar liquidación» usa `sl<IPaymentsRepository>().generarLiquidaciones(...)`
  directamente (mismo patrón que el resto de pantallas de pago).