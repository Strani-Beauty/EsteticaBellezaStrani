# Plan: Ejecución del Tratamiento, Consentimiento y Face Map — cierre de gaps

| | |
|---|---|
| **Fecha** | 2026-08-25 |
| **Estado** | APROBADO por el usuario (2026-08-25) |
| **Proyecto Supabase** | `hhyjremkguvphmjuaazp` |
| **Decisiones tomadas** | (1) Firma y fotos a buckets privados con URLs firmadas. (2) Firma como primer paso obligatorio (tratamiento nace en `PENDIENTE_FIRMA`). (3) Face Map del especialista reutilizando el widget interactivo del paciente. (4) Unidad de producto sugerida por `tipo_precio` del servicio. |

## Contexto

Revisión de las 15 actividades del módulo **Ejecución del Tratamiento y Consentimiento**.
Resultado de la revisión:

| # | Actividad | Estado |
|---|-----------|--------|
| 1 | Crear tratamiento asociado a la cita al iniciar | ✅ IMPLEMENTADO |
| 2 | Validar cita en estado En sitio | ✅ IMPLEMENTADO |
| 3 | Consentimiento digital con firma desde la app | ✅ IMPLEMENTADO |
| 4 | Almacenar firma + fecha/relación | ⚠️ DEUDA (bucket público + URL pública) |
| 5 | Impedir iniciar sin consentimiento | ❌ NO IMPLEMENTADO |
| 6 | Captura de fotos pre desde la app | ❌ NO IMPLEMENTADO (solo "por URL"; sin `image_picker`) |
| 7 | Almacenamiento privado de fotos | ❌ NO IMPLEMENTADO (sin migración/RLS, URLs públicas) |
| 8 | Validar ≥1 foto previa antes de avanzar | ❌ NO IMPLEMENTADO |
| 9 | Pantalla Face Map del especialista | ❌ NO IMPLEMENTADO |
| 10 | Observaciones/notas del especialista | ✅ IMPLEMENTADO |
| 11 | Productos aplicados | ✅ IMPLEMENTADO |
| 12 | Cantidad con unidad del servicio | ⚠️ PARCIAL (unidad texto libre) |
| 13 | No cerrar sin info mínima | ⚠️ PARCIAL (solo saldo bloquea) |
| 14 | Pruebas del flujo completo | ⚠️ PARCIAL (E2E no cubre firma/fotos/productos) |
| 15 | Vinculación cita→tratamiento→consentimiento→fotos→productos | ✅ IMPLEMENTADO (datos; sin E2E) |

## Decisiones

1. **Almacenamiento privado**: buckets `firmas-consentimiento` y `fotografias-tratamiento`
   pasan a `public=FALSE`; se elimina la lectura pública; se agregan policies de SELECT
   por dueño (especialista vía tratamiento) y administrador; las filas guardan el **path**
   y se sirven con `createSignedUrl(path, 3600)` (patrón `20260817000000_documentos_storage_privado.sql`).
2. **Act. 5 — Firma como primer paso**: al pulsar "Iniciar servicio" se crea el tratamiento
   en `PENDIENTE_FIRMA` (enum ya existe en BD) y se abre la firma. Evaluación, productos,
   fotos y finalización quedan bloqueados hasta firmar. Tras firmar, el tratamiento pasa a
   `EN_PROCESO`. La firma necesita `tratamiento_id` (FK) → se captura después de crear el
   tratamiento; no rompe la FK.
3. **Act. 9 — Face Map del especialista**: nueva pantalla que reutiliza el canvas interactivo
   del paciente (`InjectionPoint`, `HeadView`, `reconstruirPuntosFaceMap`), precarga el mapa
   del paciente si existe (por `paciente_id`/`tratamiento_id`) y guarda puntos vinculados al
   tratamiento en `face_maps`/`face_map_puntos`. Requiere policies de escritura del especialista.
4. **Act. 12 — Unidad por servicio**: unidad por defecto según `tipo_precio`
   (POR_UNIDAD→`unidades`, POR_JERINGA→`jeringas`, POR_SESION→`sesiones`, resto→`unidades`),
   editable en el form de producto.
5. **Act. 13 — Info mínima para finalizar**: firma firmada + ≥1 foto tipo PRE + evaluación
   inicial guardada. Productos opcionales (no todo servicio usa insumos). El saldo pendiente
   sigue bloqueando el cierre (existente).

## Actividades → implementación

### A. Migraciones BD (idempotentes, aplicar con `supabase db push`)

- [x] A1. `supabase/migrations/20260825000100_treatment_storage_privado.sql`
  - Buckets `firmas-consentimiento` y `fotografias-tratamiento` → `public=FALSE`.
  - Drop `firma_storage_public_select`; SELECT own (especialista vía path) + admin en ambos buckets.
  - `ALTER TABLE fotografias_tratamiento ENABLE ROW LEVEL SECURITY` + policies:
    especialista own (ALL vía `tratamientos.especialista_id`), paciente SELECT (vía
    `tratamientos.paciente_id`), administrador (ALL).
  - Migrar `consentimientos_tratamiento.firma_url` y `fotografias_tratamiento.archivo_url`
    de URL pública a path (`regexp_replace`).
- [x] A2. `supabase/migrations/20260825000200_face_map_especialista_rls.sql`
  - Policies INSERT/UPDATE/DELETE del especialista en `face_maps` y `face_map_puntos`
    vía `tratamientos.especialista_id` (hoy solo SELECT).

### B. Capa de datos

- [x] B1. `treatment_execution_supabase_datasource.dart`: `subirFirma` guarda path;
  `crearUrlFirmada`; `fetchConsentimiento` devuelve URL firmada; `_citaSelect` agrega
  `tipo_precio` a servicios.
- [x] B2. `treatment_photos_supabase_datasource.dart`: `subirFotografia` guarda path;
  `fetchFotografias` devuelve URLs firmadas.
- [x] B3. `iniciarTratamiento` crea el tratamiento en `PENDIENTE_FIRMA`; tras firmar
  → `EN_PROCESO` vía `actualizarTratamiento`.
- [x] B4. Face Map del especialista: datasource/usecases `getFaceMapPorTratamiento`,
  `guardarFaceMap`; entidades `face_map_entity`/`face_map_punto_entity` (reutilizan
  modelo `InjectionPoint`/`HeadView`).

### C. Cubit + DI

- [x] C1. `TreatmentExecutionCubit`: carga fotos en `loadDetalle` (inyecta `GetFotografias`);
  expone `fotografias`/`fotografiasPre`; gate en `finalizar` (firma + ≥1 foto PRE +
  evaluación inicial); `firmarConsulta` pasa tratamiento a `EN_PROCESO`.
- [x] C2. DI `_registerTreatmentExecution`: registrar nuevos usecases (face map) y
  `GetFotografias` en el cubit.

### D. UI

- [x] D1. `cita_detalle_screen.dart`: al "Iniciar servicio" → crear tratamiento
  `PENDIENTE_FIRMA` y abrir firma como primer paso; secciones habilitadas tras firmar;
  botón finalizar con requisitos faltantes; Card "Face Map / Puntos de aplicación".
- [x] D2. `fotografias_screen.dart`: `image_picker` en pubspec + botón cámara/galería
  (`subirFotografia`, tipo `PRE` por defecto); banner estado de fotos PRE.
- [x] D3. `face_map_especialista_screen.dart`: canvas interactivo, precarga mapa del
  paciente, guarda por tratamiento.
- [x] D4. Form de producto: unidad por defecto según `tipo_precio`.

### E. Verificación y documentación

- [x] E1. `flutter analyze` 0 issues; `flutter test` verde.
- [x] E2. Plan actualizado con checkpoints `[x]`.
- [x] E3. E2E manual `docs/pruebas/2026-08-25_treatment_execution_e2e.md`
  (llegada → firma → fotos → productos → face map → finalización, Act 14/15).

## Notas

- El paciente sigue guardando su Face Map pre-tratamiento vía `SupabaseService` (legacy);
  no se toca `patients_compliance`. El especialista usa el nuevo datasource por feature.
- Migraciones A1/A2 aplicadas al remoto el 2026-08-25 desde el SQL Editor del Dashboard
  (a petición del usuario; `supabase migration list` requería login).
- `consentimientos_tratamiento.firma_url` y `fotografias_tratamiento.archivo_url` cambian
  de URL pública a path; revisar consumidores (preview con `cached_network_image` pasará
  a URLs firmadas).
- No se toca la máquina de estados de citas (`trg_validar_transicion_estado_cita`).