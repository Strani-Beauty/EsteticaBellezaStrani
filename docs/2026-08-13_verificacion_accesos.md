# Verificación de accesos, perfiles y roles — checklist de aceptación

**Fecha:** 2026-08-13
**Ámbito:** auth (`auth_users`), perfiles/roles, guards de navegación (`route_guard.dart`), RLS de Supabase, `dispositivos_usuario`.
**Método:** revisión de código + tests + verificación manual sugerida. Estado = implementado / parcial / pendiente.

---

## 1. Resultado de la revisión

| # | Criterio de aceptación | Estado | Evidencia (archivo:línea) |
|---|---|---|---|
| 1 | Se puede registrar un usuario | ✅ Implementado | `login_screen.dart:423` (`_submit` → `signUp`), `auth_supabase_datasource.dart:25-47` |
| 2 | Se crea correctamente su profile | ✅ Implementado | Trigger `handle_new_user` (`20260813000000_admin_gestion_usuarios.sql:62-107`); fallback `createProfile` (`auth_supabase_datasource.dart:121-201`) |
| 3 | Se asigna correctamente su rol | ✅ Implementado | Trigger normaliza `role` (`20260813000000...sql:73-78`); lectura `ProfileModel._extractRolNombre` (`profile_model.dart:116-123`); getters `ProfileEntity` (`profile_entity.dart:42-44`) |
| 4 | Paciente, Especialista y Administrador reciben interfaces diferentes | ✅ Implementado | `route_guard.dart:91-100` (`_redirectByRole`); homes en `app_routes.dart:94-146` |
| 5 | Un usuario modifica únicamente la información que le corresponde | ✅ Implementado | RLS `own_profile_access` (`20260804000100_secure_supabase_setup.sql:52-56`); edición solo `full_name`/`phone` en perfil |
| 6 | Un paciente no consulta info privada de otro paciente | ✅ Implementado | RLS `own_*_access` en `profiles`, `pacientes`, `direcciones_paciente`, `face_maps`, `solicitudes`, `pagos`, `transacciones` |
| 7 | Un especialista no accede a funciones administrativas | ✅ Implementado | `route_guard.dart:60-68` + tests (`route_guard_test.dart:179-203`) |
| 8 | Un usuario desactivado no utiliza el sistema | ✅ Implementado | `route_guard.dart:41-52` → `onDeactivated()` → `signOut()`; RFC semántica `activo` en SQL |
| 9 | La sesión se mantiene correctamente | ✅ Implementado | `auth_cubit.dart:162-169`; logout offline con try/catch en datasource (`signOut` :49-57) |
| 10 | La recuperación de contraseña funciona | ✅ Implementado | Envío: `resetPassword` (`auth_supabase_datasource.dart:69-71`), diálogo en `login_screen.dart:463-510`. Consumo del deep link: evento `passwordRecovery` → `ResetPasswordScreen` (`/auth/reset-password`) → `completePasswordReset` (`auth_cubit.dart`) |
| 11 | El dispositivo queda registrado para notificaciones | ✅ Implementado (código) | Tabla + RLS (`20260813010000_dispositivos_usuario_rls.sql`); `FcmTokenService` + `RegisterFcmToken`; se dispara al autenticarse. **Pendiente manual**: config Firebase por plataforma (B1) |
| 12 | Las restricciones funcionan por ruta o consulta directa no autorizada | ✅ Implementado | Tests (`route_guard_test.dart:36-203`, 11 casos) + policies RLS de `SELECT`/`UPDATE` por dueño/admin |

> Los planes para cerrar los puntos 10 y 11 están en `docs/plans/2026-08-13_pendientes_recovery_fcm.md`. La implementación está documentada en `docs/2026-08-13_recuperacion_password_y_dispositivos_fcm.md`.

---

## 2. Cómo se prueba cada punto

### 2.1 Automatizado (`test/route_guard_test.dart`)

- Acceso sin sesión a rutas públicas/privadas (:36-57).
- Cada rol accede a su home y no a otras rutas (:59-123).
- Usuario desactivado: especialista/admin → `onDeactivated` + welcome; paciente inactivo → `completeProfile` (:125-177).
- Deep-links cruzados: paciente→`/admin`/`/specialist`, especialista→`/admin`, admin→`/specialist` (:179-203).

### 2.2 Manual (runtime)

1. **Registro (Paciente, item 1-3):** en `/login` → "Registrarse", completo email/contraseña/nombre, rol Paciente. Confirmar correo (si aplica). Verificar en Supabase: `profiles` con `role='Paciente'`, `activo=false`, y fila en `pacientes`.
2. **Registro (Especialista):** mismo flujo con rol Especialista → `profiles.activo=true` de inmediato; su habilitación clínica se gobierna con `especialistas.estado_verificacion`.
3. **Interfaces por rol (item 4):** iniciar sesión con cada cuenta → paciente a `/services`, especialista a `/specialist`, admin a `/admin`.
4. **Solo edita su info (item 5):** en `/profile` editar nombre/teléfono → persiste solo en su fila. Intentar vía SQL Editor un UPDATE a otra fila como paciente → `0 rows affected` (RLS).
5. **Paciente no ve info de otro (item 6):** en SQL Editor (`SET ROLE authenticated` como paciente) consultar `profiles` de otro → sin filas.
6. **Especialista vs admin (item 7):** con especialista, pegar `.../admin/usuarios` → redirige a `/specialist`.
7. **Desactivado (item 8):** el admin desactiva a un especialista desde `/admin/usuarios`; al navegar el especialista → sesión cerrada.
8. **Sesión (item 9):** usar la app unos minutos y recargar → sigue autenticado (PKCE + autoRefresh).
9. **Recuperación (item 10, parcial):** en `/login` "¿Olvidaste tu contraseña?" → llega el email. **Pendiente:** abrir el link del correo (no hay handler en la app).
10. **Dispositivo (item 11, parcial):** insert a mano en `dispositivos_usuario` con tu `token_fcm` → dueño lo ve, otro usuario no. **Pendiente:** captura real de token FCM.
11. **Consulta directa (item 12):** en SQL Editor probar `select`/`update` de un paciente a datos ajenos → 0 filas; con admin → sí.

---

## 3. Pendientes detectados

| Punto | Carencia | Plan |
|---|---|---|
| 10 | Sin flujo de recuperación con token (deep link `PASSWORD_RECOVERY` + formulario de nueva contraseña) | ✅ **Resuelto** — `docs/2026-08-13_recuperacion_password_y_dispositivos_fcm.md` → Fase A |
| 11 | Token FCM nunca se obtiene/registra en runtime (sin `firebase_messaging`, sin usecase, sin llamada desde UI) | ⚠️ **Código listo** — falta config Firebase por plataforma (manual) — ídem → Fase B |