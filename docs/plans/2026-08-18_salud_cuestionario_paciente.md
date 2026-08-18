# Plan: Salud, Cuestionario y Validación del Paciente

Fecha: 2026-08-18
Estado: aprobado

## Objetivo

Cerrar el flujo de salud del paciente: registro/perfil con info básica, cuestionario
real de salud (configurable en BD con versiones), almacenamiento de respuestas con
versión conservada, evaluación con resultado/riesgos, validación de telemedicina con
fechas de aprobación/vencimiento, gate RN-020 a nivel BD y consulta de estado de salud.
Mejorar lo existente (flujo legacy en `SupabaseService`, pantalla de prueba con
preguntas hardcodeadas, tablas sin RLS) siguiendo Clean Architecture.

## Decisiones tomadas

- Un solo cuestionario real de salud (semilla en BD). Estructura BD/código lista para
  más cuestionarios en el futuro.
- Versión por edición: nueva fila `cuestionarios` con mismo `nombre`, `version+1`,
  `activo=true`; la anterior queda `activo=false`. Las evaluaciones conservan
  `version_cuestionario` y un snapshot del texto de la pregunta.
- Qualify: se mantiene la simulación (delay 3s) pero se persisten
  `fecha_validacion`/`fecha_vencimiento` (+365 días), `proveedor`, `codigo_referencia`
  y estado real. Integración con API real queda fuera de alcance.
- RN-020 reforzado con trigger en BD (configurable vía `configuracion_sistema.enforce_rn020`)
  + validación en la capa de aplicación.

## Estado detectado

- [x] `handle_new_user` crea `profiles` + `pacientes` al registrarse (mejora: añadir campos clínicos).
- [x] Tablas BD de salud existen pero SIN RLS (hueco de seguridad).
- [x] Flujo health/validación vive en el monolito legacy `SupabaseService` (deuda).
- [x] `PatientQuestionnaireScreen` con preguntas hardcodeadas y Qualify simulado.
- [x] Entidades de dominio huérfanas sin models ni datasource.
- [x] `fetchQuestionnaireQuestions` roto: selecciona `preguntas.opciones` inexistente.

## Fases y checkpoints

### F1 — Migración BD `20260818000300_salud_cuestionario_paciente_rls.sql`
- [x] RLS en `cuestionarios`, `preguntas`, `cuestionario_preguntas`, `servicio_cuestionarios`,
      `evaluaciones_salud`, `respuestas_salud`, `validaciones_telemedicina`.
      Admin full CRUD; authenticated SELECT en catálogo; paciente INSERT+SELECT propias.
- [x] Columnas: `preguntas.opciones jsonb`, `preguntas.riesgo jsonb`,
      `respuestas_salud.pregunta_texto`, `pacientes.fecha_nacimiento/genero/grupo_sanguineo/alergias/antecedentes`,
      `evaluaciones_salud.resultado` + `riesgos jsonb`, constraint `(nombre, version)` en `cuestionarios`.
- [x] Índices en `evaluaciones_salud(paciente_id, created_at)` y
      `validaciones_telemedicina(paciente_id, created_at)`.
- [x] Trigger RN-020 en `solicitudes` (config-gated) que bloquea INSERT si el servicio
      `requiere_telemedicina` y no hay validación APROBADA vigente.
- [x] Seed del cuestionario real de salud (preguntas médicas + `cuestionario_preguntas`
      + vínculo `servicio_cuestionarios`).
- [ ] Aplicar migración al remoto (`supabase db push`) — diferido hasta terminar refactor Dart.

### F2 — Clean Architecture en `patients_compliance` (patrón `marketplace_citas`)
- [x] Datasource `PatientsComplianceSupabaseDataSource`.
- [x] Models: Paciente, Cuestionario, Pregunta (mapeo `tipo_respuesta_enum`↔enum Dart),
      CuestionarioPregunta, EvaluacionSalud, RespuestaSalud, ValidacionTelemedicina.
- [x] `PatientsComplianceRepositoryImpl(datasource)` con `Either<Failure,T>` (reemplaza const stub).
- [x] Usecases y cubits (`PatientHealthCubit`, `AdminCuestionarioCubit`).
- [x] Motor de reglas en dominio (sentinelas `riesgo` → `riesgos`/`resultado`) — autoridad en RPC BD.
- [x] Actualizar `injection.dart` (datasource, repo, usecases, cubits).

### F3 — Flujo paciente en Flutter
- [x] Refactor `PatientQuestionnaireScreen` con preguntas reales del DB y render por `tipo_respuesta`.
- [x] `CompleteProfileScreen`: fecha_nacimiento/género + uso de usecases.
- [x] Nueva `EstadoSaludScreen` (requisito 13) + rutas + enlace desde menú paciente.
- [x] Dictamen Qualify con fechas reales (fecha_validacion + fecha_vencimiento).
- [x] `ServicesDashboardScreen` usa `ValidarAccesoRN020` (capa limpia).

### F4 — Admin mínimo (requisitos 3-5 y 14)
- [x] Ruta `/admin/cuestionario` desde AdminDashboard: ver versión activa e histórico,
      editar preguntas, crear nueva versión, activar versión.

### F5 — Pruebas (requisitos 14-15)
- [x] Unit: motor de reglas (sentinelas → resultado) y models/enum mapping
      (`test/patients_compliance/patients_compliance_test.dart`, 14 casos).
- [x] Seed SQL con 2 versiones del cuestionario (`supabase/seed_cuestionario_2_versiones.sql`).
- [x] Checklist manual E2E en `docs/Pruebas manuales/07_patients_compliance.md`.
- [x] `flutter analyze` (0 issues) + `flutter test` (95/95 verde).

## Riesgos / notas

- Trigger RN-020 puede chocar con seeds/flows de prueba → configurable (`enforce_rn020`).
- `preguntas.opciones` se agrega para dejar consistente el select del legacy.
- Face map / geocoding quedan temporalmente en `SupabaseService` (deuda marcada, fuera de alcance).