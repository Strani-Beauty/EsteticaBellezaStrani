import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:esteticaybellezastrani/app/config/app_theme.dart';

import '../../domain/entities/financiero_entity.dart';
import '../cubits/mis_liquidaciones_cubit.dart';

/// Historial de liquidaciones y pagos del especialista (solo lectura).
class MisLiquidacionesScreen extends StatefulWidget {
  final String especialistaId;
  const MisLiquidacionesScreen({super.key, required this.especialistaId});

  @override
  State<MisLiquidacionesScreen> createState() => _MisLiquidacionesScreenState();
}

class _MisLiquidacionesScreenState extends State<MisLiquidacionesScreen> {
  bool _cargado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_cargado) {
      _cargado = true;
      context.read<MisLiquidacionesCubit>().load(widget.especialistaId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Mis liquidaciones'),
        backgroundColor: AppTheme.cDeepAccent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: BlocConsumer<MisLiquidacionesCubit, MisLiquidacionesState>(
        listener: (context, state) {
          if (state is MisLiquidacionesError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        builder: (context, state) {
          if (state is MisLiquidacionesLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.cDeepAccent),
            );
          }
          if (state is MisLiquidacionesError) {
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
                      onPressed: () =>
                          context.read<MisLiquidacionesCubit>().load(widget.especialistaId),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (state is! MisLiquidacionesLoaded) {
            return const SizedBox.shrink();
          }
          return RefreshIndicator(
            onRefresh: () async =>
                context.read<MisLiquidacionesCubit>().load(widget.especialistaId),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (state.liquidaciones.isEmpty && state.pagos.isEmpty)
                  const Card(
                    elevation: 0,
                    color: AppTheme.cPastelPurple,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Aún no tienes liquidaciones. Se mostrarán aquí cuando el '
                        'administrador genere tu corte semanal.',
                        style: TextStyle(color: AppTheme.cMutedText),
                      ),
                    ),
                  )
                else ...[
                  _SectionHeader(
                    titulo: 'Liquidaciones',
                    count: state.liquidaciones.length,
                  ),
                  ...state.liquidaciones.map(
                    (l) => _LiquidacionCard(liquidacion: l),
                  ),
                  if (state.pagos.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _SectionHeader(
                      titulo: 'Pagos recibidos',
                      count: state.pagos.length,
                    ),
                    ...state.pagos.map(
                      (p) => _PagoCard(
                        pago: p,
                        onVerComprobante: (path) => _verComprobante(path),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  /// Muestra el comprobante de pago (URL firmada) en un diálogo.
  Future<void> _verComprobante(String path) async {
    final url =
        await context.read<MisLiquidacionesCubit>().firmarComprobante(path);
    if (!mounted) return;
    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo firmar el comprobante.')),
      );
      return;
    }
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Comprobante de pago',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(url,
                    height: 360,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('No se pudo cargar la imagen.'),
                        )),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String titulo;
  final int count;
  const _SectionHeader({required this.titulo, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        '$titulo ($count)',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
    );
  }
}

class _LiquidacionCard extends StatelessWidget {
  final LiquidacionEntity liquidacion;
  const _LiquidacionCard({required this.liquidacion});

  Color _colorEstado() {
    switch (liquidacion.estado) {
      case EstadoLiquidacion.pendiente:
        return AppTheme.cPastelBlue;
      case EstadoLiquidacion.enRevision:
        return Colors.amber.shade700;
      case EstadoLiquidacion.aprobada:
        return AppTheme.cBrandGreen;
      case EstadoLiquidacion.pagada:
        return AppTheme.cDeepAccent;
      case EstadoLiquidacion.anulada:
        return AppTheme.cMutedText;
      case null:
        return AppTheme.cPastelBlue;
    }
  }

  String _labelEstado() {
    switch (liquidacion.estado) {
      case EstadoLiquidacion.pendiente:
        return 'PENDIENTE';
      case EstadoLiquidacion.enRevision:
        return 'EN REVISIÓN';
      case EstadoLiquidacion.aprobada:
        return 'APROBADA';
      case EstadoLiquidacion.pagada:
        return 'PAGADA';
      case EstadoLiquidacion.anulada:
        return 'ANULADA';
      case null:
        return '—';
    }
  }

  String _fmt(DateTime d) {
    final l = d.toLocal();
    return '${l.day}/${l.month}/${l.year}';
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorEstado();
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
                  child: Text(
                    liquidacion.fechaInicio != null
                        ? 'Período: ${_fmt(liquidacion.fechaInicio!)}'
                            '${liquidacion.fechaFin != null ? ' → ${_fmt(liquidacion.fechaFin!)}' : ''}'
                        : 'Liquidación',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Text(_labelEstado(),
                      style: TextStyle(fontSize: 11, color: color)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Servicios: \$${liquidacion.montoTotalServicios.toStringAsFixed(2)} · '
              'Comisión: \$${liquidacion.montoComision.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              'A pagar: \$${liquidacion.montoPagar.toStringAsFixed(2)}',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: AppTheme.cDeepAccent),
            ),
            if (liquidacion.fechaPago != null)
              Text(
                'Pagada el: ${_fmt(liquidacion.fechaPago!)}',
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.cMutedText),
              ),
          ],
        ),
      ),
    );
  }
}

class _PagoCard extends StatelessWidget {
  final PagoEspecialistaEntity pago;
  final ValueChanged<String> onVerComprobante;
  const _PagoCard({required this.pago, required this.onVerComprobante});

  String _fmt(DateTime d) {
    final l = d.toLocal();
    return '${l.day}/${l.month}/${l.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(
          'Pago ${pago.fechaPago != null ? '· ${_fmt(pago.fechaPago!)}' : ''}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${pago.metodoPago ?? '—'} · ${pago.referenciaPago ?? ''}'
          '${pago.notas != null && pago.notas!.isNotEmpty ? '\n${pago.notas}' : ''}',
          style: const TextStyle(fontSize: 12, color: AppTheme.cMutedText),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (pago.comprobanteUrl != null && pago.comprobanteUrl!.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.receipt_long_outlined,
                    color: AppTheme.cDeepAccent),
                tooltip: 'Ver comprobante',
                onPressed: () => onVerComprobante(pago.comprobanteUrl!),
              ),
            Text(
              '\$${pago.montoPagado.toStringAsFixed(2)}',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: AppTheme.cDeepAccent),
            ),
          ],
        ),
      ),
    );
  }
}