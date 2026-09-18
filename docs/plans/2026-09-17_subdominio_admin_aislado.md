# Plan — Subdominio de administración aislado (`admin.<dominio>`)

Fecha: 2026-09-17
Estado: APROBADO PARA GUARDAR (solicitud del usuario: "por el momento, sólo guarda el
plan para implementarlo cuando se tengan los dominios"). PENDIENTE de implementación
hasta adquirir el dominio base. Sin commit.

## Objetivo

Crear un subdominio dedicado a los administradores del proyecto según los cánones
vigentes (naming canónico `admin.<dominio>`; DNS por CNAME; HTTPS administrado).
Decisiones del usuario (m1184):
1. **Enfoque B — Aislado solo-admin**: build dedicada con `--dart-define=ADMIN_ONLY=true`
   en un segundo sitio de Firebase Hosting; el subdominio fuerza el panel admin y
   bloquea rutas de paciente/especialista.
2. **Dominio base por comprar** (hoy no existe dominio propio; solo
   `esteticaybellezastrani.web.app`).
3. **Deploy manual** (igual que hoy: `flutter build web --release` + `firebase deploy`).

Contexto verificado: app = UNA sola build Flutter Web para los 3 roles; el route guard
(`route_guard.dart` `resolveAuthRedirect`) redirige por rol (`Administrador → /admin`).
Hosting: Firebase proyecto `esteticaybellezastrani` (`firebase.json` público
`build/web`, rewrite SPA `** → /index.html`). Router: GoRouter `initialLocation:
AppRoutes.welcome` (`app_routes.dart:158`). Listener `AuthUnauthenticated` en
`app.dart` hace `appRouter.go(AppRoutes.welcome)`.

## Cambios

### 1. Flag de compilación (`lib/app/config/app_env.dart`)
```dart
static const bool adminOnly = bool.fromEnvironment('ADMIN_ONLY');
```
Solo existe en la build admin; la build pública queda intacta.

### 2. Aislamiento por rol (`lib/app/config/route_guard.dart`)
Añadir parámetro `bool adminOnly = false` a `resolveAuthRedirect`:
- `adminOnly` + sin sesión → solo se permite `/login`; cualquier otra ruta redirige a `/login`.
- `adminOnly` + sesión que **no** es Administrador → `onRoleMismatch` + redirige a `/login`.
- `adminOnly` + Administrador → comportamiento actual (login → `/admin`, rutas `/admin/*`).

### 3. Router (`lib/app/config/app_routes.dart`)
- `initialLocation: kAdminOnly ? AppRoutes.login : AppRoutes.welcome`.
- Pasar `adminOnly: kAdminOnly` al `resolveAuthRedirect` del `redirect`.

### 4. Listener de sesión (`lib/app/app.dart`)
- `AuthUnauthenticated → appRouter.go(kAdminOnly ? AppRoutes.login : AppRoutes.welcome)`
  (tras logout/signOut en la build admin, vuelve al login, no a la bienvenida pública).

### 5. Tests (`test/.../route_guard_test.dart`)
Añadir casos para `adminOnly=true`: anónimo → login; autenticado paciente/especialista →
login; administrador → `/admin`. (Los 366 tests actuales siguen pasando: el parámetro
es opcional con default `false`.)

### 6. Firebase multi-site (CLI)
```powershell
firebase hosting:sites:create esteticaybellezastrani-admin
firebase target:apply hosting admin esteticaybellezastrani-admin
```
En `firebase.json`, segundo bloque `hosting` con `"target": "admin"`,
`"public": "build/admin"` y el mismo rewrite SPA.

### 7. Deploy manual (2 builds)
```powershell
# Pública (sitio principal)
flutter build web --release
firebase deploy --only hosting
# Admin
flutter build web --release --dart-define=ADMIN_ONLY=true --output build/admin
firebase deploy --only hosting:admin
```

### 8. Dominio y DNS (usuario, desde Firebase Console / registrador)
- Comprar el dominio base (naming canónico: `admin.tudominio.com`).
- Firebase Console → Hosting → añadir dominio personalizado a cada sitio:
  - Sitio principal: `tudominio.com` (+ `www`).
  - Sitio admin: `admin.tudominio.com` → CNAME a `esteticaybellezastrani-admin.web.app`.
- Verificación TXT de propiedad + CNAME; el certificado HTTPS se emite automáticamente.

### 9. Supabase Auth (Dashboard) — requisito para el login PKCE desde el subdominio
- URL de redirección: añadir `https://admin.tudominio.com` (y sus callbacks
  `/auth/v1/...`) en **Auth → URL Configuration → Redirect URLs**, y opcionalmente
  ajustar `Site URL`.

## Verificación

- [ ] `flutter analyze` limpio.
- [ ] `flutter test` (366 + casos nuevos de adminOnly).
- [ ] Manual: navegar `admin.tudominio.com` → login admin → panel; login paciente
      rechazado en esa build; sitio público sin cambios.

## Notas

- Sin cambios de BD/RLS (misma Supabase, mismas keys).
- Pasos 8 y 9 requieren la cuenta del usuario (registrador y Firebase Console);
  los pasos 1-7 y los deploys los ejecuta el asistente.
- Pendiente de implementación hasta tener el dominio base. Sin commit (regla del
  proyecto: preguntar antes).