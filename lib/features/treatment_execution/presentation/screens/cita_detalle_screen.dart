import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import 'package:esteticaybellezastrani/app/config/app_constants.dart';
import 'package:esteticaybellezastrani/app/config/app_routes.dart';
import 'package:esteticaybellezastrani/app/core/di/injection.dart';
import 'package:esteticaybellezastrani/app/core/utils/geo_service.dart';
import 'package:esteticaybellezastrani/features/payments_stripe/domain/repositories/i_payments_repository.dart';
import 'package:esteticaybellezastrani/features/payments_stripe/domain/entities/pago_entity.dart';
import 'package:esteticaybellezastrani/features/payments_stripe/presentation/widgets/stripe_payment_sheet.dart';
import 'package:esteticaybellezastrani/features/treatment_photos/domain/entities/fotografia_tratamiento_entity.dart';
import '../../domain/entities/cita_ejecucion_entity.dart';
import '../../domain/entities/consentimiento_tratamiento_entity.dart';
import '../../domain/entities/producto_aplicado_entity.dart';
import '../../domain/entities/tratamiento_entity.dart';
import '../cubits/treatment_execution_cubit.dart';
import '../widgets/estado_chip.dart';
import '../widgets/producto_card.dart';
import 'firma_consentimiento_screen.dart';

/// Ejecución de una cita: ciclo de estados, tratamiento, insumos y firma.
class CitaDetalleScreen extends StatefulWidget {
  final String citaId;
  const CitaDetalleScreen({super.key, required this.citaId});

  @override
  State<CitaDetalleScreen> createState() => _CitaDetalleScreenState();
}

class _CitaDetalleScreenState extends State<CitaDetalleScreen> {
  @override
  void initState() {
    super.initState();
    context.read<TreatmentExecutionCubit>().loadDetalle(citaId: widget.citaId);
  }

  void _mensaje(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  /// Unidad sugerida para los insumos según el tipo de precio del servicio
  /// (Act. 12): POR_UNIDAD → unidades, POR_JERINGA → jeringas, etc.
  String? _unidadSugerida(String? tipoPrecio) {
    switch (tipoPrecio) {
      case AppConstants.precioPorUnidad:
        return 'unidades';
      case AppConstants.precioPorJeringa:
        return 'jeringas';
      case AppConstants.precioPorSesion:
        return 'sesiones';
      case AppConstants.precioPorPlan:
        return 'plan';
      default:
        return null;
    }
  }

  String _resumenFotos(List<FotografiaTratamientoEntity> fotos) {
    final pre = fotos.where((f) => f.esPre).length;
    final post = fotos.where((f) => f.esPost).length;
    return 'Registra y consulta evidencia PRE/POST del tratamiento. '
        '($pre PRE · $post POST)';
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TreatmentExecutionCubit>();
    return Scaffold(
      appBar: AppBar(title: const Text('Ejecutar cita')),
      body: BlocConsumer<TreatmentExecutionCubit, TreatmentExecutionState>(
        listenWhen: (prev, curr) =>
            curr is TreatmentExecutionError ||
            (prev is TreatmentExecutionLoaded &&
                curr is TreatmentExecutionLoaded &&
                prev.trabajando &&
                !curr.trabajando &&
                curr.cita?.estado == EstadoCitaEjecucion.finalizada),
        listener: (context, state) {
          if (state is TreatmentExecutionError) _mensaje(state.message);
          if (state is TreatmentExecutionLoaded &&
              state.cita?.estado == EstadoCitaEjecucion.finalizada) {
            Navigator.of(context).pop();
          }
        },
        builder: (context, state) {
          if (state is TreatmentExecutionLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is TreatmentExecutionError) {
            return Center(child: Text(state.message));
          }
          if (state is! TreatmentExecutionLoaded || state.cita == null) {
            return const SizedBox.shrink();
          }
          final cita = state.cita!;
          final tratamiento = cita.tratamiento;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _InfoHeader(cita: cita),
              const SizedBox(height: 16),
              if (cita.estado == EstadoCitaEjecucion.programada) ...[
                _AccionButton(
                  icon: Icons.directions_walk_rounded,
                  label: 'Comenzar desplazamiento',
                  onPressed: () => cubit.avanzar(
                    citaId: cita.id,
                    nuevoEstado: EstadoCitaEjecucion.enCamino,
                  ),
                ),
                const SizedBox(height: 8),
                _AccionSecundaria(
                  icon: Icons.navigation_outlined,
                  label: 'Navegar al domicilio',
                  onPressed: () => _abrirNavegacion(cita),
                ),
              ],
              if (cita.estado == EstadoCitaEjecucion.enCamino) ...[
                _AccionButton(
                  icon: Icons.pin_drop_rounded,
                  label: 'Llegué al domicilio',
                  onPressed: () => _llegarAlDomicilio(cita),
                ),
                const SizedBox(height: 8),
                _AccionSecundaria(
                  icon: Icons.navigation_outlined,
                  label: 'Navegar al domicilio',
                  onPressed: () => _abrirNavegacion(cita),
                ),
              ],
              if (cita.estado == EstadoCitaEjecucion.llego)
                _AccionButton(
                  icon: Icons.play_circle_outline_rounded,
                  label: 'Iniciar servicio',
                  onPressed: () async {
                    await cubit.avanzar(
                      citaId: cita.id,
                      nuevoEstado: EstadoCitaEjecucion.enProceso,
                    );
                    if (mounted) {
                      await cubit.iniciarTratamiento(citaId: cita.id);
                    }
                    if (!mounted) return;
                    final s =
                        context.read<TreatmentExecutionCubit>().state;
                    final t = s is TreatmentExecutionLoaded
                        ? s.cita?.tratamiento
                        : null;
                    // La firma es el primer paso obligatorio: si el tratamiento
                    // nació PENDIENTE_FIRMA se abre la captura de firma.
                    if (t != null &&
                        t.estado == EstadoTratamiento.pendienteFirma) {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => FirmaConsentimientoScreen(
                          tratamientoId: t.id,
                          pacienteId: t.pacienteId,
                          tipoConsentimiento: 'TRATAMIENTO_ESTETICO',
                        ),
                      ));
                    }
                  },
                ),
              if (cita.estado.esPendienteDeEjecucion)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: _AccionSecundaria(
                    icon: Icons.cancel_outlined,
                    label: 'Cancelar cita',
                    color: Theme.of(context).colorScheme.error,
                    onPressed: () => _dialogoCancelar(cubit, cita),
                  ),
                ),
              if (cita.estado == EstadoCitaEjecucion.enProceso) ...[
                if (tratamiento != null) ...[
                  _FirmaSection(
                    tratamiento: tratamiento,
                    consentimiento: state.consentimiento,
                  ),
                  if (state.consentimiento?.firmado == true) ...[
                    const SizedBox(height: 16),
                    _EvaluacionCard(
                      tratamientoId: tratamiento.id,
                      evaluacion: tratamiento.evaluacionInicial,
                    ),
                    const SizedBox(height: 16),
                    _ProductosSection(
                      tratamientoId: tratamiento.id,
                      productos: state.productos,
                      trabajando: state.trabajando,
                      unidadSugerida: _unidadSugerida(cita.tipoPrecio),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: AppTheme.cPastelPurple,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.photo_library_outlined,
                              color: AppTheme.cDeepAccent, size: 24),
                        ),
                        title: const Text('Fotografías del tratamiento',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(_resumenFotos(state.fotografias)),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.push(
                          AppRoutes.fotografiasTratamientoDe(tratamiento.id),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: AppTheme.cPastelPurple,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                              Icons.face_retouching_natural_outlined,
                              color: AppTheme.cDeepAccent,
                              size: 24),
                        ),
                        title: const Text('Face Map / Puntos de aplicación',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text(
                            'Documenta los puntos de aplicación del tratamiento.'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.push(
                          AppRoutes.faceMapEspecialistaDe(tratamiento.id),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _AccionButton(
                      icon: Icons.check_circle_outline_rounded,
                      label: 'Finalizar tratamiento',
                      color: AppTheme.cBrandGreen,
                      onPressed: () => _dialogoFinalizar(cubit, cita,
                          tratamiento.id, state.consentimiento,
                          state.fotografias),
                    ),
                  ] else ...[
                    const SizedBox(height: 16),
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.lock_outline_rounded,
                                color: AppTheme.cMutedText),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'La firma del consentimiento es el primer paso '
                                'obligatorio. Una vez firmado podrás registrar '
                                'la evaluación, insumos, fotografías y '
                                'finalizar el tratamiento.',
                                style:
                                    TextStyle(color: AppTheme.cMutedText),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ],
              if (cita.estado == EstadoCitaEjecucion.finalizada)
                const _EstadoFinal(icon: Icons.task_alt, texto: 'Cita finalizada'),
              if (cita.estado == EstadoCitaEjecucion.cancelada ||
                  cita.estado == EstadoCitaEjecucion.noCompletada)
                const _EstadoFinal(
                    icon: Icons.cancel_outlined, texto: 'Cita sin ejecutar'),
            ],
          );
        },
      ),
    );
  }

  Future<void> _dialogoFinalizar(
    TreatmentExecutionCubit cubit,
    CitaEjecucionEntity cita,
    String tratamientoId,
    ConsentimientoTratamientoEntity? consentimiento,
    List<FotografiaTratamientoEntity> fotografias,
  ) async {
    final faltantes = <String>[
      if (consentimiento?.firmado != true)
        'Firma del consentimiento del paciente',
      if (!fotografias.any((f) => f.esPre)) 'Al menos una fotografía PRE',
      if (cita.tratamiento?.evaluacionInicial == null ||
          (cita.tratamiento!.evaluacionInicial ?? '').trim().isEmpty)
        'Evaluación inicial',
    ];
    if (faltantes.isNotEmpty) {
      if (!mounted) return;
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
    final observaciones = TextEditingController();
    final recomendaciones = TextEditingController();
    final guardar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finalizar tratamiento'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: observaciones,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Observaciones finales',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: recomendaciones,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Recomendaciones post tratamiento',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );
    if (guardar == true && mounted) {
      final saldoCobrado = await _pagarSaldoPendiente(cita);
      if (!saldoCobrado) return;
      await cubit.finalizar(
        citaId: cita.id,
        tratamientoId: tratamientoId,
        observacionesFinales:
            observaciones.text.isEmpty ? null : observaciones.text,
        recomendacionesPostTratamiento: recomendaciones.text.isEmpty
            ? null
            : recomendaciones.text,
      );
    }
  }

  /// Cobra el saldo pendiente de la solicitud antes de finalizar el tratamiento.
  /// Devuelve `false` si el pago se cancela o falla (no se finaliza la cita).
  Future<bool> _pagarSaldoPendiente(CitaEjecucionEntity cita) async {
    final solicitudId = cita.solicitudId;
    if (solicitudId == null) return true; // sin solicitud → nada que cobrar

    final pago = await _consultarPago(solicitudId);
    if (!mounted) return false;
    if (pago == null || pago.saldoPendiente <= 0) return true;
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
              'El paciente aún tiene un saldo pendiente de \$${monto.toStringAsFixed(2)} USD '
              'por este servicio.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 10),
            const Text(
              'Se abrirá el pago con Stripe antes de finalizar el tratamiento.',
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
      concepto: 'SALDO',
      solicitudId: solicitudId,
      citaId: cita.id,
    );
    if (stripeRef == null) {
      _mensaje('El pago del saldo no se completó.');
      return false;
    }

    try {
      final registrado = await sl<IPaymentsRepository>().registrarPagoSaldo(
        citaId: cita.id,
        solicitudId: solicitudId,
        monto: monto,
        stripePaymentRef: stripeRef,
      );
      if (registrado) {
        _mensaje('Saldo de \$${monto.toStringAsFixed(2)} USD cobrado.');
      }
      return true;
    } catch (e) {
      _mensaje('No se pudo registrar el saldo: $e');
      return false;
    }
  }

  Future<PagoEntity?> _consultarPago(String solicitudId) async {
    try {
      return await sl<IPaymentsRepository>().consultarPago(
        solicitudId: solicitudId,
      );
    } catch (e) {
      _mensaje('No se pudo consultar el estado de pago: $e');
      return null;
    }
  }

  /// Act. 6: abre la navegación hacia el domicilio del paciente (url_launcher).
  Future<void> _abrirNavegacion(CitaEjecucionEntity cita) async {
    final lat = cita.latitud;
    final lng = cita.longitud;
    final Uri uri;
    if (lat != null && lng != null) {
      uri = Uri.parse('google.navigation:q=$lat,$lng');
    } else {
      final q = Uri.encodeComponent(
          '${cita.direccion ?? ''}${cita.ciudad != null ? ', ${cita.ciudad}' : ''}');
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$q');
    }
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        _mensaje('No se pudo abrir la aplicación de mapas.');
      }
    } catch (_) {
      if (mounted) _mensaje('No se pudo abrir la aplicación de mapas.');
    }
  }

  /// Act. 8: registra la llegada del especialista con GPS (estado LLEGO +
  /// latitud/longitud/distancia del domicilio).
  Future<void> _llegarAlDomicilio(CitaEjecucionEntity cita) async {
    final cubit = context.read<TreatmentExecutionCubit>();
    try {
      final pos = await sl<GeoService>().obtenerPosicionActual();
      if (!mounted) return;
      await cubit.avanzar(
        citaId: cita.id,
        nuevoEstado: EstadoCitaEjecucion.llego,
      );
      if (!mounted) return;
      final distancia = await cubit.registrarLlegada(
        citaId: cita.id,
        latitud: pos.latitud,
        longitud: pos.longitud,
      );
      if (!mounted) return;
      _mensaje(distancia != null
          ? 'Llegada registrada a ${distancia.toStringAsFixed(0)} m del domicilio.'
          : 'Llegada registrada.');
    } on GeoServiceException catch (e) {
      _mensaje('No se pudo obtener tu ubicación: ${e.message}');
    }
  }

  /// Act. 10: cancela la cita registrando motivo y usuario (RPC `cancelar_cita`).
  Future<void> _dialogoCancelar(
    TreatmentExecutionCubit cubit,
    CitaEjecucionEntity cita,
  ) async {
    final motivo = TextEditingController();
    final cancelar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar cita'),
        content: TextField(
          controller: motivo,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Motivo de cancelación *',
            hintText: 'Obligatorio para la trazabilidad.',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancelar cita'),
          ),
        ],
      ),
    );
    if (cancelar == true && mounted) {
      final m = motivo.text.trim();
      if (m.isEmpty) {
        _mensaje('El motivo de cancelación es obligatorio.');
        return;
      }
      await cubit.cancelar(citaId: cita.id, motivo: m);
      if (mounted) cubit.loadDetalle(citaId: cita.id);
    }
  }
}

// ── Header con datos de paciente/servicio ─────────────────────────

class _InfoHeader extends StatelessWidget {
  final CitaEjecucionEntity cita;
  const _InfoHeader({required this.cita});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Paciente',
                      style: TextStyle(color: AppTheme.cMutedText, fontSize: 12)),
                ),
                EstadoChip(estado: cita.estado),
              ],
            ),
            const SizedBox(height: 4),
            Text(cita.pacienteNombre,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            if (cita.pacienteTelefono != null)
              Text('Tel: ${cita.pacienteTelefono}',
                  style: const TextStyle(color: AppTheme.cMutedText)),
            const Divider(height: 24),
            _fila('Servicio', cita.servicioNombre),
            _fila('Precio base', '\$${cita.precioBase.toStringAsFixed(2)}'),
            if (cita.direccion != null)
              _fila('Dirección',
                  '${cita.direccion}${cita.ciudad != null ? ', ${cita.ciudad}' : ''}'),
            if (cita.fechaAceptacion != null)
              _fila('Aceptada',
                  '${cita.fechaAceptacion!.day}/${cita.fechaAceptacion!.month}/${cita.fechaAceptacion!.year}'),
          ],
        ),
      ),
    );
  }

  Widget _fila(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 90,
              child: Text(k,
                  style: const TextStyle(
                      color: AppTheme.cMutedText, fontSize: 12)),
            ),
            Expanded(
              child: Text(v, style: const TextStyle(fontSize: 14)),
            ),
          ],
        ),
      );
}

// ── Evaluación inicial ────────────────────────────────────────────

class _EvaluacionCard extends StatefulWidget {
  final String tratamientoId;
  final String? evaluacion;
  const _EvaluacionCard({required this.tratamientoId, this.evaluacion});

  @override
  State<_EvaluacionCard> createState() => _EvaluacionCardState();
}

class _EvaluacionCardState extends State<_EvaluacionCard> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.evaluacion ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Evaluación inicial',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Anamnesis, área a tratar, notas de la sesión…',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: () {
                  context.read<TreatmentExecutionCubit>().guardarEvaluacion(
                    tratamientoId: widget.tratamientoId,
                    evaluacionInicial:
                        _controller.text.trim().isEmpty ? null : _controller.text.trim(),
                  );
                },
                child: const Text('Guardar evaluación'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Insumos aplicados ─────────────────────────────────────────────

class _ProductosSection extends StatelessWidget {
  final String tratamientoId;
  final List<ProductoAplicadoEntity> productos;
  final bool trabajando;
  final String? unidadSugerida;
  const _ProductosSection({
    required this.tratamientoId,
    required this.productos,
    required this.trabajando,
    this.unidadSugerida,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Insumos aplicados',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (productos.isEmpty)
              const Text('Sin insumos registrados',
                  style: TextStyle(color: AppTheme.cMutedText)),
            ...productos.map((p) => ProductoCard(
                  producto: p,
                  onDelete: trabajando
                      ? null
                      : () => context
                          .read<TreatmentExecutionCubit>()
                          .eliminarProducto(p.id),
                )),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: () =>
                    _dialogoProducto(context, tratamientoId, unidadSugerida),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 18),
                    SizedBox(width: 6),
                    Text('Agregar insumo'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _dialogoProducto(
      BuildContext context, String tratamientoId, String? unidadSugerida) async {
    final nombre = TextEditingController();
    final fabricante = TextEditingController();
    final lote = TextEditingController();
    final cantidad = TextEditingController(text: '1');
    final unidad = TextEditingController(text: unidadSugerida ?? '');
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar insumo'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombre,
                decoration: const InputDecoration(
                    labelText: 'Producto *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: fabricante,
                decoration: const InputDecoration(
                    labelText: 'Fabricante', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: lote,
                decoration: const InputDecoration(
                    labelText: 'Lote', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: cantidad,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Cantidad *', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: unidad,
                      decoration: const InputDecoration(
                          labelText: 'Unidad', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final n = nombre.text.trim();
              if (n.isEmpty) return;
              context.read<TreatmentExecutionCubit>().agregarProducto(
                    tratamientoId: tratamientoId,
                    productoNombre: n,
                    fabricante: fabricante.text.trim().isEmpty
                        ? null
                        : fabricante.text.trim(),
                    lote: lote.text.trim().isEmpty ? null : lote.text.trim(),
                    cantidadTotal:
                        double.tryParse(cantidad.text.trim()) ?? 1,
                    unidadMedida:
                        unidad.text.trim().isEmpty ? null : unidad.text.trim(),
                  );
              Navigator.pop(context);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

// ── Firma / consentimiento ────────────────────────────────────────

class _FirmaSection extends StatelessWidget {
  final TratamientoEntity tratamiento;
  final ConsentimientoTratamientoEntity? consentimiento;
  const _FirmaSection({required this.tratamiento, this.consentimiento});

  @override
  Widget build(BuildContext context) {
    final firmado = consentimiento?.firmado == true;
    return Card(
      child: ListTile(
        leading: Icon(
          firmado ? Icons.verified_rounded : Icons.edit_document,
          color: firmado ? AppTheme.cBrandGreen : AppTheme.cDeepAccent,
          size: 32,
        ),
        title: Text(firmado ? 'Consentimiento firmado' : 'Consentimiento pendiente'),
        subtitle: Text(
          firmado
              ? 'Firmado el ${_fecha(consentimiento!.fechaFirma)}'
              : 'Solicita la firma del paciente para continuar.',
        ),
        trailing: firmado
            ? null
            : FilledButton.tonal(
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => FirmaConsentimientoScreen(
                      tratamientoId: tratamiento.id,
                      pacienteId: tratamiento.pacienteId,
                      tipoConsentimiento: 'TRATAMIENTO_ESTETICO',
                    ),
                  ));
                },
                child: const Text('Firmar'),
              ),
      ),
    );
  }

  String _fecha(DateTime? d) =>
      d == null ? '—' : '${d.day}/${d.month}/${d.year}';
}

// ── Botones y estados ─────────────────────────────────────────────

class _AccionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color color;
  const _AccionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color = AppTheme.cDeepAccent,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}

class _AccionSecundaria extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color? color;
  const _AccionSecundaria({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: color ?? AppTheme.cDeepAccent,
          side: BorderSide(color: color ?? AppTheme.cDeepAccent),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}

class _EstadoFinal extends StatelessWidget {
  final IconData icon;
  final String texto;
  const _EstadoFinal({required this.icon, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 64, color: AppTheme.cBrandGreen),
        const SizedBox(height: 8),
        Text(texto, style: const TextStyle(fontSize: 16)),
      ],
    );
  }
}