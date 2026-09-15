# Plan — Catálogo: acceso directo al login de paciente

Fecha: 2026-09-15
Estado: APROBADO por el usuario (m0242: "aprobado"). Sin commit.

## Objetivo

Desde el catálogo (`/services`), al seleccionar **"Iniciar sesión"** o al seleccionar
**cualquier servicio** (visitante anónimo), ir directamente al **login de paciente**
(formulario de inicio de sesión como Paciente), sin pasar por la selección de rol ni
por el diálogo de registro.

## Cambios

### 1. `lib/features/auth_users/presentation/screens/login_screen.dart`
- Nuevo campo `final bool loginPaciente;` (default `false`).
- `initState`: nuevo branch `else if (widget.loginPaciente) { _selectedType = _UserType.client; _mode = _AuthMode.signIn; }`.

### 2. `lib/app/config/app_routes.dart` (builder `/login`)
- Pasar `loginPaciente: state.uri.queryParameters['login'] == 'paciente'` junto a `loginEspecialista`.

### 3. `lib/features/catalog_services/presentation/screens/services_dashboard_screen.dart`
- `_onServiceSelected` anónimo (línea 94): `_showRegisterPrompt();` → `context.go('${AppRoutes.login}?login=paciente');`.
- Eliminar el método `_showRegisterPrompt` (278-311, sin más referencias).
- BlocListener tras `signOut` (línea 453): `context.go(AppRoutes.login)` → `context.go('${AppRoutes.login}?login=paciente')`.
- Botón "Iniciar sesión" (línea 505): `onPressed` → `context.go('${AppRoutes.login}?login=paciente')`.

### Sin cambios
- Route guard: `/login` ya es pública sin sesión; el redirect por rol tras login lleva a `/services`.

## Verificación

- [x] `flutter analyze` limpio.
- [x] `flutter test` (366 tests).
- [ ] Manual en `flutter run -d chrome`: botón "Iniciar sesión" y tap en servicio → formulario "Ingresar como Paciente".

## Notas
- Sin commit (regla del proyecto: preguntar antes de commitear).