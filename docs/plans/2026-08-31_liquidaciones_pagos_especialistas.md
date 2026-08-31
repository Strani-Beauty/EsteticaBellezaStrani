# Plan: Liquidaciones y Pagos a Especialistas

| | |
|---|---|
| **Fecha** | 2026-08-31 |
| **Estado** | APROBADO por el usuario (2026-08-31) |
| **Proyecto Supabase** | `hhyjremkguvphmjuaazp` |
| **Decisiones tomadas** | (1) Estados `PENDIENTE\|EN_REVISION\|APROBADA\|PAGADA\|ANULADA` con trigger de transición (patrón `trg_validar_transicion_estado_cita`). (2) Pago externo vía RPC SECURITY DEFINER admin-only que INSERT `pagos_especialistas` + marca `PAGADA` (idempotente; monto por defecto = `monto_pagar` neto). (3) Comprobante en bucket privado `comprobantes-pagos` con `uploadBinary` + URL firmada (patrón fotografías). (4) Clave config `inicio_semana_liquidacion` (1=lunes) para período por defecto en UI. (5) `generar_liquidaciones` existente se mantiene intacto. (6) Se agrega `fetchCitasFinalizadasAdmin({desde, hasta})` para que el admin vea las citas FINALIZADAS pagadas del período antes de generar el corte (resuelve el bloqueo: el admin no podía ver citas terminadas por fecha). |

## Contexto

El RPC `generar_liquidaciones` (migración `20260828000100`) ya agrupa por especialista e inserta `liquidaciones_especialistas` + `liquidacion_detalles` + `comisiones`. Faltan: máquina de estados, aprobación, pago externo con comprobante en Storage, período semanal configurable, y la vista de citas terminadas por fecha (el admin solo podía consultar detalle pegando un UUID). Tablas/RLS admin-only ya existen (`20260822000100`), FKs ok (`20260822000200`). `PagoEspecialistaEntity` no tiene `comprobanteUrl`; `LiquidacionEntity.estado` es `String?`.

## Actividades → implementación

### A. Migración `supabase/migrations/20260831000100_liquidaciones_estados_pagos_especialistas.sql`

- [x] A1. CHECK en `liquidaciones_especialistas.estado`:
  `CHECK (estado = ANY (ARRAY['PENDIENTE','EN_REVISION','APROBADA','PAGADA','ANULADA']))`.
- [x] A2. Trigger `trg_validar_transicion_estado_liquidacion` (BEFORE UPDATE OF estado,
  solo admin; matriz PENDIENTE→EN_REVISION/ANULADA; EN_REVISION→APROBADA/ANULADA;
  APROBADA→PAGADA/ANULADA).
- [x] A3. RPC `cambiar_estado_liquidacion(p_liquidacion_id uuid, p_nuevo_estado text)`
  RETURNS json SECURITY DEFINER admin-only (GRANT authenticated).
- [x] A4. RPC `registrar_pago_especialista(p_liquidacion_id uuid, p_metodo_pago text,
  p_referencia_pago text, p_comprobante_url text, p_notas text, p_monto_pagado numeric
  DEFAULT NULL)` RETURNS json SECURITY DEFINER admin-only: valida `APROBADA`
  (NO_ENCONTRADA/ESTADO_INVALIDO/YA_PAGADA), INSERT `pagos_especialistas`, UPDATE
  liquidación `PAGADA` + `fecha_pago` (GRANT authenticated).
- [x] A5. Seed `inicio_semana_liquidacion` = '1' (NUMERIC) en `configuracion_sistema`.
- [x] A6. Bucket privado `comprobantes-pagos` + policy storage admin ALL/SELECT.

### B. Capa de datos/dominio

- [x] B1. `financiero_entity.dart`: enum `EstadoLiquidacion` (toDb/fromDb),
  `LiquidacionEntity.estado`→enum, `DetalleLiquidacionEntity`, `PagoEspecialistaEntity.comprobanteUrl`,
  `CitaFinalizadaAdminEntity`.
- [x] B2. `i_admin_master_data_repository.dart` + impl: `getCitasFinalizadasAdmin`,
  `getLiquidacionDetalles`, `cambiarEstadoLiquidacion`, `registrarPagoEspecialista`,
  `subirComprobantePago`, `firmarComprobante`.
- [x] B3. `admin_master_data_supabase_datasource.dart`: RPCs + `fetchCitasFinalizadasAdmin`
  (join citas→solicitudes→pagos→especialistas + tratamiento COMPLETADO + NOT EXISTS
  liquidacion_detalles, filtro `fecha_finalizacion` rango) + upload comprobante a bucket +
  parse `comprobante_url` en `fetchPagosEspecialistas`.
- [x] B4. Usecases: `GetCitasFinalizadasAdmin`, `GetLiquidacionDetalles`,
  `CambiarEstadoLiquidacion`, `RegistrarPagoEspecialista`, `SubirComprobantePago`,
  `GetInicioSemanaLiquidacion`, `FirmarComprobante`.

### C. Cubit + DI

- [x] C1. `AdminConciliacionCubit` inyecta `GetCitasFinalizadasAdmin` +
  `GetInicioSemanaLiquidacion`; estado con `citasFinalizadas`, `inicioSemana`,
  `cargandoCitas`; métodos `cargarCitasPorPeriodo({desde, hasta})` y `rangoUltimaSemana(hoy)`.
- [x] C2. `AdminComisionesCubit` inyecta `CambiarEstadoLiquidacion`, `RegistrarPagoEspecialista`,
  `SubirComprobantePago`, `GetLiquidacionDetalles`; métodos `cambiarEstado`,
  `registrarPago`, `cargarDetalles`.
- [x] C3. `injection.dart`: registrar usecases y actualizar cubits.

### D. UI

- [x] D1. `admin_conciliacion_screen.dart`: tab "Citas terminadas" con selector de período
  (`showDateRangePicker`, por defecto última semana completa según `inicio_semana_liquidacion`)
  que lista las citas terminadas elegibles (especialista, bruto/depósito/saldo, estado) →
  desde ahí se genera la liquidación.
- [x] D2. `admin_comisiones_screen.dart`: `_LiquidacionCard` con chip de estado coloreado +
  botones contextuales (PENDIENTE→Enviar a revisión; EN_REVISION→Aprobar/Anular;
  APROBADA→Registrar pago) + detalle expandible por cita; diálogo "Registrar pago"
  (método Transferencia/Efectivo/Cheque/Otro, referencia, notas, monto, adjuntar comprobante con
  `image_picker` → subir → RPC → recarga) + ver comprobante con URL firmada.
- [x] D3. `_generarLiquidacion` con período por defecto = última semana completa (lunes-domingo).
- [ ] D4. Historial por especialista (búsqueda/filtro).

### E. Constantes + verificación

- [x] E1. `app_constants.dart`: `bucketComprobantes`, estados liquidación,
  `rpcCambiarEstadoLiquidacion`, `rpcRegistrarPagoEspecialista`, `inicioSemanaLiquidacionClave`.
- [x] E2. `flutter analyze` 0 issues + `flutter test` 366/366.
- [ ] E3. Pruebas manuales del ciclo completo (Act. 15) con la cita 85e1d764
  (FINALIZADA/PAGADA): ver citas por fecha → generar corte → revisar → aprobar → pago
  externo → subir comprobante → liquidación PAGADA.
- [x] E4. Plan actualizado con checkpoints `[x]`.

## Notas

- La migración `20260831000100` está escrita en disco y **PENDIENTE de aplicar al remoto**
  (`supabase db push --db-url ...` o SQL Editor, orden ascendente).
- Patrón de errores `Either<Failure,T>` y cubits inyectando usecases por nombre.
- En producción `inicio_semana_liquidacion` puede ajustarse (1=lunes ... 7=domingo).
- El bucket `comprobantes-pagos` es privado; solo admin sube/lee (URLs firmadas).
- D4 (búsqueda/filtro por especialista) queda fuera de alcance de esta iteración.

## Complementos posteriores (misma fecha)

- **Fixes de pruebas del ciclo**: `admin_comisiones_screen.dart` — crash de layout al
  enviar a revisión (botones Aprobar/Anular en `Row` con ancho ilimitado → `Wrap`,
  patrón del fix `ed589e7`); migración `20260831000200_fix_check_metodo_pago.sql`
  (el CHECK original de `pagos_especialistas.metodo_pago` era
  `['ACH','ZELLE','TRANSFERENCIA','OTRO']` y el RPC `registrar_pago_especialista`
  fallaba con `Transferencia` → se cambió a `['Transferencia','Efectivo','Cheque','Otro']`,
  aplicada al remoto).
- **Lista de citas en "Detalle por cita"**: el tab "Detalle por cita" de
  `admin_conciliacion_screen.dart` ahora muestra, con el mismo selector de período del
  corte, una lista de citas terminadas elegibles con **Paciente · Servicio(s) · Fecha ·
  Especialista** (+ Total/Depósito/Saldo) para **seleccionar** una y ver su detalle
  financiero (`consultarDetalle(citaId)`); se mantiene la consulta directa por UUID como
  alternativa. `CitaFinalizadaAdminEntity` ganó `pacienteNombre` y `servicios`, y
  `fetchCitasFinalizadasAdmin` amplía su select embebido con
  `solicitudes(pacientes(profiles(full_name)), solicitud_detalles(servicios(nombre)))`.
- Verificación: `flutter analyze` 0 issues; `flutter test` 366/366.

## Diagnóstico y cierre del fix de RLS admin (commit `91a1234`)

El fix `91a1234` ("Arregla consulta de detalle financiero y RLS de admin en pagos,
solicitud_detalles y pacientes") **ya funciona** para el detalle financiero: se
verificó en el remoto que la migración `20260831000300` está aplicada
(`pagos_admin_select`, `solicitud_detalles_admin_select`, `pacientes_admin_select`)
y se simuló la consulta como admin (rol `authenticated` + claims JWT del admin
`40000000-...`) → la cita 85e1d764 devuelve monto_total=180, deposito=90,
saldo_pendiente=0, estado=PAGADO, y `comision_porcentaje`=20.

Quedaban dos huecos RLS que rompían la **lista "Citas terminadas"** de la
conciliación (`fetchCitasFinalizadasAdmin`, que consulta `liquidacion_detalles`
para idempotencia y `tratamientos` COMPLETADO para elegibilidad):

- `tratamientos`: solo tenía `tratamiento_especialista_own` (20260807000000),
  sin policy admin → el admin no veía qué citas tienen tratamiento COMPLETADO y
  la lista salía vacía.
- `liquidacion_detalles`: RLS habilitada pero SIN ninguna policy (creada por SQL
  Editor) → el admin no podía leer la idempotencia.

**Solución**: migración `20260831000400_admin_read_tratamientos_liquidacion_detalles.sql`
(2 policies SELECT admin-only con `public.is_administrador()`, idempotente),
**aplicada al remoto** (se verificó: `tratamientos` → 2 policies,
`liquidacion_detalles` → 1 policy) y confirmada con simulación RLS como admin
(Q1/Q2/Q3 de `fetchCitasFinalizadasAdmin` devuelven filas correctas).

**Nota de idempotencia**: la cita de prueba 85e1d764 ya está liquidada
(`liquidacion_detalles` → liquidación `e402f686` estado PAGADA), por lo que NO
aparece en la lista "Citas terminadas" (comportamiento correcto de no-duplicación);
solo afecta a citas aún sin liquidar del período.

## Causa raíz REAL de los "montos en cero" (fix Dart, no RLS)

El usuario seguía viendo **todos los montos en 0** al consultar el detalle
financiero de una cita concreta, pese a que RLS ya permitía al admin leer
`pagos`. Reproduciendo la llamada PostgREST EXACTA con un JWT real de admin
(`admin@test`, password `Test1234!`):

```
GET /rest/v1/citas?select=id,solicitud_id,solicitudes(pagos(monto_total,deposito,saldo_pendiente,estado))&id=eq.85e1d764-...
```

PostgREST devuelve `pagos` como **OBJETO único** (no array):
```json
{ "solicitudes": { "pagos": { "estado":"PAGADO", "deposito":90.00, "monto_total":180.00, "saldo_pendiente":0.00 } } }
```
porque `pagos.solicitud_id` tiene UNIQUE → relación 1-a-1 (no 1-a-muchos).

El código de parseo asumía **Lista** en dos sitios → `pagos` Map fallaba el
`is List` → pago vacío → montos en 0 (detalle) y lista "Citas terminadas"
vacía (el filtro `estadoPago != 'PAGADO'` descartaba todas las citas):

1. `lib/features/payments_stripe/domain/entities/detalle_financiero_entity.dart`
   `DetalleFinancieroCitaEntity.fromJson` → ahora acepta List **o** Map.
2. `lib/features/admin_master_data/data/datasources/admin_master_data_supabase_datasource.dart`
   `fetchCitasFinalizadasAdmin` (parseo de `solicitudes['pagos']`) → idem.

(Referencia correcta del patrón: `seguimiento_solicitud_model.dart` ya manejaba
ambos. No se requirió migración; el fix es solo Dart.)

Verificación: `flutter analyze` 0 issues; `flutter test` 366/366.