# Pruebas manuales — payments_stripe

| | |
|---|---|
| **Módulo** | payments_stripe (cuota inicial, reserva de servicios, cobro de saldo) |
| **Estado del código** | COMPLETO (datasource + repo + PaymentsCubit factory en DI; sin pantallas propias) |
| **Fecha** | 2026-08-14 |
| **Versión** | 1.0 |

## Alcance

Helper global `procesarPagoStripe` (`stripe_payment_sheet.dart`), PaymentsCubit (`crearIntent`, `pagarCuotaInicial`, `crearSolicitudDeposito`, `pagarServicio`, `registrarSaldo`, `consultarPago`), escrituras en `profiles`, `pacientes`, `solicitudes`, `pagos`, `transacciones`. Consumidores: CompleteProfileScreen, ServicesDashboardScreen, CitaDetalleScreen, PatientQuestionnaireScreen.

## Fuera de alcance

Flujos de UI que disparan el pago (docs 01, 05, 07, 09).

## Precondiciones generales

- **Modo simulado**: sin publishable key de Stripe o en web → referencias `STRIPE_SIM_<ts>` (los casos marcados [SIM] aplican solo aquí).
- **Modo real**: con key y edge function `create-payment-intent` desplegada (casos marcados [REAL]).
- `configuracion_sistema.clave='deposito_reserva'` (default 30).
- Paciente con perfil completo para cuota; solicitud con pago parcial para saldo.

## 1. Camino feliz

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| PS-H-01 | Cuota inicial $30 | Paciente en complete-profile | 1. Pagar cuota | `registerInitialPayment`: `profiles.payment_completed=true` + `pacientes.activo=true`; referencia guardada | Crítica | | |
| PS-H-02 | Depósito de servicio | Servicio seleccionado | 1. Pagar depósito | `createServicePayment`: solicitud BORRADOR + `pagos` (monto_total, depósito, saldo, PARCIAL) + `transacciones` (DEPÓSITO, APROBADO) | Crítica | | |
| PS-H-03 | Pago total de servicio | Servicio seleccionado | 1. Pagar totalidad | Solicitud **PUBLICADA** + pago PAGADO + transacción PAGO_TOTAL | Crítica | | |
| PS-H-04 | Cobro de saldo | Cita con `saldo_pendiente>0` | 1. Finalizar tratamiento → pagar saldo | `registrarPagoSaldo`: `pagos`→PAGADO, saldo 0 + transacción SALDO ligada a la cita | Crítica | | |
| PS-H-05 | Consultar pago | Solicitud con pago | 1. `consultarPago(solicitudId)` | Devuelve el pago con saldo correcto | Media | | |

## 2. Validaciones y casos negativos

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| PS-V-01 | PaymentSheet cancelado | Pago en curso | 1. Cancelar el sheet | `StripeException` → `null`; el flujo consumidor aborta sin registros | Crítica | | |
| PS-V-02 | Intent fallido | Edge function caída | 1. Iniciar pago | `crearIntent` falla → `PaymentsError`; sin PaymentSheet ni registros | Alta | | |
| PS-V-03 | Saldo ya en cero | Pago PAGADO | 1. `registrarPagoSaldo` de nuevo | Devuelve `false` (idempotencia); no crea segunda transacción | Crítica | | |
| PS-V-04 | `consultarPago` inexistente | Solicitud sin pago | 1. Consultar | Resultado vacío controlado; sin crash | Media | | |
| PS-V-05 | Doble cobro de saldo | Diálogo de finalización | 1. Pagar saldo 2. Intentar finalizar de nuevo | Segundo intento detecta saldo 0 y finaliza sin cobrar | Crítica | | |

## 3. Roles y permisos (guards / RLS)

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| PS-G-01 | Especialista no paga servicios | Sesión de especialista | 1. Intentar flujo de pago de servicio | Las escrituras de solicitud/pago están ligadas a paciente; verificar RLS | Alta | | |
| PS-G-02 | RLS de pagos | Paciente A | 1. Intentar leer `pagos` del paciente B | RLS lo impide | Alta | | |
| PS-G-03 | Edge function autenticada | Sin sesión | 1. Llamar `create-payment-intent` | `_shared/auth.ts` rechaza sin token | Alta | | |

## 4. Estados y transiciones

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| PS-E-01 | Secuencia del cubit | Pago válido | 1. `crearIntent` | `PaymentsLoading` → `PaymentsIntentReady(intent)` | Baja | | |
| PS-E-02 | Depósito no publica | Solicitud con solo depósito | 1. Verificar estado | BORRADOR; invisible en marketplace hasta pagar totalidad | Crítica | | |
| PS-E-03 | Completar pago parcial | Solicitud BORRADOR | 1. Pagar el resto | ¿Existe flujo para pasar BORRADOR→PUBLICADA pagando el saldo? Verificar (laguna posible) | Alta | | |
| PS-E-04 | `registerInitialPayment` no activa profile | Paciente recién pagado | 1. Verificar `profiles.activo` | Sigue `false` hasta `saveQualifyTestValidation`; verificar guard entre pago y cuestionario | Alta | | |

## 5. Red y edge cases

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| PS-N-01 | Pago sin red tras intent | Intent creado, luego modo avión | 1. Presentar sheet | Fallo controlado; sin registros | Alta | | |
| PS-N-02 | Registro fallido tras pago OK | Stripe OK, BD caída | 1. Provocar fallo en `createServicePayment` | **Crítico**: dinero cobrado sin registro; verificar detección/reintento | Crítica | | |
| PS-N-03 | Depósito desde configuración | `deposito_reserva` ausente | 1. Pagar depósito | Usa default 30 | Media | | |

## 6. Sospechosos de código

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| PS-S-01 | [SIM] Todo funciona sin pasarela | Sin key / web | 1. Recorrer todos los flujos de pago | Referencias `STRIPE_SIM_<ts>`; ningún flujo falla por pago — documentar que el modo demo nunca ejercita errores reales | Alta | | |
| PS-S-02 | [REAL] Cancelación no deja huérfanos | Con key real | 1. Cancelar PaymentSheet en cada consumidor (cuota, reserva, saldo) | Ningún consumidor registra solicitud/pago tras cancelación | Crítica | | |
| PS-S-03 | PaymentsCubit como factory | — | 1. Dos pagos consecutivos | Cada `sl<PaymentsCubit>()` crea instancia nueva; sin estado residual entre pagos | Media | | |

## Resumen de ejecución

| Total | Pasa | Falla | Bloqueado | Pendiente |
|---|---|---|---|---|
| 23 | | | | 23 |
