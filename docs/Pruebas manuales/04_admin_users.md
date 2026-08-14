# Pruebas manuales — admin_users

| | |
|---|---|
| **Módulo** | admin_users (gestión de usuarios por admin) |
| **Estado del código** | COMPLETO (datasource + repo + AdminUsersCubit en DI) |
| **Fecha** | 2026-08-14 |
| **Versión** | 1.0 |

## Alcance

AdminUsersScreen (`/admin/usuarios`): listado de `profiles` con activación/desactivación de cuentas; AdminUsersCubit (`loadUsuarios`, `setActivo`).

## Fuera de alcance

Panel de verificación de especialistas (doc 03); efectos clínicos en el paciente (doc 07).

## Precondiciones generales

- Cuenta `admin@test`.
- Usuarios de los tres roles para la lista; `esp.desactivado` y `pac.desactivado` ya creados o por crear durante la prueba.
- ⚑ Un segundo dispositivo con sesión activa de especialista y otra de paciente.

## 1. Camino feliz

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| AUU-H-01 | Carga de usuarios | Admin logueado | 1. Entrar a `/admin/usuarios` | Lista de profiles (email, full_name, phone, role, activo) ordenada por `created_at` | Crítica | | |
| AUU-H-02 | Desactivar paciente | Paciente activo | 1. Apagar switch del paciente | `setActivo(userId,false)`; lista recargada con el cambio | Crítica | | |
| AUU-H-03 | Reactivar paciente | `pac.desactivado` | 1. Encender switch | `activo=true`; el paciente vuelve a operar normal | Alta | | |
| AUU-H-04 | Desactivar especialista | Especialista activo | 1. Apagar switch | Éxito + recarga | Crítica | | |

## 2. Validaciones y casos negativos

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| AUU-V-01 | Sin usuarios | BD sin profiles | 1. Cargar | Mensaje "No hay usuarios registrados." | Baja | | |
| AUU-V-02 | `setActivo` falla | Sin red | 1. Toggle | Snackbar de error; switch vuelve al estado previo tras recarga | Alta | | |

## 3. Roles y permisos (guards / RLS)

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| AUU-G-01 | No-admin a `/admin/usuarios` | Sesión de paciente o especialista | 1. Deep link | Guard redirige por rol | Crítica | | |
| AUU-G-02 | RLS select de profiles | Paciente | 1. Intentar leer la lista completa de profiles vía cliente | Policies `profiles_admin_select` lo impiden (solo admin) | Crítica | | |
| AUU-G-03 | RLS update de activo | Paciente/especialista | 1. Intentar `update` de `profiles.activo` ajeno | `profiles_admin_update` lo impide | Crítica | | |
| AUU-G-04 | Sin switch para admins | Lista con otro admin | 1. Observar fila de otro Administrador | Sin switch (`canToggle=false` para rol Administrador) | Alta | | |
| AUU-G-05 | Sin switch para sí mismo | Admin logueado | 1. Observar propia fila ("· tú") | Sin switch; no puede desactivarse a sí mismo | Alta | | |

## 4. Estados y transiciones

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| AUU-E-01 | ⚑ Desactivar especialista con sesión activa | Especialista logueado en 2º dispositivo | 1. Desactivar como admin 2. Navegar en el 2º dispositivo | Guard `onDeactivated` fuerza `signOut` + redirect a `/` | Crítica | | |
| AUU-E-02 | ⚑ Desactivar paciente con sesión activa | Paciente logueado en 2º dispositivo | 1. Desactivar 2. Navegar | Paciente queda restringido a rutas permitidas (`/complete-profile`, etc.) | Alta | | |
| AUU-E-03 | Login de desactivado | `esp.desactivado` | 1. Login fresco | Guard fuerza logout inmediato (especialista/admin) | Alta | | |
| AUU-E-04 | Marca "· tú" | Admin en la lista | 1. Buscar propia fila | Sufijo "· tú" visible | Baja | | |

## 5. Red y edge cases

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| AUU-N-01 | Carga sin red | Modo avión | 1. Entrar a `/admin/usuarios` | Vista de error con "Reintentar" | Alta | | |
| AUU-N-02 | Toggle rápido doble | Usuario activo | 1. Apagar y encender rápidamente | Sin estados inconsistentes; última acción gana y recarga | Media | | |

## 6. Sospechosos de código

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| AUU-S-01 | Confianza en policies del servidor | — | 1. Verificar con cuenta no-admin que el select a `profiles` falla | El datasource no filtra por rol en cliente; la seguridad depende 100% de RLS — confirmarlo | Crítica | | |
| AUU-S-02 | Desactivar admin (laguna UI) | Dos admins | 1. Observar si la UI impide desactivar a OTRO admin | La regla `canToggle` excluye admins; confirmar que no hay vía alternativa | Media | | |

## Resumen de ejecución

| Total | Pasa | Falla | Bloqueado | Pendiente |
|---|---|---|---|---|
| 19 | | | | 19 |
