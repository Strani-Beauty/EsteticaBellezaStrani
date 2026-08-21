# Pruebas manuales — marketplace_citas

| | |
|---|---|
| **Módulo** | marketplace_citas (mapa de solicitudes y aceptación de citas) |
| **Estado del código** | COMPLETO (datasource con RPCs + MarketplaceCubit en DI) + multi-servicio, geofencing y notificaciones (2026-08-21) |
| **Fecha** | 2026-08-14 (actualizado 2026-08-21) |
| **Versión** | 1.1 |

## Alcance

SpecialistMapScreen (`/specialist/map`): restricción de acceso por verificación, mapa FlutterMap (OSM) con solicitudes y especialistas, orden por cercanía (Haversine), RPC `aceptar_solicitud`. Desde 2026-08-21: solicitudes **multi-servicio** (jsonb) con precio total y preferencia de fecha, **geofencing** server-side por radio (`ST_DWithin`) y notificación in-app a los especialistas del radio cuando otra acepta.

## Fuera de alcance

Ejecución de la cita aceptada (doc 09), publicación de solicitudes vía depósito de reserva (doc 12).

## Precondiciones generales

- `esp.aprobado` con contrato, disponibilidad activa y ubicación guardada.
- `esp.revision` o `esp.rechazado` para pruebas de acceso.
- ⚑ Dos especialistas aprobados+disponibles+online para concurrencia.
- Al menos una solicitud `PUBLICADA` (paciente con pago total, doc 05) y una expirada.

## 1. Camino feliz

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| MK-H-01 | Carga del mapa | `esp.aprobado` | 1. Entrar a `/specialist/map` | Carga dashboard + `MarketplaceCubit.load`: markers de solicitudes y especialistas aprobados; tarjeta de conteo | Crítica | | |
| MK-H-02 | Marker de paciente | Mapa cargado | 1. Tocar marker de solicitud | Detalle del paciente | Alta | | |
| MK-H-03 | Orden por cercanía | Varias solicitudes | 1. "Por cercanía" | Bottom sheet ordenado por distancia Haversine desde mi ubicación | Alta | | |
| MK-H-04 | Aceptar solicitud | Solicitud vigente | 1. Detalle → "Aceptar" | RPC `aceptar_solicitud` → `aceptada`: se elimina de la lista; "¡El paciente es tuyo!"; cita creada | Crítica | | |
| MK-H-05 | Pull-to-refresh | Mapa cargado | 1. Deslizar | Recarga solicitudes/especialistas | Baja | | |
| MK-H-06 | Recentrar y zoom | Mapa cargado | 1. FABs de recentrar/zoom | Centran en mi ubicación / ajustan zoom | Baja | | |

## 2. Validaciones y casos negativos

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| MK-V-01 | Acceso restringido | `esp.revision` (no aprobado) | 1. Entrar a `/specialist/map` | `_AccesoRestringido`; sin mapa | Crítica | | |
| MK-V-02 | Solicitud expirada | Solicitud con `fechaExpiracion` pasada | 1. "Aceptar" | RPC devuelve `expirada`: se elimina de la lista con aviso | Alta | | |
| MK-V-03 | Especialista no aprobado acepta | Vía forzada (cliente manipulado) | 1. Llamar RPC sin estar aprobado | RPC devuelve `noAprobado`: "Solo especialistas verificados y activos…" | Crítica | | |
| MK-V-04 | Solicitud ya asignada | Solicitud aceptada por otro | 1. "Aceptar" | `ASIGNADA`/`NO_ENCONTRADA`: "ya fue asignado" + refresco | Alta | | |

## 3. Roles y permisos (guards / RLS)

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| MK-G-01 | Paciente a `/specialist/map` | Sesión de paciente | 1. Deep link | Guard redirige por rol | Crítica | | |
| MK-G-02 | RPC con sesión de paciente | Paciente | 1. Invocar `obtener_solicitudes_publicadas_geo` | RLS/security definer lo impide o devuelve vacío | Alta | | |
| MK-G-03 | Solo aprobados en el mapa | Especialista BLOQUEADO | 1. Cargar mapa | `fetchEspecialistasAprobados` filtra `APROBADO + activo + disponible + en_linea + ultima_conexion<180s`; el bloqueado no aparece | Alta | | |

## 4. Estados y transiciones

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| MK-E-01 | Ubicación aproximada | Solicitud publicada | 1. Verificar coords del marker | RPC `obtener_solicitudes_publicadas_geo` devuelve ubicación con 3 decimales (RN-018, privacidad) | Alta | | |
| MK-E-02 | Feedback y `clearFeedback` | Aceptación | 1. Observar snackbar | Mensaje según resultado; se limpia al cambiar de estado | Baja | | |
| MK-E-03 | `aceptandoId` durante la llamada | Aceptación lenta | 1. Observar UI mientras corre el RPC | Indicador de carga en el botón; doble tap no duplica la llamada | Alta | | |
| MK-E-04 | Solicitudes solo PUBLICADAS | Solicitud BORRADOR (solo depósito) | 1. Cargar mapa | La BORRADOR no aparece | Crítica | | |

## 5. Red y edge cases

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| MK-N-01 | Carga sin red | Modo avión | 1. Entrar al mapa | Estado `MarketplaceError` con mensaje | Alta | | |
| MK-N-02 | Especialista sin ubicación | Sin `ubicaciones_especialista` | 1. Cargar mapa 2. Pulsar recentrar | Carga sin crash; recentrar no hace nada (sin punto propio) | Media | | |
| MK-N-03 | Tiles OSM sin red | Modo avión | 1. Ver mapa | Mapa sin tiles pero app estable | Baja | | |
| MK-N-04 | Una de las 3 consultas falla | Fallo parcial | 1. Provocar error en una consulta | El primer error gana → estado de error; sin estado parcial corrupto | Media | | |

## 6. Sospechosos de código

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| MK-S-01 | ⚑ Concurrencia de aceptación | 2 especialistas ante la misma solicitud | 1. Ambos pulsan "Aceptar" casi a la vez | "Primer aviso gana": uno recibe `aceptada`, el otro `ASIGNADA`; sin doble cita | Crítica | ✅ | E2E ítems 10-11 (claim atómico) |
| MK-S-02 | Fold que ignora failures | Fallo de red en `aceptar` | 1. Aceptar sin red | **Confirmar bug**: `res.fold((f) => null, …)` no maneja el error; verificar si la UI queda sin feedback o bloqueada | Alta | ✅ | **Corregido 2026-08-21**: `_refrescar` conserva el mapa y avisa "No se pudo actualizar el mapa: …"; test `marketplace_cubit_test` (MK-S-02) |
| MK-S-03 | Getter `expirada` sin uso | Solicitud expirada en lista | 1. Observar si la UI marca expiradas antes del RPC | El getter de la entidad no se usa; la expiración solo la decide el RPC al aceptar | Baja | ⬜ | Pendiente de prueba específica |

## 7. Nuevo (2026-08-21): multi-servicio, geofencing y notificaciones

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| MK-M-01 | Solicitud multi-servicio | Solicitud con `solicitud_detalles` PUBLICADA | 1. Ver detalle del paciente en el mapa | Lista de servicios con cantidad y subtotal; total agregado | Alta | ✅ | E2E ítem 1 |
| MK-M-02 | Preferencia de fecha | Solicitud con `fecha_programada` | 1. Ver detalle | Muestra la fecha/hora preferida por el paciente | Media | ✅ | E2E ítem 3 |
| MK-M-03 | Geofencing por radio | 2 solicitudes, una fuera del radio configurado | 1. Cargar el mapa | Solo aparece la solicitud dentro del radio del especialista | Crítica | ✅ | E2E ítem 7 (smoke2: solo especialistas del radio) |
| MK-M-04 | Radio override por solicitud | Solicitud con `radio_busqueda` propio | 1. Cargar el mapa | Se usa el radio de la solicitud si está definido | Alta | ⬜ | Pendiente de prueba específica |
| MK-M-05 | Notificación a otros | 2 especialistas en el radio | 1. Uno acepta la solicitud | El otro recibe notificación in-app `SOLICITUD_ASIGNADA` | Crítica | ✅ | E2E ítem 11 (smoke2: 2 usuarios) |
| MK-M-06 | Dirección exacta revelada | Cita asignada | 1. Entrar a Mis Citas → detalle | Se revela la dirección exacta (RLS `solicitud_especialista_asignado_select`) | Crítica | ✅ | E2E ítem 12 |
| MK-M-07 | Historial SOLICITUD | Solicitud creada/publicada/aceptada | 1. Consultar `historial_estados` (tipo_entidad=SOLICITUD) | Registra creaciones y cambios de estado | Alta | ✅ | E2E ítem 14 (sin duplicados post-00500) |

## Resumen de ejecución

| Total | Pasa | Falla | Bloqueado | Pendiente |
|---|---|---|---|---|
| 31 | 8 | 0 | 0 | 23 |
