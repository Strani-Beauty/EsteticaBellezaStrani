# Plan — Dashboard interactivo de ventas (admin)

Fecha: 2026-09-18
Estado: APROBADO por el usuario (m1488: "aprobado"; m1492: "aprobado commit/push").
Acceso: se coloca en la sección **Administrativo** del panel admin (m1490).

## Objetivo

Vista admin con KPIs y gráficos interactivos de ventas: por servicio, por
especialista, montos recibidos/pagados, comisión %, neto especialistas, citas,
con selector de período (rangos rápidos + date range picker libre).

Decisiones del usuario (m1484):
1. Librería de gráficos: **`fl_chart`**.
2. Agregación: **RPCs SQL nuevos** por período (patrón `admin_resumen_kpis`).
3. Alcance: set completo (KPIs + barras por servicio + barras por especialista +
   línea serie temporal + selector de período).
4. Selector de período: rangos rápidos (Última semana / 30 días / Este mes / Todo)
   + `showDateRangePicker`.

## Cambios

### 1. `pubspec.yaml`
- Añadir `fl_chart` (última estable) → `flutter pub get`.

### 2. Migración `supabase/migrations/20260918000200_dashboard_ventas_rpc.sql`
RPCs SECURITY DEFINER con chequeo `is_administrador()` (patrón `admin_resumen_kpis`).
Todos con `p_desde timestamptz, p_hasta timestamptz`:
- `dashboard_ventas_resumen` → json: montos_recibidos (transacciones APROBADO por
  fecha_transaccion), montos_pagados (pagos_especialistas por fecha_pago),
  comision_porcentaje (config), neto_especialistas (citas FINALIZADA con pagos
  PAGADO), citas_realizadas, servicios_aplicados, solicitudes, usuarios_activos.
- `dashboard_ventas_por_servicio` → SETOF (servicio_id, nombre, cantidad,
  monto_total, monto_comision): agrega solicitud_detalles de citas FINALIZADA.
- `dashboard_ventas_por_especialista` → SETOF (especialista_id, nombre, citas,
  servicios, monto_total, monto_comision, monto_especialista) por cita FINALIZADA.
- `dashboard_ventas_serie(p_desde, p_hasta, p_agrupacion text)` → SETOF
  (periodo date, monto_recibido, monto_pagado, citas) por 'day'|'week'|'month'.
- Índices: pagos(solicitud_id), transacciones(fecha_transaccion),
  transacciones(estado), citas(estado, fecha_finalizacion),
  liquidaciones_especialistas(especialista_id), liquidacion_detalles(cita_id),
  comisiones(cita_id) — `CREATE INDEX IF NOT EXISTS`.
- Aplicar por pooler (driver `pg` en pgcheck).

### 3. Módulo `lib/features/reports_dashboards/` (Clean Architecture)
- **Domain**: `dashboard_ventas_entity.dart` (ResumenVentasEntity,
  VentaPorServicioEntity, VentaPorEspecialistaEntity, PuntoSerieVentasEntity);
  `i_reports_repository.dart` (getResumen/getVentasPorServicio/
  getVentasPorEspecialista/getSerie); usecases GetResumenVentas,
  GetVentasPorServicio, GetVentasPorEspecialista, GetSerieVentas.
- **Data**: `reports_supabase_datasource.dart` (4 RPCs),
  `reports_repository_impl.dart` (Either<Failure,T>), models.
- **Presentation**: `ReportsDashboardCubit` (Loading/Loaded{resumen, porServicio,
  porEspecialista, serie, desde, hasta, agrupacion}/Error; load() default último
  mes, cargarPeriodo, cambiarAgrupacion); `sales_dashboard_screen.dart` con
  fl_chart: KPIs + BarChart por servicio + BarChart por especialista + LineChart
  serie + selector de período.

### 4. Punto de entrada
- `app_routes.dart`: `salesDashboard = '/admin/dashboard-ventas'` + GoRoute privada.
- `admin_dashboard_screen.dart`: `_NavCard` "Dashboard de Ventas" en sección
  Administrativo, permiso `admin.dashboard`.
- DI: `_registerReportsDashboards()` implementado.

### Sin cambios
RLS (SELECT admin ya cubre todas las tablas), flujos de pago/liquidación.

## Verificación

- [x] `flutter analyze` limpio; `flutter test` (370, ALL PASSED).
- [x] Pooler: migración aplicada + SELECT de prueba de los 4 RPCs
      (`dashboard_ventas_por_servicio` → Desintoxicación Facial 180.00/com 36.00;
      `por_especialista` → Dr. Carlos Medina 1 cita 180/36/144; `serie` semana
      2026-09-14 rec 149.83; `resumen` → NO_AUTORIZADO sin JWT, esperado).
- [ ] Manual: dashboard con datos reales, selector de período, gráficos renderizan.
- [x] Fix web (reportado por el usuario): el botón 'Personalizado' (`OutlinedButton.icon`)
      en el Row horizontal del selector lanzaba `BoxConstraints forces an infinite width`
      (ButtonStyleButton propaga constraints infinitos a su hijo). Se reemplazó por un
      `ChoiceChip` (`_chipPersonalizado`, mismo estilo que `_chipRango`), que ya no falla.
      `flutter analyze` limpio + 370 tests ALL PASSED.

## Notas

- Commit/push aprobado (m1492). Mensaje de commit en español imperativo.