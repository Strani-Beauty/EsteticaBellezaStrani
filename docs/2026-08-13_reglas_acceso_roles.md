# Reglas de acceso por rol — Estética y Belleza Strani

**Fecha:** 2026-08-13
**Alcance:** rutas GoRouter (`lib/app/config/app_routes.dart` + `route_guard.dart`), RLS de Supabase (migraciones `20260813*`) y gestión de usuarios por el admin (`lib/features/admin_users`).

---

## 1. Roles

| Rol | `profiles.role` | Nace | Acceso inicial |
|---|---|---|---|
| Paciente | `'Paciente'` | **inactivo** (`activo=false`) | Onboarding (`/complete-profile`) + catálogo (`/services`) + face map |
| Especialista | `'Especialista'` | **activo** (`activo=true`) | `/specialist` + onboarding de especialista + mis citas |
| Administrador | `'Administrador'` | **activo** (`activo=true`) | `/admin` + `/admin/usuarios` |

> Semántica de `profiles.activo`: "cuenta autorizada para usar la app".
> El **Paciente** pasa a `activo=true` al completar su onboarding (dirección + cuota inicial + evaluación médica aprobada). El **Especialista** y el **Administrador** nacen activos; su `activo=false` solo puede provenir de la desactivación del panel admin (`AdminUsersScreen`).

---

## 2. Matriz de acceso a rutas (GoRouter)

Resuelto en `lib/app/config/route_guard.dart` (`resolveAuthRedirect`).

| Ruta | Sin sesión | Paciente | Especialista | Administrador |
|---|:---:|:---:|:---:|:---:|
| `/` (welcome) | ✅ | ✅ | ✅ | ✅ |
| `/login` | ✅ | (redirige por rol) | (redirige por rol) | (redirige por rol) |
| `/services` (catálogo) | ✅ | ✅ | ✅ | ✅ |
| `/face-map-questionnaire` | ✅ | ✅ | ✅ | ✅ |
| `/complete-profile` | ❌ | ✅ (onboarding) | ❌ | ❌ |
| `/profile` | ❌ | ✅ | ✅ | ✅ |
| `/change-password` | ❌ | ✅ | ✅ | ✅ |
| `/specialist`, `/specialist/*`, `/specialist/mis-citas*` | ❌ | ❌ | ✅ | ❌ |
| `/admin`, `/admin/usuarios` | ❌ | ❌ | ❌ | ✅ |

Reglas del guard:
1. Sin sesión → solo rutas públicas (`/`, `/services`, `/face-map-questionnaire`, `/login`); el resto a `/`.
2. Con sesión y **inactivo** (`activo=false`):
   - Especialista/Administrador → `signOut()` + redirigir a `/` (no pueden usar la app).
   - Paciente → solo onboarding + catálogo; cualquier ruta protegida redirige a `/complete-profile`.
3. Con sesión activa:
   - En `/login` → redirige a la ruta home de su rol.
   - Ruta admin + no-admin → redirige al home de su rol.
   - Ruta especialista + no-especialista → redirige al home de su rol.
   - `/complete-profile` + no-paciente → redirige al home de su rol.

---

## 3. RLS en Supabase

### `profiles`
| Policy | Rol con acceso | Operación |
|---|---|---|
| `own_profile_access` | Dueño | `ALL` (solo su propia fila) |
| `profiles_admin_select` | Administrador | `SELECT` (todas las filas) |
| `profiles_admin_update` | Administrador | `UPDATE` (activar/desactivar) |

> Las policies de admin usan `public.is_administrador()` (`SECURITY DEFINER`) para evitar la recursión de RLS que ocurre si una policy sobre `profiles` consulta `profiles` directamente.

### `dispositivos_usuario`
| Policy | Rol con acceso | Operación |
|---|---|---|
| `dispositivo_own_access` | Dueño | `ALL` (solo sus propios dispositivos) |
| `dispositivo_admin_select` | Administrador | `SELECT` (todas las filas) |

### Triggers
- `handle_new_user`: crea perfil al registrar en `auth.users`. Paciente nace `activo=false`; Especialista/Administrador nace `activo=true`.
- `trg_touch_dispositivo_usuario`: actualiza `updated_at` en `dispositivos_usuario`.

---

## 4. Gestión de usuarios (item 14)

- **Pantalla:** `AdminUsersScreen` en `/admin/usuarios` (accesible desde el panel admin vía tarjeta "Usuarios del Sistema").
- **Funciones:** listar todos los perfiles y activar/desactivar cuentas (switch). No se permite desactivar a otro administrador ni a uno mismo.
- **Regla de negocio:** un usuario desactivado deja de poder usar funciones protegidas (item 17) — el guard cierra su sesión la próxima navegación.

---

## 5. Pruebas automatizadas (items 18/19)

`test/route_guard_test.dart` cubre:
- Acceso sin sesión a rutas públicas/privadas.
- Los 3 roles acceden a sus rutas y no a las de otros.
- Usuario desactivado (especialista/admin) → signOut; paciente inactivo → onboarding.
- Deep-links cruzados: paciente pegando `/admin`/`/specialist` no entra; especialista no entra a `/admin`; admin no entra a `/specialist`.

---

## 6. Verificación manual sugerida

1. Iniciar sesión como **Paciente** recién registrado → debe llegar a `/complete-profile`; tras dirección+cuota+evaluación queda `activo=true`.
2. Como **Paciente activo**, pegar `/admin` → redirige a `/services`.
3. Como **Especialista**, pegar `/admin/usuarios` → redirige a `/specialist`.
4. Como **Administrador**, abrir "Usuarios del Sistema", desactivar un especialista, y verificar que al navegar de nuevo como ese especialista la sesión se cierra.
5. Confirmar en Supabase que `profiles` de especialista/admin recién creados tienen `activo=true`.
