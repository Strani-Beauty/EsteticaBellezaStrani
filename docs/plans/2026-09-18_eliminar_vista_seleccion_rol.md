# Plan — Eliminar la vista de selección de rol en el login

Fecha: 2026-09-18
Estado: APROBADO por el usuario (m1297: "aprobado con commit/push").

## Objetivo

La vista de 3 tarjetas (Cliente/Paciente, Especialista, Administrador con botones
"Iniciar Sesión"/"Registrarse") deja de mostrarse. El login solo se accede **por rol**
mediante los deep-links ya existentes (`?login=paciente`, `?login=especialista`,
`?login=administrador`). Sin parámetro, `/login` abre directamente el login de paciente.

## Decisiones del usuario (m1293)

1. `/login` sin parámetro → login de usuario/paciente por defecto.
2. Mantener el registro por toggle (signIn↔signUp) y el deep-link `?registro=paciente`.
3. Conservar el archivo `role_selector_card.dart` (sin usos; no se borra).

## Cambios (solo `lib/features/auth_users/presentation/screens/login_screen.dart`)

1. **Enum**: `enum _AuthMode { roleSelection, signIn, signUp }` → `enum _AuthMode { signIn, signUp }`.
2. **Estado por defecto**: `_AuthMode _mode = _AuthMode.signIn;` (antes `roleSelection`);
   `_selectedType` sigue `_UserType.client`.
3. **`_buildContent`**: quitar el case `_AuthMode.roleSelection => _buildRoleSelection()`.
4. **Eliminar método `_buildRoleSelection()`** (las 3 `RoleSelectorCard` + encabezado
   "Bienvenido/a a MERAKI spa onsite" + footer copyright).
5. **Eliminar método `_goToAuth()`** (sin usos restantes).
6. **`_buildAuthForm`**: quitar el `TextButton` "Volver a selección" (líneas 345-350),
   ya que no hay selección a la que volver.
7. **Import**: quitar `import '../widgets/role_selector_card.dart';` (archivo se conserva
   sin uso).

## Sin cambios

- `app_routes.dart` (deep-links intactos: `registroPaciente`, `loginPaciente`,
  `loginEspecialista`, `loginAdministrador`).
- `role_selector_card.dart`, `auth_form_section.dart`, cubits, tests.
- `registroPaciente`/`loginAdministrador` siguen funcionando (initState intacto).

## Verificación

- [x] `flutter analyze` limpio.
- [x] `flutter test` (366 tests; ninguno referencia la vista de selección).
- [ ] Manual en `flutter run -d chrome`: `/login` directo → login de paciente; botones
      de bienvenida → especialista/admin; catálogo → paciente; toggle Registrarse intacto.

## Notas

- Commit/push aprobado por el usuario (m1297). Mensaje en español imperativo.