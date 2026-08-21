# Resumen de jornada — 2026-08-21

- **Fecha**: 2026-08-21
- **Rama**: `main`.
- **Flutter**: SDK 3.44.9 (sin cambios hoy).

Ciclo completo de **Solicitudes, Reserva y Marketplace**: implementación de la feature `solicitudes_reserva`, migraciones BD `20260821000100`–`20260821000500`, edge functions `stripe-webhook`/`send-push`, smoke tests BD de la cadena, fixes de runtime encontrados durante la verificación, y **E2E verificado 14/14** en app. Plan: `docs/plans/2026-08-21_solicitudes_reserva_marketplace.md` (APROBADO). Evidencia: `docs/pruebas/2026-08-21_solicitudes_reserva_marketplace_e2e.md`.

| Ciclo | Estado | Commit |
|---|---|---|
| 1. Implementación (feature + migraciones 00100-00400 + edge functions + tests 141/141) | ✅ Pusheado | `5814e81` |
| 2. Historial CITA unificado: se elimina el trigger duplicado `tr_log_cita_estado` (00500) | ✅ Pusheado | `7a1e76f` |
| 3. E2E verificado 14/14 + documentación de pruebas y resumen de jornada | ✅ Documentado (este commit) | — |

---

## 1. Implementación — Solicitudes, Reserva y Marketplace

- **Feature `solicitudes_reserva`** (Clean Architecture): `SolicitudResumenScreen` (multi-servicio, precio estimado, fecha/hora preferida, dirección, radio, depósito) + `MisSolicitudesScreen` + rutas `/solicitud/resumen` y `/mis-solicitudes` + DI.
- **Catálogo**: card → gates (RN-020/face-map/requisitos) → resumen de solicitud; se depreca el modal de pago directo.
- **Marketplace**: solicitudes multi-servicio (jsonb) con precio total y preferencia de fecha; geofencing server-side por radio.
- **Migraciones BD**:
  - `20260821000100_solicitudes_reserva_marketplace.sql`: RPCs `crear_solicitud_reserva` y `confirmar_deposito_solicitud`; trigger `trg_proteger_publicacion_solicitud` (anti-publicación sin pago); trigger `trg_log_solicitud_estado` (historial SOLICITUD, SECURITY DEFINER); RLS nuevas (asignado, historial, `solicitud_detalles`, cita del paciente); `obtener_solicitudes_publicadas_geo` v2 (multi-servicio + `ST_DWithin`); `aceptar_solicitud` v2 (cita con fecha preferida + notificaciones in-app).
  - `20260821000200`..`20260821000400`: fixes de runtime (ver sección 2).
  - `20260821000500_eliminar_tr_log_cita_estado.sql`: historial CITA con una sola fuente.
- **Edge functions desplegadas**: `stripe-webhook` (confirma depósito `ADELANTO`/`PAGO_TOTAL` y publica) y `send-push` (FCM).

## 2. Fixes de runtime encontrados en los smoke tests

- **CHECK de `transacciones.tipo_transaccion`** creado fuera del repo con valores acentuados (`DEPÓSITO`/`PAGO_FINAL`) → normalizado a los valores ASCII de la app (`DEPOSITO`/`PAGO_TOTAL`/`SALDO`/`REEMBOLSO`/`AJUSTE`) con `20260821000200`. Se corrigió además el literal `'DEPÓSITO'` en `payments_supabase_datasource.dart`.
- **`pagos.estado` es enum**: el `CASE` del UPDATE devolvía `text` (42804) → cast `::estado_pago_enum` en `20260821000300`.
- **Doble historial CITA**: existía el trigger `tr_log_cita_estado` (también fuera del repo) y la app insertaba manualmente. `20260821000400` quitó el insert duplicado en `aceptar_solicitud`; luego el usuario eligió la **opción 1** (`20260821000500`): se eliminó el trigger y su función, restaurando en `aceptar_solicitud` el registro de la cita creada. Fuente única: creación → RPC; transiciones → app `_insertHistorial`.

## 3. E2E verificado 14/14 ✅

Checklist completo en `docs/pruebas/2026-08-21_solicitudes_reserva_marketplace_e2e.md`. Resumen:

- **Flujo paciente (ítems 1-5)**: selección multi-servicio, crear solicitud (`PENDIENTE_PAGO` + detalles + pago PARCIAL), resumen antes de confirmar, depósito procesado y bloqueo de publicación sin depósito.
- **Marketplace (ítems 6-8)**: solo verificados la reciben, solo dentro del radio la ven, dirección exacta oculta (RN-018).
- **Aceptación (ítems 9-13)**: first-accept atómico, exclusividad para los demás, dirección revelada solo al asignado, cita `PROGRAMADA`.
- **Registro (ítem 14)**: historial SOLICITUD + CITA sin duplicados.
- Smoke tests BD con rollback: crear → confirmar → `PUBLICADA` → aceptar → cita + historial + notificaciones.

## Verificación transversal

- `flutter analyze` → sin issues.
- `flutter test` → **144/144** OK.
- BD: migraciones `00100`–`00500` aplicadas al remoto y registradas en `schema_migrations` (Local == Remote).

### Pendientes documentados

- Pruebas manuales específicas aún ⬜ en `docs/Pruebas manuales/12_solicitudes_reserva.md` (pago totalidad, pago cancelado, depósito mínimo, RLS detalles, radio override) y `06_marketplace_citas.md` (23/31).
- Deuda pre-existente (no tocada): buckets públicos (`contratos`, `firmas-consentimiento`, `fotografias-tratamiento`), RPC sin filtro de `fecha_expiracion` en la publicación.
- **Push FCM**: `send-push` desplegado y configs `edge_function_base_url` + `anon_key` seteadas en `configuracion_sistema` (2026-08-21); **pendiente** el secret `FCM_LEGACY_SERVER_KEY` en la edge function (Firebase Console → Project settings → Cloud Messaging → Server key) para que el push real funcione. Las notificaciones in-app ya funcionan.

---

## 4. Seguimiento post-documentación (2026-08-21): fix MK-S-02 + push FCM

- **MK-S-02 corregido**: `marketplace_cubit._refrescar` ignoraba el error del refresco tras una aceptación perdida (`fold((f) => null)`). Ahora conserva la lista y avisa "No se pudo actualizar el mapa: …". Añadido `test/features/marketplace_citas/presentation/cubits/marketplace_cubit_test.dart` (3 tests). `flutter analyze` 0 issues; `flutter test` **144/144**.
- **Push FCM configurado (parcial)**: se insertaron `edge_function_base_url` y `anon_key` en `configuracion_sistema` para que el hook `pg_net → send-push` tenga base y auth. Falta únicamente `FCM_LEGACY_SERVER_KEY` (secret de la edge function) para el envío real.
