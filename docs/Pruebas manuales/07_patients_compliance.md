# Pruebas manuales — patients_compliance

| | |
|---|---|
| **Módulo** | patients_compliance (cuestionario de salud, evaluación, dirección, face map) |
| **Estado del código** | STUB (repo `const` delegando en `SupabaseService` legacy; sin cubit; pantallas llaman directo) |
| **Fecha** | 2026-08-14 |
| **Versión** | 1.0 |

## Alcance

PatientQuestionnaireScreen (push desde complete-profile), PatientAddressScreen, FaceMapQuestionnaireScreen (`/face-map-questionnaire`), PatientMapPicker, flujos `saveHealthEvaluation`, `saveQualifyTestValidation`, `savePatientAddress`, `saveFaceMapRecord`.

## Fuera de alcance

Pago de cuota inicial (docs 01/08), catálogo (doc 05).

## Precondiciones generales

- `pac.nuevo` con perfil básico completo (teléfono/dirección) y cuota pagada o pospuesta.
- Edge function `geocode-address` desplegada.
- Assets de silueta facial disponibles (y probar ausencia para el fallback).

## 1. Camino feliz

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| PC-H-01 | Cuestionario completo | Al finalizar complete-profile | 1. Responder las 5 preguntas (alergias, embarazo, autoinmunes, medicación, tratamientos previos multi-selección) 2. Enviar | `saveHealthEvaluation` encadena cuestionarios/evaluaciones_salud/respuestas con `evaluation_passed=true` | Crítica | | |
| PC-H-02 | Elección de modalidad | Cuestionario enviado | 1. Elegir Telemedicina o Medicina Interna | Diálogo de modalidad guarda la elección | Alta | | |
| PC-H-03 | Proceso Qualify | Modalidad elegida | 1. Esperar proceso simulado (~3 s) | `saveQualifyTestValidation(aprobado:true)`: `profiles.activo=true`, `evaluation_passed=true`, `payment_completed=true`, vigencia 365 días | Crítica | | |
| PC-H-04 | Solicitud y pago iniciales | Qualify aprobado | 1. Continuar | `createSolicitudAndPayment` con ref Stripe o `STRIPE_SIM_…`; modal de éxito; `onCompleted` refresca perfil y va al catálogo | Alta | | |
| PC-H-05 | Guardar dirección | PatientAddressScreen | 1. Escribir dirección 2. Geocodificar 3. Confirmar en mapa | `savePatientAddress` en `direcciones_paciente` con coords | Alta | | |
| PC-H-06 | Face map completo | `/face-map-questionnaire` | 1. Elegir vista (Izq/Fte/Der) 2. Marcar puntos predefinidos 3. Añadir punto custom + nota 4. Guardar | `saveFaceMapRecord`: fila en `face_maps` + puntos | Alta | | |

## 2. Validaciones y casos negativos

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| PC-V-01 | Cuestionario incompleto | Formulario | 1. Dejar preguntas sin responder 2. Enviar | Snackbar naranja; no se envía | Alta | | |
| PC-V-02 | Dirección vacía | PatientAddressScreen | 1. Guardar sin dirección | Validator bloquea | Media | | |
| PC-V-03 | Geocoding sin resultados | Dirección inexistente | 1. Geocodificar | Mensaje claro; opción de elegir punto manual en mapa | Media | | |
| PC-V-04 | Face map sin puntos | Cuestionario facial | 1. Guardar sin puntos | Comportamiento definido: ¿permite guardar vacío? Verificar | Media | | |

## 3. Roles y permisos (guards / RLS)

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| PC-G-01 | Face map público | Sin sesión | 1. `/face-map-questionnaire` | Accesible (ruta pública) | Media | | |
| PC-G-02 | Cuestionario sin sesión | Sesión cerrada | 1. Forzar entrada al cuestionario | Verificar comportamiento: `userId ?? 'invitado_test'` | Alta | | |
| PC-G-03 | RLS de evaluaciones | Paciente A | 1. Intentar leer evaluaciones del paciente B | RLS lo impide | Alta | | |

## 4. Estados y transiciones

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| PC-E-01 | Posponer pago de cuota | Modal de cuota en complete-profile | 1. Pulsar "Posponer" | Abre cuestionario con `paid:false`; el flujo continúa sin pagar | Alta | | |
| PC-E-02 | Evaluación VENCIDA tras 365 días | Registro antiguo | 1. Renovar desde catálogo/complete-profile | Dialog de renovación con pago de $30; nueva vigencia | Alta | | |
| PC-E-03 | `checkPatientFlowStatus` | Distintos estados | 1. Entrar a complete-profile | Enruta según evaluación: VENCIDA→renovar, RECHAZADA→no apto, APROBADA→catálogo, PENDIENTE→cuestionario | Alta | | |

## 5. Red y edge cases

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| PC-N-01 | Envío sin red | Modo avión | 1. Enviar cuestionario | Error controlado; sin registros parciales (cuestionario+evaluación+respuestas) | Alta | | |
| PC-N-02 | Edge function caída | `geocode-address` sin desplegar | 1. Geocodificar | Fallback Nominatim funciona; caché y rate-limit respetados | Media | | |
| PC-N-03 | Assets de silueta ausentes | Asset eliminado | 1. Abrir face map | `silueta_asset_fallback.dart` evita crash | Media | | |
| PC-N-04 | Cadena de escrituras parcial | Fallo a mitad de `saveHealthEvaluation` | 1. Provocar fallo | Verificar si quedan huérfanos en cuestionarios/evaluaciones/respuestas | Alta | | |

## 6. Sospechosos de código

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| PC-S-01 | Qualify siempre aprueba | Cualquier cuestionario | 1. Responder con respuestas de riesgo (embarazo + inyectables) | **Confirmar**: el proceso simulado de 3 s SIEMPRE aprueba; no hay lógica de rechazo real | Alta | | |
| PC-S-02 | Pago pospuesto marcado como pagado | Paciente que pospuso la cuota | 1. Completar cuestionario y Qualify | **Confirmar bug de negocio**: `saveQualifyTestValidation` fija `payment_completed=true` aunque nunca pagó los $30 | Crítica | | |
| PC-S-03 | Usuario invitado | Sin sesión | 1. Guardar face map | **Confirmar**: se usa `userId ?? 'invitado_test'`; fila huérfana con id fijo compartido | Media | | |
| PC-S-04 | Legacy `SupabaseService` | — | 1. Revisar que el módulo no pasa por repositorios/Either | Documentar: errores no se envuelven en `Failure`; los maneja cada pantalla | Baja | | |

## Resumen de ejecución

| Total | Pasa | Falla | Bloqueado | Pendiente |
|---|---|---|---|---|
| 24 | | | | 24 |
