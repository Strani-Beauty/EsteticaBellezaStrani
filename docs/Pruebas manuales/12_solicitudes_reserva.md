# Pruebas manuales — solicitudes_reserva (reserva y depósito del paciente)

| | |
|---|---|
| **Módulo** | solicitudes_reserva (creación de solicitud, resumen, depósito y publicación) |
| **Estado del código** | COMPLETO (RPCs + feature Clean Architecture + rutas) |
| **Fecha** | 2026-08-21 |
| **Versión** | 1.1 (resultados parciales verificados 2026-08-21) |

## Alcance

Flujo paciente de extremo a extremo: seleccionar servicio(s) en el catálogo →
`SolicitudResumenScreen` (resumen: servicios, precio, fecha/hora, ubicación, radio) →
pago del depósito (adelanto % o totalidad) por Stripe → `crear_solicitud_reserva`
(`PENDIENTE_PAGO` + detalles + pago PARCIAL) → `confirmar_deposito_solicitud`
(webhook o simulado) → `PUBLICADA` → `MisSolicitudesScreen` (seguimiento).

## Fuera de alcance

Aceptación del especialista (doc 06), ejecución de la cita (doc 09), pago del saldo (doc 08).

## Precondiciones generales

- Paciente con perfil completo, evaluación APTO vigente (gate RN-020) y **dirección principal** en `direcciones_paciente`.
- `configuracion_sistema.enforce_pago_real = 'false'` para pruebas simuladas (sin dinero real); en producción `'true'` (webhook).
- Stripe en test mode (tarjetas 4242...) o modo simulado (STRIPE_SIM).

## 1. Camino feliz

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| RS-H-01 | Resumen de la solicitud | Evaluación APTO | 1. Entrar a `/services` 2. Tocar un servicio | Navega a `SolicitudResumenScreen`: servicio, precio total, depósito (adelanto %), ubicación y radio | Crítica | ✅ | E2E ítem 3 |
| RS-H-02 | Multi-servicio | Resumen abierto | 1. "Agregar" 2. Elegir otro servicio | Se suma al resumen; total y depósito recalculan | Alta | ✅ | E2E ítem 1 |
| RS-H-03 | Fecha/hora preferida | Resumen abierto | 1. "Elegir" 2. Seleccionar fecha y hora | Muestra la preferencia en el resumen | Media | ✅ | E2E ítem 3 |
| RS-H-04 | Crear + pagar depósito | Dirección principal | 1. "Pagar depósito" 2. PaymentSheet (4242) | Solicitud `PENDIENTE_PAGO`; pago OK; confirmación → `PUBLICADA` (o pendiente webhook) | Crítica | ✅ | E2E ítems 2, 4, 5 |
| RS-H-05 | Mis solicitudes | Tras crear | 1. Ir a `/mis-solicitudes` | Lista con estado, servicios, montos y cita (si aceptada) | Alta | ✅ | E2E ítem 2 |
| RS-H-06 | Pago totalidad | Resumen abierto | 1. Activar "¿Pagar totalidad?" 2. Pagar | Depósito = total; `pagos.estado=PAGADO` | Alta | ⬜ | Pendiente de prueba específica |

## 2. Validaciones y casos negativos

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| RS-V-01 | Sin dirección | Paciente sin `direcciones_paciente` | 1. Intentar pagar | Bloqueado: "Registra tu dirección antes de confirmar" | Crítica | ⬜ | Pendiente de prueba específica |
| RS-V-02 | Sin evaluación APTO | RN-020 no vigente | 1. Tocar servicio del catálogo | Modal de evaluación/requisitos (gate previo) | Crítica | ✅ | Gate pre-existente verificado en catálogo (E2E 2026-08-20) |
| RS-V-03 | Pago cancelado | PaymentSheet | 1. Cancelar el pago | "El pago no se completó"; solicitud queda `PENDIENTE_PAGO` en Mis Solicitudes | Alta | ⬜ | Pendiente de prueba específica |
| RS-V-04 | Depósito mínimo | Servicio de precio bajo | 1. Pagar | RPC valida ≥0.50 USD; error claro si aplica | Media | ⬜ | Pendiente de prueba específica |
| RS-V-05 | Publicación directa | Manipular estado | 1. UPDATE directo a `PUBLICADA` sin pago confirmado | Trigger `trg_proteger_publicacion_solicitud` lo bloquea (42501/except) | Crítica | ✅ | E2E ítem 5 (contra-prueba) |

## 3. Seguridad / RLS

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| RS-G-01 | Enforce pago real | `enforce_pago_real=true` | 1. Llamar `confirmar_deposito_solicitud` como paciente | Rechazado (solo webhook); la app muestra "se publicará en unos segundos" | Crítica | ✅ | E2E ítem 5 (gate) |
| RS-G-02 | `solicitud_detalles` RLS | Otro paciente | 1. Leer detalles de solicitud ajena | Sin filas (RLS) | Alta | ⬜ | Pendiente de prueba específica (policy verificada en esquema) |
| RS-G-03 | Especialista lee solicitud aceptada | Cita asignada | 1. Leer la solicitud ACEPTADA de su cita | Visible (revela dirección exacta vía cita) | Crítica | ✅ | E2E ítem 12 |

## Resumen de ejecución

| Total | Pasa | Falla | Bloqueado | Pendiente |
|---|---|---|---|---|
| 14 | 9 | 0 | 0 | 5 |
