# Plan: Adelanto porcentual configurable para pago de servicios

Fecha: 2026-08-17
Estado: aprobado por el usuario

## Contexto

El pago de $30 (cuota inicial / aprobación Qualify) es obligatorio y cubre la
telemedicina o el servicio médico interno. **No se modifica**: `createSolicitudAndPayment`
(+ `deposito_reserva`) y `registerInitialPayment` siguen igual.

Lo que cambia es el pago al seleccionar un servicio del catálogo
(`createServicePayment`): hoy ofrece un "depósito" fijo de $30
(services_dashboard_screen.dart:228,340 y `_getDepositoReserva()`). Debe ser un
**adelanto porcentual del total** del servicio, configurable en
`configuracion_sistema`, o el pago completo.

El cobro del saldo pendiente al finalizar el tratamiento se mantiene como está hoy
(decisión diferida: se definirá la mejor fecha al desarrollar citas y tratamientos).

## Checklist

- [x] Plan persistido en `docs/plans/` (este archivo).
- [x] Migración `20260817010001_adelanto_porcentaje.sql` creada.
- [x] `AdelantoServicioEntity` en dominio de payments_stripe.
- [x] Datasource: `_getAdelantoPorcentaje()` + `calcularAdelanto()` + `createServicePayment` con `montoAPagar`.
- [x] Repositorio (`IPaymentsRepository` + impl) con `calcularAdelanto` y firma de `createServicePayment` actualizada.
- [x] Usecase `PagarServicio` y cubit `payments` propagan `montoAPagar`.
- [x] UI: modal con "Pagar Adelanto ($X · Y%)" y "Pagar Totalidad ($price)".
- [x] `_processServicePayment` usa `montoAPagar` calculado (adelanto o total).
- [x] Docstrings obsoletos ("depósito $30") actualizados.
- [x] `flutter analyze` sin issues; `flutter test` en verde.
- [x] Migración aplicada con `supabase db push`.

## Cambios por archivo

- `supabase/migrations/20260817010001_adelanto_porcentaje.sql`
- `lib/features/payments_stripe/domain/entities/adelanto_servicio_entity.dart` (nuevo)
- `lib/features/payments_stripe/domain/repositories/i_payments_repository.dart`
- `lib/features/payments_stripe/data/repositories/payments_repository_impl.dart`
- `lib/features/payments_stripe/data/datasources/payments_supabase_datasource.dart`
- `lib/features/payments_stripe/domain/usecases/pagar_servicio.dart`
- `lib/features/payments_stripe/presentation/cubits/payments_cubit.dart`
- `lib/features/catalog_services/presentation/screens/services_dashboard_screen.dart`

## Semántica

- `pagos.deposito` / `solicitudes.deposito_requerido` pasan a representar el
  "monto pagado por adelantado" (adelanto o totalidad). Compatible con el esquema.
- `calcularAdelanto(servicePrice)` devuelve `AdelantoServicioEntity(porcentaje, monto)`
  con `monto = (servicePrice × porcentaje / 100)` redondeado a 2 decimales.
- `createServicePayment` recibe `montoAPagar` (lo que ya cobró Stripe) y graba:
  `deposito_requerido = montoAPagar`, `deposito = montoAPagar`,
  `saldo_pendiente = (servicePrice - montoAPagar).clamp(0, …)`,
  `estado = montoAPagar >= servicePrice ? 'PAGADO' : 'PARCIAL'`, `deposito_pagado = true`.
- La cuota Qualify (`deposito_reserva` = 30) permanece sin cambios.