# Plan — Entrevista médica F2F por videollamada (panel admin + paciente)

Fecha: 2026-09-24
Estado: APROBADO por el usuario (m0063: "aprobado"). Sin commit.

## Objetivo

Implementar la **entrevista face-to-face médico↔paciente por videollamada**:
un administrador con permiso nuevo `admin.entrevistas` **agenda** una cita con
fecha/hora, revisa la evaluación aplicada del paciente, conduce la entrevista por
**videollamada embebida (Jitsi iframe web)**, captura **notas/hallazgos +
consentimiento (firma) + grabación**, y emite el **dictamen del examen médico
total** (evaluación + entrevista). El paciente ve y se une a la entrevista desde
la app. Todo auditado (ePHI/HIPAA).

## Decisiones confirmadas

Ronda 1 (m0052):
1. Ejecuta la entrevista = **Admin con permiso nuevo** (rol Administrador + `admin.entrevistas`).
2. "Nueva ventana" = **nueva pantalla en el panel admin**.
3. Modalidad = entrevista por videollamada donde el médico evalúa y aprueba el
   **examen médico total** (evaluación médica + entrevista).
4. **Agenda con fecha/hora**.
5. Persistencia = **nueva tabla `entrevistas_medicas`**.

Ronda 2 (m0056):
1. Videollamada = **Jitsi embebido (iframe web)**.
2. **Sí**, pantalla del paciente para unirse.
3. **Sí**, guardar **grabación**.
4. **Sí**, recordatorios por **push FCM**.

Ronda 3 (m0059): por ahora **Jitsi público + subida directa**; se migra después
si es necesario.

## Aviso de cumplimiento (documentado a propósito)

Jitsi público (`meet.jit.si`) **no es apto para ePHI real** (sin BAA) y **no
ofrece grabación server-side**. La grabación se hará **localmente en el navegador
del médico** (MediaRecorder) y se subirá directo al bucket privado. Cuando se
requiera cumplimiento pleno, migrar a **Jitsi self-hosted + Jibri** (o JaaS con
BAA) y subida reanudable (tus). Deuda documentada.

## Fases

### [x] Fase 0 — Permiso RBAC + cierre de deuda de seguridad
`supabase/migrations/20260924000100_permiso_admin_entrevistas.sql`
- `INSERT permiso 'admin.entrevistas'` (`ON CONFLICT DO UPDATE`) + otorgamiento
  explícito al rol Administrador (el grant masivo `LIKE 'admin.%'` de
  `20260901000200` no aplica a migraciones posteriores).
- **Cerrar agujero**: `REVOKE EXECUTE ON FUNCTION public.registrar_validacion_telemedicina(bool,text,text) FROM authenticated, anon, PUBLIC`
  (hoy cualquier authenticated puede autodictaminarse). El dictamen pasa a ir
  solo por el RPC admin nuevo. Ningún widget la llama ya.

### [x] Fase 1 — Tabla `entrevistas_medicas` + RLS + trigger anti-tampering
`supabase/migrations/20260924000200_entrevistas_medicas.sql`
- Columnas: `id uuid PK`, `paciente_id→pacientes`, `evaluacion_salud_id→evaluaciones_salud`,
  `medico_id/agendada_por→profiles`, `fecha_programada timestamptz`, `duracion_min int default 30`,
  `estado text default 'PROGRAMADA'` (`PROGRAMADA|EN_CURSO|COMPLETADA|CANCELADA|NO_ASISTIO`),
  `sala_id text unique`, `notas_clinicas text`, `hallazgos text`,
  `consentimiento_telemedicina boolean default false`, `firma_consentimiento_url text`,
  `grabacion_url text`, `dictamen text` (`APTO|NO_APTO|REQUIERE_REVISION`),
  `dictamen_observaciones text`, `validacion_id→validaciones_telemedicina`,
  `iniciada_at/finalizada_at timestamptz`, `created_at/updated_at`.
- CHECKs idempotentes (`DO $$ ... pg_constraint ...`).
- Índices: `(paciente_id, fecha_programada DESC)`, `(estado, fecha_programada)`,
  `(medico_id, fecha_programada)`, unique `sala_id`.
- Trigger `updated_at` (patrón `trg_touch_respuesta_salud`).
- RLS: admin ALL (`is_administrador()`); paciente SELECT de la suya; UPDATE del
  paciente restringido por trigger `trg_proteger_entrevista` (solo
  `consentimiento_telemedicina`/`firma_consentimiento_url`), patrón `trg_proteger_*`.

### [x] Fase 2 — RPCs SECURITY DEFINER
`supabase/migrations/20260924000300_rpc_entrevistas_medicas.sql` (validan
`is_administrador() AND tiene_permiso('admin.entrevistas')`; la de consentimiento
valida al paciente dueño; todas auditan con `registrar_auditoria`):
- `agendar_entrevista(p_paciente_id, p_fecha_programada, p_duracion_min, p_evaluacion_salud_id)`
  → crea fila + `sala_id` + notifica al paciente (in-app+push).
- `iniciar_entrevista(p_entrevista_id)` → `EN_CURSO`, `iniciada_at`.
- `emitir_dictamen_entrevista(p_entrevista_id, p_aprobado, p_observaciones, p_hallazgos)`
  → `COMPLETADA`, upsert `validaciones_telemedicina` (`APROBADA/RECHAZADA`, +365d,
  proveedor `Medicina Interna`), `profiles.activo/evaluation_passed`, notifica,
  audita. **Desbloquea RN-020.**
- `registrar_consentimiento_entrevista(p_entrevista_id, p_firma_url)` (paciente dueño).
- `guardar_grabacion_entrevista(p_entrevista_id, p_path)` (admin).

### [x] Fase 3 — Storage privado
**Desviación aceptada**: un único bucket privado `entrevistas-medicas`
(`AppConstants.bucketEntrevistas`) sirve grabación (admin) y firma (paciente);
path `<entrevista_id>/<archivo>`.
`supabase/migrations/20260924000400_entrevistas_storage.sql`: políticas
`entrevista_storage_admin_insert/select/update` (`is_administrador()`) +
`entrevista_storage_paciente_insert/select` (foldername[1] = entrevista del
paciente autenticado).

### [x] Fase 4 — Recordatorios push
`supabase/migrations/20260924000500_recordatorios_entrevista.sql`: tabla
`recordatorios_entrevista` (unique `entrevista_id,tipo`), función
`enviar_recordatorios_entrevista()` (SECURITY DEFINER, `notificar_usuario_push` a
paciente y médico) y `cron.schedule('recordatorios-entrevista','*/15 * * * *', ...)`;
`REVOKE` de authenticated. Calca `20260901000700_recordatorios_cita.sql`.

### [x] Fase 5 — Capa de datos Flutter (`lib/features/medical_interviews/`)
- `data/`: datasource Supabase, `entrevista_medica_model.dart`, repo impl `Either<Failure,T>`.
- `domain/`: `EntrevistaMedicaEntity` + enums `EstadoEntrevista`/`DictamenEntrevista`
  (`toDb/fromDb`); `i_medical_interviews_repository.dart`; usecases `AgendarEntrevista`,
  `GetEntrevistas`, `GetMiEntrevista`, `IniciarEntrevista`, `EmitirDictamenEntrevista`,
  `RegistrarConsentimientoEntrevista`, `GuardarGrabacionEntrevista`.
- Patrón: `patients_compliance`.
- Implementado: datasource + repo impl + 9 usecases + registro DI. Además
  `GuardarNotasEntrevista`/`FirmarUrlEntrevista` (no listados en el plan original);
  notas se guardan por UPDATE directo (no hay RPC). Cubits en Fase 6/7.

### [x] Fase 6 — UI admin
- `admin_entrevistas_screen.dart`: agenda (lista por estado/fecha; pendientes de dictamen).
- `agendar_entrevista_screen.dart`: selector paciente + `showDatePicker`+`showTimePicker`
  (patrón `solicitud_resumen_screen.dart:68-89`).
- `entrevista_medica_detalle_screen.dart`: datos + evaluación aplicada (reusa
  `GetExpedienteSalud`/riesgos), widget `jitsi_meet_view.dart`
  (`HtmlElementView`+`platformViewRegistry`+`package:web`; `kIsWeb` con fallback
  `url_launcher`), notas/hallazgos, subida de grabación, `dictamen_dialog.dart`.
  Anteponer `confirmarAccesoExpediente(context)` (ePHI).
- Plantilla de detalle: `admin_expediente_salud_detalle_screen.dart`.

### [x] Fase 7 — UI paciente
- `mi_entrevista_screen.dart`: fecha/hora, estado, botón unirse (mismo widget Jitsi),
  consentimiento con firma (`SignatureController`, patrón `firma_consentimiento_screen.dart`).
- Ajustes: `services_dashboard_screen.dart:802`, `estado_salud_screen.dart:281`,
  `evaluacion_medica_aplicada_screen.dart` ("Qué sigue" → agendar/enlazar).

### [x] Fase 8 — Integración + DI
- `app_routes.dart`: `adminEntrevistas='/admin/entrevistas'` + detalle con `extra`;
  ruta de paciente en su área. Toda `/admin/...` auto-protegida (`route_guard.dart:107-110`).
- Tile `if (_tiene('admin.entrevistas'))` en `admin_dashboard_screen.dart`.
- Registro en `injection.dart` (datasource, repo, usecases, cubits).

### [ ] Fase 9 — Verificación
- [x] `flutter analyze` limpio.
- [x] `flutter test` (370, All tests passed!).
- [x] Aplicar migraciones por pooler en orden; verificar RLS/RPC/permiso. (5/5 aplicadas;
  permiso `admin.entrevistas` + grant Administrador; tabla `entrevistas_medicas`; 5 RPC F2F;
  bucket privado `entrevistas-medicas` + 5 policies; cron `recordatorios-entrevista` cada 15 min;
  `registrar_validacion_telemedicina` EXECUTE para authenticated = false.)
- [ ] Manual en `flutter run -d chrome`: agenda → push → ambos a Jitsi → consentimiento/
  firma → grabación → dictamen → RN-020 desbloqueado.

## Notas

- Sin commit (regla del proyecto: preguntar antes).
- La grabación es cliente-side (MediaRecorder); el video sube directo al bucket privado.
