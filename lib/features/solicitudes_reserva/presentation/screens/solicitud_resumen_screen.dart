import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:esteticaybellezastrani/app/config/app_constants.dart';
import 'package:esteticaybellezastrani/app/config/app_routes.dart';
import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import 'package:esteticaybellezastrani/app/core/di/injection.dart';
import 'package:esteticaybellezastrani/app/core/network/supabase_service.dart';
import 'package:esteticaybellezastrani/features/catalog_services/domain/entities/servicio_entity.dart';
import 'package:esteticaybellezastrani/features/catalog_services/presentation/cubits/catalog_cubit.dart';
import 'package:esteticaybellezastrani/features/payments_stripe/domain/repositories/i_payments_repository.dart';
import 'package:esteticaybellezastrani/features/payments_stripe/presentation/widgets/stripe_payment_sheet.dart';
import '../../domain/entities/servicio_seleccionado_entity.dart';
import '../cubits/solicitud_reserva_cubit.dart';

/// Resumen de la solicitud antes de confirmar (Act. 4): servicios, precio
/// estimado, fecha/hora preferida y ubicación. Tras el pago del depósito la
/// solicitud queda PENDIENTE_PAGO → PUBLICADA (confirmación por webhook o
/// simulada según `enforce_pago_real`).
class SolicitudResumenScreen extends StatefulWidget {
  final List<ServicioSeleccionadoEntity> servicios;

  const SolicitudResumenScreen({super.key, required this.servicios});

  @override
  State<SolicitudResumenScreen> createState() => _SolicitudResumenScreenState();
}

class _SolicitudResumenScreenState extends State<SolicitudResumenScreen> {
  late List<ServicioSeleccionadoEntity> _servicios;
  DateTime? _fechaProgramada;
  String _observaciones = '';
  bool _pagoTotal = false;
  bool _procesando = false;
  double? _adelantoPct;

  @override
  void initState() {
    super.initState();
    _servicios = List.of(widget.servicios);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profileId = SupabaseService.currentUser?.id;
      if (profileId != null) {
        context.read<SolicitudReservaCubit>().loadConfig(profileId);
      }
      _cargarAdelanto();
    });
  }

  double get _total => _servicios.fold(0.0, (sum, s) => sum + s.subtotal);

  double get _montoACobrar {
    if (_pagoTotal) return _total;
    final pct = _adelantoPct ?? 50;
    final monto = _total * pct / 100;
    return _total <= monto ? _total : monto;
  }

  Future<void> _cargarAdelanto() async {
    try {
      final adelanto =
          await sl<IPaymentsRepository>().calcularAdelanto(_total);
      if (mounted) setState(() => _adelantoPct = adelanto.porcentaje);
    } catch (_) {}
  }

  Future<void> _seleccionarFechaHora() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _fechaProgramada ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
          _fechaProgramada ?? now.add(const Duration(hours: 2))),
    );
    if (time == null || !mounted) return;

    setState(() {
      _fechaProgramada = DateTime(date.year, date.month, date.day, time.hour,
          time.minute);
    });
  }

  Future<void> _agregarServicio() async {
    final catalog = sl<CatalogCubit>();
    if (catalog.state is! CatalogLoaded) {
      await catalog.load();
    }
    if (!mounted) return;

    final current = catalog.state;
    if (current is! CatalogLoaded || current.servicios.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay servicios disponibles.')),
      );
      return;
    }

    final serviciosDisponibles = current.servicios
        .where((s) => !_servicios.any((sel) => sel.servicioId == s.id))
        .toList();

    final nuevo = await showModalBottomSheet<ServicioEntity>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
      ),
      builder: (ctx) => _ServicePickerSheet(servicios: serviciosDisponibles),
    );

    if (nuevo != null && mounted) {
      setState(() {
        _servicios.add(ServicioSeleccionadoEntity(
          servicioId: nuevo.id,
          nombre: nuevo.nombre,
          precioBase: nuevo.precioBase,
        ));
      });
      await _cargarAdelanto();
    }
  }

  Future<void> _pagar() async {
    final cubit = context.read<SolicitudReservaCubit>();
    final state = cubit.state;

    if (state is! SolicitudReservaReady || state.direccion == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Registra tu dirección antes de confirmar la solicitud.')),
      );
      return;
    }
    if (_servicios.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos un servicio.')),
      );
      return;
    }
    final profileId = SupabaseService.currentUser?.id;
    if (profileId == null) return;

    setState(() => _procesando = true);

    // 1) Crear la solicitud PENDIENTE_PAGO (+ detalles + obligación de pago).
    await cubit.crear(
      profileId: profileId,
      servicios: _servicios,
      direccionId: state.direccion!.id,
      fechaProgramada: _fechaProgramada,
      radioKm: state.config.radioKm,
      observaciones: _observaciones.trim().isEmpty ? null : _observaciones.trim(),
      pagoTotal: _pagoTotal,
    );

    if (!mounted) {
      setState(() => _procesando = false);
      return;
    }

    final creada = cubit.state;
    if (creada is! SolicitudReservaCreated) {
      setState(() => _procesando = false);
      if (creada is SolicitudReservaError) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(creada.message)));
      }
      return;
    }

    final reserva = creada.reserva;
    final concepto = _pagoTotal
        ? AppConstants.conceptoPagoTotal
        : AppConstants.conceptoAdelanto;

    // 2) Cobrar el depósito/adelanto con Stripe.
    final stripeRef = await procesarPagoStripe(
      monto: reserva.depositoRequerido,
      concepto: concepto,
      solicitudId: reserva.solicitudId,
    );

    if (!mounted) {
      setState(() => _procesando = false);
      return;
    }

    if (stripeRef == null) {
      setState(() => _procesando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('El pago no se completó. La solicitud quedó pendiente de pago.')),
      );
      _irAMisSolicitudes();
      return;
    }

    // 3) Confirmar el depósito (webhook en producción / simulado en pruebas).
    await cubit.confirmar(
      solicitudId: reserva.solicitudId,
      stripePaymentId: stripeRef,
      concepto: concepto,
      monto: reserva.depositoRequerido,
    );

    if (!mounted) return;

    final confirmado = cubit.state;
    if (confirmado is SolicitudReservaConfirmed) {
      final mensaje = confirmado.motivo == 'PENDIENTE_WEBHOOK'
          ? 'Pago recibido. Tu solicitud se publicará en unos segundos.'
          : '¡Solicitud publicada! Ya estás buscando especialista.';
      _irAMisSolicitudes(mensaje: mensaje);
    } else {
      setState(() => _procesando = false);
      if (confirmado is SolicitudReservaError) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(confirmado.message)));
      }
      _irAMisSolicitudes();
    }
  }

  void _irAMisSolicitudes({String? mensaje}) {
    if (!mounted) return;
    context.push(AppRoutes.misSolicitudes);
    if (mensaje != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(mensaje)));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = SupabaseService.currentUser?.id;
    final profileId = profile ?? '';

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Resumen de la Solicitud'),
        backgroundColor: AppTheme.cDeepAccent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: BlocBuilder<SolicitudReservaCubit, SolicitudReservaState>(
        builder: (context, state) {
          if (state is SolicitudReservaLoadingConfig) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.cDeepAccent),
            );
          }
          if (state is SolicitudReservaError) {
            return _ErrorView(
              message: state.message,
              onRetry: profileId.isNotEmpty
                  ? () => context
                      .read<SolicitudReservaCubit>()
                      .loadConfig(profileId)
                  : null,
            );
          }
          final ready = state is SolicitudReservaReady ? state : null;

          return _buildBody(ready: ready);
        },
      ),
    );
  }

  Widget _buildBody({SolicitudReservaReady? ready}) {
    final direccion = ready?.direccion;
    final config = ready?.config;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Section(
            title: 'Servicios',
            action: TextButton.icon(
              onPressed: _procesando ? null : _agregarServicio,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Agregar'),
            ),
            child: Column(
              children: [
                for (var i = 0; i < _servicios.length; i++)
                  _ServicioRow(
                    servicio: _servicios[i],
                    onCantidad: (c) => setState(() {
                      _servicios[i] = _servicios[i].copyWith(cantidad: c);
                    }),
                    onRemove: _servicios.length > 1
                        ? () => setState(() => _servicios.removeAt(i))
                        : null,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          _Section(
            title: 'Fecha y hora preferida',
            action: TextButton.icon(
              onPressed: _procesando ? null : _seleccionarFechaHora,
              icon: const Icon(Icons.event_rounded, size: 18),
              label: Text(_fechaProgramada == null ? 'Elegir' : 'Cambiar'),
            ),
            child: _fechaProgramada == null
                ? const Text('Lo antes posible',
                    style: TextStyle(fontSize: 13, color: AppTheme.cMutedText))
                : Text(
                    _formatearFecha(_fechaProgramada!),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
          ),
          const SizedBox(height: 12),

          _Section(
            title: 'Ubicación de la prestación',
            child: direccion == null
                ? const Text(
                    'Debes registrar una dirección antes de confirmar.',
                    style: TextStyle(fontSize: 13, color: Colors.redAccent),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(direccion.direccion,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      if (direccion.ciudad != null)
                        Text(direccion.ciudad!,
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.cMutedText)),
                    ],
                  ),
          ),
          const SizedBox(height: 12),

          _Section(
            title: 'Radio de búsqueda',
            child: Text(
              config == null
                  ? '10 km'
                  : '${config.radioKm.toStringAsFixed(0)} km',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 12),

          _Section(
            title: 'Observaciones (opcional)',
            child: TextField(
              enabled: !_procesando,
              controller: null,
              onChanged: (v) => _observaciones = v,
              maxLines: 2,
              maxLength: 300,
              decoration: AppTheme.fieldDecoration(
                label: 'Observaciones',
                hint: 'Notas para el especialista',
              ),
            ),
          ),
          const SizedBox(height: 12),

          _buildTotales(),

          const SizedBox(height: 16),

          _buildPagoButton(),
          const SizedBox(height: 8),
          if (config != null && config.enforcePagoReal)
            const Text(
              'El pago se confirma con Stripe y la solicitud se publica automáticamente.',
              style: TextStyle(fontSize: 11, color: AppTheme.cMutedText),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildTotales() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cPastelPurple.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Column(
        children: [
          _TotalRow(
            label: 'Total estimado',
            value: '\$${_total.toStringAsFixed(2)} USD',
            bold: true,
          ),
          if (!_pagoTotal && _montoACobrar < _total) ...[
            _TotalRow(
              label: 'Depósito (adelanto)',
              value: '\$${_montoACobrar.toStringAsFixed(2)} USD',
            ),
            _TotalRow(
              label: 'Saldo al finalizar',
              value: '\$${(_total - _montoACobrar).toStringAsFixed(2)} USD',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPagoButton() {
    final monto = _montoACobrar;
    final label = _pagoTotal
        ? 'Pagar totalidad (\$${monto.toStringAsFixed(2)} USD)'
        : 'Pagar depósito (\$${monto.toStringAsFixed(2)} USD)';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text('¿Pagar totalidad?',
                style: TextStyle(fontSize: 12, color: AppTheme.cMutedText)),
            const Spacer(),
            Switch(
              value: _pagoTotal,
              onChanged: _procesando
                  ? null
                  : (v) {
                      setState(() => _pagoTotal = v);
                      if (!v) _cargarAdelanto();
                    },
              activeTrackColor: AppTheme.cDeepAccent,
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.cDeepAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
            ),
            onPressed: _procesando ? null : _pagar,
            icon: _procesando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.payment_rounded),
            label: Text(_procesando ? 'Procesando...' : label),
          ),
        ),
      ],
    );
  }
}

// ── Widgets auxiliares ─────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? action;

  const _Section({required this.title, required this.child, this.action});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.cDeepAccent)),
              ),
              ?action,
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _ServicioRow extends StatelessWidget {
  final ServicioSeleccionadoEntity servicio;
  final ValueChanged<int> onCantidad;
  final VoidCallback? onRemove;

  const _ServicioRow({
    required this.servicio,
    required this.onCantidad,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.spa_rounded, size: 18, color: AppTheme.cDeepAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(servicio.nombre,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                Text('\$${servicio.subtotal.toStringAsFixed(2)} USD',
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.cMutedText)),
              ],
            ),
          ),
          _CantidadStepper(
            cantidad: servicio.cantidad,
            onChanged: onCantidad,
          ),
          if (onRemove != null)
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded,
                  size: 18, color: AppTheme.cMutedText),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}

class _CantidadStepper extends StatelessWidget {
  final int cantidad;
  final ValueChanged<int> onChanged;

  const _CantidadStepper({required this.cantidad, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: cantidad > 1 ? () => onChanged(cantidad - 1) : null,
          child: const Icon(Icons.remove_circle_outline,
              size: 22, color: AppTheme.cDeepAccent),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text('$cantidad',
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        InkWell(
          onTap: () => onChanged(cantidad + 1),
          child: const Icon(Icons.add_circle_outline,
              size: 22, color: AppTheme.cDeepAccent),
        ),
      ],
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _TotalRow(
      {required this.label, required this.value, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.cMutedText,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.cDarkText)),
        ],
      ),
    );
  }
}

class _ServicePickerSheet extends StatelessWidget {
  final List<ServicioEntity> servicios;

  const _ServicePickerSheet({required this.servicios});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: servicios.isEmpty
            ? const SizedBox(
                height: 120,
                child: Center(
                    child: Text('Todos los servicios ya están agregados.',
                        style: TextStyle(color: AppTheme.cMutedText))))
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Agregar otro servicio',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: servicios.length,
                      itemBuilder: (context, i) {
                        final s = servicios[i];
                        return ListTile(
                          leading: const Icon(Icons.spa_rounded,
                              color: AppTheme.cDeepAccent),
                          title: Text(s.nombre,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                              '\$${s.precioBase.toStringAsFixed(2)} USD'),
                          onTap: () => Navigator.of(context).pop(s),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _ErrorView({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 44),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.cMutedText)),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.cDeepAccent),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Reintentar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _formatearFecha(DateTime fecha) {
  final local = fecha.toLocal();
  final dia = local.day.toString().padLeft(2, '0');
  final mes = local.month.toString().padLeft(2, '0');
  final hora = local.hour.toString().padLeft(2, '0');
  final min = local.minute.toString().padLeft(2, '0');
  return '$dia/$mes/${local.year} $hora:$min';
}
