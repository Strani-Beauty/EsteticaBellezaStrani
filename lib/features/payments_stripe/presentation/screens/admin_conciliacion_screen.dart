import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/config/app_theme.dart';
import '../../../admin_master_data/domain/entities/financiero_entity.dart';
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
  DateTime? _desde;
  DateTime? _hasta;

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

  Future<void> _seleccionarPeriodo(AdminConciliacionLoaded state) async {
    final hoy = DateTime.now();
    final cubit = context.read<AdminConciliacionCubit>();
    final rango = cubit.rangoUltimaSemana(hoy);
    final desde = _desde ?? rango.desde;
    final hasta = _hasta ?? rango.hasta;
    final fin = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: hoy,
      initialDateRange: DateTimeRange(start: desde, end: hasta),
      helpText: 'Período del corte semanal',
      saveText: 'Cargar',
    );
    if (fin == null) return;
    setState(() {
      _desde = fin.start;
      _hasta = fin.end;
    });
    cubit.cargarCitasPorPeriodo(desde: fin.start, hasta: fin.end);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
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
              Tab(text: 'Citas terminadas'),
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
                  _buildCitasTerminadas(state),
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
    final desde = _desde;
    final hasta = _hasta;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Seleccionar cita',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.cDeepAccent,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Citas terminadas del período. Toca una para '
                  'ver su detalle financiero.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 8),
                Text(
                  desde != null && hasta != null
                      ? 'Período: ${_fmtFecha(desde)} → ${_fmtFecha(hasta)}'
                      : 'Período por defecto: última semana completa '
                          '(lunes a domingo).',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.cMutedText),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.date_range, size: 18),
                  label: const Text('Seleccionar período'),
                  onPressed: () => _seleccionarPeriodo(state),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (state.cargandoCitas)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (state.citasFinalizadas.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('No hay citas terminadas en el período.'),
            ),
          )
        else
          for (final c in state.citasFinalizadas)
            _CitaSeleccionableTile(
              cita: c,
              onSeleccionar: () => context
                  .read<AdminConciliacionCubit>()
                  .consultarDetalle(c.citaId),
            ),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),
        const Text(
          '¿Conoces el ID? Consulta directa',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
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
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildCitasTerminadas(AdminConciliacionLoaded state) {
    final desde = _desde;
    final hasta = _hasta;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Corte semanal',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.cDeepAccent,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Todas las citas terminadas del período '
                  '(incluye ya liquidadas y pendientes de pago).',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 8),
                Text(
                  desde != null && hasta != null
                      ? 'Período: ${_fmtFecha(desde)} → ${_fmtFecha(hasta)}'
                      : 'Período por defecto: última semana completa '
                          '(lunes a domingo).',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.cMutedText),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.date_range, size: 18),
                        label: const Text('Seleccionar período'),
                        onPressed: () => _seleccionarPeriodo(state),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.cBrandGreen,
                        ),
                        icon: state.generandoLiquidacion
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.assessment, size: 18),
                        label: const Text('Generar liquidación'),
                        onPressed: state.generandoLiquidacion
                            ? null
                            : () => _generarLiquidacionDesdePeriodo(state),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (state.cargandoCitas)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (state.citasFinalizadas.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('No hay citas terminadas en el período.'),
            ),
          )
        else
          for (final c in state.citasFinalizadas)
            _CitaTerminadaTile(cita: c),
        const SizedBox(height: 24),
      ],
    );
  }

  Future<void> _generarLiquidacionDesdePeriodo(
      AdminConciliacionLoaded state) async {
    final cubit = context.read<AdminConciliacionCubit>();
    final hoy = DateTime.now();
    final rango = cubit.rangoUltimaSemana(hoy);
    final desde = _desde ?? rango.desde;
    final hasta = _hasta ?? rango.hasta;
    final resumen =
        await cubit.generarLiquidaciones(fechaInicio: desde, fechaFin: hasta);
    if (!mounted || resumen == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(resumen)),
    );
    if (resumen.startsWith('Liquidación generada')) {
      _cargarCitasActuales(state);
    }
  }

  void _cargarCitasActuales(AdminConciliacionLoaded state) {
    final desde = _desde;
    final hasta = _hasta;
    if (desde == null || hasta == null) return;
    context.read<AdminConciliacionCubit>().cargarCitasPorPeriodo(
        desde: desde, hasta: hasta);
  }

  String _fmtFecha(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
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

class _CitaTerminadaTile extends StatelessWidget {
  final CitaFinalizadaAdminEntity cita;

  const _CitaTerminadaTile({required this.cita});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    cita.especialistaNombre ?? 'Especialista',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                _Chip('TERMINADA',
                    color: cita.estaPagada
                        ? AppTheme.cBrandGreen
                        : Colors.amber.shade700),
                if (cita.liquidada) ...[
                  const SizedBox(width: 6),
                  const _Chip('LIQUIDADA', color: AppTheme.cPastelBlue),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Cita: ${cita.citaId}',
              style:
                  const TextStyle(fontSize: 11, color: AppTheme.cMutedText),
              overflow: TextOverflow.ellipsis,
            ),
            if (cita.fechaFinalizacion != null)
              Text(
                'Finalizada: ${cita.fechaFinalizacion!.toLocal()}',
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.cMutedText),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _monto('Bruto', cita.montoTotal),
                _monto('Depósito', cita.deposito),
                _monto('Saldo', cita.saldoPendiente),
              ],
            ),
            if (!cita.estaPagada)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Aún con saldo pendiente: no es elegible.',
                  style: TextStyle(fontSize: 12, color: Colors.amber.shade700),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _monto(String label, double monto) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ',
              style:
                  const TextStyle(fontSize: 12, color: AppTheme.cMutedText)),
          Text('\$${monto.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 12)),
        ],
      );
}

/// Cita seleccionable para ver su detalle financiero.
/// Muestra Paciente · Servicio · Fecha · Especialista.
class _CitaSeleccionableTile extends StatelessWidget {
  final CitaFinalizadaAdminEntity cita;
  final VoidCallback onSeleccionar;

  const _CitaSeleccionableTile({required this.cita, required this.onSeleccionar});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onSeleccionar,
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
                        Expanded(
                          child: Text(
                            cita.pacienteNombre ?? 'Paciente',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (cita.especialistaNombre != null)
                          Text(
                            cita.especialistaNombre!,
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.cMutedText),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                    if (cita.servicios.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Servicio(s): ${cita.servicios.join(', ')}',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.cMutedText),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (cita.fechaFinalizacion != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Finalizada: ${cita.fechaFinalizacion!.toLocal()}',
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.cMutedText),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        _monto('Total', cita.montoTotal),
                        _monto('Depósito', cita.deposito),
                        _monto('Saldo', cita.saldoPendiente),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.cDeepAccent.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _monto(String label, double monto) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ',
              style:
                  const TextStyle(fontSize: 12, color: AppTheme.cMutedText)),
          Text('\$${monto.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 12)),
        ],
      );
}