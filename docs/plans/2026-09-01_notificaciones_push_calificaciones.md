# Plan: Notificaciones Push y Sistema de Calificaciones

| | |
|---|---|
| **Fecha** | 2026-09-01 |
| **Estado** | APROBADO por el usuario (2026-09-01) |
| **Proyecto Supabase** | `hhyjremkguvphmjuaazp` |
| **Decisiones tomadas** | (1) Actividad 7 (recordatorio previo a cita) se **documenta como fuera de alcance** (requeriría `pg_cron`/edge scheduling; queda anotada como pendiente futuro). (2) Calificaciones: **una sola tabla** `evaluaciones_servicio` **bidireccional** (columna `evaluador_id` + un evaluado por fila, paciente→especialista o especialista→paciente). (3) Promedio en Marketplace: se muestra **solo en la hoja de detalle del especialista del mapa** (no en marcadores) y en el perfil del especialista. |

## Contexto

De las 15 actividades del módulo "Notificaciones Push y Sistema de Calificaciones", la auditoría encontró:

- **Implementado**: infraestructura FCM (`send-push` HTTP v1 con service account), registro de dispositivos (`dispositivos_usuario` + `FcmTokenService`), notificaciones por cambios de estado de cita (`notificar_cambio_estado_cita`), aviso a especialistas perdedores (`notificar_solicitud_asignada_push`), helper `notificar_usuario_push` (in-app + push) usado por los 4 RPCs de pago.
- **Gap logout**: `deactivateFcmToken` nunca se llama al cerrar sesión → dispositivos huérfanos.
- **NO existe**: push a especialistas de solicitud nueva en su zona (act 4), notif al paciente cuando acepta (act 5), push FCM en rechazo de documento / verificación aprobada (act 8, solo in-app), y TODO el sistema de calificaciones (act 9-14): la tabla `evaluaciones_servicio` existe en remoto (RLS sin policies, 0 filas) pero sin migración versionada, sin RPC de escritura ni código Flutter.
- **Recordatorio previo a cita** (act 7): requiere `pg_cron`/scheduler — **fuera de alcance** (documentado).

## Actividades → implementación

### A. Migración `supabase/migrations/20260901000400_calificaciones_servicio.sql`

- [x] A1. Adaptar `evaluaciones_servicio` a modelo **bidireccional**: `evaluador_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE`, `evaluado_especialista_id uuid NULL REFERENCES especialistas(id) ON DELETE CASCADE`, `evaluado_paciente_id uuid NULL REFERENCES pacientes(id) ON DELETE CASCADE`, `puntuacion integer NOT NULL CHECK 1..5`, `comentario text NULL`, `created_at`. CHECK exactamente un evaluado. `UNIQUE (cita_id, evaluador_id)` (una evaluación por participante y cita).
- [x] A2. RLS: `evaluacion_public_select` (SELECT TO authenticated USING true) + `evaluacion_admin_all` (FOR ALL is_administrador). Escritura solo vía RPC.
- [x] A3. RPC `registrar_evaluacion(cita_id, puntuacion, comentario)` SECURITY DEFINER: valida cita FINALIZADA (no evaluar antes), rol del auth.uid() (paciente→especialista de la cita; especialista dueño→paciente de la solicitud), idempotencia `YA_EVALUADO`, puntuación 1..5.
- [x] A4. RPC `get_promedio_especialista(especialista_id)` re-creado → `json {promedio, total}` (el original retornaba NUMERIC y nadie lo usa).
- [x] A5. GRANT EXECUTE de ambos RPCs a `authenticated`.
- [x] A6. Migración `20260901000600_limpiar_constraints_evaluaciones_legacy.sql`: elimina las constraints legacy del remoto (`fk_evaluaciones_servicio_cita`, `fk_evaluaciones_servicio_paciente`, `evaluaciones_servicio_cita_id_key` UNIQUE en cita_id, `chk_evaluaciones_puntuacion_rango`) que bloquearían 2 evaluaciones por cita. Aplicada al remoto.

### B. Migración `supabase/migrations/20260901000500_push_solicitudes.sql`

- [x] B1. Trigger `trg_notificar_solicitud_publicada` (AFTER UPDATE OF estado WHEN PUBLICADA) → notificar a especialistas APROBADOS/activos dentro del radio (geo query de `aceptar_solicitud`) con `notificar_usuario_push`.
- [x] B2. `aceptar_solicitud`: notificar al paciente "Solicitud aceptada" al crear la cita PROGRAMADA.
- [x] B3. `notificar_documento_rechazado` y `notificar_verificacion_aprobada`: pasar a `notificar_usuario_push` (añade push FCM).

### C. Actividad 7 — fuera de alcance

- [x] C1. Documentar en el plan que el recordatorio previo a cita requiere `pg_cron`/scheduling y queda pendiente.

### D. Feature `lib/features/calificaciones/`

- [x] D1. Entidad `EvaluacionEntity` + `PromedioEspecialistaEntity{promedio, total}`.
- [x] D2. Datasource `CalificacionesSupabaseDataSource` (rpc `registrar_evaluacion`, rpc `get_promedio_especialista`).
- [x] D3. Repositorio + interfaz (`Either<Failure,T>`), usecases `RegistrarEvaluacion` / `GetPromedioEspecialista`.
- [x] D4. DI en `injection.dart` + constantes RPC en `app_constants.dart`.
- [x] D5. Widget `rating_dialog.dart` (estrellas 1-5 + comentario).

### E. Integración UI

- [x] E1. Paciente: `mis_solicitudes_screen.dart` — `citaId` + `yaEvaluado` en modelo/entidad, select con `citas(id, estado, fecha_aceptacion, evaluaciones_servicio(id))`, botón "Calificar especialista" cuando FINALIZADA y sin evaluar.
- [x] E2. Especialista: `cita_detalle_screen.dart` — botón "Calificar paciente" en estado finalizada.
- [x] E3. Marketplace/perfil: `fetchEspecialistasAprobados` añade `evaluaciones_servicio(puntuacion)`; promedio en hoja de detalle del especialista del mapa (sheet `_EspecialistaDetailSheet`) y en `specialist_profile_screen.dart` (`_calificacionRow`).

### F. Optimización logout

- [x] F1. `FcmTokenService.deactivateCurrentDevice()` y llamarlo en `AuthCubit.signOut()` antes de `signOut()` del repositorio; inyectar `FcmTokenService` en `AuthCubit` (DI: `AuthCubit(sl<IAuthRepository>(), sl<FcmTokenService>())`).

### G. Verificación

- [x] G1. `flutter analyze` 0 issues + `flutter test` 366/366.
- [x] G2. Migraciones 00400/00500/00600 aplicadas al remoto (node pg, orden ascendente) y verificadas: policies `evaluacion_public_select`/`evaluacion_admin_all` (RLS enabled), constraints (sin legacy), funciones `registrar_evaluacion`/`get_promedio_especialista`/`notificar_solicitud_publicada_especialistas`/`aceptar_solicitud`/`notificar_documento_rechazado`/`notificar_verificacion_aprobada`, trigger `trg_notificar_solicitud_publicada`, `aceptar_solicitud` contiene `notificar_usuario_push` + `SOLICITUD_ACEPTADA`.
- [x] G3. Pruebas BD simuladas (ROLE authenticated + `request.jwt.claim.sub`/`request.jwt.claims`, transacción ROLLBACK): paciente califica OK → `{ok:true, evaluacion_id}`; repetir → `YA_EVALUADO`; `get_promedio_especialista` → `{promedio:5, total:1}`; especialista califica paciente OK (bidireccional); admin no participante → `NO_AUTORIZADO`; puntuación 6 → `PUNTUACION_INVALIDA`. Conteo final 0 (ROLLBACK correcto). Nota técnica: el `sub` de los claims debe resolverse como superusuario antes de `SET LOCAL ROLE` (bajo RLS del rol autenticado el subquery devuelve NULL → `NO_AUTENTICADO`).
- [x] G4. Plan actualizado con checkpoints `[x]`.

## Notas

- Actividad 7 (recordatorio previo a cita): **fuera de alcance**. Requeriría `pg_cron` (`cron.schedule`) o una edge function programada; se documenta como pendiente futuro en AGENTS.md.
- El especialista NO cambia estados ni registra pagos desde calificaciones; solo califica al paciente post-servicio.
- `evaluaciones_servicio` ya existe en remoto (creada por SQL Editor, vacía, RLS sin policies); la migración la versiona y habilita sin perder datos (0 filas).
- Patrón de errores `Either<Failure,T>` y cubits inyectando usecases por nombre.