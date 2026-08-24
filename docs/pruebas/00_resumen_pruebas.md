# Resumen de pruebas realizadas

| | |
|---|---|
| **Fecha de creación** | 2026-08-24 |
| **Cobertura** | Todas las pruebas E2E y de verificación documentadas (2026-08-13 → 2026-08-24) |
| **Índice por módulo** | `docs/Pruebas manuales/00_indice_general.md` |

Resumen cronológico de todas las pruebas realizadas hasta la fecha, con su resultado
y el enlace a la evidencia completa.

## Tabla cronológica

| Fecha | Prueba | Tipo | Resultado | Evidencia |
|---|---|---|---|---|
| 2026-08-13 | Setup E2E `integration_test` (smoke) | Setup | ⬜ Sin ejecutar | [2026-08-13_e2e_setup.md](2026-08-13_e2e_setup.md) |
| 2026-08-13 | Especialistas — Fases 1 a 4 | Tests de código | ✔ 8/8 ítems por fase | [2026-08-13_tests_especialistas_fase1.md](2026-08-13_tests_especialistas_fase1.md) |
| 2026-08-18 | Compliance del especialista + contrato | E2E manual | ✔ 12/12 + 8 fixes | [2026-08-18_compliance_e2e.md](2026-08-18_compliance_e2e.md) |
| 2026-08-19 | Flujo de salud del paciente (RN-020) | E2E manual | ✔ 11/11 | [2026-08-19_salud_paciente_e2e.md](2026-08-19_salud_paciente_e2e.md) |
| 2026-08-20 | Catálogo de servicios (relaciones + flujo) | E2E manual | ✔ R1–R6 + A–H + contra-pruebas | [2026-08-20_catalogos_servicios_e2e.md](2026-08-20_catalogos_servicios_e2e.md) |
| 2026-08-21 | Solicitudes, Reserva y Marketplace | E2E manual | ✔ 14/14 | [2026-08-21_solicitudes_reserva_marketplace_e2e.md](2026-08-21_solicitudes_reserva_marketplace_e2e.md) |
| 2026-08-21 | Push FCM real (solicitud asignada) | E2E manual | ⬜ PENDIENTE (requiere dispositivo) | [2026-08-21_push_fcm_verificacion.md](2026-08-21_push_fcm_verificacion.md) |
| 2026-08-22 | Admin dashboard (KPIs + Datos Maestros) | E2E manual | ✔ migración/RPC verificados; checklist sin marcar | [2026-08-22_admin_dashboard_e2e.md](2026-08-22_admin_dashboard_e2e.md) |
| 2026-08-24 | Gestión de Citas y Logística | E2E manual | ✔ 12/14 PASS | [2026-08-24_citas_logistica_e2e.md](2026-08-24_citas_logistica_e2e.md) |

## Resumen por línea

### 2026-08-13 — Setup E2E `integration_test` (smoke test)
Smoke test de arranque (bienvenida → navegación a login) configurado en
`integration_test/app_test.dart`, pero **no ejecutado**: el emulador Pixel 10 Pro no
arranca por falta de hypervisor (AEHD) y el POCO X3 con MIUI bloquea la reinstalación
vía ADB (`DELETE_FAILED_INTERNAL_ERROR`). Quedaron documentadas las rutas de solución
(WHPX, AEHD, desinstalación manual).

### 2026-08-13 — Especialistas: Fases 1 a 4
- **Fase 1**: registro, información, especialidades, médico regente, estado PENDIENTE, disponibilidad y ubicación — 8/8 ✔.
- **Fase 2**: cubit de especialistas — 8/8 ✔.
- **Fase 3**: widgets + fix de `props` — 8/8 ✔.
- **Fase 4**: mapeo de modelos — 8/8 ✔.

### 2026-08-18 — Compliance del especialista + contrato
E2E completo del expediente de verificación: **12/12 ✔** (documentos privados en
storage, revisión del admin con motivo de rechazo, notificaciones
`DOCUMENTO_RECHAZADO`/`VERIFICACION_APROBADA`, re-subida solo del documento rechazado,
bloqueo del marketplace sin requisitos, estado "Verificado" con gate, disponibilidad →
recibe solicitudes) + firma de contrato v1 (migración `20260818000100`). Se corrigieron
**8 bugs** en el proceso (precedencia de estados en tiles, fix PGRST200 con
`profiles!especialistas_usuario_id_fkey` + migración `20260818000200`).

### 2026-08-19 — Flujo de salud del paciente
E2E del cuestionario/evaluación de salud: **11/11 ✔** (alta del paciente, cuestionario
v2 del admin con 11 preguntas, respuesta, evaluación, Qualify, vencimiento, trigger
RN-020 en BD, renovación con `version_cuestionario=2`). Hallazgo pendiente: el banner
del catálogo no se refresca al volver (solo se inicializa en `initState`).

### 2026-08-20 — Catálogo de servicios
E2E de relaciones y flujo del catálogo: **R1–R6 + A–H ✔** (matriz requisitos/face-map,
match de especialidades con `NO_COINCIDE_ESPECIALIDAD`, RLS de escritura solo admin,
RPCs de reemplazo de relaciones) + contra-pruebas por API. Se resolvieron los hallazgos
1–4 (plan `2026-08-20_fixes_catalogo_hallazgos_1_4.md`) y el hallazgo 7 (duración NOT
NULL). `flutter test` 130, 44 migraciones (Local == Remote). El servicio de prueba
`TEST E2E Sin FaceMap` quedó desactivado.

### 2026-08-21 — Solicitudes, Reserva y Marketplace
E2E del ciclo de reserva y marketplace: **14/14 ✔** (multi-servicio, creación de
solicitud en PENDIENTE_PAGO, resumen, depósito, trigger `trg_proteger_publicacion_solicitud`
anti-publicación sin pago, visibilidad solo para verificados + radio, RN-018 con
dirección oculta, aceptación atómica "primer aviso gana", dirección revelada solo al
asignado, cita PROGRAMADA, historial sin duplicados) + smoke de BD con rollback.
`flutter test` 144/144.

### 2026-08-21 — Push FCM real
Prueba preparada pero **⬜ PENDIENTE**: requiere un dispositivo/emulador Android real
para verificar el push "Solicitud asignada" a los especialistas del radio que perdieron.
El pipeline `send-push` (FCM HTTP v1) ya está operativo (HTTP 200; token falso
rechazado por-token con `InvalidRegistration`). Limitación conocida: sin handler
`onMessage`, el push solo se muestra en segundo plano/cerrada; web requeriría VAPID.

### 2026-08-22 — Admin dashboard
Panel de administración con KPIs y Datos Maestros. Migración `20260822000100` aplicada
y verificada (KPIs con datos reales), `flutter analyze` 0 issues y `flutter test`
148/148. El checklist de 11 ítems de aceptación quedó **sin marcar** (pendiente de
ejecución manual).

### 2026-08-24 — Gestión de Citas y Logística
Ciclo operativo de la cita: **12/14 PASS** en control manual (tabs Activas/Historial,
navegación al domicilio, llegada con GPS y distancia, máquina de estados, cancelación
con motivo, notificaciones de cambio de estado, vista del paciente). Pendientes:
ítem 7 (permiso de ubicación denegado) e ítem 14 (doble claim de solicitud).

## Documentos de pruebas manuales por módulo

Ver `docs/Pruebas manuales/00_indice_general.md` (2026-08-14) y los docs 01–13:

| Doc | Módulo | Estado |
|---|---|---|
| 01–11 | Especialistas, compliance, salud, catálogo, marketplace, etc. | Definidos (2026-08-14) |
| 06 | Marketplace / citas | 23/31 pendientes |
| 12 | Solicitudes y reserva | ⬜ Pendiente (pago totalidad, pago cancelado, depósito mínimo, RLS detalles, radio override) |
| 13 | Admin dashboard | Creado |

## Verificación automatizada por fecha

Evolución de la suite `flutter test` (`flutter analyze` siempre 0 issues):

| Fecha | `flutter test` |
|---|---|
| 2026-08-13 → 08-18 | 80/80 |
| 2026-08-19 | 95/95 |
| 2026-08-20 | 130/130 |
| 2026-08-21 | 144/144 |
| 2026-08-22 y 08-24 | 148/148 |

## Pendientes conocidos

- **Push FCM real** (`2026-08-21_push_fcm_verificacion.md`): requiere dispositivo/emulador.
- **Admin dashboard**: checklist de 11 ítems sin marcar.
- **Citas y logística**: ítems 7 (permiso ubicación) y 14 (doble claim).
- **Pruebas manuales por módulo**: 06 (23/31) y 12 pendientes.
- **Deuda técnica documentada**: buckets de storage públicos (`contratos`,
  `firmas-consentimiento`, `fotografias-tratamiento`).