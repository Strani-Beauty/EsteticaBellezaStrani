# Pruebas de integración End-to-End (E2E) — Log de ejecución y hallazgos

| | |
|---|---|
| **Fecha** | 2026-09-02 |
| **Versión** | 1.0 |
| **Entorno** | Simulación RPC/BD contra el remoto (node `pg`, transacciones con `ROLLBACK`) |
| **Plan** | `docs/plans/2026-09-02_integracion_pruebas_e2e.md` |
| **Proyecto Supabase** | `hhyjremkguvphmjuaazp` |
| **Scripts** | `verify_e2e_consistencia.js`, `verify_e2e_flujos.js`, `verify_e2e_integral.js` (en `%TEMP%\opencode\pgcheck`) |

## Alcance

Se ejecutaron las 15 actividades de integración mediante simulación de las llamadas
reales de la app contra la BD remota (roles `authenticated` + claims JWT), en
transacciones que siempre hacen `ROLLBACK` (no quedan datos residuales). La prueba
**manual UI completa** queda como pendiente documentado en
`docs/pruebas/2026-09-02_integracion_e2e_checklist_manual.md`.

## Resultados por fase

| Fase | Actividades | Script | Resultado |
|---|---|---|---|
| B — Consistencia de estados (act 13) | B1 solicitud↔cita, B2 pagos, B3 transacciones, B4 tratamiento↔cita, B5 liquidaciones, B6 evaluaciones, B7 notificaciones | `verify_e2e_consistencia.js` | **18 PASS / 1 hallazgo** (E2E-H1) |
| C — Flujos E2E por RPC (act 1-12) | verificación especialista, onboarding paciente, solicitud→PUBLICADA, geofencing, privacidad, first-accept, ciclo de atención, financiero, corte semanal, pago manual, notificaciones, calificaciones | `verify_e2e_flujos.js` | **18/18 PASS** |
| D — Escenario integral (act 15) | 2 pacientes + 2 solicitudes simultáneas, 2 especialistas, 1 cita ejecutada + 1 cancelada, finanzas, calificaciones, KPI admin | `verify_e2e_integral.js` | **8/8 PASS** |

## Hallazgos (actividad 14)

### E2E-H1 — Solicitud legacy `PUBLICADA` sin transacciones ni dirección (abierta)

- **Dónde**: solicitud `ade47773-4e3a-4682-a8cb-a01cd54e08da` (paciente
  `818399b1-15dc-4848-a65a-2e221aa9cef3` "Paciente Compliance Uno", creada
  2026-08-21), pago `6eb9dee1-0ec6-45f8-9654-7b99b4741a8d`.
- **Qué**: estado `PUBLICADA`, `deposito_pagado=true`, pago `PAGADO`
  (monto_total=180, deposito=180, saldo_pendiente=0) pero **0 transacciones**
  y **sin `direccion_id`**.
- **Impacto**: el check de consistencia "solicitud con pago → depósito APROBADO"
  falla para esta fila (no hay transacción DEPOSITO) y, al no tener dirección,
  la solicitud **no aparece en el marketplace** (exclusión silenciosa del
  geofencing).
- **Causa**: dato creado por el flujo **legacy pre-pagos** (antes del módulo de
  pagos con transacciones) y/o por SQL Editor en pruebas manuales antiguas.
- **Clasificación**: dato de prueba heredado, no un defecto del flujo actual.
  **Acción recomendada**: limpiar/anular esta solicitud en una migración de
  saneamiento si persiste en producción (documentado; no se borra en esta
  iteración para no tocar datos de prueba).

### Notas de verificación

- Invariante de pagos corregido a `deposito + saldo_pendiente <= monto_total`
  (tras `confirmar_pago_saldo` el depósito conserva el adelanto y el saldo va a 0).
- El check de transacciones se restringe a solicitudes **con** fila en `pagos`
  (las legacy pre-flujo de pagos no tienen transacciones).
- Al verificar historial de estados dentro de una misma transacción, dos filas
  pueden compartir el mismo `now()` → el `ORDER BY fecha_estado DESC LIMIT 1` da
  orden indeterminado; se usa `count(*) WHERE estado='...'` en su lugar.

## Cobertura detallada (Fase C, act 1-12)

1. **Registro/verificación especialista**: el dueño NO puede auto-aprobarse
   (trigger `trg_proteger_verificacion_especialista` bloquea); el admin puede
   mover `PENDIENTE → EN_REVISION`. PASS.
2. **Flujo completo paciente**: `guardar_respuestas_evaluacion` (cuestionario 5,
   respuestas "No"/"Ninguno") → resultado `APTO`; `registrar_validacion_telemedicina`
   → activa `profiles.activo/payment_completed/evaluation_passed`. PASS.
3. **Solicitud → Marketplace**: `crear_solicitud_reserva` (Botox 9.95, depósito
   4.98) + `confirmar_deposito_solicitud` → `PUBLICADA`. PASS.
4. **Geofencing**: el especialista con geo ve la solicitud dentro del radio
   (coordenadas truncadas a 3 decimales, ~110 m); el especialista sin geo ve 0.
   PASS.
5. **First-Accept**: el primer especialista gana (`aceptar_solicitud` → cita);
   el segundo recibe `ASIGNADA`. PASS.
6. **Privacidad progresiva**: antes de aceptar solo hay coordenadas aproximadas
   y ciudad; la dirección exacta se revela tras la aceptación (RLS
   `direccion_paciente_especialista_cita`). PASS.
7. **Ciclo de atención**: EN_CAMINO → LLEGO (+ `registrar_llegada_especialista`)
   → EN_PROCESO (tratamiento + consentimiento + productos + 2 fotos PRE/POST +
   face map + puntos) → COMPLETADO / FINALIZADA con historial. PASS.
8. **Ciclo financiero**: `confirmar_pago_saldo` → transacción SALDO APROBADO +
   `pagos` PAGADO/saldo 0. PASS.
9. **Corte semanal multi-especialista**: `generar_liquidaciones` agrupa por
   especialista (comisión 20 %, solo citas FINALIZADAS con tratamiento COMPLETADO
   y pago PAGADO). PASS.
10. **Pago manual con comprobante**: `cambiar_estado_liquidacion` EN_REVISION →
    APROBADA, luego `registrar_pago_especialista` (Transferencia, referencia,
    comprobante en bucket privado) → liquidación PAGADA + pago en
    `pagos_especialistas`. PASS.
11. **Notificaciones push**: paciente {CITA_ESTADO:4, PAGO:2, SOLICITUD_ACEPTADA:1},
    especialista {LIQUIDACION:2, SOLICITUD_NUEVA:1}. PASS.
12. **Calificaciones post-atención**: paciente→especialista (5) y
    especialista→paciente (4) en una sola tabla bidireccional;
    `get_promedio_especialista` → {promedio:5, total:1}. PASS.

## Escenario integral (Fase D, act 15) — 8/8

- 2 pacientes activados + 2 solicitudes simultáneas PUBLICADAS (A y B) con geo.
- Ambos especialistas (esp1, espCompliance) ven y aceptan (2 citas PROGRAMADAS).
- Cita A: ciclo completo → FINALIZADA; Cita B: `cancelar_cita` → CANCELADA con
  historial.
- Saldo A pagado; `generar_liquidaciones` solo incluye la cita A (liqA=1, liqB=0).
- Calificaciones bidireccionales en la cita A; `admin_resumen_kpis()` OK.

## Estado

- `flutter analyze`: 0 issues.
- `flutter test`: 366/366.
- Sin cambios de esquema en esta fase (solo verificación; ninguna migración nueva).
- Checklist manual UI completa: **pendiente** (documentado en
  `docs/pruebas/2026-09-02_integracion_e2e_checklist_manual.md`).