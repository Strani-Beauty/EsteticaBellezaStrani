# Plan: Firebase FCM (Web+Android) y deep link de recovery (A4 + B1)

**Fecha:** 2026-08-12
**Origen:** `docs/plans/2026-08-13_pendientes_recovery_fcm.md` (manuales A4 y B1).
**Regla aplicada:** plan persistido antes de tocar código.

---

## Estado

- [x] **Fase A4 — Redirect de recovery en Supabase + deep link Android** (código ✅, Dashboard pendiente usuario)
- [x] **Fase B1 — Firebase FCM Web + Android** (código ✅, apps registradas automáticamente por flutterfire)
- [x] **Fix extra — AGP 9→8.13 + Gradle 9.1→8.14** (app_links 3.5.1 usa DSL viejo incompatible con AGP 9; override compileSdk en subproyectos)
- [x] **Verificación final** `flutter analyze` limpio, `flutter test` 14/14, `flutter build web` + `flutter build apk --debug` OK

---

## Fase A4 — Redirect del email de recovery + deep link Android

### Contexto detectado
- `resetPasswordForEmail(email)` se llama SIN `redirectTo` (`auth_supabase_datasource.dart:70`) → gotrue usa la Site URL de Supabase.
- Detección del link: `authStateChanges` en `app.dart:53-61` → evento `passwordRecovery` → navega a `/auth/reset-password` (pública en `route_guard.dart:18`).
- Android: applicationId `com.example.esteticaybellezastrani`, sin intent-filter de deep link.
- Supabase: ref `hhyjremkguvphmjuaazp`, Site URL pendiente, Redirect URLs pendientes.

### Sub-tareas
- [ ] **A4.1 (usuario)** Dashboard → Authentication → URL Configuration → Site URL `https://esteticaybellezastrani.web.app` + Redirect URLs: `https://esteticaybellezastrani.web.app/**`, `http://localhost:8080/**`, `com.example.esteticaybellezastrani://`, `com.example.esteticaybellezastrani://**`.
- [x] **A4.2 (código)** intent-filter deep link en `android/app/src/main/AndroidManifest.xml` (scheme `com.example.esteticaybellezastrani`). ✅
- [x] **A4.3 (código)** `resetPasswordForEmail(email, redirectTo: 'com.example.esteticaybellezastrani://')` en `auth_supabase_datasource.dart:70`. ✅
- [x] **A4.4 (deploy usuario)** `flutter build web` + `firebase deploy --only hosting`. Build listo; deploy manual.

---

## Fase B1 — Firebase FCM Web + Android

### Contexto detectado
- `.firebaserc` ya apunta al proyecto Firebase `esteticaybellezastrani`; hosting configurado en `firebase.json`.
- `fcm_token_service.dart:25` llama `Firebase.initializeApp()` sin options → rompe en web (degrada con log, nunca registra token web).
- CLI disponibles: `firebase` 15.24.0, `flutterfire` 1.4.0.
- No existen `firebase_options.dart`, `google-services.json`, `firebase-messaging-sw.js`.

### Sub-tareas
- [x] **B1.1 (usuario)** ✅ Hecho automáticamente. `flutterfire configure` registró Android (`com.example.esteticaybellezastrani`) y Web en Firebase Console. `google-services.json` descargado a `android/app/`. `firebase_options.dart` generado.
- [x] **B1.2 (código)** `flutterfire configure --platforms=android,web` — generó `lib/firebase_options.dart`, `android/app/google-services.json`, editó `settings.gradle.kts` + `app/build.gradle.kts` (google-services plugin), y `firebase.json`. ✅
- [x] **B1.3 (código)** `fcm_token_service.dart`: `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`. ✅
- [x] **B1.4 (código)** `web/firebase-messaging-sw.js` con `firebaseConfig` web + `getMessaging()`. ✅
- [x] **B1.5 (verificación)** `flutter pub get` + `flutter analyze` + `flutter test` (14/14) + `flutter build web` + `flutter build apk --debug`. ✅

---

## Verificaciones manuales (usuario)

- **A4**: reset con correo real → abrir link → formulario "Nueva contraseña" → guardar → login con nueva clave.
- **B1**: login → console `📱 [FCM] Token obtenido` → fila en `dispositivos_usuario` (`plataforma='web'` y luego `'android'`) → RLS: otro usuario no ve el token.

---

## Archivos tocados

- `android/app/src/main/AndroidManifest.xml` (intent-filter deep link scheme)
- `android/app/google-services.json` (nuevo, generado por flutterfire)
- `android/app/build.gradle.kts` (plugin google-services, auto flutterfire)
- `android/settings.gradle.kts` (plugin google-services + AGP 8.13.0 downgrade)
- `android/build.gradle.kts` (subprojects afterEvaluate compileSdk override)
- `android/gradle/wrapper/gradle-wrapper.properties` (Gradle 8.14)
- `lib/firebase_options.dart` (nuevo, generado)
- `lib/features/auth_users/data/services/fcm_token_service.dart` (options + import)
- `lib/features/auth_users/data/datasources/auth_supabase_datasource.dart` (redirectTo)
- `web/firebase-messaging-sw.js` (nuevo, SW para FCM web)
- `firebase.json` (flutter config, auto flutterfire)