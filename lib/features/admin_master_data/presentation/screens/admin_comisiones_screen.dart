import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:esteticaybellezastrani/app/config/app_routes.dart';
import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import 'package:esteticaybellezastrani/app/core/di/injection.dart';
import 'package:esteticaybellezastrani/features/payments_stripe/domain/repositories/i_payments_repository.dart';
import '../cubits/admin_comisiones_cubit.dart';

/// Comisiones y Liquidaciones — listado de liquidaciones y pagos a especialistas.
class AdminComisionesScreen extends StatefulWidget {
  const AdminComisionesScreen({super.key});

  @override
  State<AdminComisionesScreen> createState() => _AdminComisionesScreenState();
}

class _AdminComisionesScreenState extends State<AdminComisionesScreen> {
  bool _cargado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_cargado) {
      _cargado = true;
      context.read<AdminComisionesCubit>().load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Comisiones y Liquidaciones'),
        backgroundColor: AppTheme.cDeepAccent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: BlocConsumer<AdminComisionesCubit, AdminComisionesState>(
        listener: (context, state) {
          if (state is AdminComisionesError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        builder: (context, state) {
          if (state is AdminComisionesLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.cDeepAccent),
            );
          }
          if (state is AdminComisionesError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.redAccent, size: 44),
                    const SizedBox(height: 12),
                    Text(state.message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.cMutedText)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.cDeepAccent),
                      onPressed: () => context.read<AdminComisionesCubit>().load(),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (state is! AdminComisionesLoaded) {
            return const SizedBox.shrink();
          }
          return RefreshIndicator(
            onRefresh: () async => context.read<AdminComisionesCubit>().load(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  elevation: 0,
                  color: AppTheme.cPastelPurple.withValues(alpha: 0.3),
                  child: ListTile(
                    leading: const Icon(Icons.info_outline_rounded,
                        color: AppTheme.cDeepAccent),
                    title: const Text('Porcentaje de comisión',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text(
                        'Se edita en Configuración del Sistema (clave comision_porcentaje).'),
                    trailing: IconButton(
                      icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                      onPressed: () => context.push(AppRoutes.adminConfiguracion),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 0,
                  color: AppTheme.cBrandGreen.withValues(alpha: 0.12),
                  child: ListTile(
                    leading: const Icon(Icons.event_available_outlined,
                        color: AppTheme.cBrandGreen),
                    title: const Text('Generar liquidación',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text(
                        'Agrupa por especialista las citas FINALIZADAS y '
                        'pagadas de un periodo.'),
                    trailing: IconButton(
                      icon: const Icon(Icons.play_arrow_rounded,
                          color: AppTheme.cBrandGreen),
                      tooltip: 'Generar liquidación del periodo',
                      onPressed: _generarLiquidacion,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Liquidaciones',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (state.liquidaciones.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Sin liquidaciones registradas.',
                        style: TextStyle(color: AppTheme.cMutedText)),
                  )
                else
                  for (final l in state.liquidaciones)
                    _LiquidacionCard(
                      especialista: l.especialistaNombre ?? 'Especialista',
                      estado: l.estado ?? '—',
                      totalServicios: l.montoTotalServicios,
                      comision: l.montoComision,
                      aPagar: l.montoPagar,
                      fecha: l.fechaInicio,
                    ),
                const SizedBox(height: 16),
                const Text('Pagos a especialistas',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (state.pagos.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Sin pagos registrados.',
                        style: TextStyle(color: AppTheme.cMutedText)),
                  )
                else
                  for (final p in state.pagos)
                    Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: const Icon(Icons.payments_outlined,
                            color: AppTheme.cDeepAccent),
                        title: Text(
                            p.especialistaNombre ?? 'Especialista',
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          '${p.metodoPago ?? '—'} · ${p.referenciaPago ?? ''}'
                          '${p.fechaPago != null ? ' · ${_fmt(p.fechaPago!)}' : ''}',
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.cMutedText),
                        ),
                        trailing: Text(
                          '\$${p.montoPagado.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.cDeepAccent),
                        ),
                      ),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }

  static String _fmt(DateTime d) {
    final l = d.toLocal();
    return '${l.day}/${l.month}/${l.year}';
  }

  Future<void> _generarLiquidacion() async {
    final now = DateTime.now();
    final hoy = DateTime(now.year, now.month, now.day);
    final inicioDefault = hoy.subtract(const Duration(days: 6));

    final inicio = await showDatePicker(
      context: context,
      initialDate: inicioDefault,
      firstDate: DateTime(2024),
      lastDate: hoy,
      helpText: 'Inicio del periodo',
    );
    if (inicio == null || !mounted) return;

    final fin = await showDatePicker(
      context: context,
      initialDate: hoy,
      firstDate: inicio,
      lastDate: DateTime(now.year + 1),
      helpText: 'Fin del periodo',
    );
    if (fin == null || !mounted) return;

    try {
      final res = await sl<IPaymentsRepository>()
          .generarLiquidaciones(fechaInicio: inicio, fechaFin: fin);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res.ok
                ? 'Liquidación generada: ${res.especialistas} especialista(s), '
                    '${res.citas} cita(s), \$${res.montoPagar.toStringAsFixed(2)} '
                    'a pagar.'
                : 'No se pudo generar la liquidación: ${res.motivo}',
          ),
        ),
      );
      context.read<AdminComisionesCubit>().load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al generar la liquidación: $e')),
      );
    }
  }
}

class _LiquidacionCard extends StatelessWidget {
  final String especialista;
  final String estado;
  final double totalServicios;
  final double comision;
  final double aPagar;
  final DateTime? fecha;

  const _LiquidacionCard({
    required this.especialista,
    required this.estado,
    required this.totalServicios,
    required this.comision,
    required this.aPagar,
    this.fecha,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(especialista,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.cPastelPurple,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Text(estado,
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.cDeepAccent)),
                ),
              ],
            ),
            if (fecha != null)
              Text(
                'Periodo: ${_fmt(fecha!)}',
                style:
                    const TextStyle(fontSize: 12, color: AppTheme.cMutedText),
              ),
            const SizedBox(height: 8),
            Text(
              'Servicios: \$${totalServicios.toStringAsFixed(2)} · '
              'Comisión: \$${comision.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              'A pagar: \$${aPagar.toStringAsFixed(2)}',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: AppTheme.cDeepAccent),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmt(DateTime d) {
    final l = d.toLocal();
    return '${l.day}/${l.month}/${l.year}';
  }
}
