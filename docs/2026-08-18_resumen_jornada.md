# Resumen de jornada — 2026-08-18

- **Fecha**: 2026-08-18
- **Rama**: `main`.
- **Flutter**: SDK **3.44.9** (sin cambios hoy).

Un ciclo grande hoy: **compliance del especialista de extremo a extremo** — expediente habilitante, aprobación gated (admin) y notificaciones in-app. Plan en `docs/plans/2026-08-18_compliance_especialista_expediente_notificaciones.md` (APROBADO por el usuario, ítems 4–14 de la lista de actividades compliance).

| Ciclo | Estado | Commit |
|---|---|---|
| 1. Compliance especialista: expediente + Verificado gated + notificaciones in-app | ✅ A pushear | *pendiente* |

---

## 1. Compliance especialista — expediente habilitante, aprobación gated y notificaciones in-app

**Contexto**: los ítems 4–7 (estados por documento, consulta admin, revisión con fecha/admin, rechazo con motivo) y el ítem 11 (firma de contrato) ya estaban implementados. Hoy se cerraron los huecos restantes (ítems 8, 9, 10, 12, 13, 14): el ciclo completo de **subida → revisión → feedback → reenvío**, el expediente habilitante y las notificaciones.

**Definición de expediente habilitante (confirmada por el usuario)** = 3 documentos APROBADOS (identificación, licencia y formación = diploma|certificación) + datos profesionales (médico regente activo + ≥1 especialidad) + **contrato firmado** antes de Verificado. El admin solo puede aprobar cuando el expediente está completo; el especialista solo puede operar (disponibilidad/marketplace) después.

### Migración `supabase/migrations/20260818000000_compliance_especialista.sql` (aplicada al remoto)

- **RLS `notificaciones`**: `notificacion_own_select` + `notificacion_own_update` (dueño) y `notificacion_admin_all` (rol Administrador, FOR ALL); índice `(usuario_id, leida)`.
- **Función `public.cumple_requisitos_habilitacion(p_especialista)`** → boolean: define el expediente habilitante (docs APROBADOS + médico regente activo + ≥1 especialidad + contrato firmado).
- **Trigger `trg_validar_habilitacion_especialista`** (BEFORE UPDATE de `estado_verificacion`): bloquea pasar a `'APROBADO'` sin expediente completo, **incluso para admin** (ítem 10).
- **`proteger_verificacion_especialista` extendido** (ítem 14): el dueño puede alternar `disponible`, pero activarlo a `true` exige `estado_verificacion='APROBADO'` y `activo`; la aprobación/rechazo/bloqueo sigue reservada al admin.
- **`proteger_revision_documento` extendido** (ítem 8): el especialista solo puede registrar `PENDIENTE`/`activo=true` como primera carga o re-subida de un tipo **RECHAZADO**; bloqueado duplicar un tipo APROBADO o apilar PENDIENTES del mismo tipo. Revisión (estado/observación/revisado_por/fecha/activo) sigue solo-admin.
- **Triggers de notificación (SECURITY DEFINER)** (ítem 13): `trg_notificar_documento_rechazado` (documento → RECHAZADO, con el motivo en el mensaje y versión) y `trg_notificar_verificacion_aprobada` (especialista → APROBADO) insertan en `notificaciones`.
- **`aceptar_solicitud` endurecida** (ítems 12/14, defensa en profundidad): valida `estado_verificacion='APROBADO'` + `activo` + `cumple_requisitos_habilitacion(id)` antes del claim atómico; motivo `NO_APROBADO` si no.

### App — ítem 8 (re-subida solo de rechazado)

- `subirDocumento`: `version_documento = MAX(version_documento)+1` por `(especialista, tipo)` (helper `_siguienteVersionDocumento`), no siempre 1.
- `specialist_documents_screen.dart`: tiles por requisito con estado real — **Aprobado** (no re-subible), **Rechazado** (motivo + botón "Reintentar" que fuerza ese tipo), **En revisión** (esperando al admin) y **Pendiente** (adjuntar; selector de alternativa solo si aplica).
- `documentos_section.dart` (home): "Subir" solo muestra tipos sin documento APROBADO (`tiposSubiblesDocumentos`) y se oculta al estar verificado.
- Helpers en `documentos_requeridos.dart`: `tieneDocumentosAprobadosRequeridos` y `tiposSubiblesDocumentos`.

### App — ítems 9/10 (expediente + Verificado gated)

- Helper `expediente_compliance.dart`: `ExpedienteEspecialista` con checklist booleana (`documentosAprobados`, `medicoRegenteActivo`, `tieneEspecialidades`, `contratoFirmado`), `cumple` y `pendientes`.
- `admin_dashboard_screen.dart`: checklist "Expediente" en cada card del especialista (carga contratos y conteo de especialidades por especialista en `loadAllEspecialistas`) y botón **"Aprobar" deshabilitado** con aviso de qué falta cuando `expediente.cumple == false`.
- `specialist_home_screen.dart`: card "Tu expediente de verificación" con checklist y pendientes para el especialista; card verde "Expediente completo" si ya está verificado.

### App — ítem 13 (notificaciones in-app)

- Módulo completo `lib/features/notifications/` en Clean Architecture: datasource, model, entity, repositorio (`INotificationsRepository` + impl), usecases (`GetNotificaciones`, `MarcarNotificacionLeida`, `MarcarTodasLeidas`) y `NotificationsCubit` (estados Initial/Loading/Loaded/Error, `noLeidas`, `markRead`, `markAllRead`; guard `isClosed` como el resto de cubits singleton).
- UI: `NotificacionesBell` (campanita con `Badge` de no leídas) en el AppBar del home del especialista + `notifications_screen.dart` (lista, marcar leída, marcar todas). Ruta `/specialist/notificaciones`.
- DI (`_registerNotifications`) + router (`BlocProvider<NotificationsCubit>.value`, mismo patrón singleton que el resto).

### App — ítems 12/14 (marketplace + disponibilidad)

- `DisponibilidadCard`: nuevo parámetro `habilitado`; toggle bloqueado (`onChanged: null`) con aviso "Disponible solo cuando estés verificado" si no lo está (+ test actualizado y nuevo test del switch bloqueado).

**Verificación**: `flutter analyze` sin issues; `flutter test` en verde (81/81); migración aplicada al remoto con `supabase db push` (confirmación del usuario).

---

## Verificación transversal

- `flutter analyze` → sin issues.
- `flutter test` → 81/81 OK.
- BD: migraciones aplicadas al remoto hasta `20260818000000` compliance especialista.

### Working tree actual
- Todo el trabajo del día queda commiteado/pusheado en este ciclo para seguir en laptop.

### Pendientes documentados
- Push FCM (edge function/webhook) para notificaciones — **fuera de alcance** de esta iteración (solo in-app).
- Convertir buckets aún públicos (`contratos`, `firmas`, `fotografias-tratamiento`) a privados — pendiente de otro ciclo.
- Versionar tablas creadas a mano en el dashboard (`disponibilidad_especialista`, `ubicaciones_especialista`, `contratos`) — pendiente de otro ciclo.
