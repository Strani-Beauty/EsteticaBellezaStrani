import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import '../../domain/entities/ventas_entities.dart';
import '../cubits/reports_dashboard_cubit.dart';

/// Dashboard interactivo de ventas para el administrador.
///
/// Muestra KPIs financieros del período, gráficos de barras de ventas por
/// servicio y por especialista, y una serie temporal de montos/citas.
/// Incluye selector de período (rangos rápidos + rango libre).
class SalesDashboardScreen extends StatefulWidget {
  const SalesDashboardScreen({super.key});

  @override
  State<SalesDashboardScreen> createState() => _SalesDashboardScreenState();
}

class _SalesDashboardScreenState extends State<SalesDashboardScreen> {
  DateTime _desde = DateTime.now();
  DateTime _hasta = DateTime.now();
  bool _inicializado = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _hasta = now;
    _desde = DateTime(now.year, now.month - 1, now.day, now.hour);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ReportsDashboardCubit>().load(desde: _desde, hasta: _hasta);
    });
  }

  void _cargar(DateTime desde, DateTime hasta) {
    setState(() {
      _desde = desde;
      _hasta = hasta;
    });
    context.read<ReportsDashboardCubit>().load(desde: desde, hasta: hasta);
  }

  Future<void> _seleccionarRangoLibre() async {
    final now = DateTime.now();
    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024, 1, 1),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: _desde,
        end: _hasta.isAfter(now) ? now : _hasta,
      ),
      helpText: 'Selecciona el período de ventas',
      confirmText: 'Aplicar',
    );
    if (rango == null) return;
    _cargar(
      DateTime(rango.start.year, rango.start.month, rango.start.day),
      DateTime(rango.end.year, rango.end.month, rango.end.day, 23, 59, 59),
    );
  }

  void _aplicarRangoRapido(_RangoRapido rango) {
    final now = DateTime.now();
    switch (rango) {
      case _RangoRapido.ultimaSemana:
        _cargar(
          DateTime(now.year, now.month, now.day - 6, now.hour),
          now,
        );
      case _RangoRapido.treintaDias:
        _cargar(
          DateTime(now.year, now.month, now.day - 29, now.hour),
          now,
        );
      case _RangoRapido.esteMes:
        _cargar(DateTime(now.year, now.month, 1), now);
      case _RangoRapido.todo:
        _cargar(DateTime(2024, 1, 1), now);
    }
  }

  String _etiquetaRango(DateTime desde, DateTime hasta) {
    final d = _fmtFecha(desde);
    final h = _fmtFecha(hasta);
    return '$d — $h';
  }

  static String _fmtFecha(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    return '$dia/$mes/${fecha.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.cSurface,
      appBar: AppBar(
        backgroundColor: AppTheme.cDeepAccent,
        foregroundColor: Colors.white,
        title: const Text('Dashboard de Ventas'),
      ),
      body: BlocBuilder<ReportsDashboardCubit, ReportsState>(
        builder: (context, state) {
          if (state is ReportsLoading && !_inicializado) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.cDeepAccent),
            );
          }
          if (state is ReportsError) {
            return _ErrorVentas(message: state.message);
          }
          if (state is ReportsLoaded) {
            _inicializado = true;
            return RefreshIndicator(
              onRefresh: () =>
                  context.read<ReportsDashboardCubit>().load(desde: _desde, hasta: _hasta),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSelectorPeriodo(state),
                  const SizedBox(height: 16),
                  _buildKpis(state.resumen),
                  const SizedBox(height: 20),
                  _buildGraficoServicios(state.porServicio),
                  const SizedBox(height: 20),
                  _buildGraficoEspecialistas(state.porEspecialista),
                  const SizedBox(height: 20),
                  _buildSerieTemporal(state),
                  const SizedBox(height: 24),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  // ── Selector de período ────────────────────────────────────────────────────

  Widget _buildSelectorPeriodo(ReportsLoaded state) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Período',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.cMutedText,
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chipRango('Última semana', _RangoRapido.ultimaSemana),
                const SizedBox(width: 8),
                _chipRango('30 días', _RangoRapido.treintaDias),
                const SizedBox(width: 8),
                _chipRango('Este mes', _RangoRapido.esteMes),
                const SizedBox(width: 8),
                _chipRango('Todo', _RangoRapido.todo),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _seleccionarRangoLibre,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.cDeepAccent,
                    side: const BorderSide(color: AppTheme.cDeepAccent),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  icon: const Icon(Icons.date_range_rounded, size: 16),
                  label: const Text('Personalizado'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded,
                  size: 14, color: AppTheme.cMutedText),
              const SizedBox(width: 6),
              Text(
                _etiquetaRango(state.desde, state.hasta),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.cDarkText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chipRango(String label, _RangoRapido rango) {
    final seleccionado = _rangoSeleccionado(rango);
    return ChoiceChip(
      label: Text(label),
      selected: seleccionado,
      onSelected: (_) => _aplicarRangoRapido(rango),
      showCheckmark: false,
      selectedColor: AppTheme.cDeepAccent,
      labelStyle: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: seleccionado ? Colors.white : AppTheme.cDarkText,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
    );
  }

  bool _rangoSeleccionado(_RangoRapido rango) {
    final ahora = DateTime.now();
    final d = _desde;
    switch (rango) {
      case _RangoRapido.ultimaSemana:
        return d.isAfter(DateTime(ahora.year, ahora.month, ahora.day - 7));
      case _RangoRapido.treintaDias:
        return d.isAfter(DateTime(ahora.year, ahora.month, ahora.day - 30));
      case _RangoRapido.esteMes:
        return d.year == ahora.year && d.month == ahora.month;
      case _RangoRapido.todo:
        return d.year == 2024 && d.month == 1 && d.day == 1;
    }
  }

  // ── KPIs ───────────────────────────────────────────────────────────────────

  Widget _buildKpis(ResumenVentasEntity resumen) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _KpiCard(
          label: 'Recibidos',
          value: _moneda(resumen.montosRecibidos),
          icon: Icons.payments_rounded,
          color: AppTheme.cBrandGreen,
        ),
        _KpiCard(
          label: 'Pagados',
          value: _moneda(resumen.montosPagados),
          icon: Icons.currency_exchange_rounded,
          color: AppTheme.cGoldAccent,
        ),
        _KpiCard(
          label: 'Comisión',
          value: '${_num(resumen.comisionPorcentaje)}%',
          icon: Icons.percent_rounded,
          color: AppTheme.cDeepAccent,
        ),
        _KpiCard(
          label: 'Neto especialistas',
          value: _moneda(resumen.netoEspecialistas),
          icon: Icons.savings_rounded,
          color: AppTheme.cDeepAccent,
        ),
        _KpiCard(
          label: 'Citas realizadas',
          value: '${resumen.citasRealizadas}',
          icon: Icons.event_available_rounded,
          color: AppTheme.cBrandGreen,
        ),
        _KpiCard(
          label: 'Servicios aplicados',
          value: '${resumen.serviciosAplicados}',
          icon: Icons.spa_rounded,
          color: AppTheme.cDeepAccent,
        ),
        _KpiCard(
          label: 'Solicitudes',
          value: '${resumen.solicitudes}',
          icon: Icons.request_page_rounded,
          color: AppTheme.cMutedText,
        ),
        _KpiCard(
          label: 'Usuarios activos',
          value: '${resumen.usuariosActivos}',
          icon: Icons.people_rounded,
          color: AppTheme.cMutedText,
        ),
      ],
    );
  }

  // ── Gráfico de barras: ventas por servicio ────────────────────────────────

  Widget _buildGraficoServicios(List<VentaPorServicioEntity> items) {
    return _CardGrafico(
      titulo: 'Ventas por servicio',
      subtitulo: 'Monto total por servicio (USD)',
      child: items.isEmpty
          ? const _VacioGrafico()
          : SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  barGroups: [
                    for (var i = 0; i < items.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: items[i].montoTotal,
                            color: AppTheme.cDeepAccent,
                            width: 18,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6),
                            ),
                          ),
                        ],
                      ),
                  ],
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 46,
                        getTitlesWidget: (value, meta) => Text(
                          _abreviarMoneda(value),
                          style: const TextStyle(fontSize: 9),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= items.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              _acortarNombre(items[index].servicioNombre),
                              style: const TextStyle(fontSize: 9),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: const FlGridData(show: true, drawVerticalLine: false),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final item = items[group.x.toInt()];
                        return BarTooltipItem(
                          '${item.servicioNombre}\n${_moneda(item.montoTotal)}\n'
                          '${item.cantidad} aplicación(es) · comisión ${_moneda(item.montoComision)}',
                          const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  // ── Gráfico de barras: ventas por especialista ────────────────────────────

  Widget _buildGraficoEspecialistas(List<VentaPorEspecialistaEntity> items) {
    return _CardGrafico(
      titulo: 'Ventas por especialista',
      subtitulo: 'Monto total y neto por especialista (USD)',
      child: items.isEmpty
          ? const _VacioGrafico()
          : SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  barGroups: [
                    for (var i = 0; i < items.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: items[i].montoTotal,
                            color: AppTheme.cDeepAccent,
                            width: 14,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6),
                            ),
                          ),
                          BarChartRodData(
                            toY: items[i].montoEspecialista,
                            color: AppTheme.cBrandGreen,
                            width: 14,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6),
                            ),
                          ),
                        ],
                        barsSpace: 3,
                      ),
                  ],
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 46,
                        getTitlesWidget: (value, meta) => Text(
                          _abreviarMoneda(value),
                          style: const TextStyle(fontSize: 9),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= items.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              _acortarNombre(items[index].especialistaNombre),
                              style: const TextStyle(fontSize: 9),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: const FlGridData(show: true, drawVerticalLine: false),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final item = items[group.x.toInt()];
                        final esBruto = rodIndex == 0;
                        final monto = esBruto
                            ? item.montoTotal
                            : item.montoEspecialista;
                        final etiqueta =
                            esBruto ? 'Monto total' : 'Neto especialista';
                        return BarTooltipItem(
                          '${item.especialistaNombre}\n$etiqueta: ${_moneda(monto)}\n'
                          'Citas: ${item.citas} · Servicios: ${item.servicios}',
                          const TextStyle(color: Colors.white, fontSize: 11),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  // ── Serie temporal ────────────────────────────────────────────────────────

  Widget _buildSerieTemporal(ReportsLoaded state) {
    final serie = state.serie;
    return _CardGrafico(
      titulo: 'Evolución en el período',
      subtitulo: 'Montos recibidos vs. pagados a especialistas',
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _chipAgrupacion('Día', 'day', state),
              const SizedBox(width: 8),
              _chipAgrupacion('Semana', 'week', state),
              const SizedBox(width: 8),
              _chipAgrupacion('Mes', 'month', state),
            ],
          ),
          const SizedBox(height: 14),
          if (serie.isEmpty)
            const _VacioGrafico()
          else
            SizedBox(
              height: 220,
              child: _LineChartSerie(puntos: serie),
            ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Leyenda(color: AppTheme.cDeepAccent, texto: 'Recibidos'),
              const SizedBox(width: 16),
              _Leyenda(color: AppTheme.cBrandGreen, texto: 'Pagados'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chipAgrupacion(
      String label, String valor, ReportsLoaded state) {
    final seleccionado = state.agrupacion == valor;
    return ChoiceChip(
      label: Text(label),
      selected: seleccionado,
      onSelected: (_) =>
          context.read<ReportsDashboardCubit>().cambiarAgrupacion(valor),
      showCheckmark: false,
      selectedColor: AppTheme.cDeepAccent,
      labelStyle: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: seleccionado ? Colors.white : AppTheme.cDarkText,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
    );
  }

  // ── Helpers de formato ─────────────────────────────────────────────────────

  static String _moneda(double valor) {
    return '\$${valor.toStringAsFixed(2)}';
  }

  static String _num(double valor) {
    final entero = valor % 1 == 0;
    return entero ? valor.toStringAsFixed(0) : valor.toStringAsFixed(1);
  }

  static String _abreviarMoneda(double valor) {
    if (valor >= 1000) {
      return '\$${(valor / 1000).toStringAsFixed(1)}k';
    }
    return '\$${valor.toStringAsFixed(0)}';
  }

  static String _acortarNombre(String nombre) {
    if (nombre.length <= 12) return nombre;
    return '${nombre.substring(0, 11)}…';
  }
}

enum _RangoRapido { ultimaSemana, treintaDias, esteMes, todo }

// ─────────────────────────────────────────────────────────────────────────────
// WIDGETS AUXILIARES
// ─────────────────────────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppTheme.cMutedText,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.cDarkText,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardGrafico extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final Widget child;

  const _CardGrafico({
    required this.titulo,
    required this.subtitulo,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.cDarkText,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitulo,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppTheme.cMutedText,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _VacioGrafico extends StatelessWidget {
  const _VacioGrafico();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: Center(
        child: Text(
          'Sin datos en este período.',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppTheme.cMutedText,
          ),
        ),
      ),
    );
  }
}

class _LineChartSerie extends StatelessWidget {
  final List<PuntoSerieVentasEntity> puntos;

  const _LineChartSerie({required this.puntos});

  @override
  Widget build(BuildContext context) {
    final maxRecibido =
        puntos.fold<double>(0, (max, p) => p.montoRecibido > max ? p.montoRecibido : max);
    final maxPagado =
        puntos.fold<double>(0, (max, p) => p.montoPagado > max ? p.montoPagado : max);
    final maxY = _tope(maxRecibido > maxPagado ? maxRecibido : maxPagado);
    final n = puntos.length;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (n - 1).toDouble(),
        minY: 0,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < n; i++)
                FlSpot(i.toDouble(), puntos[i].montoRecibido),
            ],
            isCurved: true,
            color: AppTheme.cDeepAccent,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppTheme.cDeepAccent.withValues(alpha: 0.10),
            ),
          ),
          LineChartBarData(
            spots: [
              for (var i = 0; i < n; i++)
                FlSpot(i.toDouble(), puntos[i].montoPagado),
            ],
            isCurved: true,
            color: AppTheme.cBrandGreen,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppTheme.cBrandGreen.withValues(alpha: 0.08),
            ),
          ),
        ],
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 46,
              getTitlesWidget: (value, meta) => Text(
                _SalesDashboardScreenState._abreviarMoneda(value),
                style: const TextStyle(fontSize: 9),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= n) return const SizedBox.shrink();
                final dia = puntos[index].periodo.day.toString();
                final mes = puntos[index].periodo.month.toString();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '$dia/$mes',
                    style: const TextStyle(fontSize: 9),
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) {
              return [
                for (final s in spots)
                  LineTooltipItem(
                    '${_SalesDashboardScreenState._fmtFecha(
                      puntos[s.x.toInt()].periodo,
                    )} · ${_SalesDashboardScreenState._moneda(s.y)}',
                    const TextStyle(color: Colors.white, fontSize: 11),
                  ),
              ];
            },
          ),
        ),
      ),
    );
  }

  static double _tope(double valor) {
    if (valor <= 0) return 100;
    final potencia = 1;
    var factor = 1;
    while (valor / factor > 10) {
      factor *= 10;
    }
    return (((valor / factor).ceil() + potencia) * factor).toDouble();
  }
}

class _Leyenda extends StatelessWidget {
  final Color color;
  final String texto;

  const _Leyenda({required this.color, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          texto,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: AppTheme.cMutedText,
          ),
        ),
      ],
    );
  }
}

class _ErrorVentas extends StatelessWidget {
  final String message;
  const _ErrorVentas({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppTheme.cError,
            ),
            const SizedBox(height: 12),
            Text(
              'No pudimos cargar el dashboard de ventas.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.cDarkText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppTheme.cMutedText,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context
                  .read<ReportsDashboardCubit>()
                  .load(desde: DateTime.now().subtract(const Duration(days: 30)), hasta: DateTime.now()),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.cDeepAccent,
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}