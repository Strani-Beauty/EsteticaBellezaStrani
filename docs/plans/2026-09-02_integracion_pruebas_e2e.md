# Plan: Integración General y Pruebas End-to-End

| | |
|---|---|
| **Fecha** | 2026-09-02 |
| **Estado** | APROBADO por el usuario (2026-09-02) |
| **Proyecto Supabase** | `hhyjremkguvphmjuaazp` |
| **Decisiones tomadas** | (1) Ejecución **opción 2**: todo se valida vía simulación RPC/BD (sin navegador), con `SET LOCAL ROLE` + claims JWT y transacciones ROLLBACK. (2) Se **documenta como pendiente** una prueba manual UI completa (checklist) en la web desplegada. (3) Los hallazgos de la act. 14 se registran en `docs/pruebas/2026-09-02_integracion_e2e_log.md` y los corregibles se arreglan con migraciones idempotentes. |

## Contexto

Los 15 flujos de la plataforma están implementados (especialistas, pacientes, solicitudes, marketplace/geofencing, first-accept, privacidad progresiva de dirección, ciclo de atención, finanzas/liquidaciones, notificaciones push, calificaciones). Este módulo valida la **integración de extremo a extremo**, detecta inconsistencias de estado entre módulos (act. 13) y registra pendientes (act. 14).

Estado base verificado en el remoto: 41 perfiles, 22 pacientes, 13 especialistas, 5 solicitudes (2 PUBLICADA, 3 ACEPTADA), 3 citas (2 PROGRAMADA, 1 FINALIZADA/PAGADA `85e1d764`), 3 pagos/transacciones, 1 tratamiento COMPLETADO, 1 liquidación PAGADA, 0 evaluaciones, 7 notificaciones.

Config para pruebas: `enforce_pago_real=false` (permite confirmar pago desde app/RPC), `enforce_rn020=true` (valida telemedicina), `simular_llegada=true`, `push_notifications=true`, `radio_busqueda_km=10`, `adelanto_porcentaje=50`.

Cuentas de prueba (clave `Test1234!`): `admin@test`, `esp.aprobado@test` (APROBADO pero **sin geo**), `esp.nuevo@test`, `esp.revision/rechazado/bloqueado/desactivado@test`, `pac.activo@test` (activado), `pac.nuevo@test` (inactivo), `pac.vencido@test` (VENCIDA), `pac.rechazado/desactivado@test`. Especialistas con geo: `especialista1@test.com` (en_línea), `especialista2/3/4@test.com`, `esp.compliance1@test.com`.

## Actividades → implementación

### A. Preparación

- [x] A1. Persistir plan (este archivo).
- [x] A2. Verificar configuración de pruebas (`enforce_pago_real=false`, `simular_llegada=true`, `push_notifications=true`).
- [x] A3. Inventariar catálogo (servicios, precios, `requiere_telemedicina`).

### B. Consistencia de estados (act. 13) — script `verify_e2e_consistencia.js`

- [x] B1. Cadena solicitud→cita: cita con `solicitud_id`; solicitud ACEPTADA ⇒ ≥1 cita.
- [x] B2. `pagos`: 1 por solicitud; `deposito + saldo_pendiente <= monto_total`; estado coherente (saldo 0 ⇒ PAGADO).
- [x] B3. `transacciones`: cita FINALIZADA ⇒ SALDO APROBADO; solicitud PUBLICADA ⇒ DEPOSITO/PAGO_TOTAL APROBADO (solo solicitudes con fila en `pagos`; las legacy pre-flujo no tienen transacciones → hallazgo E2E-H1); sin huérfanas.
- [x] B4. Tratamiento↔cita: cita FINALIZADA ⇔ tratamiento COMPLETADO (1:1).
- [x] B5. Liquidaciones: detalle ⊆ FINALIZADAS pagadas; Σ detalle = monto liquidación; comisión = % config.
- [x] B6. Evaluaciones: solo FINALIZADAS; UNIQUE(cita_id, evaluador_id).
- [x] B7. Notificaciones: usuario destino existe.
- [x] B8. Salida: log de incoherencias → alimenta act. 14 (E2E-H1).

### C. Flujos E2E por RPC (act. 1-12) — simulación BD

- [x] C1. (act 1) Especialista: verificación PENDIENTE→EN_REVISION→APROBADO; dueño NO puede auto-aprobar (trigger lo bloquea), admin sí.
- [x] C2. (act 2) Paciente: onboarding→cuestionario (`guardar_respuestas_evaluacion` APTO)→telemedicina (`registrar_validacion_telemedicina`)→`profiles.activo`.
- [x] C3. (act 3) Solicitud: `crear_solicitud_reserva` (PENDIENTE_PAGO)→`confirmar_deposito_solicitud` (PUBLICADA).
- [x] C4. (act 4) Geofencing: solicitud cerca → solo especialista con geo la ve; sin geo o fuera de radio no.
- [x] C5. (act 5) First-Accept: 1º acepta→cita; 2º → ASIGNADA/EXPIRADA.
- [x] C6. (act 6) Privacidad progresiva: `obtener_solicitudes_publicadas_geo` devuelve coords truncadas (3 decimales) sin dirección/teléfono; tras aceptar, la dirección exacta es visible.
- [x] C7. (act 7) Ciclo de atención: PROGRAMADA→EN_CAMINO→LLEGO (`registrar_llegada_especialista`)→EN_PROCESO (consentimiento, evaluación, face map, productos, fotos PRE/POST)→COMPLETADO + FINALIZADA.
- [x] C8. (act 8) Financiero: depósito→saldo (`confirmar_pago_saldo`)→transacción SALDO→comisión→liquidación.
- [x] C9. (act 9) Corte semanal multi-especialista: `generar_liquidaciones` agrupa por especialista.
- [x] C10. (act 10) Pago manual: `registrar_pago_especialista` (método/referencia/comprobante) tras aprobar la liquidación.
- [x] C11. (act 11) Push: notificaciones por estados de solicitud/cita (SOLICITUD_NUEVA, SOLICITUD_ACEPTADA, CITA_ESTADO, PAGO, LIQUIDACION, RECORDATORIO_CITA).
- [x] C12. (act 12) Calificaciones: paciente→especialista y especialista→paciente; promedio.

### D. Escenario integral simulado (act. 15)

- [x] D1. Seed: 2 pacientes (1 con dirección geo, otro activado vía telemedicina), 2+ especialistas geo, catálogo.
- [x] D2. Flujo combinado: 2 solicitudes simultáneas→publicación→geofencing→first-accept→1 cita ejecutada + 1 cancelada (`cancelar_cita`)→finanzas→calificaciones→notificaciones.
- [x] D3. Verificar `admin_resumen_kpis` refleja el escenario.

### E. Log de hallazgos y correcciones (act. 14)

- [x] E1. `docs/pruebas/2026-09-02_integracion_e2e_log.md`: tabla de resultados por fase + hallazgo E2E-H1 detallado.
- [ ] E2. Corregir hallazgos de código/migración (idempotentes) y verificar. (E2E-H1 es dato de prueba heredado pre-flujo de pagos; se documenta con acción recomendada de saneamiento, sin migración por el momento.)

### F. Verificación final + checklist manual pendiente

- [x] F1. `flutter analyze` 0 issues + `flutter test` 366/366.
- [x] F2. Sin correcciones de código → no requiere re-deploy a Firebase.
- [x] F3. Checkpoints `[x]` en este plan.
- [x] F4. Checklist de prueba manual UI completa (pendiente documentado) en `docs/pruebas/2026-09-02_integracion_e2e_checklist_manual.md`.

## Notas

- Todas las simulaciones usan ROLLBACK (sin residuos en BD) salvo el seed del escenario D (que se marca y se puede limpiar).
- Patrón `SET LOCAL ROLE authenticated` + `set_config('request.jwt.claim.sub'/'request.jwt.claims')`; resolver `sub` como superusuario antes del cambio de rol (RLS filtra).
- Los scripts de BD viven en `C:\Users\Jaime\AppData\Local\Temp\opencode\pgcheck`.