# Resumen de jornada — 2026-08-20

- **Fecha**: 2026-08-20
- **Rama**: `main`.
- **Flutter**: SDK **3.44.9** (sin cambios hoy).

Dos ciclos hoy: **E2E del catálogo (Act. 12-13)** y después los **4 fixes post-E2E** (hallazgos 1-4 del reporte). Planes: `docs/plans/2026-08-20_catalogos_e2e_relaciones_flujo_completo.md` y `docs/plans/2026-08-20_fixes_catalogo_hallazgos_1_4.md` (ambos APROBADOS por el usuario). Evidencia en `docs/pruebas/2026-08-20_catalogos_servicios_e2e.md`.

| Ciclo | Estado | Commit |
|---|---|---|
| 1. E2E catálogo (Act. 12-13): relaciones + flujo completo + fix trigger huérfano | ✅ Pusheado | `48012e4` |
| 2. Fixes post-E2E (hallazgos 1-4): refresh listado, feedback de error, continuar al pago tras face map, re-link cuestionario v2 | ✅ (este commit) | `(por confirmar)` |

---

## 1. E2E del catálogo — Act. 12 (matriz de relaciones) y Act. 13 (flujo completo)

**Contexto**: el catálogo quedó implementado el 19-08 (commit `3cf9de9`); faltaban las pruebas manuales E2E de las Actividades 12 y 13 del plan de semana 6. Se ejecutaron hoy con el formato de los E2E previos (compliance, salud).

### Hallazgo bloqueante resuelto: trigger huérfano `tr_log_solicitud_estado`

- El INSERT de `solicitudes` por el paciente fallaba con `42501` ("new row violates row-level security policy for table historial_estados").
- **Causa raíz**: trigger **remoto huérfano** (creado a mano en el SQL Editor, **ausente de migraciones**) `tr_log_solicitud_estado` (AFTER INSERT en `solicitudes`) cuya función `log_solicitud_estado_change()` insertaba en `historial_estados` con `tipo_entidad='SOLICITUD'` usando los permisos del llamante. La única policy de esa tabla (`historial_cita_own`, migración `20260807000000`) solo cubre `CITA` de especialistas → el INSERT del paciente rompía. La app nunca usa historial para SOLICITUD.
- **Fix**: diagnóstico con `20260820000100_diag_solicitud_triggers.sql` (función `_diag_solicitud_triggers`) → eliminación con `20260820000200_remove_tr_log_solicitud_estado.sql` (DROP TRIGGER + DROP FUNCTION IF EXISTS) → limpieza del diagnóstico con `20260820000300_remove_diag_solicitud_triggers.sql`. Post-fix: INSERT del paciente → **HTTP 201**. `supabase migration list`: Local == Remote (43).

### Act. 12 — Matriz de relaciones (R1-R6) ✅

- **R1** (cuestionario obligatorio): todos los servicios con cues 5 tenían `requiere_face_map=true` y el paso 2 (face map) corre antes que el paso 3 (requisitos) en `_onServiceSelected` → se creó en la app `TEST E2E Sin FaceMap` (id `9a42322c`, precio 200 PRECIO_FIJO, sin face map, cues 5 obligatorio). `paciente1` (sin APTO) → modal "Requisito de salud pendiente"; `pac.compliance1` (APTO v2) → pasa al pago.
- **R2** (face map sin cues): Desintoxicación Facial Profunda → face map directo. ✅
- **R3** (sin relaciones): Cavitación → modal de pago directo. ✅
- **R4** (match de especialidades): vía API `aceptar_solicitud` — esp.compliance1 (15/21/5) sobre Relleno de Labios (esp 1+14) → `NO_COINCIDE_ESPECIALIDAD`; esp.aprobado (1/15) → `OK` + cita creada. ✅
- **R5** (servicio sin especialidades visible para todos): `TEST-R5-SinEspecialidad` visto por ambos especialistas en `obtener_solicitudes_publicadas_geo`. ✅
- **R6** (RPC reemplazo): al asignar esp 17 dejan de verlo; cues 5 reflejado; no-admin → `P0001 Solo administradores...`. ✅

### Act. 13 — Flujo completo (A-H) ✅

A/B/C (admin crea categorías/servicio con precio+tipo+duración, asocia especialidades y cues), **D** (inactivo no aparece al paciente — switch admin + login paciente), **E** (especialista sin especialidad no recibe — contra-prueba API), **F** (=R1a), **G** (=R1b), **H** (precio estimado correcto: Cavitación → $80).

### Limpieza de datos de prueba

Cita `d5fe2e7e` (invisible para admin por RLS, borrada como especialista), solicitudes residuales (16837301 ACEPTADA + 5781b03a PUBLICADA), direcciones de prueba (`Street Test 123`), servicio `TEST-R5`. Se dejó el servicio `TEST E2E Sin FaceMap` **desactivado** (Decisión 3 del plan: el CRUD admin no borra servicios). BD final: 0 solicitudes de prueba.

---

## 2. Fixes post-E2E — hallazgos 1-4 del reporte

**Contexto**: el reporte E2E dejó 4 hallazgos de deuda técnica. El usuario pidió implementarlos (plan `2026-08-20_fixes_catalogo_hallazgos_1_4.md`).

### Fix 1 — El listado de servicios del admin no refrescaba tras guardar

- **Causa**: `AdminServicioDetailScreen` se navegaba con `context.push` y al volver el listado no se reconstruía con el servicio nuevo.
- **Fix**: `_guardar` ahora hace `Navigator.pop(context, creado)` devolviendo el servicio; `AdminCatalogScreen` captura el resultado del `push` (FAB y `onAbrir`) y dispara `cubit.load()` al volver → la lista siempre refresca (incl. ediciones).

### Fix 2 — El guardado de servicio no daba feedback de error

- **Causa**: si el INSERT fallaba (ej. `categoria_id` NOT NULL → `23502`), `_guardar` retornaba silenciosamente sin snackbar.
- **Fix**: si `creado == null` → snackbar con el `error` del estado del cubit; si falla el reemplazo de especialidades/cuestionarios (`false`) → también se muestra el error sin cerrar la pantalla.

### Fix 3 — Post-face map nuevo no abría el modal de pago

- **Causa**: al completar un face map **nuevo** (rama `else` de `_onServiceSelected`), el "Aceptar" del diálogo "Mapeo Registrado" hacía `pop` sin valor → el paciente debía volver a tocar el servicio.
- **Fix**: ese "Aceptar" ahora devuelve `'continuar'` (`pop('continuar')` en `face_map_questionnaire_screen.dart`) y la rama `else` del dashboard captura el resultado y abre `_showPaymentOptionsModal` → flujo continuo hasta el pago, igual que en modo solo lectura.

### Nota 1 — Re-link de 5 servicios inactivos al cuestionario v2

- Los 5 servicios inactivos (Toxina Botulínica `11111111`, Ácido Hialurónico `22222222`, Peelings Médicos `33333333`, Microneedling `44444444`, Lipólisis Alta Frecuencia `55555555`) quedaron enlazados al "Cuestionario de Salud" **v1 (id=4, inactiva)** por el flujo de compliance previo. Como los pacientes responden la v2 (id=5, activa), `tieneEvaluacionAptaDeCuestionario(id=4)` nunca encontraría APTO → bloqueo falso si se activaran.
- **Fix**: migración `20260820000400_relink_servicios_cuestionario_v2.sql` (UPDATE idempotente con `NOT EXISTS`, conserva `obligatorio`/`orden`, respeta `servicio_cuestionarios_servicio_cuestionario_idx`). Verificado por API: **0 filas con id=4, 18 con id=5**. `supabase migration list`: Local == Remote (44).

### Verificación

- `flutter analyze` → sin issues (se corrigió un `use_build_context_synchronously` capturando el cubit antes del `await`).
- `flutter test` → **130/130 en verde**.
- Migración `20260820000400` aplicada al remoto con `supabase db push`.

---

## Verificación transversal

- `flutter analyze` → sin issues.
- `flutter test` → 130/130 OK.
- BD: migraciones aplicadas al remoto hasta `20260820000400` (Local == Remote, 44).

### Pendientes documentados (del reporte E2E)

- **Hallazgo 2** (nota de producto, no bug): todos los servicios con cues 5 tienen `requiere_face_map=true` y el face map corre antes que la validación de requisitos en `_onServiceSelected` → para ejercitar el modal de requisitos hay que crear un servicio sin face map.
- Deuda pre-existente (no tocada hoy): buckets públicos (`contratos`, `firmas`, `fotografias-tratamiento`), tablas creadas a mano sin versionar, RPC `obtener_solicitudes_publicadas_geo` sin filtro de `fecha_expiracion`, push FCM de notificaciones.
- Prueba manual en app de los 3 fixes de UI (Fix 1-3) pendiente: `flutter run -d web-server --web-port 8080`.