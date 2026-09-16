# Plan — Quitar Qualify → "Evaluación Médica Interna"

Fecha: 2026-09-16
Estado: APROBADO por el usuario (m0583). Sin commit.

## Objetivo

Eliminar la marca/flujo **Qualify** y unificar todo en **Evaluación Médica Interna**
(`proveedor = 'Medicina Interna'`), conservando el **mismo trato simulado para pruebas**
(delay 3 s, `aprobado=true`, validez 365 días, pago \$30 vía `createSolicitudAndPayment`,
gate RN-020 intacto). En bienvenida el badge pasa a **"Evaluación Médica Interna"**.

Decisiones confirmadas (m0579):
1. Conservar el diálogo de modalidad con **una sola opción** ("Evaluación Médica Interna").
2. **Migrar** los registros existentes de `validaciones_telemedicina.proveedor` a `'Medicina Interna'`.
3. Limpiar lo visible + renombrar lo obvio (métodos/widgets internos con "Qualify");
   se dejan intactas columnas BD y usecases.
4. Badge sin punto final: `Evaluación Médica Interna`.

## Cambios

### 1. Migración SQL (nueva) `supabase/migrations/20260916000100_validaciones_medicina_interna.sql`
Idempotente, sin cambios de RLS: `UPDATE public.validaciones_telemedicina SET proveedor='Medicina Interna'`
donde `proveedor IS NULL` / vacío / ILIKE '%qualify%' / ILIKE '%telemedicina%'.
Se aplica por pooler (el CLI da 401 sin `supabase login`).

### 2. `lib/features/patients_compliance/presentation/screens/patient_questionnaire_screen.dart`
- `_showEvaluationModalitySelector()`: diálogo con **un solo botón** "Evaluación Médica Interna".
- Renombrar `_triggerEvaluationProcess({proveedor})` → `_triggerInternalEvaluation()` (proveedor fijo).
- Renombrar `_showQualifySuccessModal` → `_showEvaluationSuccessModal`.
- Textos: 'Evaluación Médica Interna', 'Procesando... con el departamento de Medicina Interna...',
  '¡Evaluación Médica Interna Exitosa!'; botón final 'Enviar y Evaluar'.

### 3. Textos visibles restantes
- `welcome_screen.dart`: badge → 'Evaluación Médica Interna'.
- `services_dashboard_screen.dart`: defaults `_proveedorEvaluacion='Medicina Interna'`; banner
  'Evaluación Médica Interna Aprobada'; modal expiración y modal pendiente con marca interna.
- `complete_profile_screen.dart`: default 'Medicina Interna'; dictamen negativo sin 'Qualify';
  corregir typo 'Renovar Evaluation' → 'Renovar Evaluación'.
- `estado_salud_screen.dart`: 'Tu Evaluación Médica Interna está vigente.' y
  'Aprobada (Evaluación Médica Interna)'.
- `admin_servicio_detail_screen.dart`: tile 'Requiere evaluación médica (RN-020)' (campo/columna intactos).

### 4. Renombrados internos (no visibles)
- `supabase_service.dart`: `saveQualifyTestValidation` → `saveMedicalEvaluation` (default
  `'Medicina Interna'`); default `proveedorEvaluacion` (l.890) → 'Medicina Interna'; comentarios.
- `i_patients_compliance_repository.dart` + `patients_compliance_repository_impl.dart`: renombre y default.
- `app_env.dart`: `qualifyApiUrl` → `internalEvaluationApiUrl`; `.env.example` actualizado.
- Comentarios/docs: `app_constants.dart`, `failures.dart`, `evaluacion_salud_entity.dart`,
  `estado_salud_entity.dart`, comentarios en `payments_stripe`.

### Sin cambios
Columnas BD (`requiere_telemedicina`, tabla `validaciones_telemedicina`), usecase
`RegistrarValidacionTelemedicina` y params, RLS, storage, cubits, rutas.

## Verificación

- [x] `flutter analyze` limpio.
- [x] `flutter test` (366 tests).
- [x] Aplicar migración y confirmar por pooler (12 filas actualizadas, 0 pendientes; total 16).
- [ ] Manual en `flutter run -d chrome`: badge, cuestionario con un solo botón, dictamen y
      estado de salud con la marca interna.

## Notas

- Sin commit (regla del proyecto: preguntar antes de commitear).
