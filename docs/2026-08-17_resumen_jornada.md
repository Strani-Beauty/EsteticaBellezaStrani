# Resumen de jornada — 2026-08-17

- **Fecha**: 2026-08-17
- **Rama**: `main` (sincronizada con `origin/main` en `a4ec43e`; trabajo de la mañana pusheado).
- **Flutter**: SDK en **3.44.9** (ver bloque 3).

Cinco ciclos de trabajo hoy:

| Ciclo | Estado | Commit |
|---|---|---|
| 1. Fix confirmación de correo PKCE | ✅ Pusheado | `191b563` |
| 2. Documentos de compliance + storage privado | ✅ Pusheado | `36b9ab5` |
| 3. Upgrade Flutter 3.44.9 + cerrar deuda `dart:html` | ✅ Pusheado | `2bf3140` |
| 4. Face map reutilizable por servicio | ✅ Pusheado | `a4ec43e` |
| 5. Adelanto porcentual configurable para pago de servicios | 🚧 Implementado y verificado, **sin commit** | — |

Planes detallados en `docs/plans/` (inmutables): `2026-08-17_fix_confirmacion_correo_pkce.md`, `2026-08-17_documentos_compliance_storage_privado.md`, `2026-08-17_upgrade_flutter_3449_y_deuda_dart_html.md`, `2026-08-17_face_map_servicio_estado_tratamiento.md`, `2026-08-17_adelanto_porcentual_servicios.md`.

---

## 1. Fix confirmación de correo PKCE — `191b563`

**Bug**: confirmar el correo fallaba silenciosamente cuando ya había sesión previa o actividad en el browser de registro.

**Causa raíz**: con `AuthFlowType.pkce` + `detectSessionInUri: true`, el link de confirmación necesita el *code verifier* guardado en el browser al registrarse. Al cerrar pestaña, `AppLifecycleState.detached` llamaba `clearLocalSession()` (signOut local de gotrue), que **borraba también el verifier**; con sesión previa (login por contraseña) el verifier nunca existía. Sin verifier, `exchangeCodeForSession` lanza `AuthException('Code verifier could not be found in local storage.')` que supabase_flutter loguea en silencio → el usuario no veía nada. También rompía el recovery de contraseña (mismo verifier).

**Cambios**:
- `lib/app/core/session_storage_cleaner.dart` + `session_storage_cleaner_web.dart` (import condicional): en web elimina **solo** el token de sesión (`sb-<project>-auth-token`), preservando `flutter.supabase.auth.token-code-verifier`; stub no-op fuera de web.
- `lib/app/app.dart`: en `detached`, web → limpiar solo el token; mobile → `clearLocalSession()` (comportamiento previo).
- `lib/main.dart` + `App`: si la URL inicial es callback de auth (`code`/`error`/`error_description`/`error_code`) y no hay usuario, muestra SnackBar amigable ("El enlace no se pudo usar (expiró, ya fue usado o fue enviado desde otro navegador)...").

**Verificación**: `flutter analyze` sin issues; `flutter test` 80/80.

**Pendiente (manual)**: registrar → cerrar pestaña → abrir link de confirmación en el mismo browser con sesión previa → la cuenta se confirma.

---

## 2. Documentos de compliance + storage privado — `36b9ab5`

**Contexto**: el especialista veía el estado de sus documentos y el admin los revisaba, pero el bucket `documentos-especialistas` era **público** (`url_archivo` con `getPublicUrl`), la subida desde el panel solo "registraba" el tipo sin archivo, y requeridos = solo `[identificacion, licencia]`.

**Cambios**:
- **Migración `20260817000000_documentos_storage_privado.sql`** (aplicada al remoto con `supabase db push`; remoto en `20260817000000`):
  - `storage.buckets` → `public = FALSE` para `documentos-especialistas` (idempotente).
  - `DROP POLICY "documento_storage_public_select"`; nuevas policies: `documento_storage_own_select` (dueño, path `[1]` = id del especialista) y `documento_storage_admin_select` (rol Administrador).
  - Migra `url_archivo` existentes (URL pública → path `<especialistaId>/<ts>.<ext>`) para conservar el historial.
- **Capa de datos**: `subirDocumento` guarda el **path** (sin `getPublicUrl`); nuevo `crearUrlFirmada(path)` → `createSignedUrl(path, expiresIn: 3600)` (URL firmada 1h, generada on-demand); repositorio `generarUrlFirmadaDocumento` + usecase `GenerarUrlFirmadaDocumento` + registro en `injection.dart`; `SpecialistsCubit.generarUrlFirmadaDocumento`.
- **Requeridos**: identificación, licencia profesional y **formación** (se cumple con **diploma O certificación**). Helper compartido `documentos_requeridos.dart` usado por `specialist_documents_screen.dart` (3 tiles + selector de formación) y `specialist_home_screen.dart`.
- **UI**: `documentos_section.dart` — "Subir" con FilePicker + `uploadDocument`, botón "Ver" con URL firmada; `admin_dashboard_screen.dart` — `_abrirDocumento` firma la URL antes de `launchUrl`.
- **AGENTS.md**: sección "Rol de experto Senior en Flutter y Supabase" (seguridad/RLS/storage privado/sin secretos, Clean Architecture, calidad, buenas prácticas de Supabase).

**Verificación**: `flutter analyze` sin issues; `flutter test` 80/80; migración aplicada al remoto.

**Fuera de alcance (documentado en el plan)**: convertir los otros buckets públicos (`contratos`, `firmas`, `fotografias-tratamiento`) a privados; renombrar `url_archivo` (semántica = path, se mantiene el nombre).

---

## 3. Upgrade Flutter 3.44.9 + cerrar deuda `dart:html` — `2bf3140` ✅

**Objetivo aprobado**: actualizar el SDK a **3.44.9** (patch de la línea actual, no 3.47.0), migrar `session_storage_cleaner_web.dart` a `package:web` y subir `supabase_flutter` 2.5.0 → 2.16.0. **Sin deploy** (solo build de verificación). Fases 1-3 juntas.

### Preparación / rollback
- Commit previo del SDK capturado: `058e0af2c2b57e369d905a03ac9748b0ebf543c6` (punto de rollback).
- Tag `pre-flutter-upgrade` sobre `36b9ab5` (rollback del repo).

### Fase 1 — SDK 3.44.9
- `git checkout 3.44.9` en `C:\Users\Jaime\Desktop\Flutter\flutter` (detached HEAD; Dart 3.12.2, DevTools 2.57.0).
- `flutter pub get` sin cambios de lockfile (patch); `flutter analyze` OK; `flutter test` 80/80; `flutter build web` OK (aviso de Wasm por `app_links` 3.5.1, resuelto en Fase 3).

### Fase 2 — Cleaner web a `package:web`
- `web: ^1.1.1` como dependencia directa; `session_storage_cleaner_web.dart` reescrito con `web.window.localStorage` (`key(i)`/`length`/`removeItem`), sin `dart:html` ni `ignore_for_file`. Mismo comportamiento (borra solo `sb-*-auth-token`, preserva el verifier).

### Fase 3 — supabase_flutter 2.16.0
- `supabase_flutter: ^2.16.0` → **resuelto 2.16.0**; `supabase 2.14.0`, `storage_client 2.6.0`, `gotrue 2.26.0`, `postgrest 2.8.0`, `realtime_client 2.11.0` **sin cambios** → `createSignedUrl(path, 3600)` intacto. Nuevos transitivos: `passkeys_platform_interface 2.9.0`, `app_links 7.2.1` (federado → `app_links_web`).
- **Incidencia resuelta**: el registrant web apuntaba a `package:app_links/src/app_links_web.dart` (existe solo en 3.5.1; en 7.x el impl web es federado `app_links_web`) → `flutter clean` + `pub get` + rebuild → build web OK y **Wasm dry run OK**.

### Fase 4 — Verificación integral
- `flutter analyze` sin issues; `flutter test` 80/80 (post-clean); `flutter build web` ✓ Built.
- Plan persistido en `docs/plans/2026-08-17_upgrade_flutter_3449_y_deuda_dart_html.md`.

### Commit
- `2bf3140` "Actualiza Flutter a 3.44.9 y cierra deuda dart:html: cleaner web con package:web y supabase_flutter 2.16.0" → pusheado a `main` (36b9ab5..2bf3140).

### Pendiente
- [ ] Smoke test manual en browser (checklist en el plan): login/registro PKCE, logout web (solo `sb-*-auth-token` en Local Storage), subida de documentos → URL firmada, revisión admin con observación, vista rápida de mapa/firma/stripe/avatar.

---

## 4. Face map reutilizable por servicio — `a4ec43e` ✅

**Objetivo aprobado**: al re-seleccionar un servicio inyectable, si el tratamiento aún no está cerrado, mostrar los puntos ya seleccionados por el paciente (solo lectura + "Continuar al Pago"); solo pedir editar puntos al iniciar otro tratamiento del mismo tipo (pre-cargando los puntos previos).

**Definición de "tratamiento cerrado" (acordada con el usuario)**: tratamiento aplicado (todos los productos, todos los puntos, especialista informa) **y pagado en su totalidad** → `tratamientos.estado = 'COMPLETADO'` para ese servicio **y** `pagos.saldo_pendiente = 0`. Cualquier otro caso (sin fila, `INICIADO/EN_PROCESO/PENDIENTE_FIRMA`, `CANCELADO`) = no cerrado → mostrar puntos guardados.

**Cambios**:
- **Migración `20260817010000_face_map_servicio_y_puntos.sql`** (aplicada al remoto): `face_maps.servicio_id` + índice `(paciente_id, servicio_id)`; `face_map_puntos.punto_id` + `vista` + índice `face_map_id`.
- `SupabaseService.saveFaceMapRecord` ahora guarda `servicio_id` y por punto `punto_id`/`vista`; nuevo `getFaceMapPorServicio({profileId, servicioId})` → último mapa del paciente+servicio con `tratamientoCerrado` (consulta `citas→tratamientos(estado)` por `solicitud_id` + `pagos.saldo_pendiente`).
- `IPatientsComplianceRepository` + impl espejados; **backfill** `face_maps.solicitud_id` en `createServicePayment` (el face map se guarda antes de que exista la solicitud → trazabilidad a tratamiento/pago).
- Face map screen: params `servicioId`/`soloLectura`/`puntosIniciales`, modo lectura (banner, oculta barra rápida/notas/borrado, botón "Continuar al Pago" → `pop('continuar')`), pre-carga en edición, `FaceMapParams` (ruta retro-compatible con `String`), helper `reconstruirPuntosFaceMap` (agrupa por `punto_id`/`vista`, fallback por label).
- `services_dashboard_screen.dart`: consulta `getFaceMapPorServicio` → lectura si hay mapa y no cerrado (→ 'continuar' abre pago) o edición pre-cargada.

**Verificación**: `flutter analyze` sin issues; `flutter test` 80/80; migración aplicada al remoto (remoto en `20260817010000`).

---

## 5. Adelanto porcentual configurable para pago de servicios — 🚧 SIN COMMIT

**Objetivo aprobado**: el pago de $30 (cuota inicial / Qualify) cubre la telemedicina o el servicio médico interno y es obligatorio → **no se modifica**. Al pagar un servicio del catálogo debe ofrecerse un **adelanto porcentual del total** (configurable) o el servicio completo — no un "depósito" fijo de $30. El cobro del saldo al finalizar se mantiene como hoy (decisión diferida: se definirá la mejor fecha al desarrollar citas y tratamientos).

**Cambios**:
- **Migración `20260817010001_adelanto_porcentaje.sql`** (aplicada al remoto): seed `adelanto_porcentaje = 50` en `configuracion_sistema`. `deposito_reserva` ($30, cuota Qualify) intacto.
- `AdelantoServicioEntity(porcentaje, monto)` (nuevo); datasource: `_getAdelantoPorcentaje()` (default 50) + `calcularAdelanto(servicePrice)` (monto = precio × %/100, 2 decimales) + `createServicePayment` con `montoAPagar` (lo ya cobrado por Stripe) → graba `deposito_requerido`/`deposito` = monto pagado, `saldo_pendiente = precio − monto`, `estado = PAGADO/PARCIAL`; transacción parcial usa `DEPOSITO` (consistente con el enum).
- `IPaymentsRepository` (+impl): `calcularAdelanto` nuevo y firma de `createServicePayment` con `montoAPagar`; usecase `PagarServicio` y cubit `payments` propagan `montoAPagar`.
- UI (`services_dashboard_screen.dart`): el modal consulta `calcularAdelanto(price)` y muestra **"Pagar Adelanto ($X · 50%)"** o **"Cancelar Totalidad ($price)"**; `_processServicePayment` usa el `montoAPagar` calculado (concepto `ADELANTO`/`PAGO_TOTAL`).

**Verificación**: `flutter analyze` sin issues; `flutter test` 80/80; migración aplicada al remoto.

**Pendiente**: commit + push (el usuario avisará; mensaje en español).

---

## Verificación transversal

- `flutter analyze` → sin issues (en los cinco ciclos).
- `flutter test` → 80/80 OK (tests placeholder/widget; el proyecto no tiene suite real de tests).
- BD: migraciones aplicadas al remoto hasta `20260817010001` (`supabase db push`).

### Working tree actual (sin commitear)
- Ciclo 5 (adelanto porcentual): `supabase/migrations/20260817010001_adelanto_porcentaje.sql`, `lib/features/payments_stripe/domain/entities/adelanto_servicio_entity.dart`, datasource/repositorio/usecase/cubit de `payments_stripe`, `services_dashboard_screen.dart`.
- `docs/plans/2026-08-17_adelanto_porcentual_servicios.md` (nuevo) y este resumen.