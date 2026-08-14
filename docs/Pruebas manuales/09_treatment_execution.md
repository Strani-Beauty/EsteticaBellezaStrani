# Pruebas manuales — treatment_execution

| | |
|---|---|
| **Módulo** | treatment_execution (ejecución de citas a domicilio) |
| **Estado del código** | COMPLETO (datasource + repo + TreatmentExecutionCubit con 12 usecases en DI) |
| **Fecha** | 2026-08-14 |
| **Versión** | 1.0 |

## Alcance

MisCitasScreen (`/specialist/mis-citas`), CitaDetalleScreen (`/specialist/mis-citas/:id`), FirmaConsentimientoScreen, máquina de estados PROGRAMADA→EN_CAMINO→LLEGO→EN_PROCESO→FINALIZADA, tratamiento, insumos, consentimiento, cobro de saldo.

## Fuera de alcance

Aceptación de la cita (doc 06), mecánica de pagos (doc 08), fotografías (doc 10).

## Precondiciones generales

- `esp.aprobado` con citas aceptadas en estados ejecutables.
- Citas con `solicitudId` y pagos: una con saldo pendiente, una pagada en su totalidad.
- Una cita CANCELADA/NO_COMPLETADA para solo lectura.

## 1. Camino feliz

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| TE-H-01 | Lista de citas | Citas ejecutables | 1. Entrar a `/specialist/mis-citas` | Lista PROGRAMADA/EN_CAMINO/LLEGO/EN_PROCESO ordenada por `fecha_aceptacion`, con chip de estado, paciente, servicio, ciudad | Crítica | | |
| TE-H-02 | Desplazamiento | Cita PROGRAMADA | 1. Abrir detalle 2. "Comenzar desplazamiento" | Estado EN_CAMINO + registro en `historial_estados` | Crítica | | |
| TE-H-03 | Llegada | Cita EN_CAMINO | 1. "Llegué al domicilio" | Estado LLEGO | Crítica | | |
| TE-H-04 | Inicio de servicio | Cita LLEGO | 1. "Iniciar servicio" | Estado EN_PROCESO + `fecha_inicio`; `iniciarTratamiento` crea/recupera tratamiento INICIADO | Crítica | | |
| TE-H-05 | Evaluación inicial | Cita EN_PROCESO | 1. Editar evaluación 2. Guardar | `guardarEvaluacion` persiste | Alta | | |
| TE-H-06 | Agregar insumo | Cita EN_PROCESO | 1. Diálogo: nombre, fabricante, lote, cantidad, unidad 2. Guardar | `agregarProducto` crea fila (cantidad default 1) | Alta | | |
| TE-H-07 | Eliminar insumo | Insumo agregado | 1. Eliminar | `eliminarProducto` borra | Media | | |
| TE-H-08 | Consentimiento firmado | Cita EN_PROCESO | 1. Sección firma → dibujar → confirmar | PNG en bucket `firmas-consentimiento`; fila en `consentimientos_tratamiento` (tipo TRATAMIENTO_ESTETICO) | Crítica | | |
| TE-H-09 | Finalización con saldo cobrado | Cita con saldo pendiente | 1. "Finalizar tratamiento" 2. Observaciones 3. "Cobrar y Finalizar" 4. Pagar | Pago de saldo + `finalizar`: tratamiento COMPLETADO, cita FINALIZADA, `fecha_finalizacion`, historial tipo CITA; pop automático | Crítica | | |
| TE-H-10 | Finalización sin saldo | Cita pagada totalmente | 1. "Finalizar tratamiento" 2. Confirmar | Finaliza directo sin diálogo de cobro | Alta | | |

## 2. Validaciones y casos negativos

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| TE-V-01 | Insumo sin nombre | Diálogo de producto | 1. Nombre vacío 2. Guardar | Validator bloquea | Media | | |
| TE-V-02 | Firma vacía | Pantalla de firma | 1. Confirmar sin dibujar | Validación impide guardar | Media | | |
| TE-V-03 | Pago de saldo cancelado | Diálogo de cobro | 1. Cancelar PaymentSheet | **No se finaliza la cita**; la cita sigue EN_PROCESO | Crítica | | |
| TE-V-04 | Pago de saldo fallido | Fallo Stripe | 1. Provocar fallo | Cita sin finalizar; error informado | Alta | | |
| TE-V-05 | Lista vacía | Especialista sin citas | 1. Entrar a mis-citas | Vista vacía con icono | Baja | | |

## 3. Roles y permisos (guards / RLS)

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| TE-G-01 | Paciente a `/specialist/mis-citas` | Sesión de paciente | 1. Deep link | Guard redirige por rol | Crítica | | |
| TE-G-02 | Especialista A ve cita de B | Cita ajena | 1. Deep link con id de otro especialista | RLS impide leer/modificar la cita ajena | Crítica | | |
| TE-G-03 | `historial_estados` con usuario | Cualquier transición | 1. Revisar BD | Cada cambio inserta historial con `usuario_id` del autenticado | Media | | |

## 4. Estados y transiciones

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| TE-E-01 | Orden correcto completo | Cita PROGRAMADA | 1. Recorrer EN_CAMINO→LLEGO→EN_PROCESO→FINALIZADA | Cada transición persiste y actualiza UI | Crítica | | |
| TE-E-02 | Transición inválida | Cita PROGRAMADA | 1. Forzar salto a EN_PROCESO (cliente manipulado) | El cliente NO valida: verificar respuesta del servidor (¿rechaza o acepta?) | Alta | | |
| TE-E-03 | Cita CANCELADA | Cita cancelada | 1. Abrir detalle | "Cita sin ejecutar", solo lectura | Media | | |
| TE-E-04 | Cita NO_COMPLETADA | Cita no completada | 1. Abrir detalle | Solo lectura | Media | | |
| TE-E-05 | Pop al finalizar | Finalización exitosa | 1. Observar navegación | `listenWhen` específico dispara pop al llegar a FINALIZADA | Media | | |
| TE-E-06 | `iniciarTratamiento` idempotente | Tratamiento ya INICIADO | 1. Reabrir detalle y volver a iniciar | Recupera el tratamiento existente; no duplica | Alta | | |

## 5. Red y edge cases

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| TE-N-01 | Carga sin red | Modo avión | 1. Entrar a mis-citas | Estado `Error(message)` con mensaje | Alta | | |
| TE-N-02 | Transición sin red | Modo avión | 1. Avanzar estado | Verificar feedback al usuario (ver sospechoso TE-S-01) | Alta | | |
| TE-N-03 | Subida de firma sin red | Modo avión | 1. Firmar | Snackbar de error; sin fila huérfana | Alta | | |
| TE-N-04 | Joins incompletos | Cita sin dirección del paciente | 1. Abrir detalle | Nulls manejados; sin crash | Media | | |

## 6. Sospechosos de código

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| TE-S-01 | Navegación rota al detalle | Lista con citas | 1. Tocar cualquier cita | **RESUELTO (2026-08-14)**: `mis_citas_screen` ahora navega con `AppRoutes.misCitasDetalleDe(id)` (path con el id real); el detalle ya no recibe el literal `':id'`. Verificar que el detalle carga | Crítica | | |
| TE-S-02 | Errores de `avanzar` tragados | Fallo en transición | 1. Provocar fallo | **Confirmar bug**: el fold descarta la failure y re-emite el estado previo sin mensaje; el usuario no se entera | Alta | | |
| TE-S-03 | Finalizar sin consentimiento | Cita sin firma | 1. Finalizar sin firmar | La UI no exige la firma; verificar si el negocio lo requiere | Media | | |
| TE-S-04 | `cancelarCita` sin exponer | — | 1. Buscar forma de cancelar desde la UI | El datasource tiene `cancelarCita` pero ningún usecase/cubit lo expone; laguna funcional | Media | | |
| TE-S-05 | Estados sin Equatable | — | 1. Provocar rebuilds | El cubit no usa Equatable: verificar rebuilds innecesarios o listeners duplicados | Baja | | |

## Resumen de ejecución

| Total | Pasa | Falla | Bloqueado | Pendiente |
|---|---|---|---|---|
| 33 | | | | 33 |
