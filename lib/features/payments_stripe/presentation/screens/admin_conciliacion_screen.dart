import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/config/app_theme.dart';
import '../../domain/entities/detalle_financiero_entity.dart';
import '../../domain/entities/transaccion_entity.dart';
import '../cubits/admin_conciliacion_cubit.dart';

/// Vista administrativa de transacciones y pagos para conciliación con Stripe.
class AdminConciliacionScreen extends StatefulWidget {
  const AdminConciliacionScreen({super.key});

  @override
  State<AdminConciliacionScreen> createState() =>
      _AdminConciliacionScreenState();
}

class _AdminConciliacionScreenState extends State<AdminConciliacionScreen> {
  bool _cargado = false;
  final TextEditingController _citaController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_cargado) {
      _cargado = true;
      context.read<AdminConciliacionCubit>().load();
    }
  }

  @override
  void dispose() {
    _citaController.dispose();
    super.dispose();
  }

  void _copiar(String texto) {
    Clipboard.setData(ClipboardData(text: texto));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Referencia copiada: $texto')));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          backgroundColor: AppTheme.cDeepAccent,
          foregroundColor: Colors.white,
          title: const Text('Conciliación de Pagos'),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: AppTheme.cGoldAccent,
            tabs: [
              Tab(text: 'Transacciones'),
              Tab(text: 'Detalle por cita'),
            ],
          ),
        ),
        body: BlocBuilder<AdminConciliacionCubit, AdminConciliacionState>(
          builder: (context, state) {
            if (state is AdminConciliacionLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is AdminConciliacionError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppTheme.cMutedText, size: 40),
                      const SizedBox(height: 12),
                      Text(
                        state.message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () =>
                            context.read<AdminConciliacionCubit>().load(),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              );
            }
            if (state is AdminConciliacionLoaded) {
              return TabBarView(
                children: [
                  _buildTransacciones(state),
                  _buildDetalle(state),
                ],
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildTransacciones(AdminConciliacionLoaded state) {
    final totalComision = state.comisiones.fold<double>(
        0, (sum, c) => sum + c.montoComision);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (state.comisiones.isNotEmpty)
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Comisiones de la plataforma',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.cDeepAccent,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${state.comisiones.length} cita(s) · Total comisión '
                    '\$${totalComision.toStringAsFixed(2)} USD',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        if (state.transacciones.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 32),
            child: Center(
              child: Text('Aún no hay transacciones registradas.'),
            ),
          ),
        for (final tx in state.transacciones) _TransaccionTile(
          tx: tx,
          onCopiar: () => _copiar(tx.stripePaymentId ?? tx.id),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildDetalle(AdminConciliacionLoaded state) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _citaController,
          keyboardType: TextInputType.text,
          decoration: const InputDecoration(
            labelText: 'ID de la cita',
            hintText: 'uuid de la cita',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.cBrandGreen,
          ),
          onPressed: () {
            final id = _citaController.text.trim();
            if (id.isEmpty) return;
            context.read<AdminConciliacionCubit>().consultarDetalle(id);
          },
          child: const Text('Consultar detalle financiero'),
        ),
        const SizedBox(height: 16),
        if (state.detalle != null) _DetalleFinancieroCard(state.detalle!),
      ],
    );
  }
}

class _TransaccionTile extends StatelessWidget {
  final TransaccionEntity tx;
  final VoidCallback onCopiar;

  const _TransaccionTile({required this.tx, required this.onCopiar});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _Chip(tx.tipo.db),
                      const SizedBox(width: 8),
                      _Chip(_labelEstado(tx.estado.db),
                          color: _colorEstado(tx.estado.db)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '\$${tx.monto.toStringAsFixed(2)} USD',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${tx.fechaTransaccion.toLocal()}',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.cMutedText),
                  ),
                  if (tx.stripePaymentId != null &&
                      tx.stripePaymentId!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Stripe: ${tx.stripePaymentId}',
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.cMutedText),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 20),
              tooltip: 'Copiar referencia',
              onPressed: onCopiar,
            ),
          ],
        ),
      ),
    );
  }
}

class _DetalleFinancieroCard extends StatelessWidget {
  final DetalleFinancieroCitaEntity detalle;

  const _DetalleFinancieroCard(this.detalle);

  @override
  Widget build(BuildContext context) {
    Widget fila(String label, String valor) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.cMutedText)),
              Text(valor, style: const TextStyle(fontSize: 13)),
            ],
          ),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Detalle financiero de la cita',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.cDeepAccent,
              ),
            ),
            const SizedBox(height: 12),
            fila('Monto total', '\$${detalle.montoTotal.toStringAsFixed(2)} USD'),
            fila('Depósito', '\$${detalle.deposito.toStringAsFixed(2)} USD'),
            fila('Pago final',
                '\$${detalle.montoPagoFinal.toStringAsFixed(2)} USD'),
            fila('Saldo pendiente',
                '\$${detalle.saldoPendiente.toStringAsFixed(2)} USD'),
            fila('Comisión (${detalle.porcentajeComision.toStringAsFixed(1)}%)',
                '\$${detalle.montoComision.toStringAsFixed(2)} USD'),
            fila('Neto especialista',
                '\$${detalle.montoEspecialista.toStringAsFixed(2)} USD'),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Estado',
                    style: TextStyle(
                        fontSize: 13, color: AppTheme.cMutedText)),
                _Chip(detalle.estaCompleta ? 'PAGADA' : 'SALDO PENDIENTE',
                    color: detalle.estaCompleta
                        ? AppTheme.cBrandGreen
                        : Colors.amber.shade700),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final Color? color;

  const _Chip(this.text, {this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (color ?? AppTheme.cPastelBlue).withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color ?? AppTheme.cDeepAccent,
        ),
      ),
    );
  }
}

Color _colorEstado(String estado) {
  switch (estado) {
    case 'FALLIDA':
      return Colors.red.shade600;
    case 'APROBADO':
      return AppTheme.cBrandGreen;
    case 'REEMBOLSADA':
      return Colors.amber.shade700;
    case 'PROCESADA':
      return AppTheme.cPastelBlue;
    default:
      return AppTheme.cMutedText;
  }
}

String _labelEstado(String estado) {
  switch (estado) {
    case 'APROBADO':
      return 'Aprobada';
    case 'FALLIDA':
      return 'Fallida';
    case 'REEMBOLSADA':
      return 'Reembolsada';
    case 'PROCESADA':
      return 'Procesada';
    default:
      return 'Pendiente';
  }
}