# Resumen de jornada — 2026-08-17

- **Fecha**: 2026-08-17
- **Rama**: `main` (sincronizada con `origin/main` en `6c19d8a`; todo el trabajo del día pusheado y desplegado).
- **Flutter**: SDK en **3.44.9** (ver bloque 3).

Siete ciclos de trabajo hoy:

| Ciclo | Estado | Commit |
|---|---|---|
| 1. Fix confirmación de correo PKCE | ✅ Pusheado | `191b563` |
| 2. Documentos de compliance + storage privado | ✅ Pusheado | `36b9ab5` |
| 3. Upgrade Flutter 3.44.9 + cerrar deuda `dart:html` | ✅ Pusheado | `2bf3140` |
| 4. Face map reutilizable por servicio | ✅ Pusheado | `a4ec43e` |
| 5. Adelanto porcentual configurable para pago de servicios | ✅ Pusheado | `4cfdf84` |
| 6. Avatares específicos del ingreso de datos paciente | ✅ Pusheado | `5fa0211` |
| 7. Confirmación de correos pendientes (pruebas, reversible) | ✅ Pusheado | `617d602` |
| 8. Flujo de registro y panel del especialista en web (4 bugs) | ✅ Pusheado + **desplegado** | `6c19d8a` |
| 9. Avatares: bucket privado + URLs firmadas + DiceBear local | ✅ Pusheado | `d01b7c2` |
| 10. Presets DiceBear creativos (8 estilos) + fix de subida/preview | ✅ Desplegado | *pendiente commit* |

Planes detallados en `docs/plans/` (inmutables): `2026-08-17_fix_confirmacion_correo_pkce.md`, `2026-08-17_documentos_compliance_storage_privado.md`, `2026-08-17_upgrade_flutter_3449_y_deuda_dart_html.md`, `2026-08-17_face_map_servicio_estado_tratamiento.md`, `2026-08-17_adelanto_porcentual_servicios.md`, `2026-08-17_avatars_storage_dicebear.md`, `2026-08-17_avatares_dicebear_creativos_y_fix_foto.md`.

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

## 5. Adelanto porcentual configurable para pago de servicios — `4cfdf84` ✅

**Objetivo aprobado**: el pago de $30 (cuota inicial / Qualify) cubre la telemedicina o el servicio médico interno y es obligatorio → **no se modifica**. Al pagar un servicio del catálogo debe ofrecerse un **adelanto porcentual del total** (configurable) o el servicio completo — no un "depósito" fijo de $30. El cobro del saldo al finalizar se mantiene como hoy (decisión diferida: se definirá la mejor fecha al desarrollar citas y tratamientos).

**Cambios**:
- **Migración `20260817010001_adelanto_porcentaje.sql`** (aplicada al remoto): seed `adelanto_porcentaje = 50` en `configuracion_sistema`. `deposito_reserva` ($30, cuota Qualify) intacto.
- `AdelantoServicioEntity(porcentaje, monto)` (nuevo); datasource: `_getAdelantoPorcentaje()` (default 50) + `calcularAdelanto(servicePrice)` (monto = precio × %/100, 2 decimales) + `createServicePayment` con `montoAPagar` (lo ya cobrado por Stripe) → graba `deposito_requerido`/`deposito` = monto pagado, `saldo_pendiente = precio − monto`, `estado = PAGADO/PARCIAL`; transacción parcial usa `DEPOSITO` (consistente con el enum).
- `IPaymentsRepository` (+impl): `calcularAdelanto` nuevo y firma de `createServicePayment` con `montoAPagar`; usecase `PagarServicio` y cubit `payments` propagan `montoAPagar`.
- UI (`services_dashboard_screen.dart`): el modal consulta `calcularAdelanto(price)` y muestra **"Pagar Adelanto ($X · 50%)"** o **"Cancelar Totalidad ($price)"**; `_processServicePayment` usa el `montoAPagar` calculado (concepto `ADELANTO`/`PAGO_TOTAL`).

**Verificación**: `flutter analyze` sin issues; `flutter test` 80/80; migración aplicada al remoto.

---

## 6. Avatares específicos del ingreso de datos paciente — `5fa0211` ✅

Se corrigió el selector de avatar del ingreso de datos del paciente para mostrar avatares más específicos en una sola fila (commit `5fa0211` "Avatares de paciente más específicos y en una sola fila en el ingreso de datos").

---

## 7. Flujo de registro y panel del especialista en web — `6c19d8a` ✅

**Contexto**: prueba manual completa del flujo en web: onboarding (dirección → especialidades/licencia) → documentos requeridos → panel. Se encontraron y arreglaron 4 bugs:

### 7.1 Onboarding atascado en el spinner — `Cannot emit new states after calling close`
- **Causa raíz**: todos los cubits de features se registran como `registerLazySingleton` en DI, y `BlocProvider(create: (_) => sl<Cubit>(), ...)` **cierra el singleton** al hacer dispose de la pantalla (flutter_bloc marca el cubit como self-created y lo `close()` en dispose). La siguiente pantalla usa el mismo singleton ya cerrado → `emit` lanza `Bad state: Cannot emit new states after calling close`.
- **Fix**: en `app_routes.dart` los 12 providers de cubits singleton pasaron a `BlocProvider<X>.value(value: sl<X>(), ...)` (rutas services, specialistHome, specialistProfile, specialistDocuments, specialistContract, specialistOnboarding, adminDashboard, adminUsuarios, fotografiasTratamiento, specialistPatientMap, misCitas, misCitasDetalle); guard defensivo en `SpecialistsCubit.emit` (no-op si `isClosed`); `specialist_onboarding_screen.dart` sale del spinner ante `SpecialistsError` y muestra el formulario.

### 7.2 Pantalla de documentos en blanco — `BoxConstraints forces an infinite width`
- **Causa raíz** (error real del browser): el `OutlinedButton` del tile es hijo **no-flex de un `Row`** → el flex le da ancho ilimitado (`BoxConstraints(w=Infinity, 40.0<=h<=Infinity)`) y el mínimo interno del botón (altura 40) colapsa → excepción de layout → pantalla en blanco (SDK 3.44, `render/flex.dart` `_constraintsForNonFlexChild`).
- **Fix**: envolver el botón "Adjuntar" en `SizedBox(width: 108, height: 40)` (`specialist_documents_screen.dart`). Único `OutlinedButton` en `Row` de la app (el de admin_users está en un `Column`, seguro).

### 7.3 Pantallas sin opción de volver atrás
- **Causa raíz**: las pantallas se abrían con `context.go()` (reemplaza la ruta, sin pila → sin flecha atrás).
- **Fix**: onboarding → documentos ahora `context.push`; flecha atrás en onboarding (→ panel, sustituye al "Salir"); flecha atrás en documentos (`pop()` si hay pila, sino `go(panel)`); el redirect del panel a docs y "Corregir y reenviar" (`specialist_home_screen.dart`) y "Corregir" del perfil (`specialist_profile_screen.dart`) → `push`. El redirect panel → onboarding se mantiene como `go` a propósito (evita double-push: el listener del panel comparte el cubit singleton y empujaría documentos duplicados durante el onboarding).

### 7.4 Toggle de disponibilidad → 400
- **Causa raíz** (reproducida contra la BD real): `{"code":"23502","message":"null value in column \"fecha_inicio\" of relation \"disponibilidad_especialista\" violates not-null constraint"}`. La tabla `disponibilidad_especialista` (creada a mano en el dashboard, no versionada) tiene `fecha_inicio NOT NULL` (default `now()`), pero el datasource enviaba `fecha_inicio: null` al alternar.
- **Fix** (app-side, sin migración — el esquema es correcto): en `setDisponibilidad`/`updateDisponibilidad` se usa `(fechaInicio ?? DateTime.now())` (`specialists_supabase_datasource.dart`).

**Verificación**: `flutter analyze` sin issues; `flutter test` 80/80; URL generada por postgrest 2.8.0 confirmada con test temporal (eliminado).

**Commit**: `6c19d8a` "Arregla el flujo de registro y panel del especialista: cubit singleton que no se cierra al navegar, pantallas sin retroceso, botón de documentos sin ancho infinito y toggle de disponibilidad que enviaba fecha_inicio null" → pusheado a `main`.

---

## 8. Deploy a Firebase Hosting — ✅

- `flutter build web --release` OK (Wasm dry run OK).
- `firebase deploy --only hosting` → 71 archivos subidos al proyecto `esteticaybellezastrani`.
- **URL de producción**: https://esteticaybellezastrani.web.app (rewrites SPA a `/index.html`).

---

## 9. Pruebas: confirmación de correos pendientes (TEMPORAL, reversible)

**Contexto**: el toggle "Confirm email" de Supabase está apagado para pruebas, pero las cuentas creadas **antes** de apagarlo quedaron con `auth.users.email_confirmed_at = null` y la app seguía mostrando "Confirma tu correo" (el flujo lo dispara GoTrue con `email_not_confirmed`, no la app). Se confirmaron los correos pendientes para poder probar login con cuentas existentes.

**Migración aplicada al remoto**: `20260817010002_confirmar_correos_testing.sql`
- Confirma los usuarios con `email_confirmed_at is null` en `auth.users`.
- Deja una snapshot en `public.mig_20260817010002_confirmados (user_id, email, confirmado_en)` para revertir con precisión.
- Idempotente (`ON CONFLICT DO NOTHING`).

**REVERT (cuando termine la prueba — volver a NO confirmados)**:

```sql
update auth.users u
set email_confirmed_at = null
from public.mig_20260817010002_confirmados m
where u.id = m.user_id;

-- opcional, limpiar la snapshot:
drop table public.mig_20260817010002_confirmados;
```

- Nota: con el toggle apagado, los **usuarios nuevos** ya entran directo (signUp devuelve sesión); no necesitan confirmación. Si se reactiva el toggle, las nuevas altas vuelven a exigir confirmación como antes.

---

## 10. Avatares: bucket privado + URLs firmadas + DiceBear local — ✅ (pendiente commit)

**Bug**: en el ingreso de datos del paciente (`complete_profile_screen`) la subida de foto mostraba "subida correctamente", pero el círculo de vista previa no mostraba la imagen. Causa raíz: el bucket `avatars` era **privado** (creado a mano), pero `AvatarSelector._upload` guardaba en `avatar_url` una URL pública (`getPublicUrl`) que `Image.network` pedía sin auth → 400.

**Cambios** (plan en `docs/plans/2026-08-17_avatars_storage_dicebear.md`):
- **Migración `20260817000100_avatars_storage_privado.sql`** (aplicada con `supabase db push --include-all`):
  - Bucket `avatars` → `public = FALSE` (idempotente).
  - `DROP POLICY "avatars_public_select"`; nuevas policies `avatars_storage_own_insert/select/update/delete` (dueño: `(storage.foldername(name))[1] = auth.uid()::text`) + `avatars_storage_admin_select`.
  - Migra `profiles.avatar_url` existentes (URL pública → path `<userId>/<ts>.<ext>`).
- **Capa de datos (auth_users)**: `crearUrlFirmadaAvatar(path)` → `createSignedUrl(path, 3600)` (datasource + repositorio + usecase `GenerarUrlFirmadaAvatar` + registro en `injection.dart`); `AvatarSelector._upload` guarda el **path** (`uploaded`), sin `getPublicUrl`.
- **Widget compartido `AvatarView`** (`auth_users/presentation/widgets/avatar_view.dart`): preset key → ícono pastel; path/URL legacy → URL firmada → `CachedNetworkImage`; null + paciente → DiceBear identicon; null + admin/especialista → ícono de rol. Reemplaza el contenido de `_Preview` (avatar_selector) y `_AvatarContent` (profile_screen).
- **DiceBear local**: `dicebear_core 10.6.0` + `dicebear_styles 10.5.0` + `flutter_svg 2.3.0`; `Style.parse(adventurer)` + `Avatar(style, {'seed': uid})` → `SvgPicture.string(avatar.svg)`.

**Verificación**: `flutter analyze` sin issues; `flutter test` 80/80; migración aplicada al remoto (remoto en `20260817000100`); `flutter build web --release` OK + `firebase deploy --only hosting` (https://esteticaybellezastrani.web.app).

**Pendiente manual**: smoke test en browser (subida + preview + perfil + DiceBear sin avatar).

---

## 11. Presets DiceBear creativos (8 estilos) + fix de subida/preview de foto — ✅ (pendiente commit)

**Quejas del usuario**: (1) "los avatares a seleccionar siguen siendo los mismos" — los presets del ingreso de datos eran íconos pastel de Material; (2) "la foto no la sube o no la muestra" — la foto seguía sin aparecer en el círculo.

**Cambios** (plan en `docs/plans/2026-08-17_avatares_dicebear_creativos_y_fix_foto.md`, aprobado por el usuario):
- **Helper `avatar_preset.dart`** (`auth_users/presentation/widgets/`): `AvatarPreset` (key, label, style, seed, color), lista `avatarPresets` (claves `avatar_1..8`), `presetFor`, `isPresetKey`, `dicebearSvg(style, seed)`, `dicebearSvgFor(key)`, `presetColorFor`. **8 estilos DiceBear distintos** por preset: `adventurer`, `avataaars`, `lorelei`, `micah`, `fun_emoji`, `open_peeps`, `big_ears`, `miniavs`; seed fijo por clave → mismo avatar siempre, offline. Estilos parseados cacheados en `Map<String, Style>`.
  - Nota: `dicebear_core` exporta un tipo `Color` que choca con Flutter → se importa con prefijo `as dicebear`.
- **`avatar_selector.dart`**: `_PresetTile` renderiza el **SVG DiceBear** (`SvgPicture.string`) en vez del ícono Material; `AvatarSelector` pasa a `StatefulWidget` con estado de subida (botón con spinner mientras sube) y snackbar con el **error real**.
- **`avatar_view.dart`**: rama preset → SVG DiceBear; rama null+paciente → DiceBear (adventurer + seed); ya no importa `avatar_selector` (rompe el import circular).
- **Fix de la foto**: `_SignedAvatar` ahora tiene `didUpdateWidget` (re-resuelve la URL firmada si cambia `value`), estado `_error` con el motivo real, tap para reintentar y `debugPrint` del error.

**Verificación**: `flutter analyze` sin issues; `flutter test` 80/80; `flutter build web --release` OK + `firebase deploy --only hosting` (https://esteticaybellezastrani.web.app).

**Smoke test (validado por el usuario con hard refresh)**: los 8 presets DiceBear se ven distintos y por preset cambia la vista previa; la foto subida aparece en la vista previa, persiste al re-entrar y se muestra en el perfil. El flujo `createSignedUrl` quedó validado en vivo (sin migración correctiva; también confirma el mecanismo de documentos de especialistas).

---

## Verificación transversal

- `flutter analyze` → sin issues (en todos los ciclos).
- `flutter test` → 80/80 OK (tests placeholder/widget; el proyecto no tiene suite real de tests).
- BD: migraciones aplicadas al remoto hasta `20260817010002` + `20260817000100` avatares (`supabase db push --include-all`).

### Working tree actual
- Trabajo del día commiteado/pusheado hasta `d01b7c2` y desplegado; **pendiente de commit**: plan `2026-08-17_avatares_dicebear_creativos_y_fix_foto.md`, `avatar_preset.dart`, `avatar_selector.dart` y `avatar_view.dart` (presets DiceBear + fix de foto, ciclo 11) y este resumen.

### Pendientes documentados
- Revert de la confirmación de correos de pruebas (sección 9) cuando termine la prueba.
- Versionar las tablas creadas a mano en el dashboard (`disponibilidad_especialista`, `ubicaciones_especialista`, `contratos`) — hoy se tocó `disponibilidad_especialista` (toggle) y sigue sin estar en migraciones.
- Convertir a privados los buckets aún públicos (`contratos`, `firmas`, `fotografias-tratamiento`) — fuera de alcance del ciclo 2.
- Smoke test manual en browser del flujo del especialista (checklist del ciclo 8) y del resto de módulos tras el upgrade 3.44.9.