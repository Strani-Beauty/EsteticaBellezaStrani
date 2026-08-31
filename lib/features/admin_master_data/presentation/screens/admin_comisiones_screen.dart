import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:esteticaybellezastrani/app/config/app_routes.dart';
import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import 'package:esteticaybellezastrani/app/core/di/injection.dart';
import 'package:esteticaybellezastrani/features/payments_stripe/domain/repositories/i_payments_repository.dart';

import '../../domain/entities/financiero_entity.dart';
import '../../domain/usecases/financiero_usecases.dart';
import '../cubits/admin_comisiones_cubit.dart';

/// Comisiones y Liquidaciones — corte semanal, revisión, aprobación y pago
/// a especialistas (pago externo + comprobante).
class AdminComisionesScreen extends StatefulWidget {
  const AdminComisionesScreen({super.key});

  @override
  State<AdminComisionesScreen> createState() => _AdminComisionesScreenState();
}

class _AdminComisionesScreenState extends State<AdminComisionesScreen> {
  bool _cargado = false;
  final Set<String> _expandidas = {};

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
                      icon: state.trabajando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppTheme.cBrandGreen))
                          : const Icon(Icons.play_arrow_rounded,
                              color: AppTheme.cBrandGreen),
                      tooltip: 'Generar liquidación del periodo',
                      onPressed: state.trabajando ? null : _generarLiquidacion,
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
                      liquidacion: l,
                      expandida: _expandidas.contains(l.id),
                      detalles: state.detallesPorLiquidacion[l.id] ?? const [],
                      trabajando: state.trabajando,
                      onToggleDetalle: () => _toggleDetalle(l.id),
                      onCambiarEstado: (nuevoEstado) =>
                          _cambiarEstado(l.id, nuevoEstado),
                      onRegistrarPago: () => _dialogoRegistrarPago(l),
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
                    _PagoEspecialistaCard(pago: p, onVerComprobante: _verComprobante),
              ],
            ),
          );
        },
      ),
    );
  }

  void _toggleDetalle(String liquidacionId) {
    setState(() {
      if (_expandidas.contains(liquidacionId)) {
        _expandidas.remove(liquidacionId);
      } else {
        _expandidas.add(liquidacionId);
        context.read<AdminComisionesCubit>().cargarDetalles(liquidacionId);
      }
    });
  }

  Future<void> _cambiarEstado(String liquidacionId, String nuevoEstado) async {
    final cubit = context.read<AdminComisionesCubit>();
    final motivo = await cubit.cambiarEstado(liquidacionId, nuevoEstado);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(motivo == 'OK'
            ? 'Liquidación actualizada a $nuevoEstado.'
            : 'No se pudo cambiar el estado: $motivo'),
      ),
    );
  }

  /// Muestra el comprobante de pago (URL firmada) en un diálogo.
  Future<void> _verComprobante(String path) async {
    final signed = await sl<FirmarComprobante>()(FirmarComprobanteParams(path: path));
    if (!mounted) return;
    final url = signed.fold((l) => null, (u) => u);
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
                    height: 360, fit: BoxFit.contain,
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

  Future<void> _generarLiquidacion() async {
    final now = DateTime.now();
    final hoy = DateTime(now.year, now.month, now.day);
    // Última semana completa (lunes a domingo).
    final diff = (hoy.weekday - DateTime.monday) % 7;
    final lunesActual = hoy.subtract(Duration(days: diff));
    final inicioDefault = lunesActual.subtract(const Duration(days: 7));
    final finDefault = lunesActual.subtract(const Duration(days: 1));

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
      initialDate: finDefault.isBefore(inicio) ? inicio : finDefault,
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

  Future<void> _dialogoRegistrarPago(LiquidacionEntity liquidacion) async {
    final resultado = await showDialog<_DatosPago>(
      context: context,
      builder: (context) => _RegistrarPagoDialog(
        montoSugerido: liquidacion.montoPagar,
      ),
    );
    if (resultado == null || !mounted) return;

    final cubit = context.read<AdminComisionesCubit>();
    final motivo = await cubit.registrarPago(
      liquidacionId: liquidacion.id,
      metodoPago: resultado.metodoPago,
      referenciaPago: resultado.referencia,
      comprobanteBytes: resultado.comprobanteBytes,
      comprobanteNombre: resultado.comprobanteNombre,
      notas: resultado.notas,
      montoPagado: resultado.monto,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(motivo == 'OK'
            ? 'Pago registrado. La liquidación quedó PAGADA.'
            : 'No se pudo registrar el pago: $motivo'),
      ),
    );
  }
}

class _LiquidacionCard extends StatelessWidget {
  final LiquidacionEntity liquidacion;
  final bool expandida;
  final List<DetalleLiquidacionEntity> detalles;
  final bool trabajando;
  final VoidCallback onToggleDetalle;
  final void Function(String nuevoEstado) onCambiarEstado;
  final VoidCallback onRegistrarPago;

  const _LiquidacionCard({
    required this.liquidacion,
    required this.expandida,
    required this.detalles,
    required this.trabajando,
    required this.onToggleDetalle,
    required this.onCambiarEstado,
    required this.onRegistrarPago,
  });

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
                  child: Text(liquidacion.especialistaNombre ?? 'Especialista',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
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
            if (liquidacion.fechaInicio != null)
              Text(
                'Periodo: ${_fmt(liquidacion.fechaInicio!)}'
                '${liquidacion.fechaFin != null ? ' → ${_fmt(liquidacion.fechaFin!)}' : ''}',
                style:
                    const TextStyle(fontSize: 12, color: AppTheme.cMutedText),
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
            const SizedBox(height: 8),
            // Detalle expandible por cita (líneas de la liquidación).
            InkWell(
              onTap: onToggleDetalle,
              child: Row(
                children: [
                  Icon(expandida
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded, size: 18),
                  const SizedBox(width: 4),
                  Text(expandida ? 'Ocultar detalle' : 'Ver detalle por cita',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.cDeepAccent)),
                ],
              ),
            ),
            if (expandida) ...[
              const SizedBox(height: 8),
              if (detalles.isEmpty)
                const Text('Sin detalle disponible.',
                    style: TextStyle(fontSize: 12, color: AppTheme.cMutedText))
              else
                for (final d in detalles)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.event_rounded, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Cita: ${d.citaId}',
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.cMutedText),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text('S: \$${d.montoServicio.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 8),
                        Text('C: \$${d.comisionAplicada.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 8),
                        Text('Neto: \$${d.montoEspecialista.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.cDeepAccent)),
                      ],
                    ),
                  ),
            ],
            const SizedBox(height: 8),
            // Acciones contextuales según el estado.
            if (trabajando)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            if (liquidacion.estado == EstadoLiquidacion.pendiente)
              _botonAccion(
                context,
                icon: Icons.rate_review_outlined,
                label: 'Enviar a revisión',
                color: AppTheme.cPastelBlue,
                onTap: () => onCambiarEstado(EstadoLiquidacion.enRevision.db),
              ),
            if (liquidacion.estado == EstadoLiquidacion.enRevision)
              Row(
                children: [
                  _botonAccion(
                    context,
                    icon: Icons.check_circle_outline,
                    label: 'Aprobar',
                    color: AppTheme.cBrandGreen,
                    onTap: () => onCambiarEstado(EstadoLiquidacion.aprobada.db),
                  ),
                  const SizedBox(width: 8),
                  _botonAccion(
                    context,
                    icon: Icons.cancel_outlined,
                    label: 'Anular',
                    color: AppTheme.cMutedText,
                    onTap: () => onCambiarEstado(EstadoLiquidacion.anulada.db),
                  ),
                ],
              ),
            if (liquidacion.estado == EstadoLiquidacion.aprobada)
              _botonAccion(
                context,
                icon: Icons.payments_outlined,
                label: 'Registrar pago',
                color: AppTheme.cBrandGreen,
                onTap: onRegistrarPago,
              ),
          ],
        ),
      ),
    );
  }

  Widget _botonAccion(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.6)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }

  static String _fmt(DateTime d) {
    final l = d.toLocal();
    return '${l.day}/${l.month}/${l.year}';
  }
}

class _PagoEspecialistaCard extends StatelessWidget {
  final PagoEspecialistaEntity pago;
  final void Function(String path) onVerComprobante;

  const _PagoEspecialistaCard({required this.pago, required this.onVerComprobante});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const Icon(Icons.payments_outlined,
            color: AppTheme.cDeepAccent),
        title: Text(pago.especialistaNombre ?? 'Especialista',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${pago.metodoPago ?? '—'} · ${pago.referenciaPago ?? ''}'
          '${pago.fechaPago != null ? ' · ${_fmt(pago.fechaPago!)}' : ''}'
          '${pago.notas != null && pago.notas!.isNotEmpty ? '\n${pago.notas}' : ''}',
          style:
              const TextStyle(fontSize: 12, color: AppTheme.cMutedText),
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

  static String _fmt(DateTime d) {
    final l = d.toLocal();
    return '${l.day}/${l.month}/${l.year}';
  }
}

class _DatosPago {
  final String metodoPago;
  final String? referencia;
  final String? notas;
  final double? monto;
  final List<int>? comprobanteBytes;
  final String? comprobanteNombre;

  const _DatosPago({
    required this.metodoPago,
    this.referencia,
    this.notas,
    this.monto,
    this.comprobanteBytes,
    this.comprobanteNombre,
  });
}

/// Diálogo para registrar un pago externo: método, referencia, monto,
/// notas y comprobante adjunto (imagen → storage).
class _RegistrarPagoDialog extends StatefulWidget {
  final double montoSugerido;

  const _RegistrarPagoDialog({required this.montoSugerido});

  @override
  State<_RegistrarPagoDialog> createState() => _RegistrarPagoDialogState();
}

class _RegistrarPagoDialogState extends State<_RegistrarPagoDialog> {
  static const _metodos = ['Transferencia', 'Efectivo', 'Cheque', 'Otro'];

  String _metodo = 'Transferencia';
  final _referenciaCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();
  final _montoCtrl = TextEditingController();
  List<int>? _comprobanteBytes;
  String? _comprobanteNombre;

  @override
  void initState() {
    super.initState();
    _montoCtrl.text = widget.montoSugerido.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _referenciaCtrl.dispose();
    _notasCtrl.dispose();
    _montoCtrl.dispose();
    super.dispose();
  }

  Future<void> _adjuntarComprobante() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _comprobanteBytes = bytes;
      _comprobanteNombre = file.name;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Registrar pago a especialista'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _metodo,
              decoration: const InputDecoration(labelText: 'Método de pago'),
              items: _metodos
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (v) => setState(() => _metodo = v ?? 'Transferencia'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _referenciaCtrl,
              decoration: const InputDecoration(
                  labelText: 'Referencia del pago', hintText: 'Opcional'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _montoCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Monto pagado (USD)',
                  hintText: 'Por defecto: monto a pagar'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notasCtrl,
              decoration: const InputDecoration(
                  labelText: 'Notas', hintText: 'Opcional'),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _adjuntarComprobante,
              icon: const Icon(Icons.attach_file_rounded, size: 18),
              label: Text(_comprobanteNombre != null
                  ? 'Comprobante: $_comprobanteNombre'
                  : 'Adjuntar comprobante'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppTheme.cBrandGreen),
          onPressed: () {
            final monto =
                double.tryParse(_montoCtrl.text.trim().replaceAll(',', '.'));
            Navigator.of(context).pop(_DatosPago(
              metodoPago: _metodo,
              referencia: _referenciaCtrl.text.trim().isEmpty
                  ? null
                  : _referenciaCtrl.text.trim(),
              notas:
                  _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
              monto: monto,
              comprobanteBytes: _comprobanteBytes,
              comprobanteNombre: _comprobanteNombre,
            ));
          },
          icon: const Icon(Icons.check_rounded, size: 18),
          label: const Text('Registrar pago'),
        ),
      ],
    );
  }
}