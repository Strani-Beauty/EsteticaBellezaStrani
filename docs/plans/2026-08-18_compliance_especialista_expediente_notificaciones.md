# Plan: Compliance especialista — expediente completo, habilitación gated y notificaciones

| | |
|---|---|
| **Fecha** | 2026-08-18 |
| **Origen** | Actividades compliance especialista (ítems 4–14). Ítems 4–7 ya implementados (estados por documento, consulta admin, revisión con fecha/admin, rechazo con motivo) y el flujo de firma de contrato (ítem 11) también. |
| **Estado** | APROBADO por el usuario (2026-08-18). |
| **Proyecto Supabase** | `hhyjremkguvphmjuaazp` (bellezastrani@gmail.com). |

## Decisiones de producto (confirmadas por el usuario)

- **Expediente habilitante** = 3 documentos APROBADOS (identificación, licencia, formación = diploma|certificación) + datos profesionales (médico regente activo + ≥1 especialidad) + **contrato firmado antes de Verificado**.
- El admin solo puede aprobar (estado `APROBADO`/Verificado) cuando el expediente está completo; el especialista puede operar/recibir solicitudes solo después.
- **Notificaciones ítem 13**: solo in-app (tabla `notificaciones` + triggers + UI con badge). Push FCM queda fuera de alcance en esta iteración.

## Estado verificado en el código

- `estado_revision` por documento con `PENDIENTE/APROBADO/RECHAZADO` (enum `EstadoRevisionDocumento`), `revisado_por`, `fecha_revision`, `observacion_revision`, `version_documento`, `activo`.
- Admin revisa docs por especialista en `admin_dashboard_screen.dart` (`_DocumentosBloque`, `_revisarDocumento`).
- Contrato: `firmarContrato` inserta `firmado=true`, `fecha_firma`, `metodo_firma` (TOUCH), `url_documento`; pantalla `contract_signature_screen.dart`.
- `updateVerificacion` hoy permite aprobar sin validar expediente (hueco del ítem 10).
- Marketplace filtra `estado_verificacion='APROBADO'` + activo + disponible + en_línea; `aceptar_solicitud` valida APROBADO+activo.
- `subirDocumento` siempre inserta `version_documento=1` y permite re-subir cualquier tipo (hueco del ítem 8).
- Tabla `notificaciones` existe (id, usuario_id, titulo, mensaje, tipo, leida, fecha_envio, created_at) sin RLS ni triggers ni UI.

## Tareas

### 1. Migración `supabase/migrations/20260818000000_compliance_especialista.sql`
- [x] RLS `notificaciones`: `notificacion_own_select` + `notificacion_admin_all`; índice `(usuario_id, leida)`.
- [x] Función `public.cumple_requisitos_habilitacion(p_especialista uuid) returns boolean`.
- [x] Trigger `trg_validar_habilitacion_especialista` (BEFORE UPDATE `especialistas`): bloquea `estado_verificacion='APROBADO'` sin expediente completo (ítem 10).
- [x] Extender `proteger_verificacion_especialista`: dueño solo `disponible=true` si `APROBADO` y `activo` (ítem 14).
- [x] Extender `proteger_revision_documento` (INSERT dueño): bloquear si existe `APROBADO`/`PENDIENTE` del mismo tipo; permitir solo primera carga o re-subida de `RECHAZADO` (ítem 8).
- [x] Triggers de notificación: `documentos_especialista`→`RECHAZADO` y `especialistas`→`APROBADO` insertan en `notificaciones` (SECURITY DEFINER) (ítem 13).
- [x] Endurecer `aceptar_solicitud` con `cumple_requisitos_habilitacion` (ítems 12/14).

### 2. App — ítem 8 (recargar solo rechazado)
- [x] `subirDocumento`: `version_documento = MAX(version_documento)+1` por `(especialista, tipo)`.
- [x] `specialist_documents_screen.dart`: tiles por requisito con estado real (Aprobado/Rechazado+motivo+Reintentar/Pendiente) y re-subida solo del tipo rechazado.
- [x] `documentos_section.dart` (home): "Subir" solo tipos sin doc APROBADO; ocultar al estar verificado.
- [x] Helper `tieneDocumentosAprobadosRequeridos(docs)` en `documentos_requeridos.dart`.

### 3. App — ítems 9/10 (expediente + Verificado gated)
- [x] Helper `expediente_compliance.dart`: checklist booleana + `cumple`.
- [x] `admin_dashboard_screen.dart`: checklist en la card y "Aprobar" deshabilitado hasta cumplir (carga de contratos y conteo de especialidades por especialista en `loadAllEspecialistas`).
- [x] Home especialista: banner de estado del expediente (qué falta).

### 4. App — ítem 13 (notificaciones in-app)
- [x] Módulo `lib/features/notifications/` (datasource, model, entity, repo, usecases, cubit).
- [x] UI: campanita con badge + `notifications_screen.dart`; ruta `/specialist/notificaciones`.
- [x] DI + router.

### 5. App — ítems 12/14 (Marketplace + disponibilidad)
- [x] `DisponibilidadCard`: toggle bloqueado con aviso si no está verificado (+ test actualizado).

### 6. Verificación
- [x] `flutter analyze` sin issues.
- [x] `flutter test` en verde (81/81).
- [x] Aplicar migración con `supabase db push` (confirmación usuario) — aplicada en remoto.

## Fuera de alcance
- Push FCM (edge function/webhook) para notificaciones.
- Convertir buckets públicos restantes a privados.