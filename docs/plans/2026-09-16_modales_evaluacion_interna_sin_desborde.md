# Plan — Modales de Evaluación Médica Interna sin desborde en celular

Fecha: 2026-09-16
Estado: APROBADO por el usuario (m0978: "si, commit/push al finalizar").

## Objetivo

Los textos "Evaluación Médica Interna" / "Medicina Interna" en las ventanas modales
del cuestionario se **desbordan en celular** (`RenderFlex overflowed`). La causa es
que el `title` del `AlertDialog` es un `Row` con el `Text` **sin `Expanded`/`Flexible`**,
y los diálogos no fijan `insetPadding`/`constraints` como sí lo hacen los de
`complete_profile_screen.dart` y `services_dashboard_screen.dart`.

## Cambios

Archivo único: `lib/features/patients_compliance/presentation/screens/patient_questionnaire_screen.dart`

1. **`_showEvaluationModalitySelector`** (l.158-195):
   - Añadir `insetPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 24)` y
     `constraints: BoxConstraints(maxWidth: 440)`.
   - Envolver el `Text('Evaluación Médica Interna')` del título en `Expanded`.
   - Botón de acción con etiqueta corta **'Continuar'** (se conserva el icono
     `local_hospital_rounded`).
2. **`_showDictamenConRiesgos`** (l.366-435):
   - Añadir `insetPadding` + `constraints: BoxConstraints(maxWidth: 440)`.
   - Envolver el `Text` del título en `Expanded`.
3. **`_triggerInternalEvaluation`** (l.242-269) y **`_showEvaluationSuccessModal`**
   (l.285-356): añadir `insetPadding` + `constraints` por uniformidad.

### Sin cambios
BD, cubits, rutas y los modales que ya funcionan (`complete_profile_screen.dart`,
`services_dashboard_screen.dart`).

## Verificación

- [ ] `flutter analyze` limpio.
- [ ] `flutter test` (366 tests).
- [ ] Manual en móvil (~360 px): el modal de Evaluación Médica Interna y los
      dictámenes ya no desbordan.

## Notas

- Commit/push autorizado por el usuario al finalizar (m0978).
