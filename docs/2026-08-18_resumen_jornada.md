# Resumen de jornada — 2026-08-18

- **Fecha**: 2026-08-18
- **Rama**: `main`.
- **Flutter**: SDK **3.44.9** (sin cambios hoy).

Un ciclo grande hoy: **compliance del especialista de extremo a extremo** — expediente habilitante, aprobación gated (admin) y notificaciones in-app. Plan en `docs/plans/2026-08-18_compliance_especialista_expediente_notificaciones.md` (APROBADO por el usuario, ítems 4–14 de la lista de actividades compliance). Después, un segundo ciclo: **flujo de salud del paciente** — cuestionario real configurable con versiones, evaluación con riesgos, validación de telemedicina con fechas reales y gate RN-020. Plan en `docs/plans/2026-08-18_salud_cuestionario_paciente.md` (requisitos 1–15). Las pruebas E2E del ciclo 3 quedan programadas para mañana (`docs/pruebas/2026-08-19_salud_cuestionario_e2e.md`).

| Ciclo | Estado | Commit |
|---|---|---|
| 1. Compliance especialista: expediente + Verificado gated + notificaciones in-app | ✅ Pusheado | `8e51419` |
| 2. Verificación E2E del compliance (12 ítems) + fixes + deploy | ✅ Pusheado y desplegado | `6c60f33` |
| 3. Salud del paciente: cuestionario real con versiones + evaluación con riesgos + validación telemedicina + gate RN-020 + admin cuestionarios | ✅ Pusheado | `779bc74` |

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

## 2. Verificación E2E del compliance del especialista (12 ítems) — ciclo 2

**Contexto**: tras cerrar la implementación (ciclo 1), se ejecutó la prueba manual de punta a punta del checklist de aceptación (12 ítems). Resultado: **12/12 ✅**. Evidencia completa en `docs/pruebas/2026-08-18_compliance_e2e.md` (plan en `docs/plans/2026-08-18_verificacion_compliance_especialista.md`). Se usó una cuenta nueva (`esp.compliance1@test.com`) registrada en la app.

### Flujo probado y resultados
- A–E (ítems 1–10): subida de documentos → revisión admin → notificación de rechazo → re-subida (v2) → aprobados permanecen → bloqueo de marketplace (sin tarjetas, toggle deshabilitado, `/specialist/map` restringido).
- F (ítem 11): contra-pruebas SQL del trigger (bloquea APROBADO con expediente incompleto; positivo con expediente completo) → docs aprobados + contrato firmado → checklist verde → admin aprueba → **Verificado** + notificación `VERIFICACION_APROBADA`.
- G (ítem 12): toggle de disponibilidad habilitado, tarjetas mapa/citas visibles, mapa sin restricción, aceptó solicitud de María González → cita `PROGRAMADA`.

### Bugs fijos en esta verificación
- **UX documentos (Fase C/D)**: botón "Reintentar" con ancho adaptable, motivo del rechazo resaltado, campanita en el AppBar de Documentos, precedencia de tile `aprobado > enRevision > rechazado > pendiente`, helper `documentosVigentes` (una fila por tipo) y `tiposSubiblesDocumentos` que excluye APROBADOS y PENDIENTES activos.
- **`_AccesoRestringido` (Fase E)**: "Volver" con `canPop()`/`context.go` para URL directa.
- **Firma de contrato (Fase F)**: `contratos.version_contrato` era columna de texto → migración `20260818000100_contratos_version_integer.sql` (normaliza a INTEGER) + modelo robusto con `int.tryParse`.
- **Mapa de especialistas (Fase G)**: doble causa — `profiles(full_name)` ambiguo (fix: hint `profiles!especialistas_usuario_id_fkey`) y **`ubicaciones_especialista` sin FK hacia `especialistas`** (tabla creada a mano en el dashboard) → PostgREST no resolvía el embed. Migración `20260818000200_ubicaciones_especialista_fk.sql` (constraint idempotente + limpieza de huérfanos) + se quitaron los modifiers `order=/limit=` embebidos y se ordena por `created_at` desc en el cliente.

### Hallazgos registrados (doc de pruebas)
- Deuda: `especialista1-4@test.com` (seed) están `APROBADO` con expediente incompleto (`cumple_requisitos_habilitacion=false`) → `aceptar_solicitud` los rechazaría del marketplace (decidir backfill).
- UX menor: `obtener_solicitudes_publicadas_geo` no filtra `fecha_expiracion` → el mapa muestra solicitudes vencidas (recomendado filtrarlas).

### Despliegue
- Commit `6c60f33` pusheado a `main` y desplegado en **Firebase Hosting** (`esteticaybellezastrani.web.app`) con `flutter build web --release` + `firebase deploy --only hosting`.

---

## 3. Salud del paciente — cuestionario real, evaluación con riesgos, validación de telemedicina y gate RN-020 (ciclo 3)

**Contexto**: el flujo de salud vivía en el monolito legacy `SupabaseService` (sin repositorios ni RLS) y `PatientQuestionnaireScreen` usaba preguntas hardcodeadas con Qualify simulado sin fechas reales. Hoy se reescribió el módulo de punta a punta en Clean Architecture (plan `docs/plans/2026-08-18_salud_cuestionario_paciente.md`, requisitos 1–15).

### Migración `supabase/migrations/20260818000300_salud_cuestionario_paciente_rls.sql` (aplicada al remoto)

- **RLS en 8 tablas de salud** (`cuestionarios`, `preguntas`, `cuestionario_preguntas`, `servicio_cuestionarios`, `evaluaciones_salud`, `respuestas_salud`, `validaciones_telemedicina`): Admin full CRUD (`es_administrador()` SECURITY DEFINER, helper `is_administrador`); authenticated SELECT de catálogo; **paciente INSERT+SELECT propias sin UPDATE/DELETE** (evaluaciones, respuestas, validaciones).
- **Columnas nuevas**: `preguntas.opciones jsonb` (LISTA/MULTIPLE) y `preguntas.riesgo jsonb` (sentinelas `{"detonante":...,"etiqueta":...,"critico":...}`); `respuestas_salud.pregunta_texto` (snapshot del texto respondido, conserva la versión); `pacientes.fecha_nacimiento/genero/grupo_sanguineo/alergias/antecedentes` (revive `PacienteEntity`); `evaluaciones_salud.resultado + riesgos jsonb`.
- **Unique `cuestionarios (nombre, version)`** (índice `cuestionarios_nombre_version_idx`, dedupe previo) para el versionado por edición; tablas puente deduped + unique para `ON CONFLICT DO NOTHING` idempotente.
- **RPC `public.guardar_respuestas_evaluacion`** (SECURITY DEFINER, única autoridad de la evaluación): recibe respuestas + `p_codigo_referencia`, inserta `evaluaciones_salud` (con `version_cuestionario`) y `respuestas_salud` (con `pregunta_texto`), computa sentinelas → `riesgos` + `resultado` (`APTO`/`REQUIERE_REVISION`/`NO_APTO`) y devuelve `ResultadoEvaluacionRegistrada`. Sentinela `SI_NO`: compara `v_valor = 'Sí'` (con acento) contra `detonante` en mayúsculas; el seed usa opciones `["Sí","No"]`.
- **RPC `public.registrar_validacion_telemedicina`** (SECURITY DEFINER): fija `estado=APROBADA`, `fecha_validacion=now()`, `fecha_vencimiento=+365 días`, `proveedor`, `codigo_referencia`; además actualiza `profiles.activo/evaluation_passed/payment_completed=true`.
- **Trigger `trg_rn020_solicitud`** (BEFORE INSERT en `solicitudes`): bloquea el INSERT si el servicio `requiere_telemedicina` y el paciente no tiene validación `APROBADA` vigente. **Config-gated** por `configuracion_sistema.enforce_rn020` (seed `'true'`; poner `'false'` para desarrollo/pruebas).
- **Seed v1** del cuestionario real de salud: 10 preguntas médicas (alergias, embarazo/lactancia, autoinmunes/diabetes/coagulación, medicación anticoagulante, tratamientos previos, conteo anual, último chequeo, tabaquismo, cicatrización queloidal, síntomas) + vínculo `servicio_cuestionarios` a los 5 servicios médicos/inyectables del catálogo. Helper idempotente `_seed_pregunta`.
- Seed opcional con 2 versiones: `supabase/seed_cuestionario_2_versiones.sql` (crea v2 INACTIVA copiando preguntas de v1 + 1 pregunta nueva de antecedentes oncológicos).

### Clean Architecture en `patients_compliance` (patrón `marketplace_citas`)

- **Datasource** `PatientsComplianceSupabaseDataSource` (solo Supabase → Models) + **models** (Paciente, Cuestionario, Pregunta con mapeo `tipo_respuesta_enum`↔`TipoRespuestaPregunta`, CuestionarioPregunta, EvaluacionSalud, RespuestaSalud, ValidacionTelemedicina).
- **Repositorio** `PatientsComplianceRepositoryImpl(datasource)` con `Either<Failure,T>` (reemplaza el `const RepoImpl()` stub). Nota: el error envuelto usa `TelemedinaFailure` (typo preexistente en `failures.dart`, es el nombre real).
- **14 usecases**: `get_mi_paciente`, `update_mi_paciente`, `get_cuestionarios`, `get_cuestionario_activo`, `get_cuestionario_preguntas`, `crear_nueva_version_cuestionario`, `activar_version_cuestionario`, `guardar_respuestas_evaluacion`, `get_ultima_evaluacion`, `registrar_validacion_telemedicina`, `get_mi_validacion`, `consultar_estado_salud`, `validar_acceso_rn020`, `update_pregunta`.
- **Cubits** `PatientHealthCubit` (carga paciente/cuestionario/preguntas, `enviarRespuestas`, `registrarValidacion`, `consultarEstado`) y `AdminCuestionarioCubit` (lista de versiones, `editarPregunta`, `crearNuevaVersion`, `activarVersion`). DI actualizado en `_registerPatientsCompliance()` (+ `ValidarAccesoRN020` y `UpdatePregunta`).
- **Entidad nueva `EstadoSaludEntity`** con `habilitado` y `siguientePaso` (requisitos 12/13); `PacienteEntity.edad` calcula desde `fecha_nacimiento`.

### App — flujo paciente

- **`PatientQuestionnaireScreen` reescrito**: carga preguntas reales vía cubit (no hardcodeadas), render por `TipoRespuestaPregunta` (SI_NO, TEXTO, NUMERO, DECIMAL, FECHA, LISTA, MULTIPLE, ARCHIVO, IMAGEN), enviar → `guardar_respuestas_evaluacion` → dictamen APTO (selector modalidad → Qualify simulado 3 s → `registrarValidacion` → modal de éxito con `fecha_validacion`/`fecha_vencimiento` reales → `createSolicitudAndPayment`) o REVISIÓN/NO APTO (modal con etiquetas de riesgo, sin Qualify).
- **`CompleteProfileScreen`**: campos `fecha_nacimiento` (date picker) y `genero` (Femenino/Masculino/Otro/Prefiero no decir; columna TEXT libre) cargados con `GetMiPaciente` y guardados con `UpdateMiPaciente`.
- **`EstadoSaludScreen` nueva** (requisito 13), ruta `AppRoutes.estadoSalud = '/estado-salud'`, accesible desde el catálogo (icono AppBar) y muestra cuota/cuestionario/evaluación/validación + siguiente paso.
- **`ServicesDashboardScreen`**: el gate RN-020 ahora usa `ValidarAccesoRN020` (usecase limpio) en `_loadFlowStatus` y `_onServiceSelected` (reemplaza `SupabaseService.checkPatientFlowStatus`/`validateReservationRulesRN020`).

### App — admin mínimo (requisitos 3–5 y 14)

- **`AdminCuestionarioScreen`** nueva, ruta `AppRoutes.adminCuestionario = '/admin/cuestionario'` (tarjeta en el AdminDashboard): lista de versiones con badge ACTIVA/INACTIVA, "crear nueva versión" (`version+1`, copia preguntas, INACTIVA), "activar versión" (desactiva las demás del mismo nombre) y editar pregunta (diálogo con texto, opciones por línea, `riesgo` JSON editable, switches obligatoria/activa) vía `UpdatePregunta`.

### Pruebas y verificación

- Test unitario nuevo `test/patients_compliance/patients_compliance_test.dart` (14 casos): mapeo de enums a BD, `ResultadoEvaluacionRegistrada.fromJson`, gate RN-020 (`ValidacionTelemedicinaEntity`), `EstadoSaludEntity.habilitado/siguientePaso`, `RiesgoSentinel/RiesgoDetectado`, `PacienteEntity.edad`.
- `flutter analyze` sin issues; `flutter test` **95/95 en verde** (se agregó la suíte de patients_compliance).
- Checklist manual E2E actualizado en `docs/Pruebas manuales/07_patients_compliance.md` (28 casos, v2.0).
- Migración aplicada al remoto con `supabase db push` (también incluyó las dos pendientes de la mañana: `20260818000100` contratos integer y `20260818000200` FK ubicaciones).
- Commit `779bc74` pusheado; **working tree limpio**. Pruebas E2E del flujo pendientes para mañana (se generará el doc `docs/pruebas/2026-08-19_salud_cuestionario_e2e.md`).

---

## Verificación transversal

- `flutter analyze` → sin issues.
- `flutter test` → 95/95 OK (incluye la suíte nueva de `patients_compliance`).
- BD: migraciones aplicadas al remoto hasta `20260818000300` (salud/cuestionario), incluyendo `20260818000100` (version_contrato integer) y `20260818000200` (FK ubicaciones_especialista).

### Working tree actual
- Ciclos 1 (`8e51419`), 2 (`6c60f33`) y 3 (`779bc74`) pusheados. Working tree limpio.
- **Nota**: la app desplegada en `esteticaybellezastrani.web.app` NO incluye aún el ciclo 3 (deploy pendiente tras las pruebas E2E de mañana).

### Pendientes documentados
- **E2E del flujo de salud (ciclo 3)** — mañana; checklist en `docs/Pruebas manuales/07_patients_compliance.md` (28 casos) y el doc de evidencia se generará en `docs/pruebas/`.
- Aplicar el seed opcional `supabase/seed_cuestionario_2_versiones.sql` cuando se quiera probar el versionado admin con 2 versiones reales.
- Push FCM (edge function/webhook) para notificaciones — **fuera de alcance** de esta iteración (solo in-app).
- Convertir buckets aún públicos (`contratos`, `firmas`, `fotografias-tratamiento`) a privados — pendiente de otro ciclo.
- Versionar tablas creadas a mano en el dashboard (`disponibilidad_especialista`, `contratos`) — pendiente de otro ciclo.
- Backfill/decisión de producto para `especialista1-4@test.com` (APROBADO legacy con expediente incompleto) — ver doc de pruebas.
- RPC `obtener_solicitudes_publicadas_geo`: filtrar `fecha_expiracion` para no mostrar solicitudes vencidas en el mapa — pendiente de otro ciclo.
- Migrar el resto de flujos legacy (`face_map`, geocoding, `checkPatientFlowStatus`) fuera de `SupabaseService` — deuda marcada.
