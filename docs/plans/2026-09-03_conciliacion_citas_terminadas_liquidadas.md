# Conciliación de pagos — mostrar todas las citas terminadas del lapso

Fecha: 2026-09-03

## Objetivo

El administrador quiere ver **todas** las citas terminadas (FINALIZADA) del período
seleccionado en la vista "Conciliación de Pagos → Citas terminadas", incluyendo las ya
liquidadas y las que aún tienen saldo pendiente o pago no PAGADO, para revisar pagos y
cierre de cita. Hasta ahora el datasource descartaba las citas ya liquidadas
(idempotencia) y las no pagadas, ocultando por ejemplo la cita `85e1d764-9088-47cd-882f-12eb8455170f`
(finalizada 28-08-26, ya liquidada en `e402f686`).

## Cambios

- [x] Entidad `CitaFinalizadaAdminEntity`: campo `liquidada` (bool, default false) + props.
- [x] Datasource `fetchCitasFinalizadasAdmin`: sin descartar liquidadas ni no pagadas;
      marcar `liquidada` según `liquidacion_detalles`; mostrar todas las FINALIZADA del lapso.
- [x] UI `admin_conciliacion_screen.dart`: chip `LIQUIDADA`, subtítulos y empty states.
- [x] Verificar: `flutter analyze` + `flutter test` (366 tests, sin issues).
- [x] Commit + push (solicitado por el usuario).

## Archivos tocados

- `lib/features/admin_master_data/domain/entities/financiero_entity.dart`
- `lib/features/admin_master_data/data/datasources/admin_master_data_supabase_datasource.dart`
- `lib/features/payments_stripe/presentation/screens/admin_conciliacion_screen.dart`

## Fuera de alcance

- RPC `generar_liquidaciones`: mantiene su filtro de idempotencia (no re-liquidar).
- Repositorios, usecases, cubits: sin cambios de firma.