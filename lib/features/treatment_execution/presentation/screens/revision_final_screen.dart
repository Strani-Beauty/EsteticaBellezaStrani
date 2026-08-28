import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/config/app_constants.dart';
import '../../../../app/config/app_theme.dart';
import '../../../../app/core/di/injection.dart';
import '../../../../features/payments_stripe/domain/entities/pago_entity.dart';
import '../../../../features/payments_stripe/domain/repositories/i_payments_repository.dart';
import '../../../../features/payments_stripe/presentation/widgets/stripe_payment_sheet.dart';
import '../../../../features/treatment_photos/domain/entities/fotografia_tratamiento_entity.dart';
import '../../domain/entities/cita_ejecucion_entity.dart';
import '../../domain/entities/face_map_especialista_entity.dart';
import '../../domain/entities/producto_aplicado_entity.dart';
import '../cubits/treatment_execution_cubit.dart';

/// Pantalla de revisión final antes de cerrar el tratamiento.
/// Consolida evaluación, puntos del face map con producto/cantidad, insumos,
/// fotografías PRE/POST y notas; valida la evidencia mínima y confirma el
/// cierre (con cobro del saldo pendiente si aplica).
class RevisionFinalScreen extends StatefulWidget {
  final String citaId;
  final String tratamientoId;

  const RevisionFinalScreen({
    super.key,
    required this.citaId,
    required this.tratamientoId,
  });

  @override
  State<RevisionFinalScreen> createState() => _RevisionFinalScreenState();
}

class _RevisionFinalScreenState extends State<RevisionFinalScreen> {
  late final TextEditingController _observacionesController;
  late final TextEditingController _recomendacionesController;
  bool _cerrando = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<TreatmentExecutionCubit>().state;
    if (state is TreatmentExecutionLoaded) {
      _observacionesController = TextEditingController(
        text: state.cita?.tratamiento?.observacionesFinales ?? '',
      );
      _recomendacionesController = TextEditingController(
        text: state.cita?.tratamiento?.recomendacionesPostTratamiento ?? '',
      );
    } else {
      _observacionesController = TextEditingController();
      _recomendacionesController = TextEditingController();
      context
          .read<TreatmentExecutionCubit>()
          .loadDetalle(citaId: widget.citaId);
    }
  }

  @override
  void dispose() {
    _observacionesController.dispose();
    _recomendacionesController.dispose();
    super.dispose();
  }

  /// Agrupa las filas de face_map_puntos por punto lógico (punto_id),
  /// devolviendo una fila representativa por punto.
  List<Map<String, dynamic>> _puntosUnicos(
    List<Map<String, dynamic>> filas,
  ) {
    final vistos = <String>{};
    final resultado = <Map<String, dynamic>>[];
    for (final fila in filas) {
      final id = fila['punto_id'] as String? ??
          (fila['zona_anatomica'] as String?) ??
          '';
      if (id.isEmpty || vistos.contains(id)) continue;
      vistos.add(id);
      resultado.add(fila);
    }
    return resultado;
  }

  bool _puntoCompleto(Map<String, dynamic> fila) {
    final prodId = fila['producto_id'];
    final cantidad = fila['cantidad'];
    return prodId is String &&
        prodId.isNotEmpty &&
        cantidad is num &&
        cantidad > 0;
  }

  List<String> _faltantes(TreatmentExecutionLoaded state) {
    final tratamiento = state.cita?.tratamiento;
    final puntos = _puntosUnicos(state.faceMap?.puntos ?? const []);
    final sinProducto = puntos.any((p) => !_puntoCompleto(p));
    return [
      if (state.consentimiento?.firmado != true)
        'Firma del consentimiento del paciente',
      if (!state.fotografias.any((f) => f.esPre)) 'Al menos una fotografía PRE',
      if (!state.fotografias.any((f) => f.esPost))
        'Al menos una fotografía POST',
      if (tratamiento?.evaluacionInicial == null ||
          (tratamiento!.evaluacionInicial ?? '').trim().isEmpty)
        'Evaluación inicial',
      if (puntos.isEmpty) 'Face map con al menos un punto de aplicación',
      if (puntos.isNotEmpty && sinProducto)
        'Producto y cantidad > 0 en cada punto del face map',
    ];
  }

  void _mensaje(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _confirmarCierre(TreatmentExecutionLoaded state) async {
    final faltantes = _faltantes(state);
    if (faltantes.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No se puede finalizar el tratamiento'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Faltan requisitos mínimos:',
                  style: TextStyle(fontSize: 14)),
              const SizedBox(height: 8),
              for (final f in faltantes)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: AppTheme.cMutedText, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(f)),
                    ],
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar cierre del tratamiento'),
        content: const Text(
          'Se finalizará el tratamiento y la cita pasará a estado FINALIZADA. '
          'Esta acción no se puede deshacer.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.cBrandGreen,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar y finalizar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    final cita = state.cita!;
    final saldoCobrado = await _pagarSaldoPendiente(cita);
    if (!mounted || !saldoCobrado) return;

    setState(() => _cerrando = true);
    await context.read<TreatmentExecutionCubit>().finalizar(
          citaId: widget.citaId,
          tratamientoId: widget.tratamientoId,
          observacionesFinales: _observacionesController.text.trim().isEmpty
              ? null
              : _observacionesController.text.trim(),
          recomendacionesPostTratamiento:
              _recomendacionesController.text.trim().isEmpty
                  ? null
                  : _recomendacionesController.text.trim(),
        );
    if (mounted) {
      _mensaje('Tratamiento finalizado correctamente.');
      Navigator.of(context).pop();
    }
  }

  /// Cobra el saldo pendiente de la solicitud antes de finalizar.
  /// Un fallo/cancelación del pago NO bloquea el cierre: registra la
  /// transacción FALLIDA y el saldo queda pendiente.
  Future<bool> _pagarSaldoPendiente(CitaEjecucionEntity cita) async {
    final solicitudId = cita.solicitudId;
    if (solicitudId == null) return true;

    final PagoEntity? pago;
    try {
      pago = await sl<IPaymentsRepository>().consultarPago(
        solicitudId: solicitudId,
      );
    } catch (e) {
      _mensaje('No se pudo consultar el estado de pago: $e');
      return false;
    }
    if (!mounted || pago == null || pago.saldoPendiente <= 0) {
      return pago == null ? false : true;
    }
    final monto = pago.saldoPendiente;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cobrar saldo pendiente'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'El paciente aún tiene un saldo pendiente de '
              '\$${monto.toStringAsFixed(2)} USD por este servicio.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 10),
            const Text(
              'Se abrirá el pago con Stripe antes de finalizar el tratamiento. '
              'Si el pago no se completa, el saldo quedará pendiente y podrá '
              'cobrarse después.',
              style: TextStyle(fontSize: 12, color: AppTheme.cMutedText),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cobrar y Finalizar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return false;

    final stripeRef = await procesarPagoStripe(
      monto: monto,
      concepto: AppConstants.conceptoSaldo,
      solicitudId: solicitudId,
      citaId: cita.id,
    );
    if (stripeRef == null) {
      await _registrarFalloSaldo(cita, solicitudId, monto, null);
      _mensaje('El pago del saldo no se completó. El saldo quedará pendiente.');
      return true;
    }

    final String motivo;
    try {
      motivo = await sl<IPaymentsRepository>().confirmarPagoSaldo(
        citaId: cita.id,
        solicitudId: solicitudId,
        monto: monto,
        stripePaymentRef: stripeRef,
      );
    } catch (e) {
      _mensaje('No se pudo confirmar el pago del saldo: $e');
      return false;
    }

    if (motivo == 'OK') {
      _mensaje('Saldo de \$${monto.toStringAsFixed(2)} USD cobrado.');
      return true;
    }
    if (motivo != 'YA_REGISTRADA') {
      await _registrarFalloSaldo(cita, solicitudId, monto, stripeRef);
    }
    _mensaje(
      motivo == 'MONTO_INCORRECTO'
          ? 'El monto del pago no coincide con el saldo pendiente. '
              'El saldo quedará pendiente.'
          : 'El saldo no pudo confirmarse. El saldo quedará pendiente.',
    );
    return true;
  }

  /// Registra la transacción FALLIDA del cobro de saldo (no bloquea el cierre).
  Future<void> _registrarFalloSaldo(
    CitaEjecucionEntity cita,
    String solicitudId,
    double monto,
    String? stripeRef,
  ) async {
    try {
      await sl<IPaymentsRepository>().registrarPagoFallido(
        citaId: cita.id,
        solicitudId: solicitudId,
        monto: monto,
        stripePaymentRef: stripeRef ?? 'CANCELADO_SIN_PAGO',
        motivo: stripeRef == null ? 'CLIENTE_CANCELO' : 'CONFIRMACION_RECHAZADA',
        tipo: AppConstants.txSaldo,
      );
    } catch (e) {
      debugPrint('⚠️ [_registrarFalloSaldo] $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: AppTheme.cDeepAccent,
        foregroundColor: Colors.white,
        title: const Text('Revisión final'),
      ),
      body: BlocConsumer<TreatmentExecutionCubit, TreatmentExecutionState>(
        builder: (context, state) {
          if (state is TreatmentExecutionLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is TreatmentExecutionError) {
            return Center(child: Text(state.message));
          }
          if (state is! TreatmentExecutionLoaded || state.cita == null) {
            return const Center(
              child: Text('Cargando revisión…'),
            );
          }
          final faltantes = _faltantes(state);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildHeader(state.cita!),
              const SizedBox(height: 12),
              if (faltantes.isNotEmpty) _buildRequisitos(faltantes),
              const SizedBox(height: 16),
              _buildEvaluacion(state),
              const SizedBox(height: 16),
              _buildFaceMap(state.faceMap),
              const SizedBox(height: 16),
              _buildProductos(state.productos),
              const SizedBox(height: 16),
              _buildFotografias(state.fotografias),
              const SizedBox(height: 16),
              _buildNotasFinales(state.cita?.tratamiento?.observacionesFinales),
              const SizedBox(height: 20),
              _AccionFinalizar(
                trabajando: state.trabajando || _cerrando,
                onPressed: () => _confirmarCierre(state),
              ),
              const SizedBox(height: 8),
              const Text(
                'Al confirmar se validará la evidencia mínima y se cobrará el '
                'saldo pendiente si existe.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: AppTheme.cMutedText),
              ),
            ],
          );
        },
        listener: (context, state) {
          if (state is TreatmentExecutionError) _mensaje(state.message);
        },
      ),
    );
  }

  Widget _buildHeader(CitaEjecucionEntity cita) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Paciente: ${cita.pacienteNombre}',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(cita.servicioNombre,
                style: const TextStyle(color: AppTheme.cMutedText)),
            Text('\$${cita.precioBase.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: AppTheme.cDeepAccent)),
          ],
        ),
      ),
    );
  }

  Widget _buildRequisitos(List<String> faltantes) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
              SizedBox(width: 6),
              Text('Evidencia mínima pendiente',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.orange)),
            ],
          ),
          const SizedBox(height: 6),
          for (final f in faltantes)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  const Icon(Icons.circle, size: 6, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                      child:
                          Text(f, style: const TextStyle(fontSize: 12))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.cDeepAccent),
        const SizedBox(width: 6),
        Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      ],
    );
  }

  Widget _buildEvaluacion(TreatmentExecutionLoaded state) {
    final evaluacion = state.cita?.tratamiento?.evaluacionInicial;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Evaluación inicial', Icons.assignment_outlined),
            const SizedBox(height: 8),
            Text(
              (evaluacion ?? '').trim().isEmpty ? '—' : evaluacion!,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFaceMap(FaceMapEspecialistaEntity? faceMap) {
    final puntos = _puntosUnicos(faceMap?.puntos ?? const []);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Puntos de aplicación (Face Map)',
                Icons.face_retouching_natural_outlined),
            const SizedBox(height: 8),
            if (puntos.isEmpty)
              const Text('Sin puntos guardados.',
                  style: TextStyle(fontStyle: FontStyle.italic))
            else
              for (final p in puntos) _buildPuntoRow(p),
            if (faceMap?.observaciones != null &&
                faceMap!.observaciones!.trim().isNotEmpty) ...[
              const Divider(height: 20),
              Text('Notas: ${faceMap.observaciones!.trim()}',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.cMutedText)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPuntoRow(Map<String, dynamic> fila) {
    final zona = fila['zona_anatomica'] as String? ?? 'Punto';
    final completo = _puntoCompleto(fila);
    final producto = fila['productos_aplicados'];
    final nombreProducto = producto is Map<String, dynamic>
        ? producto['producto_nombre'] as String?
        : null;
    final cantidad = fila['cantidad'];
    final unidad = fila['unidad_medida'] as String?;
    final cantidadTxt = cantidad is num
        ? _fmtCantidad(cantidad.toDouble())
        : null;
    final detalle = [
      if (nombreProducto != null && nombreProducto.isNotEmpty)
        nombreProducto,
      ?cantidadTxt,
      if (unidad != null && unidad.trim().isNotEmpty) unidad.trim(),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            completo ? Icons.check_circle : Icons.error_outline,
            size: 18,
            color: completo ? AppTheme.cBrandGreen : Colors.orange,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              detalle.isEmpty ? '$zona (sin producto)' : '$zona — $detalle',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductos(List<ProductoAplicadoEntity> productos) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Insumos aplicados', Icons.science_outlined),
            const SizedBox(height: 8),
            if (productos.isEmpty)
              const Text('Sin insumos registrados.',
                  style: TextStyle(fontStyle: FontStyle.italic))
            else
              for (final p in productos)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.circle, size: 6, color: AppTheme.cDeepAccent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${p.productoNombre}'
                          ' — ${_fmtCantidad(p.cantidadTotal)} '
                          '${p.unidadMedida ?? ''}'
                          '${p.lote != null ? ' · Lote ${p.lote}' : ''}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildFotografias(List<FotografiaTratamientoEntity> fotografias) {
    final pre = fotografias.where((f) => f.esPre).length;
    final post = fotografias.where((f) => f.esPost).length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Fotografías del tratamiento',
                Icons.photo_library_outlined),
            const SizedBox(height: 8),
            Text('$pre PRE · $post POST',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (fotografias.isEmpty)
              const Text('Sin fotografías registradas.',
                  style: TextStyle(fontStyle: FontStyle.italic))
            else
              SizedBox(
                height: 88,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: fotografias.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final f = fotografias[i];
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: f.archivoUrl,
                            width: 76,
                            height: 88,
                            fit: BoxFit.cover,
                            placeholder: (_, _) => Container(
                              color: Colors.grey.shade200,
                              child: const Center(
                                  child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))),
                            ),
                            errorWidget: (_, _, _) => Container(
                              width: 76,
                              height: 88,
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.broken_image_outlined),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 4,
                          top: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: f.esPost
                                  ? Colors.green.shade600
                                  : AppTheme.cDeepAccent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              f.esPre
                                  ? 'PRE'
                                  : f.esPost
                                      ? 'POST'
                                      : 'OTRO',
                              style: const TextStyle(
                                  fontSize: 9,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotasFinales(String? observaciones) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Cierre', Icons.flag_outlined),
            const SizedBox(height: 8),
            if (observaciones != null && observaciones.trim().isNotEmpty) ...[
              Text('Observaciones: ${observaciones.trim()}',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.cMutedText)),
              const SizedBox(height: 8),
            ],
            TextField(
              controller: _observacionesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Observaciones finales',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _recomendacionesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Recomendaciones post tratamiento',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtCantidad(double v) {
    final s = v.toStringAsFixed(2);
    return s.replaceFirst(RegExp(r'\.?0+$'), '');
  }
}

class _AccionFinalizar extends StatelessWidget {
  final bool trabajando;
  final VoidCallback onPressed;
  const _AccionFinalizar({required this.trabajando, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.cBrandGreen,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        onPressed: trabajando ? null : onPressed,
        icon: trabajando
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.check_circle_outline_rounded),
        label: Text(trabajando ? 'Finalizando…' : 'Confirmar y finalizar'),
      ),
    );
  }
}