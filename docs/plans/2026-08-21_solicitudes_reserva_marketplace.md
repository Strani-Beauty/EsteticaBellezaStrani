# Plan: Solicitudes, Reserva y Marketplace

| | |
|---|---|
| **Fecha** | 2026-08-21 |
| **Estado** | APROBADO por el usuario (2026-08-21) |
| **Proyecto Supabase** | `hhyjremkguvphmjuaazp` |
| **Decisiones tomadas** | Ver sección "Decisiones" |

## Contexto

Implementar el flujo de extremo a extremo del paciente: selección de servicios →
creación de solicitud (reserva) → depósito → publicación en Marketplace →
geofencing/primer aviso → aceptación → cita → historial → notificaciones.

Estado actual (revisado en código y BD):

- `marketplace_citas` (lado especialista): mapa + `obtener_solicitudes_publicadas_geo`
  (privacidad RN-018) + `aceptar_solicitud` atómico (First-Accept). OK.
- `payments_stripe`: Stripe completo (PaymentIntent + PaymentSheet + webhook) y
  creación actual `solicitudes→pagos→transacciones` en un solo paso.
- `solicitud_detalles` existe en BD pero **no se usa** (todo por `solicitudes.servicio_id`).
- `historial_estados` solo cubre CITA; el trigger huérfano de SOLICITUD se eliminó
  por RLS roto (42501).
- El paciente tiene `FOR ALL` sobre sus solicitudes → puede publicar sin pago (hueco RLS).
- `obtener_solicitudes_publicadas_geo` no filtra por radio; `buscar_especialistas_cercanos`
  y PostGIS existen pero no se usan en la app.
- No hay RLS que permita al especialista asignado leer la solicitud `ACEPTADA` →
  el join de `treatment_execution` que revela la dirección exacta queda vacío.

## Decisiones (confirmadas por el usuario)

1. **Depósito = adelanto %** (mantener modelo actual). `deposito_requerido` =
   monto del adelanto (config `adelanto_porcentaje`, default 50%) o totalidad.
   El `$30` (cuota inicial de onboarding + `deposito_reserva`) no gatilla la
   publicación. Desvío acordado respecto a la Act. 6.
2. **Confirmación server-side por webhook** (`payment_intent.succeeded`) para
   publicar. **Pruebas sin dinero real**: Stripe test mode (tarjetas 4242) y
   `configuracion_sistema.enforce_pago_real='false'` que habilita el RPC de
   confirmación simulado desde el app.
3. **Notificaciones in-app + push FCM** a los especialistas del radio (que vieron
   la solicitud) cuando otra la acepta.
4. **Radio = config global** `radio_busqueda_km` (default 10) **+ override por
   solicitud** (`solicitudes.radio_busqueda`). Geofencing con `ST_DWithin`.
5. **Sí** a pantalla paciente "Mis solicitudes" (seguimiento del ciclo).

## Actividades → implementación

### A. Migración BD `supabase/migrations/20260821000100_solicitudes_reserva_marketplace.sql` (idempotente)

- [x] A1. Índices: `solicitud_detalles(solicitud_id)`, `historial_estados(tipo_entidad, entidad_id)`, `solicitudes(estado, fecha_expiracion)`.
- [x] A2. RPC `crear_solicitud_reserva(...)` security definer → solicitud `PENDIENTE_PAGO` + `solicitud_detalles` + `pagos` PARCIAL atómico; valida RN-020 por ítem.
- [x] A3. RPC `confirmar_deposito_solicitud(...)` security definer → idempotente, transacción APROBADO, publicación con `fecha_expiracion`/`radio_busqueda`. Gate `enforce_pago_real` (service_role webhook vs app simulado).
- [x] A4. Trigger `trg_proteger_publicacion_solicitud` (BEFORE UPDATE) → cierra el hueco de publicación sin pago.
- [x] A5. `trg_log_solicitud_estado` + `log_solicitud_estado_change()` SECURITY DEFINER → historial SOLICITUD.
- [x] A6. RLS: `solicitud_especialista_asignado_select`, `historial_solicitud_select`, `solicitud_detalles` (RLS + policies), `cita_paciente_select`.
- [x] A7. `obtener_solicitudes_publicadas_geo` v2: `jsonb_agg` servicios + `precio_total` + geofencing `ST_DWithin` + seeds `radio_busqueda_km`/`solicitud_expiracion_horas`/`enforce_pago_real`/`push_notifications`.
- [x] A8. `aceptar_solicitud` v2: `cita.fecha_inicio=fecha_programada`, historial CITA y notificaciones in-app (+push vía pg_net) a especialistas del radio.
- [x] A9. **Aplicada al remoto** (SQL Editor del usuario + fixes 00200/00300/00400 vía pooler) y registradas en `supabase_migrations.schema_migrations`. Ver "Hallazgos post-aplicación".

### B. Edge functions

- [x] B1. `stripe-webhook`: concepto `ADELANTO`/`DEPOSITO`/`PAGO_TOTAL` → `confirmar_deposito_solicitud` (idempotente). Mantiene SALDO. **Desplegada.**
- [x] B2. `send-push` (nueva): FCM legacy HTTP API hacia tokens de `dispositivos_usuario`; invocada desde la BD vía `pg_net` (gate `push_notifications` + `edge_function_base_url`/`anon_key`). **Desplegada.**

### C. Feature Flutter `solicitudes_reserva` (lado paciente)

- [x] C1. `data/`: datasource (RPC crear/confirmar + reads mis solicitudes/dirección/config), models, repository `Either<Failure,T>`.
- [x] C2. `domain/`: entidades + usecases (`CrearSolicitudReserva`, `ConfirmarPagoDeposito`, `GetMisSolicitudes`, `GetMiDireccionPrincipal`, `GetConfigReserva`).
- [x] C3. `presentation/`: `SolicitudResumenScreen` (multi-servicio, precio, fecha/hora, ubicación, radio, depósito) y `MisSolicitudesScreen`. Rutas `/mis-solicitudes` y `/solicitud/resumen`.
- [x] C4. `ServicesDashboardScreen`: card → gates → navegar al resumen; se depreca el modal de pago directo.
- [x] C5. Registro DI en `injection.dart` (usecases por nombre).

### D. Marketplace (especialista) — ajustes

- [x] D1. `SolicitudPendienteModel/Entity`: lista de servicios + precio total + fecha programada (parse de `jsonb_agg`).
- [x] D2. `specialist_map_screen`: detalle/listado con multi-servicio, preferencia de fecha y total.

### E. Limpieza de deuda

- [x] E1. Deprecados `createServicePayment`/`createSolicitudAndPayment` en el catálogo (eliminado el flujo de pago directo del catálogo; el onboarding Qualify conserva `createSolicitudAndPayment`). Se normalizó `tipo_transaccion` a los valores ASCII de la app (`payments_supabase_datasource.dart`).

### F. Verificación y documentación

- [x] F1. `flutter analyze` 0 issues; `flutter test` **141/141** en verde (incluye tests nuevos de modelos y cubit de reserva).
- [x] F2. Migración aplicada al remoto y **verificada por smoke tests** (crear → confirmar → publicar → aceptar → cita → historial → notificaciones), todo con rollback.
- [x] F3. E2E manual `docs/pruebas/2026-08-21_solicitudes_reserva_marketplace_e2e.md` creado; `docs/Pruebas manuales/06_marketplace_citas.md` ampliado y nuevo `12_solicitudes_reserva.md`. **Pendiente**: ejecutar el checklist E2E en la app.

## Hallazgos post-aplicación (deuda corregida con migraciones de fix)

1. **`transacciones.tipo_transaccion` CHECK** creado fuera del repo con valores acentuados (`DEPÓSITO`/`PAGO_FINAL`); la app usa ASCII (`DEPOSITO`/`PAGO_TOTAL`/`SALDO`). Fix `20260821000200_fix_transacciones_tipo_transaccion_check.sql`: normaliza el CHECK a `(DEPOSITO, PAGO_TOTAL, SALDO, REEMBOLSO, AJUSTE)` + backfill (tabla vacía).
2. **`pagos.estado` es enum `estado_pago_enum`**: el `CASE` del UPDATE en `confirmar_deposito_solicitud` devolvía `text` → 42804. Fix `20260821000300_fix_confirmar_pagos_estado_cast.sql` (cast `::estado_pago_enum`).
3. **`tr_log_cita_estado` previo en `citas`** (también fuera del repo) ya registraba historial CITA en INSERT/UPDATE → `aceptar_solicitud` duplicaba. Fix `20260821000400_quitar_historial_cita_duplicado.sql`.
4. **Deuda pre-existente corregida**: la app (`treatment_execution._insertHistorial`) insertaba historial CITA manualmente además del trigger `tr_log_cita_estado` → doble registro en el ciclo de ejecución de citas. **Corregido** con `20260821000500_eliminar_tr_log_cita_estado.sql`: se elimina el trigger y su función, y se restaura en `aceptar_solicitud` el registro de la cita creada (PROGRAMADA). Fuente única: creación → `aceptar_solicitud`; transiciones → app (`_insertHistorial`).

## Notas

- **Pruebas sin dinero real**: Stripe test mode (4242) y `enforce_pago_real='false'`
  para E2E simulado (el app llama `confirmar_deposito_solicitud` directamente).
- El historial de SOLICITUD queda cubierto por `trg_log_solicitud_estado` (SECURITY
  DEFINER, no reintroduce el 42501); el de CITA por `aceptar_solicitud` (creación)
  y la app (`_insertHistorial`, transiciones) — se eliminó el trigger duplicado
  `tr_log_cita_estado` (00500).
- El pooler del proyecto responde en el puerto **6543** (el 5432 dio timeout).
