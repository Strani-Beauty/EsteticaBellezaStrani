# Gestión de usuarios por el admin, dispositivos push y guards por rol

**Fecha:** 2026-08-13 (sesión 2026-08-11 — commit `98fb3b5`)
**Rama:** `main` — pusheado a `origin/main`
**Alcance:** módulo `admin_users` + migraciones SQL `20260813*` + router/guard (`app_routes.dart`, `route_guard.dart`) + tests

> Complementa `docs/2026-08-13_reglas_acceso_roles.md`, que documenta la matriz de acceso por rol (items 18/19/20). Este doc cubre la **implementación técnica** de los items 14–17 y las pruebas (item 18/19).

---

## 1. Contexto y motivo

Tras cerrar los items 1–13 (auth, perfiles, especialistas), quedaban por implementar:

14. **Acceso administrativo**: el admin debía poder consultar y gestionar (activar/desactivar) a los usuarios autorizados. Antes solo existía `own_profile_access` (cada usuario ve solo su fila), sin forma de listar o togglear cuentas.
15. **Tabla `dispositivos_usuario`**: registrar los dispositivos por usuario para preparar notificaciones push.
16. **Token de notificaciones**: estructura para almacenar el token FCM del dispositivo.
17. **Guard de cuenta desactivada**: un usuario con `activo=false` no debe poder seguir usando funciones protegidas.
18/19. **Pruebas de acceso y seguridad** con los tres roles (paciente, especialista, administrador), incluyendo deep-links cruzados.
20. **Documentación** de las reglas de acceso (doc hermano, ya existente).

---

## 2. Módulo `admin_users` (item 14)

Nuevo feature bajo `lib/features/admin_users/` siguiendo Clean Architecture feature-first (patrón `specialists`).

### Data

| Archivo | Rol |
|---|---|
| `data/datasources/admin_users_supabase_datasource.dart` | Solo habla con Supabase. `fetchUsuarios()` → `select('id, email, full_name, phone, role, activo, created_at')` de `profiles`; `setActivo(userId, activo)` → `update({activo})` filtrado por `id`. Devuelve `UsuarioAdminModel`. |
| `data/models/usuario_admin_model.dart` | Parseo de la fila `profiles` (`fromJson`) y `toEntity()`. |
| `data/repositories/admin_users_repository_impl.dart` | Envuelve el datasource en `Either<Failure, _>` (fpdart): `ServerFailure` ante cualquier excepción. |

### Domain

| Archivo | Rol |
|---|---|
| `domain/entities/usuario_admin_entity.dart` | `id`, `email`, `fullName`, `phone`, `role`, `activo`, `createdAt`. |
| `domain/repositories/i_admin_users_repository.dart` | Contrato: `getUsuarios()` y `setUsuarioActivo(userId, activo)`. |
| `domain/usecases/get_usuarios.dart` | `GetUsuarios()` → lista de usuarios. |
| `domain/usecases/set_usuario_activo.dart` | `SetUsuarioActivo()` → activar/desactivar. |

### Presentation

| Archivo | Rol |
|---|---|
| `presentation/cubits/admin_users_cubit.dart` | Estados `AdminUsersInitial/Loading/Loaded/Error`; `loadUsuarios()` y `setActivo()` (en éxito recarga la lista). Inyectado por nombre en DI. |
| `presentation/screens/admin_users_screen.dart` | Pantalla `/admin/usuarios`: `ListView.separated` de tarjetas con nombre/email/rol y `Switch` de activación. |

**Reglas de negocio del tile** (`admin_users_screen.dart:100`):
- `canToggle = !esAdmin && !esAuto` → **no se puede desactivar a otro administrador ni a uno mismo**.
- El rol se compara contra `AppConstants.rolAdministrador`; el usuario actual sale de `AuthCubit.currentProfile`.

### Wiring (DI)

En `lib/app/core/di/injection.dart`:
- `AdminUsersCubit` se construye con `GetUsuarios` y `SetUsuarioActivo` inyectados por nombre sobre `IAdminUsersRepository`.
- `IAdminUsersRepository` → `AdminUsersRepositoryImpl(AdminUsersSupabaseDataSource(sl<SupabaseClient>()))`.

Acceso desde el panel admin (`admin_dashboard_screen.dart`): tarjeta "Usuarios del Sistema" → `context.go('/admin/usuarios')`.

---

## 3. Migración `20260813000000_admin_gestion_usuarios.sql`

Idempotente (DROP POLICY IF EXISTS + CREATE POLICY / CREATE OR REPLACE FUNCTION). Contenido:

1. **Helper `public.is_administrador()`** — `SECURITY DEFINER`, `STABLE`. Devuelve si `auth.uid()` tiene `role='Administrador'` en `profiles`. **Importante:** se usa para evitar la **recursión infinita de RLS** que ocurre si una policy sobre `profiles` consulta `profiles` directamente.
2. **Policy `profiles_admin_select`** — `FOR SELECT TO authenticated USING (is_administrador())`: el admin puede listar todos los perfiles.
3. **Policy `profiles_admin_update`** — `FOR UPDATE TO authenticated USING (is_administrador()) WITH CHECK (is_administrador())`: el admin puede activar/desactivar cualquier cuenta.
4. **Trigger `handle_new_user` (reemplaza/ajusta el existente)** — crea el perfil al registrarse en `auth.users`:
   - Normaliza `role` desde `raw_user_meta_data` (`Paciente` por defecto; acepta alias `cliente`, `admin`).
   - **Solo el Paciente nace `activo=false`** (debe completar onboarding); Especialista/Administrador nacen `activo=true` (su habilitación clínica la gobierna `especialistas.estado_verificacion`, no `activo`).
   - Inserta fila en `pacientes` para pacientes, idempotente (`ON CONFLICT DO NOTHING`).
5. **Backfill idempotente** — `UPDATE profiles SET activo = true WHERE role IN ('Especialista','Administrador') AND activo IS DISTINCT FROM true`, para cuentas creadas antes de esta migración.

---

## 4. Migración `20260813010000_dispositivos_usuario_rls.sql` (items 15/16)

La tabla ya existía en la BD real (creada fuera del repo); la migración la normaliza de forma idempotente y añade RLS. Columnas alineadas al esquema real (schema OpenAPI / PostgREST):

| Columna | Tipo |
|---|---|
| `id` | `UUID PK DEFAULT gen_random_uuid()` |
| `usuario_id` | `UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE` |
| `token_fcm` | `TEXT NOT NULL` — token de notificaciones push (item 16) |
| `plataforma` | `TEXT` |
| `modelo_dispositivo` | `TEXT` |
| `activo` | `BOOLEAN DEFAULT TRUE` |
| `created_at` / `updated_at` | `TIMESTAMPTZ DEFAULT NOW()` |

- `UNIQUE (token_fcm)`.
- `ADD COLUMN IF NOT EXISTS ...` para normalizar sin romper el esquema existente.
- **Trigger `trg_touch_dispositivo_usuario`** → `touch_dispositivo_usuario()` actualiza `updated_at` en UPDATE.
- **RLS** (ENABLE ROW LEVEL SECURITY):
  - `dispositivo_own_access`: dueño → `ALL` sobre sus propios dispositivos (`auth.uid() = usuario_id`).
  - `dispositivo_admin_select`: admin → `SELECT` de todos (reusa `is_administrador()`).

---

## 5. Router y guards (item 17)

### `lib/app/config/route_guard.dart` (nuevo)

Lógica pura de redirect de GoRouter extraída en `resolveAuthRedirect({authState, location, onDeactivated})`:

- **Guard de cuenta desactivada** (`activo=false`):
  - **Especialista/Administrador** → invoca `onDeactivated()` (el llamador hace `signOut()`) y redirige a `/`. No pueden usar la app.
  - **Paciente** → su `activo=false` es el estado de onboarding (dirección + cuota + evaluación); conserva solo onboarding + catálogo + face map; cualquier ruta protegida redirige a `/complete-profile`.
- **Guard de sesión**: sin sesión solo rutas públicas (`/`, `/services`, `/face-map-questionnaire`, `/login`); lo demás a `/`.
- **Guards por rol** (deep-links cruzados): ruta admin + no-admin → home del rol; ruta especialista + no-especialista → home del rol; `/complete-profile` + no-paciente → home del rol. Si está en `/login` con sesión → home del rol.

### `lib/app/config/app_routes.dart`

- Nueva ruta `/admin/usuarios` (`AppRoutes.adminUsuarios`).
- El redirect del router delega en `resolveAuthRedirect` y pasa `onDeactivated` → `AuthCubit.signOut()` cuando el guard detecta una cuenta desactivada.

---

## 6. Pruebas automatizadas (items 18/19)

`test/route_guard_test.dart` (nuevo, 204 líneas) cubre:

- Acceso sin sesión a rutas públicas/privadas.
- Los 3 roles acceden a sus rutas y son redirigidos fuera de las ajenas.
- Usuario desactivado: especialista/admin → `onDeactivated` + `/`; paciente inactivo → `/complete-profile`.
- Deep-links cruzados: paciente pegando `/admin` o `/specialist/...` no entra; especialista no entra a `/admin`; admin no entra a `/specialist`.

---

## 7. Resumen de RLS

| Tabla | Policy | Rol | Operación |
|---|---|---|---|
| `profiles` | `own_profile_access` (existente) | Dueño | `ALL` (solo su fila) |
| `profiles` | `profiles_admin_select` | Administrador | `SELECT` (todas) |
| `profiles` | `profiles_admin_update` | Administrador | `UPDATE` (activar/desactivar) |
| `dispositivos_usuario` | `dispositivo_own_access` | Dueño | `ALL` (solo suyos) |
| `dispositivos_usuario` | `dispositivo_admin_select` | Administrador | `SELECT` (todas) |

Funciones/triggers nuevos o modificados: `public.is_administrador()`, `handle_new_user` (trigger `on_auth_user_created`), `touch_dispositivo_usuario` (trigger `trg_touch_dispositivo_usuario`).

---

## 8. Verificación

- `flutter analyze` → `No issues found!`
- `flutter test` → todos los tests pasan (incluye `route_guard_test.dart`).
- Migraciones SQL: **no aplicadas al remoto** — pendiente `supabase db push` (o SQL Editor) para aplicar `20260813000000_admin_gestion_usuarios.sql` y `20260813010000_dispositivos_usuario_rls.sql` en orden ascendente.

---

## 9. Archivos

### Nuevos

```
docs/2026-08-13_reglas_acceso_roles.md
lib/app/config/route_guard.dart
lib/features/admin_users/data/datasources/admin_users_supabase_datasource.dart
lib/features/admin_users/data/models/usuario_admin_model.dart
lib/features/admin_users/data/repositories/admin_users_repository_impl.dart
lib/features/admin_users/domain/entities/usuario_admin_entity.dart
lib/features/admin_users/domain/repositories/i_admin_users_repository.dart
lib/features/admin_users/domain/usecases/get_usuarios.dart
lib/features/admin_users/domain/usecases/set_usuario_activo.dart
lib/features/admin_users/presentation/cubits/admin_users_cubit.dart
lib/features/admin_users/presentation/screens/admin_users_screen.dart
supabase/migrations/20260813000000_admin_gestion_usuarios.sql
supabase/migrations/20260813010000_dispositivos_usuario_rls.sql
test/route_guard_test.dart
```

### Modificados

```
lib/app/config/app_routes.dart
lib/app/core/di/injection.dart
lib/features/admin_config/presentation/screens/admin_dashboard_screen.dart
lib/features/auth_users/data/datasources/auth_supabase_datasource.dart
lib/features/auth_users/domain/entities/role_entity.dart
```

---

## 10. Pendientes / verificación manual sugerida

1. Aplicar las migraciones al remoto (`supabase db push`) y confirmar que `is_administrador()` responde sin recursión RLS.
2. Como **Administrador**: abrir "Usuarios del Sistema", listar, desactivar un especialista; verificar que al navegar de nuevo como ese especialista la sesión se cierra (guard item 17).
3. Confirmar que el admin **no** puede desactivar a otro admin ni a sí mismo (UI lo bloquea).
4. Registrar un dispositivo en `dispositivos_usuario` y verificar que el dueño solo ve el suyo y el admin todos.
