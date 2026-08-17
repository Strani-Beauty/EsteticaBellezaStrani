# Plan: Documentos de Compliance + Storage privado

| | |
|---|---|
| **Fecha** | 2026-08-17 |
| **Origen** | Solicitud del usuario: desarrollar sección de Documentos de Compliance (visualizar requeridos y estado), subida por Supabase Storage PRIVADO, y permitir cargar inicialmente identificación, licencia y diploma/certificación. |
| **Estado** | APROBADO por el usuario (2026-08-17) — incluye aplicar la migración al remoto con `supabase db push`. |
| **Proyecto Supabase** | `hhyjremkguvphmjuaazp` (bellezastrani@gmail.com). |

## Contexto verificado en el código

- El especialista ya ve el estado de sus documentos en `DocumentosSection` (panel, `specialist_home_screen.dart:161`) y el admin los revisa en `admin_dashboard_screen.dart` (`_DocumentoFila`, aprobar/rechazar).
- La subida real ya existe (`SpecialistsCubit.uploadDocument` → `subirDocumento`) pero el bucket es **PÚBLICO**: `subirDocumento` guarda `url_archivo` con `getPublicUrl` y existe la policy `documento_storage_public_select`.
- Documentos requeridos hoy: solo `[identificacion, licencia]` en `specialist_documents_screen.dart:32` y `specialist_home_screen.dart:118`.
- El botón "Subir" de `DocumentosSection` solo **registra** el tipo sin archivo (`registerDocument`, fila PENDIENTE sin adjunto).
- El enum `TipoDocumento` ya incluye `diploma` y `certificacion`; `EstadoRevisionDocumento` tiene pendiente/aprobado/rechazado.
- Migración del bucket original: `20260805000100_especialistas_documentos_storage.sql`.

## Decisiones (confirmadas por el usuario)

- Requeridos: **identificación, licencia profesional, formación profesional** — formación se cumple con **diploma O certificación** (uno solo).
- **Storage privado**: bucket `documentos-especialistas` → `public=FALSE`; `url_archivo` pasa a guardar el **path de storage**; la vista se hace con **URL firmada** (`createSignedUrl`, expiración 1h generada on-demand).
- **Migrar** las `url_archivo` existentes (URL pública → path) para conservar el historial visible.
- Botón "Subir" del panel → **subida real con archivo** (FilePicker) + botón "Ver" con URL firmada.
- Aplicar la migración al remoto con `supabase db push`.

## Tareas

### 1. Migración `supabase/migrations/20260817000000_documentos_storage_privado.sql`
- `storage.buckets`: `public = FALSE` para `documentos-especialistas` (idempotente `ON CONFLICT ... DO UPDATE`).
- `DROP POLICY "documento_storage_public_select"` (SELECT público).
- Nuevas políticas SELECT en `storage.objects`:
  - `documento_storage_own_select`: dueño (path `[1]` = id del especialista del usuario).
  - `documento_storage_admin_select`: rol Administrador.
- Migrar datos: `regexp_replace(url_archivo, '^.*/object/public/documentos-especialistas/', '')` sobre las filas cuya `url_archivo` contenga `/object/public/documentos-especialistas/` → queda el path `<especialistaId>/<ts>.<ext>`.

### 2. Capa de datos: firmar URLs
- Datasource `specialists_supabase_datasource.dart`:
  - `subirDocumento`: guardar `url_archivo: path` (quitar `getPublicUrl`).
  - Nuevo método `crearUrlFirmada(path)` → `createSignedUrl(path, expiresIn: 3600)`.
- `i_specialists_repository.dart` + `specialists_repository_impl.dart`: `generarUrlFirmadaDocumento(path) → Either<Failure, String>`.
- Nuevo usecase `GenerarUrlFirmadaDocumento` (junto a los de `get_documentos.dart`).
- `specialists_cubit.dart`: añadir usecase al constructor + método `generarUrlFirmadaDocumento(path) → Future<String?>` (emite `SpecialistsError` si falla).
- `injection.dart`: registrar el usecase en `SpecialistsCubit`.

### 3. Requeridos compartidos (identificación, licencia, formación diploma|certificación)
- Nuevo helper `lib/features/specialists/presentation/widgets/documentos_requeridos.dart` (o similar): lista de requisitos con alternativas (`diploma|certificacion`) + `tieneDocumentosRequeridos(docs)` + labels.
- `specialist_documents_screen.dart`: 3 tiles (Formación con selector Diploma/Certificación), labels nuevos, usar helper.
- `specialist_home_screen.dart:118`: `_tieneDocumentosRequeridos` usa el helper compartido.

### 4. UI de compliance + vista con URL firmada
- `documentos_section.dart`: "Subir" → FilePicker + `uploadDocument` (con elección de tipo, incl. diploma/certificación); botón "Ver" por documento → URL firmada + `launchUrl`.
- `admin_dashboard_screen.dart` `_abrirDocumento`: `urlArchivo` como path → URL firmada antes de `launchUrl`.

### 5. AGENTS.md
- Añadir sección "Rol de experto Senior en Flutter y Supabase": priorizar seguridad (RLS/storage privado/sin secretos), Clean Architecture, calidad, performance y buenas prácticas de Supabase.

### 6. Verificación
- `flutter analyze` sin issues; `flutter test` (placeholder, 80/80 en verde).
- Aplicar la migración al remoto con `supabase db push`.

## Fuera de alcance
- Convertir otros buckets públicos (`contratos`, `firmas`, `fotografias-tratamiento`) a privados.
- Renombrar la columna `url_archivo` (semántica = path; se mantiene el nombre para no churn de BD).

## Checklist
- [x] Plan persistido en `docs/plans/` (este archivo).
- [x] Migración `20260817000000_documentos_storage_privado.sql` creada (idempotente).
- [x] `subirDocumento` guarda path; `crearUrlFirmada` implementado.
- [x] Repositorio + usecase `GenerarUrlFirmadaDocumento` + registro en `injection.dart`.
- [x] `SpecialistsCubit.generarUrlFirmadaDocumento`.
- [x] Helper de requisitos compartido (formación = diploma|certificación).
- [x] `specialist_documents_screen.dart` con 3 requeridos y selector de formación.
- [x] `specialist_home_screen.dart` usa el helper.
- [x] `documentos_section.dart`: subida real con archivo + botón "Ver" (URL firmada).
- [x] `admin_dashboard_screen.dart`: `_abrirDocumento` con URL firmada.
- [x] AGENTS.md con el rol de experto.
- [x] `flutter analyze` sin issues.
- [x] `flutter test` en verde (80/80).
- [x] Migración aplicada con `supabase db push` (remoto en `20260817000000`).