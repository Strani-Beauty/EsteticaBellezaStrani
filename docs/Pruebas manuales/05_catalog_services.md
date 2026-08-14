# Pruebas manuales — catalog_services

| | |
|---|---|
| **Módulo** | catalog_services (catálogo de servicios y reserva) |
| **Estado del código** | COMPLETO (datasource + repo + CatalogCubit en DI) |
| **Fecha** | 2026-08-14 |
| **Versión** | 1.0 |

## Alcance

ServicesDashboardScreen (`/services`, pública): banner de estado médico, chips de categorías, grid de servicios, reglas de reserva RN-020/RN-022, enrutamiento a face map y pagos.

## Fuera de alcance

Mecánica interna de pagos (doc 08), face map (doc 07), onboarding del paciente (docs 01/07).

## Precondiciones generales

- Servicios activos con categorías activas en BD; al menos un servicio facial/inyectable (`requiere_face_map` o categoría "Inyectables"/"Rejuvenecimiento Facial").
- Cuentas: sin sesión, `pac.nuevo` (evaluación PENDIENTE), `pac.activo` (APROBADA vigente), `pac.vencido`, `pac.rechazado`.
- Configuración `deposito_reserva` en `configuracion_sistema`.

## 1. Camino feliz

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| CS-H-01 | Catálogo público | Sin sesión | 1. Entrar a `/services` | Categorías activas + servicios activos con join `categorias_servicio`; grid visible | Crítica | | |
| CS-H-02 | Filtrar por categoría | Catálogo cargado | 1. Pulsar chip de categoría | Solo servicios de esa categoría | Alta | | |
| CS-H-03 | Volver a "Todos" | Filtro activo | 1. Pulsar "Todos" | `selectCategoria(null)` restaura todo el catálogo | Media | | |
| CS-H-04 | Banner verde | `pac.activo` | 1. Entrar a `/services` | Banner APROBADA y vigente (verde) | Media | | |
| CS-H-05 | Reserva con pago total | `pac.activo`, servicio seleccionado | 1. Seleccionar servicio 2. Modal "Cancelar Servicio" → "Cancelar Totalidad ($precio)" 3. Pagar | `procesarPagoStripe(PAGO_TOTAL)` → `createServicePayment` → solicitud **PUBLICADA**; diálogo de éxito | Crítica | | |
| CS-H-06 | Reserva con depósito | `pac.activo` | 1. "Cancelar Depósito ($30)" 2. Pagar | `procesarPagoStripe(DEPOSITO)` → solicitud **BORRADOR**; diálogo de éxito | Crítica | | |

## 2. Validaciones y casos negativos

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| CS-V-01 | Selección sin sesión | Sin sesión | 1. Seleccionar servicio | Diálogo "Regístrate como paciente" → `/login?registro=paciente` | Alta | | |
| CS-V-02 | Evaluación RECHAZADA | `pac.rechazado` | 1. Seleccionar servicio | Modal bloqueado (RN-020/RN-022); no permite pagar | Crítica | | |
| CS-V-03 | Evaluación VENCIDA | `pac.vencido` | 1. Seleccionar servicio | Modal de expiración con "Pagar $30 y Renovar" → `/complete-profile` | Alta | | |
| CS-V-04 | Evaluación PENDIENTE | `pac.nuevo` | 1. Seleccionar servicio | Modal "Completar Evaluación" → `/complete-profile` | Alta | | |
| CS-V-05 | Pago cancelado | `pac.activo` | 1. Elegir pago 2. Cancelar PaymentSheet | Flujo abortado; sin solicitud ni pago registrados | Crítica | | |
| CS-V-06 | Pago fallido | Error de Stripe | 1. Provocar fallo | Snackbar de fallo de pago (distinto del de registro) | Alta | | |
| CS-V-07 | Pago OK, registro fallido | Fallo posterior al pago | 1. Simular fallo en `createServicePayment` | Snackbar específico de fallo de registro; verificar si queda pago huérfano | Alta | | |
| CS-V-08 | Categoría sin servicios | Categoría vacía | 1. Filtrar | Grid vacío controlado | Baja | | |

## 3. Roles y permisos (guards / RLS)

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| CS-G-01 | Ruta pública | Sin sesión | 1. `/services` | Accesible sin autenticación | Media | | |
| CS-G-02 | Especialista en catálogo | Sesión de especialista | 1. Entrar a `/services` 2. Intentar reservar | Comportamiento definido: el guard no bloquea; verificar reglas RN-020 con perfil no-paciente | Media | | |
| CS-G-03 | RLS de lectura de catálogo | Sin sesión | 1. Cargar servicios | Solo servicios/categorías `activo=true` visibles | Alta | | |

## 4. Estados y transiciones

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| CS-E-01 | Estados del cubit | — | 1. Cargar catálogo | `CatalogLoading` → `CatalogLoaded(categorias, servicios, selectedCategoriaId)` | Baja | | |
| CS-E-02 | Banner por estado de evaluación | Cada cuenta de prueba | 1. Revisar banner | APROBADA vigente → verde; VENCIDA → naranja renovar $30; otro → "evaluación requerida" | Alta | | |
| CS-E-03 | Depósito → no publicada | Reserva con depósito | 1. Verificar solicitud en BD | Estado `BORRADOR`; NO aparece en el marketplace | Crítica | | |
| CS-E-04 | Total → publicada | Reserva total | 1. Verificar solicitud en BD | Estado `PUBLICADA`; visible en el marketplace (doc 06) | Crítica | | |

## 5. Red y edge cases

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| CS-N-01 | Carga sin red | Modo avión | 1. Entrar a `/services` | Estado `CatalogError` con Reintentar | Alta | | |
| CS-N-02 | Sin servicios en BD | Catálogo vacío | 1. Cargar | Vista vacía controlada | Baja | | |
| CS-N-03 | Grid responsive | Distintos tamaños de ventana | 1. Redimensionar | Columnas se adaptan sin overflow | Baja | | |

## 6. Sospechosos de código

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| CS-S-01 | Face map sin tratamientoId | Servicio facial | 1. Seleccionar servicio facial/inyectable | **Confirmar bug**: push a `/face-map-questionnaire` siempre sin `extra` → `tratamientoId=null`; el face map queda sin vincular al servicio | Alta | | |
| CS-S-02 | Detección facial por nombre | Servicio con `requiere_face_map=false` pero nombre "Inyectables" | 1. Seleccionar | La heurística por nombre/categoría lo envía a face map igualmente | Media | | |
| CS-S-03 | `copyWith` de categoría | Filtro activo | 1. `selectCategoria(null)` | Permite resetear a null (no usa `??`); comportamiento correcto | Baja | | |

## Resumen de ejecución

| Total | Pasa | Falla | Bloqueado | Pendiente |
|---|---|---|---|---|
| 27 | | | | 27 |
