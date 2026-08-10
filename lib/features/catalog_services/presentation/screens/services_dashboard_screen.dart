import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:esteticaybellezastrani/app/config/app_routes.dart';
import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import 'package:esteticaybellezastrani/app/core/di/injection.dart';
import 'package:esteticaybellezastrani/features/auth_users/presentation/cubits/auth_cubit.dart';
import 'package:esteticaybellezastrani/app/core/network/supabase_service.dart';
import 'package:esteticaybellezastrani/features/catalog_services/domain/entities/servicio_entity.dart';
import 'package:esteticaybellezastrani/features/catalog_services/presentation/cubits/catalog_cubit.dart';
import 'package:esteticaybellezastrani/features/payments_stripe/domain/repositories/i_payments_repository.dart';
import 'package:esteticaybellezastrani/features/payments_stripe/presentation/widgets/stripe_payment_sheet.dart';

/// Dashboard de catálogo de servicios — Vista post-evaluación para clientes/pacientes.
/// Los servicios y categorías se cargan desde Supabase (`servicios`, `categorias_servicio`).
/// Permite ingresar a cualquier servicio para cancelar parte (depósito) o la totalidad,
/// condicionado a contar con evaluación médica vigente (< 1 año).
class ServicesDashboardScreen extends StatefulWidget {
  const ServicesDashboardScreen({super.key});

  @override
  State<ServicesDashboardScreen> createState() => _ServicesDashboardScreenState();
}

class _ServicesDashboardScreenState extends State<ServicesDashboardScreen> {
  bool _isLoadingStatus = true;
  String _evaluationStatus = 'PENDIENTE';
  String _proveedorEvaluacion = 'Telemedicina';
  bool _isExpired = false;

  @override
  void initState() {
    super.initState();
    _loadFlowStatus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CatalogCubit>().load();
    });
  }

  Future<void> _loadFlowStatus() async {
    final user = SupabaseService.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoadingStatus = false);
      return;
    }

    try {
      final status = await SupabaseService.checkPatientFlowStatus(profileId: user.id);
      if (mounted) {
        setState(() {
          _evaluationStatus = status['evaluationStatus']?.toString() ?? 'PENDIENTE';
          _proveedorEvaluacion = status['proveedorEvaluacion']?.toString() ?? 'Telemedicina';
          _isExpired = status['isExpired'] == true;
          _isLoadingStatus = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingStatus = false);
    }
  }

  Future<void> _onServiceSelected(ServicioEntity service) async {
    final title = service.nombre;
    final user = SupabaseService.currentUser;

    if (user == null) {
      context.go(AppRoutes.login);
      return;
    }

    // ── REGLA ESTRICTA RN-020 / RN-022: Validar estado de la evaluación clínica en Supabase ──
    final ruleValidation = await SupabaseService.validateReservationRulesRN020(profileId: user.id);
    if (!mounted) return;

    final bool allowed = ruleValidation['allowed'] == true;
    final String reason = ruleValidation['reason']?.toString() ?? 'PENDIENTE';

    if (!allowed) {
      if (reason == 'RECHAZADA') {
        _showBlockedReservationModal(
          title: 'Reserva Bloqueada (RN-020 / RN-022)',
          message: 'Tu evaluación médica fue RECHAZADA. Por regulación médica y la regla RN-020/RN-022, no puedes realizar reservas de servicios.',
          icon: Icons.gavel_rounded,
          color: Colors.redAccent,
        );
        return;
      } else if (reason == 'VENCIDA') {
        _showExpirationReminderModal();
        return;
      } else {
        _showPendingEvaluationModal();
        return;
      }
    }

    // ── 2. Si el servicio es facial/inyectable, disparar Cuestionario Face Maps & Torso Silhouette ──
    final esFacialOInyectable = service.requiereFaceMap ||
        title.toLowerCase().contains('inyectable') ||
        const {'Inyectables', 'Rejuvenecimiento Facial'}
            .contains(service.nombreCategoria);
    if (esFacialOInyectable) {
      context.push(AppRoutes.faceMapQuestionnaire);
      return;
    }

    // ── 3. Si la evaluación está APROBADA y VIGENTE (< 1 año) → Mostrar Opciones de Pago / Reserva ──
    _showPaymentOptionsModal(service);
  }

  void _showBlockedReservationModal({
    required String title,
    required String message,
    required IconData icon,
    required Color color,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        constraints: const BoxConstraints(maxWidth: 440),
        title: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            message,
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: color),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showPaymentOptionsModal(ServicioEntity service) {
    final title = service.nombre;
    final price = service.precioBase;
    const deposito = 30.0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        constraints: const BoxConstraints(maxWidth: 440),
        title: Row(
          children: [
            const Icon(Icons.payment_rounded, color: AppTheme.cDeepAccent, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Cancelar Servicio',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.cDeepAccent),
              ),
              const SizedBox(height: 4),
              Text(
                service.descripcion ?? '',
                style: const TextStyle(fontSize: 12, color: AppTheme.cMutedText),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.cPastelPurple,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Flexible(
                      child: Text('Precio Total del Servicio:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                    const SizedBox(width: 8),
                    Text('\$$price USD', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.cDarkText)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'De acuerdo a tu evaluación médica aprobada ($_proveedorEvaluacion), puedes cancelar una parte (depósito) o la totalidad:',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _processServicePayment(
                    servicioId: service.id,
                    serviceTitle: title,
                    servicePrice: price,
                    payFullAmount: false,
                  );
                },
                icon: const Icon(Icons.bookmark_add_rounded, size: 18),
                label: Text('Cancelar Depósito (\$$deposito USD)'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cDeepAccent),
                onPressed: () {
                  Navigator.pop(ctx);
                  _processServicePayment(
                    servicioId: service.id,
                    serviceTitle: title,
                    servicePrice: price,
                    payFullAmount: true,
                  );
                },
                icon: const Icon(Icons.check_circle_rounded, size: 18),
                label: Text('Cancelar Totalidad (\$$price USD)'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _processServicePayment({
    required String servicioId,
    required String serviceTitle,
    required double servicePrice,
    required bool payFullAmount,
  }) async {
    final user = SupabaseService.currentUser;
    if (user == null) return;

    // Pago real con Stripe (o simulado si no hay clave configurada)
    const deposito = 30.0;
    final montoAPagar = payFullAmount ? servicePrice : deposito;
    final stripeRef = await procesarPagoStripe(
      monto: montoAPagar,
      concepto: payFullAmount ? 'PAGO_TOTAL' : 'DEPOSITO',
    );
    if (stripeRef == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El pago no se completó. Intenta de nuevo.')),
        );
      }
      return;
    }

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator(color: AppTheme.cDeepAccent)),
      );
    }

    String? solicitudId;
    try {
      solicitudId = await sl<IPaymentsRepository>().createServicePayment(
        profileId: user.id,
        servicioId: servicioId,
        servicePrice: servicePrice,
        payFullAmount: payFullAmount,
        stripePaymentRef: stripeRef,
      );
    } catch (e) {
      debugPrint('❌ [_processServicePayment] $e');
    }

    if (mounted) Navigator.pop(context); // cerrar loader

    if (solicitudId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo registrar la solicitud. Intenta de nuevo.')),
        );
      }
      return;
    }

    if (mounted) {
      _showPaymentSuccessDialog(serviceTitle, montoAPagar, payFullAmount);
    }
  }

  void _showPaymentSuccessDialog(String serviceTitle, double amount, bool isFull) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        constraints: const BoxConstraints(maxWidth: 440),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppTheme.cSuccess, size: 28),
            SizedBox(width: 10),
            Expanded(child: Text('¡Pago Registrado!')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Has cancelado ${isFull ? "la totalidad" : "el depósito"} del servicio "$serviceTitle".',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Text(
                'La solicitud se ha registrado correctamente en tu expediente y se han generado las transacciones correspondientes en el sistema por \$$amount USD.',
                style: const TextStyle(fontSize: 12, color: AppTheme.cMutedText),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cDeepAccent),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  void _showExpirationReminderModal() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        constraints: const BoxConstraints(maxWidth: 440),
        title: const Row(
          children: [
            Icon(Icons.history_toggle_off_rounded, color: Colors.orangeAccent, size: 28),
            SizedBox(width: 10),
            Expanded(child: Text('Recordatorio de Expiración')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tu evaluación médica por $_proveedorEvaluacion ha cumplido 1 año de validez (365 días).',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                'Según la política de clientes del sistema, para contratar o ingresar a cualquier servicio debes abonar nuevamente el pago previo de \$30 USD y realizar una nueva evaluación médica.',
                style: TextStyle(fontSize: 13, color: AppTheme.cDarkText, height: 1.4),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cDeepAccent),
            onPressed: () {
              Navigator.pop(ctx);
              context.push(AppRoutes.completeProfile);
            },
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Pagar \$30 USD y Renovar'),
          ),
        ],
      ),
    );
  }

  void _showPendingEvaluationModal() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        constraints: const BoxConstraints(maxWidth: 440),
        title: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: AppTheme.cDeepAccent, size: 26),
            SizedBox(width: 10),
            Expanded(child: Text('Evaluación Requerida')),
          ],
        ),
        content: const SingleChildScrollView(
          child: Text(
            'Para acceder a reservar o cancelar cualquier servicio del catálogo, primero debes completar la cuota inicial de \$30 USD y la evaluación médica (Telemedicina o Medicina Interna).',
            style: TextStyle(fontSize: 13),
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cDeepAccent),
            onPressed: () {
              Navigator.pop(ctx);
              context.push(AppRoutes.completeProfile);
            },
            child: const Text('Completar Evaluación'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthCubit>().currentProfile;
    final name = profile?.fullName ?? profile?.email ?? 'Paciente';

    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthUnauthenticated) {
          context.go(AppRoutes.login);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.cDeepAccent),
            tooltip: 'Volver atrás',
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(AppRoutes.welcome);
              }
            },
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Catálogo de Servicios'),
              Text('Bienvenido/a, $name',
                  style: const TextStyle(fontSize: 11, color: AppTheme.cMutedText)),
            ],
          ),
          actions: [
            IconButton(
              onPressed: () => context.push(AppRoutes.completeProfile),
              icon: const Icon(Icons.person_outline_rounded, color: AppTheme.cDeepAccent),
              tooltip: 'Ver Perfil y Evaluación',
            ),
            IconButton(
              onPressed: () => context.read<AuthCubit>().signOut(),
              icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
              tooltip: 'Cerrar Sesión',
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatusBanner(),
              const SizedBox(height: 16),
              Expanded(
                child: BlocConsumer<CatalogCubit, CatalogState>(
                  listener: (context, state) {
                    if (state is CatalogError) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(state.message)),
                      );
                    }
                  },
                  builder: (context, state) {
                    if (state is CatalogLoading) {
                      return const Center(
                        child: CircularProgressIndicator(color: AppTheme.cDeepAccent),
                      );
                    }
                    if (state is CatalogError) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, color: Colors.redAccent, size: 44),
                            const SizedBox(height: 12),
                            const Text(
                              'No pudimos cargar el catálogo de servicios.',
                              style: TextStyle(color: AppTheme.cMutedText),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cDeepAccent),
                              onPressed: () => context.read<CatalogCubit>().load(),
                              icon: const Icon(Icons.refresh_rounded, size: 18),
label: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      );
                    }
                    if (state is CatalogLoaded) {
                      return _buildCatalog(state);
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCatalog(CatalogLoaded state) {
    final servicios = state.servicios;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCategoryChips(state),
        const SizedBox(height: 12),
        Expanded(
          child: servicios.isEmpty && !state.loadingServicios
              ? const Center(
                  child: Text(
                    'No hay servicios disponibles en este momento.',
                    style: TextStyle(color: AppTheme.cMutedText),
                    textAlign: TextAlign.center,
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth >= 1000;
                    final isTablet = constraints.maxWidth >= 600 && constraints.maxWidth < 1000;
                    final crossAxisCount = isDesktop ? 3 : (isTablet ? 2 : 1);
                    final childAspectRatio = isDesktop ? 0.92 : (isTablet ? 0.88 : 0.90);

                    return Stack(
                      children: [
                        GridView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: servicios.length,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 18,
                            mainAxisSpacing: 18,
                            childAspectRatio: childAspectRatio,
                          ),
                          itemBuilder: (context, i) => _ServiceCard(
                            service: servicios[i],
                            onTap: () => _onServiceSelected(servicios[i]),
                          ),
                        ),
                        if (state.loadingServicios)
                          const Positioned.fill(
                            child: ColoredBox(
                              color: Colors.white54,
                              child: Center(
                                child: CircularProgressIndicator(color: AppTheme.cDeepAccent),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCategoryChips(CatalogLoaded state) {
    final selectedId = state.selectedCategoriaId;

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _CategoryChip(
              label: 'Todos',
              selected: selectedId == null,
              onTap: () => context.read<CatalogCubit>().selectCategoria(null),
            ),
          ),
          ...state.categorias.map(
            (c) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _CategoryChip(
                label: c.nombre,
                selected: selectedId == c.id,
                onTap: () => context.read<CatalogCubit>().selectCategoria(c.id),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    if (_isLoadingStatus) {
      return Container(
        padding: const EdgeInsets.all(10),
        child: const Row(
          children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.cDeepAccent)),
            SizedBox(width: 10),
            Text('Verificando política de cliente y estado médico...', style: TextStyle(fontSize: 12, color: AppTheme.cMutedText)),
          ],
        ),
      );
    }

    if (_evaluationStatus == 'APROBADA' && !_isExpired) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.cBrandGreen.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(color: AppTheme.cBrandGreen.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.verified_rounded, color: AppTheme.cBrandGreen, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Evaluación Aprobada ($_proveedorEvaluacion)',
                    style: const TextStyle(fontSize: 13, color: AppTheme.cBrandGreen, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Validez oficial de 1 año. Puedes seleccionar cualquier servicio para cancelar parte o la totalidad.',
                    style: TextStyle(fontSize: 11, color: AppTheme.cBrandGreen.withValues(alpha: 0.85)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (_evaluationStatus == 'VENCIDA' || _isExpired) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.history_toggle_off_rounded, color: Colors.orange, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    '⚠️ Evaluación Médica Expirada (Pasó 1 Año)',
                    style: TextStyle(fontSize: 13, color: Colors.orange, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Se requiere renovar la evaluación clínica y el abono inicial de \$30 USD para reservar servicios.',
                    style: TextStyle(fontSize: 11, color: AppTheme.cDarkText),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.cPastelPurple.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.cDeepAccent.withValues(alpha: 0.2)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, color: AppTheme.cDeepAccent, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Evaluación Médica requerida para la cancelación y reserva de servicios.',
              style: TextStyle(fontSize: 12, color: AppTheme.cDarkText, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      labelStyle: TextStyle(
        fontSize: 12,
        color: selected ? Colors.white : AppTheme.cDarkText,
        fontWeight: selected ? FontWeight.bold : FontWeight.w500,
      ),
      selectedColor: AppTheme.cDeepAccent,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: selected ? AppTheme.cDeepAccent : Colors.grey.shade300,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final ServicioEntity service;
  final VoidCallback onTap;

  const _ServiceCard({required this.service, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: AppTheme.cardShadow,
        ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildHero()),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        service.nombre,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 15, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      _formatPrice(service),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.cDeepAccent),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  service.descripcion ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12, height: 1.3),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    if (service.nombreCategoria != null) ...[
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.cPastelPurple,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            service.nombreCategoria!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.cDeepAccent),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (service.requiereFotos)
                      const Tooltip(
                        message: 'Este servicio requiere evidencia fotográfica',
                        child: Icon(Icons.photo_camera_outlined, size: 16, color: AppTheme.cDeepAccent),
                      ),
                    const Spacer(),
                    const Icon(Icons.chevron_right_rounded, color: AppTheme.cMutedText, size: 20),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildHero() {
    final slug = _slugify(service.nombre);

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
      ),
      child: _ServiceHeroImage(
        basePath: 'assets/images/service_$slug',
        fallback: _buildHeroFallback(),
      ),
    );
  }

  Widget _buildHeroFallback() {
    final icon = _iconForServicio(service);

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.cPastelPink, AppTheme.cPastelPurple],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(icon, size: 52, color: AppTheme.cDeepAccent),
      ),
    );
  }

  String _formatPrice(ServicioEntity service) {
    final suffix = switch (service.tipoPrecio) {
      TipoPrecio.precioFijo => '',
      TipoPrecio.porUnidad => '/unidad',
      TipoPrecio.porJeringa => '/jeringa',
      TipoPrecio.porSesion => '/sesión',
      TipoPrecio.porPlan => '/plan',
    };
    return '\$${service.precioBase}${suffix.isEmpty ? '' : ' '}$suffix';
  }
}

IconData _iconForServicio(ServicioEntity service) {
  final nombre = service.nombre.toLowerCase();
  final categoria = service.nombreCategoria?.toLowerCase() ?? '';

  if (nombre.contains('inyectable') || nombre.contains('toxina') || nombre.contains('jeringa') || categoria.contains('inyectable')) {
    return Icons.local_hospital;
  }
  if (nombre.contains('lás') || nombre.contains('lase') || nombre.contains('pulsada')) {
    return Icons.wb_incandescent;
  }
  if (nombre.contains('corporal') || nombre.contains('cuerpo') || nombre.contains('lipólisis') || nombre.contains('reductor') || nombre.contains('moldeamiento')) {
    return Icons.accessibility_new;
  }
  if (nombre.contains('mesoterapia') || nombre.contains('adelgazamiento') || nombre.contains('nutricion')) {
    return Icons.fitness_center;
  }
  if (nombre.contains('rejuvenecimiento') || nombre.contains('facial') || nombre.contains('piel') || nombre.contains('peeling') || nombre.contains('booster') || nombre.contains('skin')) {
    return Icons.face;
  }
  return Icons.spa;
}

const _kServiceAssetExtensions = ['.jpg', '.jfif', '.png', '.webp'];

/// Widget de hero que intenta cargar `assets/images/service_<slug>` probando
/// cada extensión soportada. Si ninguna existe, muestra el fallback (gradiente
/// con ícono) sin depender del AssetManifest.
class _ServiceHeroImage extends StatefulWidget {
  final String basePath;
  final Widget fallback;

  const _ServiceHeroImage({required this.basePath, required this.fallback});

  @override
  State<_ServiceHeroImage> createState() => _ServiceHeroImageState();
}

class _ServiceHeroImageState extends State<_ServiceHeroImage> {
  int _extIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (_extIndex >= _kServiceAssetExtensions.length) return widget.fallback;

    final path = widget.basePath + _kServiceAssetExtensions[_extIndex];
    return Image.asset(
      path,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stackTrace) {
        final next = _extIndex + 1;
        if (next >= _kServiceAssetExtensions.length) return widget.fallback;
        _extIndex = next;
        return build(context);
      },
    );
  }
}

/// Convierte un texto a slug para asset: minúsculas, sin acentos, sin
/// caracteres especiales y con los espacios como guion bajo.
String _slugify(String input) {
  const accents = {
    'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u',
    'ñ': 'n', 'Á': 'a', 'É': 'e', 'Í': 'i', 'Ó': 'o', 'Ú': 'u', 'Ü': 'u', 'Ñ': 'n',
  };
  final buffer = StringBuffer();
  for (final char in input.toLowerCase().trim().split('')) {
    buffer.write(accents[char] ?? (RegExp(r'[a-z0-9 ]').hasMatch(char) ? char : ''));
  }
  return buffer.toString().trim().replaceAll(RegExp(r'\s+'), '_');
}
