# Pruebas manuales — Solicitudes, Reserva y Marketplace (E2E) — VERIFICADO

| | |
|---|---|
| **Fecha** | 2026-08-21 |
| **Versión** | 1.1 (reporte verificado) |
| **Commits** | `5814e81` (implementación) + `7a1e76f` (historial CITA unificado) |
| **Entorno** | Local `flutter run -d web-server --web-port 8080` (NO el desplegado en web.app) |
| **Plan** | `docs/plans/2026-08-21_solicitudes_reserva_marketplace.md` |
| **Proyecto Supabase** | `hhyjremkguvphmjuaazp` |
| **Confirmación de correo** | Desactivada en Supabase para pruebas |

## Configuración previa

- Migraciones `20260821000100` a `20260821000500` aplicadas al remoto (SQL Editor + fixes vía pooler) y registradas en `supabase_migrations.schema_migrations`.
- `configuracion_sistema.enforce_pago_real = 'false'` (pruebas simuladas sin dinero real). El gate de producción (`'true'` → solo webhook) se valida por contra-prueba.
- Stripe en test mode (tarjeta `4242 4242 4242 4242`) o modo simulado (`STRIPE_SIM_…` sin clave).

## Cuentas

| Rol | Email | Clave |
|---|---|---|
| Paciente con APTO + dirección principal | `pac.compliance1@test.com` | `Test1234!` |
| Especialista APROBADO + expediente (acepta) | ESPECIALISTA TEST 2 (`b0671708-…`) | `Test1234!` |
| Especialistas APROBADOS del radio (notificados) | seed `Dr. Carlos Medina` / `Dr. José Ramírez` | `Test1234!` |

## Checklist de aceptación (14 ítems ✅)

| # | Ítem (Actividad) | Resultado | Evidencia / observación |
|---|---|---|---|
| 1 | Selección de uno o varios servicios (Act. 1-2) | ✅ | Catálogo → gates (RN-020/face-map/requisitos) → `SolicitudResumenScreen`; "Agregar" permite multi-servicio con cantidades y recalcula total/depósito; se crean filas en `solicitud_detalles` (smoke BD: `n` = nº de ítems). |
| 2 | Crear solicitud (Act. 5) | ✅ | `crear_solicitud_reserva` inserta solicitud en `PENDIENTE_PAGO` (`deposito_pagado=false`) + `solicitud_detalles` + `pagos` PARCIAL; historial SOLICITUD "Creación de solicitud" (smoke BD). |
| 3 | Resumen antes de confirmar (Act. 4) | ✅ | El resumen muestra servicios con cantidades/subtotal, precio estimado total, saldo, fecha/hora preferida, dirección principal, radio y depósito; botón "Pagar depósito/totalidad". Sin dirección → bloqueo con aviso. |
| 4 | Depósito procesado (Act. 6) | ✅ | PaymentSheet (test 4242 o simulado) → `confirmar_deposito_solicitud` marca `deposito_pagado=true`, inserta transacción `DEPOSITO`/`PAGO_TOTAL` APROBADO y actualiza `pagos`. **Nota**: el monto del depósito es el adelanto % (`adelanto_porcentaje`, default 50) o la totalidad; el `$30` de la Act. 6 se mantiene como cuota de onboarding / `deposito_reserva` (decisión del usuario). |
| 5 | Sin depósito no se publica (Act. 7) | ✅ | Trigger `trg_proteger_publicacion_solicitud` exige `deposito_pagado=true` + transacción APROBADO + marca de sesión del RPC; gate `enforce_pago_real` restringe a webhook en producción. Contra-prueba: UPDATE directo a `PUBLICADA` → excepción ("La solicitud no puede publicarse sin un depósito confirmado"). |
| 6 | Solo especialistas verificados la reciben (Act. 8) | ✅ | `obtener_solicitudes_publicadas_geo` exige especialista `APROBADO` + `activo`; `aceptar_solicitud` exige además `cumple_requisitos_habilitacion`. Contra-prueba: especialista APROBADO sin expediente → `NO_APROBADO`. |
| 7 | Solo especialistas disponibles dentro del radio la ven (Act. 8-9) | ✅ | Geofencing `ST_DWithin` con `radio = COALESCE(s.radio_busqueda, radio_busqueda_km) * 1000`. Especialistas fuera del radio no la ven en el RPC ni reciben notificación (smoke2: solo los del radio notificados). |
| 8 | La dirección exacta permanece oculta (Act. 10) | ✅ | RN-018: el RPC devuelve coords truncadas a 3 decimales (~110 m) + ciudad; `direccion` nunca se incluye (`SolicitudPendienteModel.direccion` siempre `null`). La policy `direccion_paciente_especialista_cita` exige cita asignada. |
| 9 | Un especialista puede aceptar la solicitud (Act. 11-12) | ✅ | `aceptar_solicitud` (validación de verificación/expediente + claim) → `aceptada=true` con `cita_id` (smoke2). |
| 10 | El primero que acepta obtiene la solicitud (Act. 11) | ✅ | Claim atómico (`UPDATE … WHERE estado IN ('PUBLICADA','BUSCANDO_ESPECIALISTA') AND not expirada` + `GET DIAGNOSTICS`); el segundo aceptar devuelve `ASIGNADA`/`EXPIRADA` y no crea cita. |
| 11 | Los demás dejan de verla/disponer de ella (Act. 11/14) | ✅ | Al pasar a `ACEPTADA` la solicitud sale del `obtener_solicitudes_publicadas_geo` (filtro por estado) y el especialista ya no puede aceptarla; se genera notificación in-app `SOLICITUD_ASIGNADA` a los especialistas del radio (smoke2: 2 usuarios). |
| 12 | La dirección completa se revela solo al asignado (Act. 12) | ✅ | Policies `solicitud_especialista_asignado_select` (lee su solicitud ACEPTADA) + `direccion_paciente_especialista_cita` (lee dirección) → la cita detalle de `treatment_execution` muestra la dirección exacta únicamente al especialista de la cita. |
| 13 | Se genera la cita correspondiente (Act. 12) | ✅ | `aceptar_solicitud` inserta cita `PROGRAMADA` con `fecha_aceptacion` y `fecha_inicio = fecha_programada` del paciente (smoke2). |
| 14 | Los cambios de estado quedan registrados (Act. 13) | ✅ | Historial SOLICITUD (`trg_log_solicitud_estado`): PENDIENTE_PAGO → PUBLICADA → ACEPTADA; historial CITA: creación (en `aceptar_solicitud`) + transiciones (app `_insertHistorial`). Post-`00500` sin duplicados (smoke2: 1 fila CITA PROGRAMADA). |

## Registro de ejecución

| Fase | Ítems | Resultado |
|---|---|---|
| A — Flujo paciente (selección, resumen, crear, depósito, publicación) | 1, 2, 3, 4, 5 | ✅ |
| B — Marketplace (verificación, radio, privacidad) | 6, 7, 8 | ✅ |
| C — Aceptación (first-accept, exclusividad, cita, dirección) | 9, 10, 11, 12, 13 | ✅ |
| D — Historial y notificaciones | 14 | ✅ |

## Comandos de verificación

```powershell
flutter analyze
flutter test
```

## Notas y hallazgos

- **Desvío aprobado**: depósito de reserva = adelanto % o totalidad (no el fijo `$30`, que queda como cuota de onboarding). `configuracion_sistema.deposito_reserva` sigue disponible.
- **Deuda pre-existente documentada** (no corregida en este ciclo): buckets públicos (`contratos`, `firmas-consentimiento`, `fotografias-tratamiento`), y RPC sin filtro de `fecha_expiracion` en la publicación (la expiración la decide el RPC al aceptar). El **push FCM quedó operativo**: `send-push` en FCM HTTP v1 (la API legacy devuelve 404), secret `FCM_SERVICE_ACCOUNT` seteado, `pg_net` habilitado y verificado de punta a punta (hook BD → `send-push` → HTTP 200).

## Estado

- Migraciones `00100`–`00500` aplicadas al remoto y registradas en `schema_migrations` (**Local == Remote**).
- Checklist E2E: **14/14 ✅** (verificado en app + smoke tests BD con rollback).
- `flutter analyze`: 0 issues.
- `flutter test`: 141/141.
