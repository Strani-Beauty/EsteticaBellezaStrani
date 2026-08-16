# Plan: Correcciones módulo auth_users según pruebas manuales 01

Fecha: 2026-08-16
Fuente: `docs/Pruebas manuales/Pruebas_manuales_01-04.xlsx` (hoja 01_auth_users).
Estado: **implementación de código completa** (Fases 1, 2, 3-código, 4 y 6 listas). Pendientes: Fase 3-diagnóstico SQL, Fase 5 (diferida por el usuario), Fase 7 re-test manual + deploy.

## Resultados decodificados (49 casos: 44 Pasa, 5 Falla + obs. global)

| ID | Severidad | Observación | Causa raíz |
|---|---|---|---|
| AU-H-02 | Crítica | "Phone en Users = NULL" (usuario Jai Mont) | Panel admin no muestra teléfono; verificar `profiles.phone` |
| AU-H-08 | Alta | "Id no debe mostrarse... Debe dejar seleccionar algún Avatar" | Badge ID crudo en complete_profile; falta selector de avatar |
| AU-H-09 | Alta | Cambio de contraseña: no carga, se traba; F12 warning | Reproducir: cadena de redirects PKCE en web |
| AU-H-10 | Crítica | "Chrome may soon delete state for intermediate websites..." | redirectTo custom scheme inválida en web (recovery) |
| AU-V-04 | Alta | "Pasa a confirmación email sin error de validación" | Email duplicado → diálogo genérico de confirmación |
| Global | — | "Error en Ingles. Invalid Login Credentials..." (V-01/02/03/05/06) | Mensajes crudos en inglés en signIn/changePassword |

## Fase 1 — Localización de errores auth (obs. global)
- [x] Ampliar `_authFailureFrom` en `auth_repository_impl.dart` con mapeo de códigos GoTrue a español.
- [x] Aplicarlo en `signIn` y `changePassword` (hoy usan `AuthFailure(e.message)` crudo).

**Archivos:** `lib/features/auth_users/data/repositories/auth_repository_impl.dart`.

**Detalle:**
- `signIn` y `changePassword` ahora devuelven `_authFailureFrom(e)` en vez de `AuthFailure(e.message, code: e.code)`.
- `_authFailureFrom` ampliado con:
  - Detección SMTP (`code == unexpected_failure` + patrones `sending confirmation email` / `send email` / `smtp` / `error sending`) → mensaje amigable indicando reintentar con "Reenviar correo".
  - Mapa de códigos GoTrue → español: `invalid_credentials`, `email_not_confirmed`, `user_already_exists`, `weak_password`, `email_address_invalid`, `same_password`, `new_password_should_be_different`, `over_email_send_rate_limit`, `over_request_rate_limit`, `user_not_found`, `email_change_token_invalid`, `recovery_token_invalid`, `otp_expired`, `otp_disabled`, `phone_already_exists`, `phone_not_confirmed`, `provider_not_found`, `mfa_verification_rejected`.
  - Fallback por patrón de mensaje (case-insensitive): `invalid login credentials`, `already registered`, `password should be at least` → mismo español.
  - Si nada coincide, devuelve el mensaje crudo de GoTrue con el `code` original.

## Fase 2 — AU-H-08: ocultar ID + selector de avatar
- [x] Eliminar badge `ID del Paciente` en `complete_profile_screen.dart:604`.
- [x] Añadir selector de avatar (grid predefinidos + subir foto a Storage).
- [x] Mostrar avatar en `profile_screen.dart`.

**Archivos:**
- `lib/features/auth_users/presentation/screens/complete_profile_screen.dart` (nuevo)
- `lib/features/auth_users/presentation/widgets/avatar_selector.dart`
- `lib/features/auth_users/presentation/screens/profile_screen.dart`
- `lib/app/core/network/supabase_service.dart`

**Detalle:**
- Eliminado el `Container` con el badge `ID del Paciente: ${profile?.id}` de la parte superior del formulario.
- Nuevo widget `AvatarSelector` (reutilizable, expuesto vía `presets`, `isPreset`, `presetIcon`, `presetColor`):
  - Vista previa circular grande (96px) del avatar actual.
  - Botón "Subir foto desde mi dispositivo" → `FilePicker` (solo imágenes) → sube a bucket `avatars` (path `{userId}/{epoch}.{ext}`) con `uploadBinary` + `getPublicUrl`, guardando la URL pública en `avatar_url`.
  - Grid 4×2 de 8 avatares predefinidos (íconos pastel de la paleta Strani) guardados como claves `avatar_1`..`avatar_8`.
- `complete_profile_screen`:
  - Nuevo estado `_avatarUrl` cargado en `_loadExistingProfileData` desde `profile.avatarUrl` / `profiles.avatar_url`.
  - `AvatarSelector` renderizado bajo el encabezado del formulario.
  - `_submit` pasa `avatarUrl: _avatarUrl` a `SupabaseService.updateProfileData`.
- `SupabaseService.updateProfileData` acepta `avatarUrl` opcional y lo incluye en el UPDATE de `profiles`.
- `profile_screen.dart`:
  - `CircleAvatar` usa fondo de preset (o pastel por defecto) y nuevo `_AvatarContent` que resuelve: preset → ícono del preset, URL → `Image.network`, si no → ícono por rol.

## Fase 3 — AU-H-02: teléfono en panel admin
- [x] Añadir teléfono en `_UserTile` de `admin_users_screen.dart`.
- [ ] Diagnóstico en SQL Editor para confirmar causa del NULL.

**Archivos:** `lib/features/admin_users/presentation/screens/admin_users_screen.dart`.

**Detalle:**
- `_UserTile` ahora muestra debajo del rol una fila con ícono de teléfono + `user.phone` cuando no es null/vacío. `UsuarioAdminEntity.phone` ya existía y el modelo lo mapeaba.
- Falta diagnóstico en BD (SQL Editor del dashboard) para el usuario "Jai Mont":
  ```sql
  select id, email, phone, full_name, created_at
  from profiles
  where email like '%jai%' or full_name like '%Jai%';
  ```

## Fase 4 — AU-H-10: recovery deep link en web
- [x] `redirectTo` dependiente de plataforma en `resetPassword` (web → `/auth/reset-password`, móvil → custom scheme).

**Archivos:** `lib/features/auth_users/data/datasources/auth_supabase_datasource.dart`.

**Detalle:**
- `resetPasswordForEmail` usa `kIsWeb` (ya importado de `package:flutter/foundation.dart`):
  - Web: `https://esteticaybellezastrani.web.app/auth/reset-password`.
  - Móvil: `com.example.esteticaybellezastrani://` (sin cambio).
- Verificado que la ruta `/auth/reset-password` existe en `app_routes.dart` y que `app.dart:56` escucha `passwordRecovery` para navegar ahí (ya estaba).
- Pendiente de validar en Supabase Auth la whitelist de "Redirect URLs" (debe incluir la URL web).

## Fase 5 — AU-H-09: cambio de contraseña se traba (reproducir)
- [ ] Reproducir en web y capturar warning exacto de F12.
- [ ] Ajustar flujo changePassword según hallazgo.

**Nota:** Diferida por el usuario ("luego la fase 5"). Mismo patrón de warning Chrome que AU-H-10 ("la aplicación debía borrar algo anterior" / navegación intermedia).

## Fase 6 — AU-V-04: email duplicado
- [x] Texto aclaratorio en `_showEmailConfirmation` de `login_screen.dart`.

**Archivos:** `lib/features/auth_users/presentation/screens/login_screen.dart`.

**Detalle:**
- El diálogo "Confirma tu correo" ahora aclara que si el correo ya estaba registrado se puede iniciar sesión con la contraseña, y sugiere revisar spam o reenviar el correo.

## Fase 7 — Verificación
- [x] `flutter analyze` + `flutter test` (80 tests OK, sin issues).
- [ ] Re-test manual de los 5 casos + observación global.
- [ ] (Opcional) `flutter build web` + `firebase deploy`.

**Resultado:** `flutter analyze` sin issues; `flutter test` 80/80 OK.