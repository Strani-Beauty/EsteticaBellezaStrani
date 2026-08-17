# Pruebas manuales — auth_users

| | |
|---|---|
| **Módulo** | auth_users (registro, login, recuperación, perfil, sesión) |
| **Estado del código** | COMPLETO (datasource + repo + AuthCubit en DI) |
| **Fecha** | 2026-08-14 |
| **Versión** | 1.0 |

## Alcance

WelcomeScreen (`/`), LoginScreen (`/login`), CompleteProfileScreen (`/complete-profile`), ProfileScreen (`/profile`), ChangePasswordScreen (`/change-password`), ResetPasswordScreen (`/auth/reset-password`), AuthCubit, guards de ruta (`resolveAuthRedirect`), registro FCM.

## Fuera de alcance

Flujo clínico del paciente (cuestionario/evaluación → doc 07), pagos del onboarding (doc 08), verificación de especialistas (doc 02/03).

## Precondiciones generales

- `.env` válido; Supabase alcanzable.
- Cuentas de la matriz (doc 00): `pac.nuevo`, `pac.activo`, `esp.nuevo`, `esp.aprobado`, `admin@test`.
- Acceso al correo de prueba para confirmar registros y recibir deep links de recuperación.

## 1. Camino feliz

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| AU-H-01 | Landing pública | Sin sesión | 1. Abrir la app | WelcomeScreen con "Agendar Cita", "Especialistas", "Explorar Servicios" | Media | | |
| AU-H-02 | Registro de paciente | Sin sesión | 1. "Agendar Cita" → `/login` 2. Rol Paciente → registro 3. Nombre, email válido, contraseña ≥6 4. Enviar | Diálogo de confirmación de correo (`AuthEmailConfirmationSent`); perfil creado con `activo=false`, rol Paciente | Crítica | | |
| AU-H-03 | Confirmación de correo | Registro recién hecho | 1. Abrir el correo 2. Confirmar | Cuenta confirmada; login posible. **Nota (2026-08-17)**: el link usa PKCE y el code verifier queda en el mismo browser donde se registró; ya no se borra al cerrar la pestaña, así que confirma aunque haya una sesión previa. Si el enlace se abre desde otro browser/dispositivo no se puede usar: la app lo avisa y sugiere iniciar sesión o reenviar. | Crítica | | |
| AU-H-04 | Login de paciente confirmado | Cuenta confirmada | 1. `/login` 2. Paciente → signIn 3. Email + contraseña correctos | `AuthAuthenticated`; redirección por rol (paciente sin perfil completo → `/complete-profile`; completo → `/services`) | Crítica | | |
| AU-H-05 | Login de especialista | `esp.aprobado` | 1. Login con credenciales de especialista | Redirección a `/specialist` | Crítica | | |
| AU-H-06 | Login de admin | `admin@test` | 1. Login con credenciales de admin | Redirección a `/admin` | Crítica | | |
| AU-H-07 | Restaurar sesión al arrancar | Sesión activa previa | 1. Cerrar la app 2. Reabrir | `checkCurrentSession` restaura; no pasa por login | Alta | | |
| AU-H-08 | Editar perfil | Sesión activa | 1. `/profile` 2. Editar nombre y teléfono 3. Guardar | `updateProfile` éxito; datos actualizados al recargar | Alta | | |
| AU-H-09 | Cambio de contraseña | Sesión activa | 1. `/change-password` 2. Actual correcta, nueva ≥6, confirmación igual 3. Enviar | Cambio exitoso; perfil recargado | Alta | | |
| AU-H-10 | Recuperación de contraseña | Cuenta confirmada | 1. `/login` → "¿Olvidaste tu contraseña?" 2. Email 3. Abrir deep link del correo 4. Nueva contraseña + confirmación | `resetPassword` envía correo; `completePasswordReset` actualiza y cierra la sesión temporal (`AuthPasswordChanged`); login con la nueva contraseña funciona | Crítica | | |
| AU-H-11 | Logout con red | Sesión activa | 1. `/profile` 2. Cerrar sesión | `signOut` completa; estado `AuthUnauthenticated`; navegación a `/` | Alta | | |
| AU-H-12 | Deep link de registro | Sin sesión | 1. Abrir `…/login?registro=paciente` | LoginScreen abre directamente el alta de paciente | Media | | |

## 2. Validaciones y casos negativos

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| AU-V-01 | Email sin `@` en registro | Formulario de registro | 1. Email `abc.com` 2. Enviar | Validator rechaza; no hay llamada al servidor | Alta | | |
| AU-V-02 | Contraseña <6 en registro | Formulario de registro | 1. Contraseña `12345` 2. Enviar | Validator rechaza | Alta | | |
| AU-V-03 | Nombre vacío en registro | Formulario de registro | 1. Nombre en blanco 2. Enviar | Validator exige nombre | Media | | |
| AU-V-04 | Registro de email duplicado | Email ya registrado | 1. Registrar el mismo email | Mensaje de error claro del servidor; sin crash | Alta | | |
| AU-V-05 | Login con contraseña incorrecta | Cuenta confirmada | 1. signIn con contraseña errónea | `AuthError` con mensaje; sin crash | Alta | | |
| AU-V-06 | Login de usuario inexistente | — | 1. signIn con email no registrado | Mensaje de error; sin crash | Media | | |
| AU-V-07 | Login con email no confirmado | Registro sin confirmar | 1. signIn | Diálogo `email_not_confirmed` con opción de reenvío | Alta | | |
| AU-V-08 | Cambio de contraseña: actual incorrecta | Sesión activa | 1. `/change-password` 2. Actual errónea | Error mostrado; contraseña sin cambiar | Alta | | |
| AU-V-09 | Cambio: nueva <6 | Sesión activa | 1. Nueva `12345` | Validator rechaza | Media | | |
| AU-V-10 | Cambio: confirmación no coincide | Sesión activa | 1. Nueva ≠ confirmación | Validator rechaza | Media | | |
| AU-V-11 | Recuperación: confirmación no coincide | Deep link abierto | 1. Passwords distintos en ResetPasswordScreen | Validator rechaza | Media | | |
| AU-V-12 | Admin sin signUp | `/login` | 1. Rol Administrador | No hay opción de registro ("acceso por invitación") | Media | | |

## 3. Roles y permisos (guards / RLS)

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| AU-G-01 | Sin sesión a ruta privada | Sin sesión | 1. Navegar a `/profile` (deep link) | Redirect a `/` | Alta | | |
| AU-G-02 | Sin sesión a `/admin` | Sin sesión | 1. Deep link `/admin` | Redirect a `/` | Crítica | | |
| AU-G-03 | Paciente a `/admin` | Sesión de paciente | 1. Deep link `/admin` | Redirect por rol (a `/services`) | Crítica | | |
| AU-G-04 | Paciente a `/specialist` | Sesión de paciente | 1. Deep link `/specialist` | Redirect por rol | Crítica | | |
| AU-G-05 | Especialista a `/admin` | Sesión de especialista | 1. Deep link `/admin` | Redirect a `/specialist` | Crítica | | |
| AU-G-06 | No-paciente a `/complete-profile` | Sesión de especialista | 1. Deep link `/complete-profile` | Redirect por rol | Alta | | |
| AU-G-07 | Logueado visita `/login` | Sesión activa | 1. Navegar a `/login` | Redirect inmediato por rol (Admin→`/admin`, Especialista→`/specialist`, Paciente→`/services`) | Media | | |
| AU-G-08 | Especialista desactivado | `esp.desactivado` (`activo=false`) | 1. Login 2. Navegar cualquier ruta | Guard fuerza `signOut` + redirect a `/` | Crítica | | |
| AU-G-09 | Admin desactivado | Admin con `activo=false` | 1. Login 2. Navegar | Logout forzado | Alta | | |
| AU-G-10 | Paciente desactivado | `pac.desactivado` | 1. Login 2. Intentar `/services` | Solo puede estar en `/complete-profile`, `/face-map-questionnaire`, `/services`, `/auth/reset-password`; el resto → `/complete-profile` | Alta | | Verificar si `/services` está realmente permitido para desactivados |
| AU-G-11 | Rutas públicas sin sesión | Sin sesión | 1. Visitar `/`, `/services`, `/face-map-questionnaire`, `/auth/reset-password` | Accesibles sin redirect | Media | | |

## 4. Estados y transiciones

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| AU-E-01 | Ciclo de estados de login | Sin sesión | 1. signIn válido | Secuencia `AuthLoading` → `AuthAuthenticated(profile)`; sin estados de error intermedios | Media | | |
| AU-E-02 | `refreshProfile` tras edición | Sesión activa | 1. `updateProfile` | Perfil recargado sin pantalla de loading completa | Baja | | |
| AU-E-03 | Aviso de cuenta pendiente | Perfil con `activo=false` | 1. Abrir `/profile` | Aviso "Cuenta pendiente de activación" visible | Media | | |
| AU-E-04 | `AuthPasswordChanged` tras reset | Deep link recovery | 1. Completar reset | Estado emitido; sesión temporal cerrada; navegación a login | Alta | | |
| AU-E-05 | `detached` limpia sesión local | Sesión activa | 1. Cerrar app hasta `detached` | **Cambiado (2026-08-17)**: web elimina solo el token de sesión (localStorage) y conserva el code verifier PKCE para enlaces pendientes; mobile conserva el signOut local de gotrue (sesión + verifier) | Media | | |

## 5. Red y edge cases

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| AU-N-01 | ⚑ Logout sin red | Sesión activa, modo avión | 1. Cerrar sesión | La sesión local se limpia igualmente (try/catch del datasource); navegación a `/` sin `AuthError` | Crítica | | |
| AU-N-02 | Login sin red | Modo avión | 1. signIn | `ServerFailure` → `AuthError` con mensaje; sin crash | Alta | | |
| AU-N-03 | `.env` incompleto | Sin `SUPABASE_URL` | 1. Arrancar la app | `AppEnv.validate()` lanza `StateError`; pantalla de error controlada (`_ErrorApp`) | Media | | |
| AU-N-04 | FCM sin Firebase configurado | Sesión activa | 1. Autenticarse | Registro FCM degrada sin crash; el flujo continúa | Media | | |
| AU-N-05 | FCM con Firebase | Sesión activa | 1. Autenticarse | Token registrado/upsert en `dispositivos_usuario` (onConflict `token_fcm`) | Baja | | |
| AU-N-06 | Token expirado al arrancar | Sesión vieja | 1. Dejar expirar refresh token 2. Reabrir | Auto-refresh o `AuthUnauthenticated`; nunca sesión zombie | Alta | | |

## 6. Sospechosos de código

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| AU-S-01 | Logout fantasma en ProfileScreen | Sesión activa, perfil en modo no-edición | 1. Abrir `/profile` sin editar 2. Pulsar el botón de logout | **RESUELTO (2026-08-14)**: el botón ahora ejecuta `AuthCubit.signOut()`; navega a `/login` vía BlocListener. Verificar que cierra sesión realmente | Crítica | | |
| AU-S-02 | Fallback de nombre vacío | Registro | 1. Registrar con nombre vacío si el validator lo permite | El fallback usa la parte local del email; verificar que no cree perfiles con nombre `null` | Baja | | |
| AU-S-03 | `createProfile` tolerante | Registro nuevo | 1. Registrar paciente y especialista | Paciente nace `activo=false`; especialista/admin `activo=true`; los upserts con fallback nunca lanzan | Alta | | |

## Resumen de ejecución

| Total | Pasa | Falla | Bloqueado | Pendiente |
|---|---|---|---|---|
| 49 | | | | 49 |
