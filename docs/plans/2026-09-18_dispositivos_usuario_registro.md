# Plan — Registro y actualización de dispositivos en `dispositivos_usuario`

Fecha: 2026-09-18
Estado: APROBADO por el usuario (m1448: "aprobado"). Sin commit.

## Objetivo

Completar el registro y la actualización de los dispositivos asociados a cada
usuario en `dispositivos_usuario`:

1. **Persistir `modelo_dispositivo`** (hoy siempre NULL): el datasource lo acepta
   pero nadie lo pasa. Se captura con `device_info_plus` en Android/iOS/web
   (enfoque unificado, decisión m1445: usar `device_info_plus` en las 3
   plataformas, sin parse manual del user agent en web).
2. **Usar el usecase `RegisterFcmToken`** (muerto): `FcmTokenService` lo inyecta
   y usa (Clean Architecture); conserva `IAuthRepository` para
   `deactivateFcmToken` (decisión m1440).
3. **Fix de listeners acumulados**: `onTokenRefresh.listen` se suscribe en cada
   `registerCurrentDevice` (se llama en cada `AuthAuthenticated`); suscribir una
   sola vez.
4. **Índice en `usuario_id`**: los RPCs de push filtran por `usuario_id`; añadir
   índice (migración idempotente).

## Cambios

### 1. `pubspec.yaml`
- Añadir `device_info_plus` (última estable) → `flutter pub get`.

### 2. Propagar `modeloDispositivo` por la cadena
- `i_auth_repository.dart`: `registerFcmToken({..., String? modeloDispositivo})`.
- `auth_repository_impl.dart`: passthrough a `upsertFcmToken`.
- `register_fcm_token.dart` (usecase): + `String? modeloDispositivo` en `call`.
- `auth_supabase_datasource.dart`: sin cambio (ya acepta `modeloDispositivo`).

### 3. `lib/features/auth_users/data/services/fcm_token_service.dart`
- Constructor: `FcmTokenService(this._registerFcmToken, this._authRepository)`.
- `registerCurrentDevice(profileId)`: `_modeloDispositivo()` y reenvío por usecase.
- `_modeloDispositivo()` con `device_info_plus`: Android → brand/model;
  iOS → brand/model; web → `webBrowserInfo` (p. ej. 'Chrome').
- `onTokenRefresh`: suscribir UNA sola vez (flag/init); el callback re-registra
  con el modelo.

### 4. DI `lib/app/core/di/injection.dart`
- `FcmTokenService(sl<RegisterFcmToken>(), sl<IAuthRepository>())`.

### 5. Migración `supabase/migrations/20260918000100_dispositivos_usuario_indice.sql`
- `CREATE INDEX IF NOT EXISTS idx_dispositivos_usuario_usuario_id
  ON public.dispositivos_usuario(usuario_id);`
- Idempotente, sin RLS. Aplicar por pooler (reinstalar driver `pg` en
  `C:\Users\Jaime\AppData\Local\Temp\opencode\pgcheck`).

### Sin cambios
Tabla/esquema, RLS, RPCs de push (`notificar_usuario_push`), `auth_cubit`
(ya llama `deactivateCurrentDevice` en signOut), `app.dart` (ya llama
`init()`/`registerCurrentDevice`).

## Verificación

- [x] `flutter analyze` limpio; `flutter test` (370 tests ALL PASSED).
- [x] Pooler: índice `idx_dispositivos_usuario_usuario_id` creado (verificado en
      `pg_indexes` junto a pkey, token_fcm_key, activo y token_fcm).
- [ ] Manual en `flutter run -d chrome`: login → revisar BD → `dispositivos_usuario`
      con `plataforma`/`modelo_dispositivo` no null; logout → `activo=false`.

## Notas

- Sin commit (regla del proyecto: preguntar antes).