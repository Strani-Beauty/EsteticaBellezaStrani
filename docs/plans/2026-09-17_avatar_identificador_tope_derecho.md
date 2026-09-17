# Plan — Avatar/foto como identificador al tope-derecho (3 pantallas)

Fecha: 2026-09-17
Estado: APROBADO por el usuario (m0987: "aprobado"; alcance decidido en m0985:
"solo las 3 pantallas principales"). Sin commit.

## Objetivo

Cuando el usuario está logueado, mostrar su **avatar/foto** (en vez del icono genérico
"Mi perfil") como identificador al tope-derecho del AppBar, en las 3 pantallas
principales: catálogo del paciente, panel del especialista y panel admin.

## Cambios

### 1. Nuevo `lib/features/auth_users/presentation/widgets/avatar_profile_button.dart`
- `AvatarProfileButton` (StatelessWidget): lee `AuthCubit.currentProfile` con
  `context.watch`; renderiza `AvatarView(avatarUrl, isPatient/isAdmin/isSpecialist,
  seed: profile.id, diameter ~36, showBorder: false)` en un círculo con anillo blanco
  de contraste (visible sobre los AppBar morados) y `InkWell` tappable.
- Tap → `context.go(profile.isSpecialist ? AppRoutes.specialistProfile : AppRoutes.profile)`
  (misma navegación que `ProfileMenuButton`); tooltip 'Mi perfil'.
- Si `currentProfile == null` → `SizedBox.shrink()` (no se muestra sin sesión).

### 2. Reemplazar `ProfileMenuButton` por `AvatarProfileButton`
- `services_dashboard_screen.dart:462` (catálogo; ya condicionado a sesión iniciada).
- `specialist_home_screen.dart:56` (panel especialista).
- `admin_dashboard_screen.dart:46` (panel admin).
- Actualizar imports (quitar `profile_menu_button.dart`; añadir el nuevo widget).

### 3. Eliminar `lib/features/auth_users/presentation/widgets/profile_menu_button.dart`
- Queda sin uso tras el reemplazo (evitar código muerto).

## Verificación

- [x] `flutter analyze` limpio.
- [x] `flutter test` (366 tests).
- [ ] Manual en `flutter run -d chrome`: paciente con retrato/foto ve su avatar en el
      catálogo (solo logueado); especialista y admin ven su avatar/ícono de rol en sus
      paneles; el tap lleva al perfil.

## Notas

- Sin cambios de BD/RLS/storage. Sin commit (regla del proyecto: preguntar antes).