# Plan: Gestión de Citas y Logística del Servicio

| | |
|---|---|
| **Fecha** | 2026-08-24 |
| **Estado** | APROBADO por el usuario (2026-08-24) |
| **Proyecto Supabase** | `hhyjremkguvphmjuaazp` |
| **Decisiones tomadas** | Act. 8: agregar `geolocator` (GPS en vivo). Act. 12: notificar al paciente en cada cambio (in-app + push FCM). |

## Contexto

Completar el ciclo operativo de la cita después de la asignación del especialista:
estados, coordinación de llegada al domicilio y trazabilidad hasta el inicio del
tratamiento. Módulo `treatment_execution` ya implementado de punta a punta.

### Estado de las 13 actividades

1. Citas asignadas (pendientes/próximas/finalizadas): **PARCIAL** (solo activas)
2. Paciente consulta estado solicitud/cita: **IMPLEMENTADO**
3. Estados operativos: **IMPLEMENTADO**
4. Cambio de estado desde app especialista: **IMPLEMENTADO**
5. Registro en `historial_estados`: **IMPLEMENTADO**
6. Navegación a dirección del paciente: **NO IMPLEMENTADO**
7. No exponer dirección antes de aceptación: **IMPLEMENTADO**
8. Registro de llegada (geo): **PARCIAL** (estado LLEGO sí; columnas geo no se escriben)
9. Validación estado correcto para iniciar tratamiento: **PARCIAL** (solo a nivel widget)
10. Cancelar cita con motivo+usuario: **PARCIAL** (datasource muerto; sin usecase/UI)
11. Evitar múltiples citas activas: **IMPLEMENTADO**
12. Notificaciones de cambio de estado de cita: **PARCIAL** (solo asignación)
13. Flujo aceptación→llegada: **IMPLEMENTADO** (huecos 6/8/9/10/12)

## Decisiones

1. **Act. 8**: agregar paquete `geolocator` (GPS en vivo). El proyecto no lo tiene;
   la ubicación se capturaba solo con pin de mapa.
2. **Act. 12**: notificar al paciente en cada cambio de estado (in-app + push FCM
   vía `send-push` + `dispositivos_usuario`, patrón `notificar_solicitud_asignada_push`).
3. **Act. 9**: máquina de estados a nivel servidor con trigger (impide saltos) +
   validación de UI como UX.
4. **Act. 10**: cancelación vía RPC con registro de motivo + usuario.
5. **Act. 6**: navegación con `url_launcher` (ya en pubspec 6.3.1).

## Actividades → implementación

### A. Migración BD `supabase/migrations/20260824000100_cita_estados_logistica.sql` (idempotente)

- [x] A1. Trigger `trg_validar_transicion_estado_cita` + `validar_transicion_estado_cita()` (máquina de estados, Act. 9).
- [x] A2. RPC `registrar_llegada_especialista(p_cita_id, p_latitud, p_longitud)` (Act. 8: escribe latitud_llegada/longitud_llegada/distancia_recorrida).
- [x] A3. RPC `cancelar_cita(p_cita_id, p_motivo)` (Act. 10: CANCELADA + historial con motivo).
- [x] A4. Trigger `trg_notificar_cambio_estado_cita` + `notificar_cambio_estado_cita()` (Act. 12: in-app al paciente + push, BEFORE/AFTER sobre citas.estado). Se usó trigger en lugar del RPC para centralizar y cubrir todos los puntos de transición.
- [x] A5. Verificar RLS notificaciones/historial sin choques. (Los inserts del trigger y del RPC `cancelar_cita` son SECURITY DEFINER → no chocan con RLS; el paciente lee vía `notificacion_own_select`.)
- [x] A6. Aplicar al remoto y verificar. (`supabase db push` OK vía `--db-url` con pooler sesión 6543; única migración pendiente, aplicada el 2026-08-24.)

### B. Capa de datos `treatment_execution`

- [x] B1. Datasource: `fetchCitasHistorial`, `registrarLlegada` (RPC), `cancelarCita` (RPC).
- [x] B2. Repositorio (`ITreatmentExecutionRepository` + impl): `getCitasHistorial`, `registrarLlegada`, `cancelarCita`.
- [x] B3. Entidad: sin cambios necesarios.

### C. Usecases + cubit + DI

- [x] C1. Usecases: `GetCitasHistorial`, `RegistrarLlegada`, `CancelarCita`.
- [x] C2. Cubit: inyectar los 3 por nombre; métodos `loadCitasHistorial`, `registrarLlegada`, `cancelar`.
- [x] C3. DI (`_registerTreatmentExecution`).

### D. UI

- [x] D1. `mis_citas_screen.dart`: tabs Activas/Historial (Act. 1).
- [x] D2. `cita_detalle_screen.dart`: botón "Navegar al domicilio" (Act. 6), GPS en "Llegué al domicilio" (Act. 8), "Cancelar cita" con motivo (Act. 10).

### E. Actividad 12 — notificaciones al paciente

- [x] E1. App: invocar `notificar_cambio_estado_cita` tras cada transición. **Se implementó vía trigger BD `trg_notificar_cambio_estado_cita` (A4)** — centraliza y cubre todos los puntos de transición sin código app adicional.
- [x] E2. Push FCM reutilizando `send-push` (dentro del trigger A4, patrón `notificar_solicitud_asignada_push`).

### F. Paquete `geolocator`

- [x] F1. pubspec + permisos Android/iOS.
- [x] F2. `GeoService` (excepciones propias) que envuelve `geolocator`.

### G. Verificación y documentación

- [x] G1. `flutter analyze` 0 issues; `flutter test` verde (148/148).
- [x] G2. E2E manual `docs/pruebas/2026-08-24_citas_logistica_e2e.md`.

## Notas

- `historial_estados.estado` es `text` — sin cambios.
- No se toca `aceptar_solicitud` (fuente única de creación de cita); las
  transiciones van por app → RPC.
- El `cancelarCita` actual del datasource (UPDATE directo) se reemplaza por RPC.
- `geolocator` es nuevo; requiere permisos de plataforma.
