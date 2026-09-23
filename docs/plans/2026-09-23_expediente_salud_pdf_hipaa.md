# Plan — Expediente de salud (ePHI/HIPAA) admin con exportación a PDF

Fecha: 2026-09-23
Estado: APROBADO por el usuario (m1863: "aprobado"). Sin commit.

## Objetivo

Vista en el Panel de administrador con la seguridad requerida en el ámbito de la
normativa HIPAA / Electronic Protected Health Information (ePHI), donde se pueda
visualizar el resultado del o los cuestionarios de cada paciente y transformarlo
a formato **.pdf** para imprimir o entregar a petición del usuario.

Decisiones confirmadas (m1860):
1. Acceso: **botón por fila** en la lista de pacientes (Admin → Pacientes) **y tile con buscador** en el panel admin.
2. Todas las **evaluaciones** del paciente (histórico cronológico), cada una con sus preguntas y respuestas.
3. **Auditoría** de acceso (EXPEDIENTE_SALUD_VISTO) y exportación (EXPEDIENTE_SALUD_PDF) en la tabla `auditoria` (RPC SECURITY DEFINER nuevo).
4. PDF con **expediente completo**: datos del paciente + clínicos + preguntas/respuestas + resultado/riesgos + validación médica + fecha de emisión/admin.

## Cambios

### 1. Migración `supabase/migrations/20260923000100_expediente_salud_auditoria.sql`
- RPC `registrar_auditoria_expediente(p_paciente_id uuid, p_accion text, p_detalle jsonb DEFAULT NULL)`:
  `SECURITY DEFINER`, `IF NOT public.is_administrador() THEN RAISE EXCEPTION`, llama al helper
  existente `registrar_auditoria(auth.uid(), p_accion, 'pacientes', p_paciente_id::text, p_detalle)`.
- `GRANT EXECUTE ON FUNCTION ... TO authenticated`.
- Aplicar por pooler (CLI da 401 sin supabase login).

### 2. `pubspec.yaml`
- Añadir `pdf` y `printing` (web: `Printing.layoutPdf` imprime vía navegador, `Printing.sharePdf` descarga).
- `flutter pub get`.

### 3. Capa de datos (`lib/features/patients_compliance/`)
**Datasource** `data/datasources/patients_compliance_supabase_datasource.dart` (métodos admin, reciben id explícito):
- `fetchPacienteExpediente(usuarioId)`: `pacientes` → `select('*, profiles(full_name, email, phone)')` `.eq('usuario_id', id).maybeSingle()`.
- `fetchEvaluacionesExpediente(pacienteId)`: `evaluaciones_salud` → `select('*, respuestas_salud(*), cuestionarios(nombre, version)')` `.eq('paciente_id', id)` `.order('created_at', desc)` (joins embebidos; RLS admin OK).
- `fetchValidacionExpediente(pacienteId)`: `validaciones_telemedicina` última (patrón `fetchMiValidacion`).
- `registrarAuditoriaExpediente({p_paciente_id, p_accion})`: `rpc('registrar_auditoria_expediente', ...)`.

**Entidades nuevas** (domain/entities/):
- `ExpedienteSaludEntity`: paciente (`PacienteEntity`), `fullName?/email?/phone?`, `List<EvaluacionExpedienteEntity>`, `ValidacionTelemedicinaEntity?`.
- `EvaluacionExpedienteEntity`: evaluación (`EvaluacionSaludEntity`), `cuestionarioNombre?/version?`, `List<RespuestaSaludEntity>`.
- Reutiliza `PacienteEntity` (getters `edad`), `EvaluacionSaludModel`/`RespuestaSaludModel`/`ValidacionTelemedicinaModel`
  (ya existen) y `RespuestaSaludEntity.valorLegible` + `respuesta.preguntaTexto` (snapshot).

**Repositorio** (`i_patients_compliance_repository.dart` + impl, Either/Failure):
- `getExpedienteSalud({required String usuarioId})` → `Future<Either<Failure, ExpedienteSaludEntity?>>`.
- `registrarAuditoriaExpediente({required String pacienteId, required String accion})` → `Future<Either<Failure, void>>`.

**Usecases** (domain/usecases/): `get_expediente_salud.dart` (`GetExpedienteSaludParams{usuarioId}`) y
`registrar_auditoria_expediente.dart` (`RegistrarAuditoriaExpedienteParams{pacienteId, accion}`).

### 4. Cubit `ExpedienteSaludCubit` (presentation/cubits/)
- Estados: `ExpedienteSaludInitial/Loading/Loaded{expediente}/Error{message}`.
- `cargarExpediente(usuarioId)`; `auditar(accion)` (fire-and-forget, no rompe carga).
- Inyecta `GetExpedienteSalud` y `RegistrarAuditoriaExpediente` por nombre.

### 5. UI (presentation/)
- **`screens/admin_expediente_salud_screen.dart`** (buscador): reusa `sl<AdminPacientesCubit>()`
  (`loadPacientes`) + `TextField` filtro local por nombre/email; ListView de pacientes;
  tap → `context.push(AppRoutes.adminExpedienteSaludPaciente, extra: paciente)`.
- **`screens/admin_expediente_salud_detalle_screen.dart`**:
  `ExpedienteSaludDetalleScreen({required PacienteAdminEntity paciente})`; initState
  `cargarExpediente(paciente.usuarioId)` + `auditar('EXPEDIENTE_SALUD_VISTO')`.
  Muestra card datos del paciente, card clínica (grupo sanguíneo, alergias, antecedentes),
  por evaluación: cabecera (cuestionario vX, fecha, badge resultado APTO/REQUIERE_REVISION/NO_APTO,
  riesgos chips), lista pregunta → respuesta legible; card validación médica.
  Botones **Imprimir** (`Printing.layoutPdf`) y **Descargar PDF** (`Printing.sharePdf`), ambos
  con `generarExpedientePdf(...)` y `auditar('EXPEDIENTE_SALUD_PDF')`.
- **`widgets/expediente_pdf.dart`**: `Future<Uint8List> generarExpedientePdf(ExpedienteSaludEntity)`
  con `pw.Document` + `MultiPage` Letter, fuentes Helvetica base; secciones: encabezado
  "MERAKI spa onsite · Expediente de Salud (ePHI)" + fecha emisión; datos del paciente; clínicos;
  por evaluación (preguntas/respuestas `valorLegible`, resultado, riesgos); validación;
  pie "Generado por {admin} · {fecha}" + aviso de confidencialidad HIPAA.
- **`screens/admin_pacientes_screen.dart`**: en `_PacienteTile` añadir `IconButton`
  (icono `folder_shared_rounded`, tooltip 'Expediente de salud') → push detalle (junto al Switch).

### 6. Rutas + panel + DI
- `app_routes.dart`: `adminExpedienteSalud='/admin/expediente-salud'`,
  `adminExpedienteSaludPaciente='/admin/expediente-salud/paciente'`; GoRoutes privadas.
  Lista con `BlocProvider<AdminPacientesCubit>`; detalle con `ExpedienteSaludDetalleScreen`.
- `admin_dashboard_screen.dart`: tile 'Expedientes de Salud' en sección Administrativo,
  `_tiene('admin.pacientes')`, icono `description_rounded`, `onTap: context.go(AppRoutes.adminExpedienteSalud)`.
- `injection.dart`: registrar `GetExpedienteSalud`, `RegistrarAuditoriaExpediente`, `ExpedienteSaludCubit`.

### Sin cambios
RLS (lectura admin ya cubre evaluaciones_salud, respuestas_salud, validaciones_telemedicina,
pacientes, profiles), flujos paciente, `preguntas`. El PDF no se persiste en storage (solo memoria).

## Verificación

- [x] `flutter analyze` limpio; `flutter test` (370, ALL PASSED).
- [x] Pooler: migración aplicada + RPC `registrar_auditoria_expediente` verificada.
- [x] Backfill `pregunta_texto` (0 vacíos de 148) + `updated_at` en `respuestas_salud` (migración 20260923000200).
- [ ] Manual: tile → buscador → detalle → imprimir/descargar PDF con datos reales; auditoría registra eventos.

## Notas

- Sin commit (regla del proyecto: preguntar antes).
- El generador de PDF es client-side (`pdf` + `printing`); el archivo solo existe en memoria
  del navegador admin al imprimir/descargar.