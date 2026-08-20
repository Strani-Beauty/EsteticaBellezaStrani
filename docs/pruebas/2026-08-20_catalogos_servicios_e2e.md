# Pruebas manuales — Catálogo de servicios: relaciones y flujo completo (E2E)

| | |
|---|---|
| **Fecha** | 2026-08-20 |
| **Versión** | 1.0 |
| **Commit** | (pendiente) |
| **Entorno** | Local `flutter run -d web-server --web-port 8080` (NO el desplegado en web.app) |
| **Plan** | `docs/plans/2026-08-20_catalogos_e2e_relaciones_flujo_completo.md` |
| **Proyecto Supabase** | `hhyjremkguvphmjuaazp` (43 migraciones, Local == Remote) |
| **Confirmación de correo** | Desactivada en Supabase para pruebas |

## Cuentas

| Rol | Email | Clave |
|---|---|---|
| Administrador | `admin@strani.com` | `Test1234!` |
| Paciente sin APTO | `paciente1@test.com` (María González) | `Test1234!` |
| Paciente con APTO v2 | `pac.compliance1@test.com` | `Test1234!` |
| Especialista (no coincide) | `esp.compliance1@test.com` (esp 15/21/5) | `Test1234!` |
| Especialista (coincide) | `esp.aprobado@test` (esp 1/15) | `Test1234!` |

## Checklist de aceptación — Act. 12 (matriz de relaciones)

| # | Ítem | Resultado | Evidencia / observación |
|---|---|---|---|
| R1 | Cuestionario obligatorio: sin APTO → modal; con APTO → pasa | ✅ | **Hallazgo clave**: todos los servicios existentes con cuestionario 5 tienen `requiere_face_map=true` y el paso 2 (face map) corre antes que el paso 3 (requisitos) en `_onServiceSelected` → el modal no se dispararía. Se creó en la app `TEST E2E Sin FaceMap` (id `9a42322c`, precio 200 PRECIO_FIJO, categoría 16, cues 5 obligatorio, sin especialidades). `paciente1` (sin APTO) → modal "Requisito de salud pendiente" y no continúa; `pac.compliance1` (APTO v2) → pasa al modal de pago |
| R2 | Face map sin cuestionario → flujo face map, sin modal | ✅ | "Desintoxicación Facial Profunda" `ced81223` va directo al cuestionario de puntos faciales, sin modal de requisitos |
| R3 | Sin relaciones ni face map → modal de pago directo | ✅ | "Cavitación Corporal Ultrasónica" `d727d7fb` → sin requisitos ni face map, abre el modal de opciones de pago |
| R4 | Match de especialidades en marketplace | ✅ | Vía API: `aceptar_solicitud` con esp.compliance1 (15/21/5) sobre Relleno de Labios (esp 1+14) → `NO_COINCIDE_ESPECIALIDAD`; con esp.aprobado (1/15) → `OK` + cita creada |
| R5 | Servicio sin `servicio_especialidades` visible para todos | ✅ | `TEST-R5-SinEspecialidad` (sin filas) → ambos especialistas lo vieron en `obtener_solicitudes_publicadas_geo` |
| R6 | RPC reemplazo refleja cambios + idempotente | ✅ | Al asignar esp 17 al TEST-R5 ambos dejan de verlo en geo; al añadir cues 5, `fetchRequisitosServicio` lo refleja. No-admin recibe `P0001 Solo administradores...` en ambos RPC |

## Checklist de aceptación — Act. 13 (flujo completo)

| # | Ítem | Resultado | Evidencia / observación |
|---|---|---|---|
| A | Admin crea/administra categorías | ✅ | Verificado al crear el servicio de prueba (tab Categorías y Servicios del Admin Catalog) |
| B | Admin crea servicio (precio + `tipo_precio` + duración) y lo edita | ✅ | `TEST E2E Sin FaceMap`: precio 200, PRECIO_FIJO, 25 min, categoría 16. Persistido en BD correctamente |
| C | Admin asocia especialidades y cuestionarios al servicio | ✅ | `servicio_cuestionarios` = cues 5 obligatorio (orden 0); `servicio_especialidades` = 0 filas |
| D | Servicio inactivo no aparece al paciente | ✅ | Se desactivó TEST E2E y el dashboard del paciente no lo muestra |
| E | Especialista sin la especialidad requerida no recibe el servicio | ✅ | Contra-prueba API: `NO_COINCIDE_ESPECIALIDAD` + geo 0 filas |
| F | Paciente que no cumple los requisitos no puede continuar | ✅ | R1a: modal de requisito pendiente, sin continuar |
| G | Paciente elegible puede seleccionar el servicio | ✅ | R1b: pasa al modal de pago |
| H | Precio estimado correcto antes de continuar | ✅ | Cavitación: modal muestra $80 (coincide con `precio_base`) |

## Hallazgos

1. **Trigger huérfano `tr_log_solicitud_estado` bloqueaba la creación de solicitudes (resuelto)**. El INSERT de `solicitudes` por el paciente fallaba con `42501` ("new row violates row-level security policy for table historial_estados"). Existía un trigger remoto (creado a mano en el SQL Editor, **ausente de migraciones**) `tr_log_solicitud_estado` (AFTER INSERT en `solicitudes`) cuya función `log_solicitud_estado_change()` insertaba en `historial_estados` con `tipo_entidad='SOLICITUD'` usando los permisos del llamante; la única policy de esa tabla (`historial_cita_own`, migración `20260807000000`) solo cubre `CITA` de especialistas. La app nunca usa historial para SOLICITUD. **Fix**: migración `20260820000200_remove_tr_log_solicitud_estado.sql` (DROP TRIGGER + DROP FUNCTION IF EXISTS). Post-fix: INSERT del paciente → HTTP 201. Diagnóstico con `20260820000100_diag_solicitud_triggers.sql` (`_diag_solicitud_triggers`, función de lectura) y limpieza en `20260820000300_remove_diag_solicitud_triggers.sql`.
2. **Todos los servicios con cuestionario 5 obligatorio tienen `requiere_face_map=true`**. El flujo de `_onServiceSelected` (services_dashboard_screen.dart:91) corre el face map (paso 2) **antes** que la validación de requisitos de salud (paso 3), por lo que con esos servicios el modal de "Requisito de salud pendiente" nunca se dispararía. No es un bug per se (el gate de face map es previo), pero hay que crear un servicio sin face map + cues obligatorio para ejercitar R1 (así se hizo con `TEST E2E Sin FaceMap`). Se documenta como nota de producto.
3. **El listado de servicios del admin no refresca tras guardar (menor)**. Tras "Guardar servicio" con los snackbars de éxito ("Servicio creado correctamente", "Cuestionario guardado"), el listado no muestra el nuevo servicio hasta **recargar la página**. El cubit emite feedback y re-emite estado, pero el widget abierto no refleja el cambio; al re-entrar a la pantalla sí aparece. Pendiente de investigar (posible estado no rebuild por el `_ServiciosTab` o BlocConsumer).
4. **El guardado de servicio no da feedback de error** (menor). Si el INSERT falla (p.ej. `categoria_id` NOT NULL `23502`), `_guardar` en `admin_servicio_detail_screen.dart` retorna silenciosamente sin mostrar snackbar; el usuario no sabe que falló. Solo se ve que el botón vuelve a "Guardar servicio".

## Contra-pruebas (triggers/RLS/RPC)

1. **`aceptar_solicitud` sin coincidencia** ✅ → `{"aceptada":false,"motivo":"NO_COINCIDE_ESPECIALIDAD"}` (esp.compliance1 sobre Relleno de Labios). Con coincidencia → `{"aceptada":true,"motivo":"OK"}` + cita `d5fe2e7e` (borrada tras la prueba).
2. **`obtener_solicitudes_publicadas_geo` filtra por especialidad** ✅ → esp.compliance1: 0 filas para Relleno de Labios (esp 1+14) pero sí ve TEST-R5 (sin especialidades); esp.aprobado: 1 fila. Tras reasignar TEST-R5 a esp 17, ambos dejan de verlo.
3. **RLS escritura en `servicios`** ✅ → INSERT/UPDATE/DELETE por no-admin → 403; `reemplazar_servicio_especialidades`/`reemplazar_servicio_cuestionarios` por no-admin → `P0001 Solo administradores...`.
4. **INSERT de `solicitudes` por el paciente** ✅ → HTTP 201 tras el fix del trigger (antes `42501`).
5. **INSERT/UPDATE por admin** ✅ → servicios y relaciones se crean/modifican sin error.

## Resumen final

| Ítem | Estado |
|---|---|
| Act. 12 — Matriz de relaciones (R1-R6) | ✅ |
| Act. 13 — Flujo completo (A-H) | ✅ |
| Contra-pruebas (aceptar_solicitud, geo, RLS, trigger) | ✅ |
| Servicio de prueba `TEST E2E Sin FaceMap` | ✅ creado y dejado **desactivado** (Decisión 3 del plan) |
| Data de prueba residual | ✅ limpiada (solicitudes 0, direcciones de prueba borradas, TEST-R5 borrado, cita de prueba borrada) |
| `flutter analyze` / `flutter test` | ✅ 0 issues / 130 tests |
| Migraciones | ✅ 43 (Local == Remote), 3 nuevas: `20260820000100`, `20260820000200`, `20260820000300` |