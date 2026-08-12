# Recuperación de contraseña completa y registro de dispositivo FCM

**Fecha:** 2026-08-13
**Alcance:** `auth_users` (recovery con deep link + registro de token FCM), bootstrap (`app.dart`), router/guard, DI.
**Cierra:** items 10 y 11 del checklist de `docs/2026-08-13_verificacion_accesos.md`.

---

## 1. Contexto

La verificación de accesos marcó dos funcionalidades **parciales**:

- **Item 10 — Recuperación de contraseña:** se enviaba el email (`resetPasswordForEmail`), pero la app no consumía el deep link de Supabase. No había pantalla de nueva contraseña tras el correo.
- **Item 11 — Registro del dispositivo FCM:** existían la tabla `dispositivos_usuario` (+ RLS) y los métodos `upsertFcmToken`/`deactivateFcmToken` del datasource, pero el token nunca se obtenía en runtime (sin `firebase_messaging`, sin usecase, sin llamada desde la UI).

Este doc describe la implementación. El plan con checkpoints está en `docs/plans/2026-08-13_pendientes_recovery_fcm.md`.

---

## 2. Fase A — Recuperación de contraseña con token

### 2.1 Detección del deep link

gotrue (pinneado 2.26.0) expone `onAuthStateChange` como un `BehaviorSubject` (`_onAuthStateChangeController`, `gotrue_client.dart:97`), por lo que **retiene el último evento**: si `Supabase.initialize` procesa la URI de recovery antes de que la app se suscriba, el evento `passwordRecovery` no se pierde.

En `lib/app/app.dart` (`_SessionLifecycleGate.initState`) se suscribe un listener:

```dart
_recoverySub = sl<AuthSupabaseDataSource>().authStateChanges.listen((authState) {
  if (authState.event == sb.AuthChangeEvent.passwordRecovery) {
    context.go(AppRoutes.resetPassword);
  }
});
```

> **Regla AGENTS preservada:** el estado de sesión NO se deriva de `authStateChanges`; este listener solo detecta el evento de recovery para navegar. La suscripción se cancela en `dispose`.

### 2.2 Ruta y pantalla

- `AppRoutes.resetPassword = '/auth/reset-password'` (`app_routes.dart`).
- `GoRoute` nuevo → `ResetPasswordScreen`.
- `ResetPasswordScreen` (`lib/features/auth_users/presentation/screens/reset_password_screen.dart`): formulario con "Nueva contraseña" + "Confirmar contraseña", validación de mínimo 6 caracteres y coincidencia; botón que llama a `AuthCubit.completePasswordReset`.
- `route_guard.dart`: la ruta se añade a `publicRoutes` (accesible sin sesión) y a la excepción del paciente inactivo (la sesión de recovery es temporal y puede estar inactiva).

### 2.3 Cubit

`AuthCubit.completePasswordReset(newPassword)`:

1. `changePassword(newPassword)` → `updatePassword` de gotrue (el token de recovery permite cambiarla sin contraseña actual).
2. En éxito → `signOut()` (la sesión de recovery es temporal y se cierra para volver a iniciar sesión).
3. Emite `AuthPasswordChanged` (estado nuevo).

La pantalla, al recibir `AuthPasswordChanged`, muestra el aviso y navega a `/login`.

---

## 3. Fase B — Registro del dispositivo / token FCM

### 3.1 Dependencias

Añadidas a `pubspec.yaml` (vía `flutter pub add`):

- `firebase_core: 4.13.0`
- `firebase_messaging: 16.5.0`

Compatibles con Flutter 3.x / supabase_flutter pinneado. Los registros de plugins de `macos`/`windows` se regeneraron automáticamente.

> El proyecto ya usa Firebase para hosting (`.firebaserc` + `firebase.json`). **La configuración por plataforma** (google-services.json, GoogleService-Info.plist, firebase_options.dart) es un paso manual del usuario.

### 3.2 Capa de dominio

`RegisterFcmToken` (`lib/features/auth_users/domain/usecases/register_fcm_token.dart`):

```dart
Future<Either<Failure, void>> call({
  required String profileId,
  required String fcmToken,
  String? plataforma,
});
```

Envuelve `IAuthRepository.registerFcmToken`.

### 3.3 Servicio defensivo

`FcmTokenService` (`lib/features/auth_users/data/services/fcm_token_service.dart`):

- `init()`: intenta `Firebase.initializeApp()`; si Firebase no está configurado en la plataforma, **degrade con log** (`_firebaseReady = false`) sin romper la sesión ni la navegación.
- `registerCurrentDevice(profileId)`:
  1. Si no hay Firebase listo → no-op.
  2. `requestPermission()`; si `authorizationStatus != authorized` → log y return.
  3. `getToken()` → `registerFcmToken(profileId, token, plataforma)`.
  4. Se suscribe a `onTokenRefresh` para re-registrar el token renovado.
- `_plataforma()`: `web` | `android` | `ios` (según `kIsWeb`/`defaultTargetPlatform`).

### 3.4 Wiring y disparo

`injection.dart` (`_registerAuthUsers`):
- `RegisterFcmToken` → `RegisterFcmToken(sl<IAuthRepository>())`.
- `FcmTokenService` → `FcmTokenService(sl<IAuthRepository>())`.

`app.dart`:
- `initState` → `sl<FcmTokenService>().init()`.
- `BlocListener<AuthCubit, AuthState>` alrededor del router → al emitirse `AuthAuthenticated` (login o refresco de sesión) → `sl<FcmTokenService>().registerCurrentDevice(state.profile.id)`.

---

## 4. Archivos

### Nuevos

```
docs/2026-08-13_recuperacion_password_y_dispositivos_fcm.md   (este doc)
docs/2026-08-13_verificacion_accesos.md                        (checklist actualizado)
docs/plans/2026-08-13_pendientes_recovery_fcm.md               (plan con checkpoints)
lib/features/auth_users/data/services/fcm_token_service.dart
lib/features/auth_users/domain/usecases/register_fcm_token.dart
lib/features/auth_users/presentation/screens/reset_password_screen.dart
```

### Modificados

```
AGENTS.md                                    (regla de planes y cortes de electricidad)
lib/app/app.dart                             (listener recovery + FCM service + BlocListener)
lib/app/config/app_routes.dart               (ruta /auth/reset-password)
lib/app/config/route_guard.dart              (ruta pública + excepción paciente inactivo)
lib/app/core/di/injection.dart               (RegisterFcmToken + FcmTokenService)
lib/features/auth_users/presentation/cubits/auth_cubit.dart  (AuthPasswordChanged + completePasswordReset)
pubspec.yaml / pubspec.lock                  (firebase_core, firebase_messaging)
macos/.../GeneratedPluginRegistrant.swift    (regenerado)
windows/.../generated_plugin_registrant.cc   (regenerado)
windows/.../generated_plugins.cmake          (regenerado)
```

---

## 5. Verificación

- `flutter analyze` → `No issues found!`
- `flutter test` → 14/14 (incluye `route_guard_test.dart`).
- Sin cambios de esquema SQL en esta sesión (la tabla `dispositivos_usuario` y su RLS ya existen).

---

## 6. Pendientes manuales (usuario)

1. **Supabase Dashboard:** configurar la URL de redirect del email de recovery apuntando al deep link de la app (p. ej. el dominio web o `esteticaybellezastrani://auth/reset-password`).
2. **Firebase por plataforma:** generar `google-services.json` (Android), `GoogleService-Info.plist` (iOS) o `firebase_options.dart` (web). Sin ello `FcmTokenService` degrada (log) y no registra token.
3. **Verificación manual:** pedir reset con un correo real → abrir el link → guardar nueva contraseña → login con la nueva clave. E iniciar sesión y confirmar la fila en `dispositivos_usuario` (token + `usuario_id` correctos; RLS del dueño).
