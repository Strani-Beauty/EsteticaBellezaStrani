# Plan — Migración de dominio a MERAKI SPA ONSITE + subdominio admin.<dominio>

Fecha: 2026-09-18
Estado: APROBADO por el usuario (m1349). Sin commit hasta petición.
Dominio: PARAMETRIZABLE (`<dominio>`, ejemplo `merakionsite.com`) — pendiente de compra.

## Objetivo

1. Cambiar el dominio público a la marca **MERAKI SPA ONSITE** (hoy
   `esteticaybellezastrani.web.app`).
2. Crear el subdominio `admin.<dominio>` dedicado a administradores
   (Opción A: una sola build, detección por hostname).
3. **Sin romper nada en web.app**: el sitio `esteticaybellezastrani.web.app`
   es el sitio por defecto de Firebase y NO puede eliminarse ni renombrarse;
   seguirá funcionando como fallback para siempre.

Decisiones del usuario (m1348): dominio aún no definido (se deja parametrizable);
apex y `www` → app pública; `admin.<dominio>` → panel admin; todo en el MISMO
sitio Firebase (Opción A).

## Hechos verificados

- `firebase.json`: único bloque hosting `public: build/web` + rewrite SPA.
  `.firebaserc` default = `esteticaybellezastrani`.
- URL web.app hardcodeada en CÓDIGO: `auth_supabase_datasource.dart:80`
  (`resetPasswordForEmail redirectTo: 'https://esteticaybellezastrani.web.app/auth/reset-password'`).
- Edge functions (stripe-webhook, create-payment-intent, send-push, geocode-address):
  SIN URLs web.app hardcodeadas.
- `web/index.html`: `title` y `apple-mobile-web-app-title` aún dicen
  `esteticaybellezastrani` (branding pendiente).
- Supabase Auth Redirect URLs actuales incluyen `https://esteticaybellezastrani.web.app/**`.
- El route guard protege `/admin` por rol; la seguridad real la da RLS (sin cambios).

## Cambios

### 1. `lib/app/config/app_env.dart` — flag admin por hostname
```dart
import 'package:flutter/foundation.dart' show kIsWeb;

/// Host del subdominio admin (ajustar al comprar el dominio).
static const String adminHost = 'admin.<dominio>';

/// Sitio dedicado a administradores (Opción A: por hostname en web).
static bool get adminOnly => kIsWeb ? Uri.base.host == adminHost : false;
```
Único punto de lectura del flag (para que migrar a Opción B sea solo cambiar
esta línea + firebase.json).

### 2. `lib/app/config/route_guard.dart` — `bool adminOnly = false`
- `AuthUnauthenticated`: si `adminOnly` → permitir SOLO `AppRoutes.login`;
  todo lo demás → login.
- `AuthAuthenticated`: ANTES del branch `location == login`, si `adminOnly &&
  !profile.isAdmin` → `onDeactivated()` (signOut) + `AppRoutes.login`
  (evita el loop del plan original con `_redirectByRole`).

### 3. `lib/app/config/app_routes.dart`
- `initialLocation: AppEnv.adminOnly ? AppRoutes.login : AppRoutes.welcome`.
- `redirect`: pasar `adminOnly: AppEnv.adminOnly` a `resolveAuthRedirect`.

### 4. `lib/app/app.dart`
- `AuthUnauthenticated → appRouter.go(AppEnv.adminOnly ? AppRoutes.login : AppRoutes.welcome)`.

### 5. Tests `test/route_guard_test.dart`
- `_guard` acepta `adminOnly`; casos nuevos: adminOnly+anónimo→login;
  adminOnly+especialista/paciente→signOut+login; adminOnly+admin→normal.
  (Los 366 actuales siguen pasando, default `false`.)

### 6. Reset-password sin URL hardcodeada (`auth_supabase_datasource.dart:80`)
- `redirectTo` en web → `'${Uri.base.origin}/auth/reset-password'` (dinámico:
  funciona desde apex, www, admin y web.app sin volver a tocar código al
  cambiar de dominio). Requiere registrar esos origins en Supabase Redirect URLs.

### 7. Branding `web/index.html`
- `title` → `MERAKI spa onsite`; `apple-mobile-web-app-title` → `MERAKI`;
  `meta description` → descripción de MERAKI SPA ONSITE.

## Infra (usuario, cuando haya dominio) — paso a paso

### 8. Firebase Hosting — añadir dominios al MISMO sitio
Consola Firebase → Build → Hosting → sitio `esteticaybellezastrani` →
"Añadir dominio personalizado", 3 veces:
- `<dominio>` (apex) → registros **A** que indica Firebase (2 IPs).
- `www.<dominio>` → **CNAME** a `esteticaybellezastrani.web.app`.
- `admin.<dominio>` → **CNAME** a `esteticaybellezastrani.web.app`.
- Añadir el **TXT de verificación** que Firebase muestre
  (`google-site-verification=...` / `firebase-noscan...`).
- Propagar DNS (minutos-horas) → "Conectado" → HTTPS automático (~1 h).

### 9. Supabase Auth — Redirect URLs (origin nuevo)
Dashboard → Authentication → URL Configuration:
- Añadir Redirect URLs: `https://<dominio>/**`, `https://www.<dominio>/**`,
  `https://admin.<dominio>/**`. Conservar `https://esteticaybellezastrani.web.app/**`.
- `Site URL`: `https://<dominio>`.

### 10. Deploy (sin cambios de proceso)
```powershell
flutter build web --release
firebase deploy --only hosting
```
Una sola build sirve apex, www, admin y web.app (Opción A).

## Migración futura a Opción B (build aislada `ADMIN_ONLY`)
Documentada: cambiar `AppEnv.adminOnly` a `bool.fromEnvironment('ADMIN_ONLY')`,
crear 2º sitio Firebase + `firebase.json` con target admin y `build/admin`,
CNAME de `admin.<dominio>` → `esteticaybellezastrani-admin.web.app`. Solo toca
`app_env.dart` + infra; el resto del código no cambia.

## Verificación

- [x] `flutter analyze` limpio.
- [x] `flutter test` (366 + 4 casos nuevos adminOnly = 370, ALL PASSED).
- [ ] Manual tras dominio: `https://<dominio>` → app pública; `https://admin.<dominio>`
      → login admin → panel; especialista en admin.<dominio> → signOut;
      `https://esteticaybellezastrani.web.app` sigue funcionando.
- [ ] Reset-password desde cada origin.

## Respuestas a preguntas del usuario (m1373, antes del commit)

1. **¿El despliegue de la app se puede hacer?**
   Sí, igual que siempre: `flutter build web --release` + `firebase deploy --only
   hosting`. En `web.app` el host real no coincide con `admin.<dominio>`, por lo que
   `AppEnv.adminOnly` es `false` → sin cambios de comportamiento en el sitio público.

2. **¿Cómo se entra como administrador hoy?**
   Por el botón **"Acceso Administrador"** de la bienvenida (→ `/login?login=administrador`)
   o logueándose con `admin@test.com` en el login normal. El aislamiento del subdominio
   (`adminOnly`) **solo se activa cuando la app se sirve desde `https://admin.<dominio>`**;
   mientras ese dominio no exista, el flujo actual es exactamente el mismo.

3. **¿La URL seguirá siendo `https://esteticaybellezastrani.web.app/` tras desplegar?**
   Sí. Firebase **no permite renombrar ni eliminar** el sitio por defecto
   `esteticaybellezastrani.web.app`; seguirá funcionando siempre como fallback. El dominio
   nuevo (apex/www/admin) se **añade encima** del mismo sitio cuando se configure.

## Notas

- Sin cambios BD/RLS/storage.
- Cambios de código commiteados con esta tarea (código listo; la infra de dominio se
  aplica cuando el usuario compre el dominio). Sin commit adicional salvo petición.