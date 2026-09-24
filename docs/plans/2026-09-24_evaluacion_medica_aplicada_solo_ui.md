# Plan — Evaluación Médica aplicada (solo UI + checkbox ePHI)

Fecha: 2026-09-24
Estado: APROBADO por el usuario ("aprobado con checkbox"). Sin commit.

## Objetivo

Sustituir la ventana de prueba (delay 3 s + `registrarValidacion aprobado:true`
+ `createSolicitudAndPayment`) por una vista real de **Evaluación Médica
aplicada**: usa el cuestionario ya generado (`guardar_respuestas_evaluacion`
→ APTO / REQUIERE_REVISION / NO_APTO + riesgos), **sin auto-dictamen**.
El dictamen lo hace un médico en entrevista F2F desde administración
(decisión del usuario). Alcance de esta iteración: **solo UI primero**,
destino catálogo con banner pendiente.

## Decisiones confirmadas

1. Dictamen médico F2F desde administración (ahora solo se aplica la evaluación).
2. Alcance: solo UI primero.
3. Destino: catálogo con banner pendiente.
4. Aprobado con **checkbox de consentimiento ePHI** en la nueva vista.

## Cambios

### 1. Nueva `lib/features/patients_compliance/presentation/screens/evaluacion_medica_aplicada_screen.dart`

- `EvaluacionMedicaAplicadaScreen({required ResultadoEvaluacionRegistrada resultado, String? serviceName, VoidCallback? onCompleted})`.
- Muestra: folio (id corto), fecha, versión cuestionario, resultado/riesgos
  (chips, sin lenguaje de "aprobado"), sección "Qué sigue" (entrevista F2F
  con médico desde administración para el dictamen), avisos FDA/HIPAA
  (ePHI: uso clínico interno, acceso auditado, sin URLs públicas).
- **Checkbox consentimiento ePHI** obligatorio:
  "He leído los avisos y autorizo el tratamiento de mis datos de salud (ePHI)
  para la evaluación médica interna." Botón "Continuar al catálogo"
  deshabilitado hasta marcarlo.
- Botón → `onCompleted` o `maybePop(true)` (el llamador lleva al catálogo).

### 2. `patient_questionnaire_screen.dart`

- Quitar los 3 modales de prueba: `_showEvaluationModalitySelector`,
  `_triggerInternalEvaluation` (delay + `registrarValidacion` + `createSolicitudAndPayment`),
  `_showEvaluationSuccessModal`.
- Quitar imports ya innecesarios (`supabase_service`, `IPaymentsRepository`,
  `ValidacionTelemedicinaEntity`).
- `_submitQuestionnaire`: si `apto` → `Navigator.push` a
  `EvaluacionMedicaAplicadaScreen`; si no → `_showDictamenConRiesgos`
  existente (sin cambios, ya no dictamina).
- **No** llamar `registrarValidacion`, **no** disparar `createSolicitudAndPayment`.

### 3. Ajustes menores de coherencia

- `complete_profile_screen.dart` (`_openQuestionnaires.onCompleted`):
  actualizar comentario (la evaluación solo se aplica; el dictamen es F2F).
- `services_dashboard_screen.dart` (`_buildStatusBanner` por defecto):
  texto pendiente F2F ("Evaluación aplicada · dictamen médico pendiente").
- `estado_salud_screen.dart` (`_validacionLabel` por defecto):
  "Pendiente de dictamen médico (F2F)".

### Sin cambios (deuda fase 2 documentada)

- Sin migración BD en esta iteración. Fase 2: columna/estado
  `EVALUACION_APLICADA` + auditoría/consentimiento + panel admin para
  dictamen F2F (aprobar/rechazar/bloquear) respetando triggers
  `trg_proteger_verificacion_especialista` / `trg_proteger_revision_documento`.
- RLS, RPCs, `registrarValidacion`, RN-020 intactos.

## Verificación

- [x] `flutter analyze` limpio.
- [x] `flutter test` (370, ALL PASSED).
- [ ] Manual en `flutter run -d chrome`: cuestionario → vista aplicada con
      folio/fecha/versión/riesgos → checkbox habilita botón → catálogo con
      banner pendiente; estado de salud muestra pendiente F2F.
