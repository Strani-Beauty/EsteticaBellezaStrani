# Gestión de cuenta: recuperación, cambio de contraseña, perfil y guards por rol

**Fecha:** 2026-08-11 (sesión 2026-08-11)
**Rama:** `main` — commit pendiente (cambios en working tree)
**Alcance:** módulo `auth_users` + router (`app_routes.dart`) + AppBar de los 3 homes

---

## 1. Contexto y motivo

El flujo de autenticación tenía tres carencias de UX y una de seguridad:

1. **Sin recuperación de contraseña**: la pantalla de login no ofrecía la opción "¿Olvidaste tu contraseña?" aunque el datasource ya exponía `resetPasswordForEmail`.
2. **Sin cambio de contraseña post-login**: no existía forma de que un usuario autenticado cambiara su contraseña desde la app.
3. **Sin pantalla de perfil**: el usuario no podía consultar/editar sus datos (nombre, teléfono) ni ver su estado/rol.
4. **Deep-links cruzados de rol**: cualquiera autenticado (p. ej. un paciente) podía navegar a `/admin` o `/specialist/...` pegando la URL (GoRouter no validaba el rol de la ruta a la que se intentaba entrar).

---

## 2. Cambios realizados

### 2.1 Recuperación de contraseña (login)

`lib/features/auth_users/presentation/screens/login_screen.dart`

- Se agregó el enlace **"¿Olvidaste tu contraseña?"** en el modo sign-in (`TextButton.icon` + `Icons.lock_reset_rounded`).
- `_showRecoveryDialog()` abre un `AlertDialog` con campo de correo; al confirmar llama a `AuthCubit.resetPassword(email)` y muestra el aviso *"Revisa tu bandeja de correo..."*.

### 2.2 Cambio de contraseña post-login

Cadena completa data → domain → presentation:

| Capa | Archivo | Cambio |
|---|---|---|
| Data | `data/datasources/auth_supabase_datasource.dart` | `updatePassword(String)` → `_client.auth.updateUser(UserAttributes(password:))` |
| Data | `data/repositories/auth_repository_impl.dart` | `changePassword` envuelto en `Either` (`AuthFailure` para `sb.AuthException`, `ServerFailure` en otros casos) |
| Domain | `domain/repositories/i_auth_repository.dart` | nuevo método `changePassword(String)` |
| Presentation | `presentation/cubits/auth_cubit.dart` | `changePassword` emite `AuthLoading` → `AuthError` o recarga el perfil vía `_emitRefreshedProfile()` (sin spinner de pantalla completa) |
| Screen | `presentation/screens/change_password_screen.dart` | formulario con contraseña nueva + confirmación, validación de coincidencia, botón de enviar vía cubit |

### 2.3 Pantalla de perfil

`lib/features/auth_users/presentation/screens/profile_screen.dart` — nueva ruta `/profile` (`AppRoutes.profile`).

- Avatar según rol (admin / especialista / paciente) + nombre del rol.
- Tacto si `profile.activo == false` ("Cuenta pendiente de activación").
- Datos de solo lectura: correo, nombre, teléfono.
- Modo edición (toggle): campos `TextFormField` para nombre y teléfono → `AuthCubit.updateProfile` (solo manda `fullName`/`phone`, que es lo único que el dueño puede actualizar; el resto del `copyWith`/update queda fuera del alcance del dueño por RLS).
- Acción en AppBar a `/change-password`.
- `BlocListener`: si el estado pasa a `AuthUnauthenticated` → login; si `AuthError` → snackbar; si recarga perfil tras guardar → cierra edición con confirmación.

### 2.4 Acceso desde los homes

`lib/features/auth_users/presentation/widgets/profile_menu_button.dart` — widget reutilizable (`IconButton` → `context.go(AppRoutes.profile)`).

Se agregó en el AppBar de los tres homes:

- `services_dashboard_screen.dart` (paciente): reemplaza el botón previo "Ver Perfil y Evaluación" (que apuntaba a `/complete-profile`).
- `specialist_home_screen.dart` (especialista).
- `admin_dashboard_screen.dart` (admin).

### 2.5 Guards por rol en el router

`lib/app/config/app_routes.dart`

- Constante nueva: `AppRoutes.changePassword = '/change-password'` + `GoRoute` para `/profile` y `/change-password`.
- `_esRutaAdmin(location)` → `location == /admin || startsWith('/admin/')`.
- `_esRutaEspecialista(location)` → lista explícita (`specialistHome`, `specialistOnboarding`, `specialistDocuments`, `specialistPatientMap`, `misCitas`, `misCitasDetalle`) o `startsWith('/specialist')`.
- En el `redirect` (bloque autenticado), antes de dejar pasar:
  - ruta admin + no-admin → `_redirectByRole(rol)`.
  - ruta especialista + no-especialista → `_redirectByRole(rol)`.
  - `/complete-profile` + no-paciente → `_redirectByRole(rol)`.
- El redirect mantiene lo previo: `AuthLoading`/`AuthInitial` no redirige, rutas públicas sin sesión pasan, y el gate de "completar perfil" sigue acotado a pacientes.

---

## 3. Verificación

- Migración SQL: **no aplica** (sin cambios de esquema).
- `flutter analyze` → `No issues found!`
- `flutter test` → todos los tests pasan (placeholder existente).

---

## 4. Archivos

### Nuevos

```
lib/features/auth_users/presentation/screens/profile_screen.dart
lib/features/auth_users/presentation/screens/change_password_screen.dart
lib/features/auth_users/presentation/widgets/profile_menu_button.dart
```

### Modificados

```
lib/app/config/app_routes.dart
lib/features/auth_users/data/datasources/auth_supabase_datasource.dart
lib/features/auth_users/data/repositories/auth_repository_impl.dart
lib/features/auth_users/domain/repositories/i_auth_repository.dart
lib/features/auth_users/presentation/cubits/auth_cubit.dart
lib/features/auth_users/presentation/screens/login_screen.dart
lib/features/admin_config/presentation/screens/admin_dashboard_screen.dart
lib/features/specialists/presentation/screens/specialist_home_screen.dart
lib/features/catalog_services/presentation/screens/services_dashboard_screen.dart
```

---

## 5. Pendientes / verificación manual sugerida

Probar en runtime (modo debug):

1. **Recuperación**: en el login, "¿Olvidaste tu contraseña?" → el correo recibe el enlace de reset de Supabase.
2. **Cambio de contraseña**: desde `/profile` → cambiar contraseña con confirmación; verificar que la sesión queda válida (gotrue no invalida la sesión al cambiar password).
3. **Perfil**: editar nombre/teléfono y confirmar que persiste en `profiles` (prueba de RLS del dueño).
4. **Guards**:
   - Un especialista pegando `.../admin` → redirigido a `/specialist`.
   - Un paciente pegando `/specialist/mis-citas` → redirigido a `/services`.
   - Un admin pegando `/complete-profile` → redirigido a `/admin`.
- Commit pendiente de confirmación del usuario (regla del proyecto).