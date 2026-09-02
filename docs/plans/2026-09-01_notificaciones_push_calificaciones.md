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

### C. Actividad 7 — Recordatorio previo a cita (implementado)

- [x] C1. Migración `20260901000700_recordatorios_cita.sql`: seed `recordatorio_horas_previas`,
      tabla `recordatorios_cita`, función `enviar_recordatorios_cita()` (SECURITY DEFINER),
      `CREATE EXTENSION IF NOT EXISTS pg_cron` + job `recordatorios-cita` (`*/15 * * * *`).
      Aplicada al remoto y verificada (cron.job, notif `RECORDATORIO_CITA` en simulación P6).

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

- El especialista NO cambia estados ni registra pagos desde calificaciones; solo califica al paciente post-servicio.
- `evaluaciones_servicio` ya existe en remoto (creada por SQL Editor, vacía, RLS sin policies); la migración la versiona y habilita sin perder datos (0 filas).
- Patrón de errores `Either<Failure,T>` y cubits inyectando usecases por nombre.

## Complemento (misma fecha) — Recordatorio previo a cita (Actividad 7) IMPLEMENTADO

Inicialmente se documentó la actividad 7 como **fuera de alcance**. Por decisión del
usuario se implementó con `pg_cron` (extensión disponible en el remoto, no instalada):
migración `20260901000700_recordatorios_cita.sql`:

- Seed `configuracion_sistema.recordatorio_horas_previas` = `'2'` (NUMERIC) — horas previas
  a la cita en las que se dispara el recordatorio.
- Tabla `public.recordatorios_cita` (cita_id PK REFERENCES citas ON DELETE CASCADE,
  fecha_envio) + RLS con policy SELECT admin → **idempotencia** (un solo recordatorio por cita).
- Función `public.enviar_recordatorios_cita()` SECURITY DEFINER: recorre citas
  `estado='PROGRAMADA'` con `fecha_inicio` dentro de la ventana `(now(), now()+horas]`
  y sin registro previo; notifica al paciente con `notificar_usuario_push`
  (`RECORDATORIO_CITA`) y registra la cita en `recordatorios_cita`.
- `CREATE EXTENSION IF NOT EXISTS pg_cron` + job `cron.schedule('recordatorios-cita',
  '*/15 * * * *', SELECT public.enviar_recordatorios_cita())` (idempotente).
- GRANT EXECUTE a `authenticated`. Aplicada al remoto y verificada (cron.job presente).

## Pruebas de control P1-P13 (verificadas en BD, script verify_control_push_calif.js)

Ejecutadas con transacciones ROLLBACK + `SET LOCAL ROLE authenticated` y claims JWT
(`request.jwt.claim.sub` + `request.jwt.claims`), resolviendo el `sub` como superusuario
antes de cambiar de rol (bajo RLS el subquery devuelve NULL → `NO_AUTENTICADO`). Nota:
`SET LOCAL ROLE` persiste en la transacción; usar `SET LOCAL ROLE postgres` antes de
consultas superuser (los SELECT de notificaciones de otro usuario dan 0 filas bajo
`notificacion_own_select`). **Resultado: 13/13 PASS, sin residuos.**

| # | Prueba | Resultado | Detalle |
|---|--------|-----------|---------|
| P1 | El dispositivo queda registrado | **PASS** | INSERT en `dispositivos_usuario` (usuario_id, token_fcm, plataforma 'WEB', activo) + SELECT propio OK (RLS `dispositivo_own_access`). |
| P2 | Push en dispositivos reales | **MANUAL** | Requiere dispositivo físico + Firebase. Infraestructura verificada: `send-push` (JWT RS256), config `push_notifications`/`edge_function_base_url`/`anon_key`, policies `dispositivos_usuario`. |
| P3 | Especialista recibe solicitud en su zona | **PASS** | Solicitud PUBLICADA con dirección geo → trigger `trg_notificar_solicitud_publicada` genera `SOLICITUD_NUEVA` a 2 especialistas APROBADOS en radio. |
| P4 | Paciente recibe confirmación al aceptar | **PASS** | `aceptar_solicitud` OK → notif `SOLICITUD_ACEPTADA` al paciente (1). |
| P5 | Notif de desplazamiento/llegada | **PASS** | UPDATE cita `EN_CAMINO` y `LLEGO` como especialista dueño → 2 notif `CITA_ESTADO` al paciente (trigger `trg_notificar_cambio_estado_cita`). |
| P6 | Recordatorios previos a cita | **PASS** | `fecha_inicio=now()+30min` en cita PROGRAMADA → `enviar_recordatorios_cita()` → notif `RECORDATORIO_CITA` (1) + fila en `recordatorios_cita` + cron.job activo. |
| P7 | Aviso de documento rechazado | **PASS** | UPDATE `documentos_especialista` a `RECHAZADO` como admin → notif `DOCUMENTO_RECHAZADO` al especialista (1). |
| P8 | Paciente califica al especialista | **PASS** | `registrar_evaluacion` (cita 85e1d764, 5★) → `{ok:true, evaluacion_id}`. |
| P9 | Especialista califica al paciente | **PASS** | `registrar_evaluacion` como especialista de la cita (4★) → `{ok:true}` (bidireccional). |
| P10 | No calificar antes de finalizar | **PASS** | Sobre cita PROGRAMADA → `{ok:false, motivo:'CITA_NO_FINALIZADA'}`. |
| P11 | No segunda calificación | **PASS** | Tras P8, repetir → `{ok:false, motivo:'YA_EVALUADO'}`. |
| P12 | Evaluaciones vinculadas a la cita | **PASS** | Fila con `cita_id`/`evaluador_id` correctos; UNIQUE `(cita_id, evaluador_id)` y FKs presentes. |
| P13 | Consulta de calificaciones acumuladas | **PASS** | `get_promedio_especialista` → `{promedio:5, total:1}`. |

P2 queda **pendiente de prueba manual** en un dispositivo real (ningún `dispositivos_usuario`
activo en BD; la entrega FCM real requiere dispositivo + Firebase).