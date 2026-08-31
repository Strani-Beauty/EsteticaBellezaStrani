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