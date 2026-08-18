# Pruebas manuales — patients_compliance

| | |
|---|---|
| **Módulo** | patients_compliance (salud, cuestionario, evaluación, validación, estado) |
| **Estado del código** | IMPLEMENTADO (Clean Architecture: datasource → repo `Either<Failure,T>` → usecases → cubits) |
| **Fecha** | 2026-08-18 |
| **Versión** | 2.0 |

## Alcance

`PatientQuestionnaireScreen` (preguntas reales de BD renderizadas por `tipo_respuesta`), `CompleteProfileScreen` (fecha_nacimiento/género), `EstadoSaludScreen` (`/estado-salud`), `AdminCuestionarioScreen` (`/admin/cuestionario`), gate RN-020 (trigger BD + `ValidarAccesoRN020`), RPC `guardar_respuestas_evaluacion` y `registrar_validacion_telemedicina`. Face map/geocoding siguen en legacy (`SupabaseService`) — fuera de alcance.

## Precondiciones generales

- Aplicar la migración `20260818000300_salud_cuestionario_paciente_rls.sql` (`supabase db push` o SQL Editor).
- Seed de catálogo aplicado (`supabase/seed_test_data.sql`) y opcional `supabase/seed_cuestionario_2_versiones.sql`.
- Usuario `paciente1@test.com` / `admin@strani.com` (clave `Test1234!`).

## 1. Camino feliz

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| PC-H-01 | Cuestionario real cargado | Migración aplicada | 1. Entrar al cuestionario desde complete-profile | Se cargan las 10 preguntas del seed (SI_NO, TEXTO, LISTA, NUMERO, FECHA, MULTIPLE) con su versión; sin preguntas hardcodeadas | Crítica | | |
| PC-H-02 | Enviar respuestas | Formulario completo | 1. Responder todas las obligatorias 2. "Enviar y Evaluar" | RPC guarda `evaluaciones_salud` + `respuestas_salud` (con snapshot `pregunta_texto`); resultado APTO si no hay riesgos | Crítica | | |
| PC-H-03 | Dictamen con riesgos | Respuesta dispara sentinela (ej. alergia = Sí) | 1. Responder Sí en alergia 2. Enviar | Modal "Revisión requerida" con la etiqueta de riesgo; NO se abre Qualify | Alta | | |
| PC-H-04 | Dictamen NO APTO | Respuesta dispara sentinela crítico (embarazo = Sí) | 1. Responder Sí en embarazo 2. Enviar | Modal "NO APTO" con riesgo crítico; NO se registra validación | Crítica | | |
| PC-H-05 | Qualify simulado con fechas reales | Dictamen APTO | 1. Elegir Telemedicina/Medicina Interna 2. Esperar ~3 s | `registrar_validacion_telemedicina`: estado APROBADA, `fecha_validacion`=hoy, `fecha_vencimiento`=+365 días; modal muestra ambas fechas | Crítica | | |
| PC-H-06 | Versión conservada | Evaluación previa existente | 1. Re-evaluar tras activar v2 | La evaluación nueva usa la versión activa; las respuestas guardan el texto de la pregunta en el momento | Alta | | |
| PC-H-07 | Estado de salud | Sesión paciente | 1. Abrir `/estado-salud` desde el catálogo (icono corazón) | Muestra cuota, cuestionario, resultado, validación, vencimiento y siguiente paso | Alta | | |

## 2. Validaciones y casos negativos

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| PC-V-01 | Obligatorias sin responder | Formulario | 1. Dejar una obligatoria vacía 2. Enviar | Error de validación por campo (chip/input) y snackbar naranja | Alta | | |
| PC-V-02 | Número inválido | Pregunta NUMERO | 1. Escribir "abc" 2. Enviar | Validator rechaza "Ingresa un valor numérico válido" | Media | | |
| PC-V-03 | Sin cuestionario activo | Config sin activa | 1. Desactivar todas las versiones 2. Abrir cuestionario | Pantalla de error con "Reintentar" | Alta | | |
| PC-V-04 | Validación vencida (gate RN-020) | Validación >365 días | 1. Intentar reservar servicio con `requiere_telemedicina` | `ValidarAccesoRN020` devuelve VENCIDA → modal de expiración | Crítica | | |
| PC-V-05 | Validación rechazada | `validaciones_telemedicina` RECHAZADA | 1. Intentar reservar | Modal "Reserva Bloqueada (RN-020/RN-022)" | Crítica | | |
| PC-V-06 | Trigger RN-020 a nivel BD | `enforce_rn020='true'` | 1. Insertar solicitud vía SQL para servicio con `requiere_telemedicina` sin validación vigente | INSERT bloqueado con error RN-020 | Crítica | | |

## 3. Roles y permisos (RLS)

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| PC-G-01 | Paciente solo su data | Sesión paciente1 | 1. Consultar `evaluaciones_salud`/`validaciones_telemedicina` de otro paciente vía SQL | RLS lo impide (SELECT solo propias) | Alta | | |
| PC-G-02 | Paciente no edita evaluaciones | Sesión paciente1 | 1. UPDATE/DELETE a `evaluaciones_salud` propia | RLS lo impide (solo INSERT/SELECT) | Alta | | |
| PC-G-03 | Catálogo legible | Cualquier sesión | 1. SELECT a `cuestionarios`/`preguntas` | Autenticados pueden leer catálogo; solo admin edita | Media | | |
| PC-G-04 | RPC protegida | Sesión paciente2 | 1. Ejecutar `guardar_respuestas_evaluacion` con `p_cuestionario_id` ajeno a otro paciente | RPC solo registra para el usuario autenticado (SECURITY DEFINER + verificación) | Alta | | |
| PC-G-05 | Admin cuestionario | Sesión admin | 1. `/admin/cuestionario` 2. Editar pregunta, crear v2, activar v2 | Acciones permitidas solo a Administrador | Alta | | |

## 4. Admin cuestionario (requisitos 3-5 y 14)

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| PC-A-01 | Ver histórico | 2 versiones sembradas | 1. Abrir `/admin/cuestionario` | Lista v1 (ACTIVA) y v2 (INACTIVA) con conteo de preguntas | Alta | | |
| PC-A-02 | Editar pregunta | Versión seleccionada | 1. Lapicito de una pregunta 2. Cambiar texto/opciones/riesgo 3. Guardar | Pregunta actualizada; se refresca la lista | Alta | | |
| PC-A-03 | Crear nueva versión | Versión seleccionada | 1. "Crear nueva versión" | Nueva fila `version+1`, INACTIVA, copia las preguntas | Alta | | |
| PC-A-04 | Activar versión | Versión inactiva creada | 1. "Activar esta versión" | Se activa y se desactivan las demás del mismo nombre | Alta | | |

## 5. Estados y transiciones

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| PC-E-01 | Complete-profile con datos clínicos | Perfil previo | 1. Guardar fecha_nacimiento + género 2. Reabrir | Se precargan los valores; `pacientes.fecha_nacimiento/genero` persistidos | Alta | | |
| PC-E-02 | Re-evaluación tras vencimiento | Validación VENCIDA | 1. Pago $30 + nuevo cuestionario + Qualify | Nueva validación con fechas renovadas; `EstadoSalud.habilitado=true` | Alta | | |
| PC-E-03 | Estado de salud refleja gate | Vencida | 1. Abrir `/estado-salud` | Banner "Cuenta incompleta"; siguiente paso sugiere renovar | Alta | | |

## 6. Red y edge cases

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| PC-N-01 | Envío sin red | Modo avión | 1. Enviar cuestionario | `PatientHealthError` con mensaje; sin registros parciales | Alta | | |
| PC-N-02 | Falla de la RPC | Servicio caído | 1. Enviar respuestas | Error controlado; botón "Reintentar" | Media | | |
| PC-N-03 | Sin preguntas configuradas | Cuestionario vacío | 1. Abrir cuestionario | Formulario vacío con botón enviar deshabilitado (0/0) | Media | | |

## 7. Sospechosos de código / deuda

| ID | Título | Detalle | Prioridad | Estado |
|---|---|---|---|---|
| PC-S-01 | Qualify simulado | Sigue simulado (3 s) con datos reales de fechas; integración API Qualify fuera de alcance | Baja | Documentado en plan |
| PC-S-02 | Legacy `SupabaseService` | Face map/geocoding/`checkPatientFlowStatus`/`validateReservationRulesRN020` aún en legacy (marcados deuda) | Baja | Pendiente de migrar |
| PC-S-03 | Edición de preguntas del catálogo | `preguntas` es catálogo compartido: editar una pregunta afecta a versiones históricas (el snapshot `pregunta_texto` protege las evaluaciones ya guardadas) | Media | Revisar política de edición |

## Resumen de ejecución

| Total | Pasa | Falla | Bloqueado | Pendiente |
|---|---|---|---|---|
| 28 | | | | 28 |