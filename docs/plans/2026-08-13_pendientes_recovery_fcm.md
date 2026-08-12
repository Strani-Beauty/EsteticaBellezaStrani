# Plan: recuperación de contraseña con token (10) y registro de dispositivo FCM (11)

**Fecha:** 2026-08-13
**Origen:** `docs/2026-08-13_verificacion_accesos.md` (puntos 10 y 11 marcados como **parcial**).
**Regla aplicada:** este plan se persiste en `docs/plans/` antes de implementar. Al retomar tras un corte, leer este archivo y reconstruir contexto con `opencode --continue`.

---

## Estado

- [x] **Fase A — Recuperación de contraseña completa (item 10)** *implementada 2026-08-13*
- [x] **Fase B — Registro del dispositivo / token FCM (item 11)** *código listo; falta config manual Firebase (B1)*
- [x] Verificación final: `flutter analyze` sin issues + `flutter test` 14/14 (2026-08-13)

---

## Fase A — Recuperación de contraseña con token (item 10)

**Problema:** hoy `resetPasswordForEmail` envía el correo, pero la app no consume el link de recovery de Supabase. Falta: detectar el deep link / evento `PASSWORD_RECOVERY` y ofrecer el formulario de nueva contraseña.

### Contexto técnico actual

- `Supabase.initialize` usa `AuthFlowType.pkce`, `detectSessionInUri: true` (AGENTS.md).
- Datasource ya tiene `resetPassword(email)` (`auth_supabase_datasource.dart:69-71`) y `updatePassword(newPassword)` (`:74-76`).
- GoRouter (`app_routes.dart:57-197`) no tiene ruta para recovery; el redirect fuerza `/login` → según sesión.
- `authStateChanges` se expone en el datasource (`:80`) pero **no se consume** para derivar estado de sesión (regla AGENTS: el estado viene de llamadas explícitas del cubit).

### Sub-tareas Fase A

- [x] **A1. Ruta de recovery en el router** (`reset_password_screen.dart` + `AppRoutes.resetPassword`, `/auth/reset-password`, pública en `route_guard.dart`).
- [x] **A2. Detección del link de recovery:** suscripción a `authStateChanges` en `app.dart` filtrando `AuthChangeEvent.passwordRecovery` (BehaviorSubject de gotrue retiene el evento emitido en `initialize`); navega a `/auth/reset-password`.
- [x] **A3. Cubit:** `completePasswordReset(newPassword)` → `changePassword` → `signOut()` (la sesión temporal de recovery se limpia) → `AuthPasswordChanged`.
- [ ] **A4. Configuración en Supabase Dashboard:** redirigir URL del email de reset al deep link de la app (acción manual del usuario).

### Verificación A
- [x] `flutter analyze` sin issues.
- [ ] Manual: pedir reset con un correo real → abrir el link → ver el formulario → guardar nueva contraseña → `updatePassword` OK → login con la nueva clave.

---

## Fase B — Registro del dispositivo / token FCM (item 11)

**Problema:** existe SQL (`dispositivos_usuario` + RLS), datasource y repositorio; pero no hay usecase, ni llamada desde la UI, ni dependencia Firebase. El token nunca se obtiene.

### Contexto técnico actual

- Tabla: `supabase/migrations/20260813010000_dispositivos_usuario_rls.sql` (`token_fcm` UNIQUE, RLS dueño/admin, trigger `updated_at`).
- Datasource: `upsertFcmToken({profileId, fcmToken, plataforma, modeloDispositivo})` y `deactivateFcmToken(token)` (`auth_supabase_datasource.dart:300-320`).
- Contrato repo: `IAppRepository`. `i_auth_repository.dart:52-58`.
- `pubspec.yaml`: **no** hay `firebase_core`/`firebase_messaging` (sin SDK Firebase).
- DI: `injection.dart` registra repositorios; cualquier usecase nuevo debe registrarse por nombre.

### Sub-tareas Fase B

- [ ] **B1. Firebase SDK (pendiente usuario):**
  - [x] Agregar `firebase_core` + `firebase_messaging` a `pubspec.yaml` (4.13.0 / 16.5.0, compatibles con Flutter 3.x).
  - [ ] Configurar proyecto Firebase + `google-services.json` (Android) / `GoogleService-Info.plist` (iOS) / `firebase_options.dart` (web). Acción manual del usuario (ya existe `.firebaserc`/`firebase.json` para hosting).
- [x] **B2. Usecase + wiring:** `RegisterFcmToken` en `auth_users/domain/usecases/`; registrado en `injection.dart`; `FcmTokenService` defensivo (degrade con log si Firebase no está disponible).
- [x] **B3. Captura del token desde la presentación:** `init()` en `app.dart`; `registerCurrentDevice(profileId)` al emitirse `AuthAuthenticated` (solicita permiso, `getToken`, upsert por perfil, suscripción a `onTokenRefresh`).
- [ ] **B4. RLS** (ya existe `dispositivo_own_access`): sin cambios SQL esperados; verificar al probar.

### Verificación B
- [x] `flutter analyze` sin issues; `flutter test` 14/14.
- [ ] Manual: iniciar sesión → el console muestra el token FCM registrado → en Supabase aparece fila en `dispositivos_usuario` con `usuario_id` correcto.
- [ ] Reglas: el mismo token registrado por un usuario no lo puede ver otro (RLS dueño).

---

## Pendientes de acciones manuales (usuario)

- [ ] Supabase Dashboard: configurar URL de redirect del email de recovery (Fase A4).
- [ ] Crear proyecto Firebase y descargar los archivos de configuración por plataforma (Fase B1).
- [ ] Tras implementar y aplicar migraciones si las hubiera, hacer ping al usuario para `supabase db push` si cambió algún esquema (en esta fase NO se esperan cambios SQL).

---

## Historial

- 2026-08-13: creado a partir de `docs/2026-08-13_verificacion_accesos.md`.