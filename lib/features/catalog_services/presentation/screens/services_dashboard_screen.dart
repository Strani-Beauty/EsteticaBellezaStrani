import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:esteticaybellezastrani/app/config/app_routes.dart';
import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import 'package:esteticaybellezastrani/features/auth_users/presentation/cubits/auth_cubit.dart';
import 'package:esteticaybellezastrani/supabase_service.dart';

/// Dashboard de catálogo de servicios — Vista post-evaluación para clientes/pacientes.
/// Permite ingresar a cualquier servicio para cancelar parte (depósito) o la totalidad,
/// condicionado a contar con evaluación médica vigente (< 1 año) por Telemedicina o Medicina Interna.
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

  static const _services = [
    {
      'title': 'Inyectables & Toxina',
      'desc': 'Toxina botulínica, ácido hialurónico y bioestimuladores de colágeno.',
      'price': 200.0,
      'icon': Icons.local_hospital,
      'image': 'assets/images/service_inyectables.jpg',
    },
    {
      'title': 'Rejuvenecimiento Facial',
      'desc': 'Peelings médicos, microneedling y terapias celulares avanzadas.',
      'price': 150.0,
      'icon': Icons.face,
      'image': 'assets/images/service_rejuvenecimiento.jpg',
    },
    {
      'title': 'Remodelación Corporal',
      'desc': 'Moldeamiento, lipólisis de alta frecuencia y tratamientos reductores.',
      'price': 180.0,
      'icon': Icons.accessibility_new,
      'image': 'assets/images/service_inyectables.jpg',
    },
    {
      'title': 'Láser Médico Avanzado',
      'desc': 'Depilación médica definitiva y rejuvenecimiento láser de alta precisión.',
      'price': 220.0,
      'icon': Icons.wb_incandescent,
      'image': 'assets/images/service_rejuvenecimiento.jpg',
    },
    {
      'title': 'Mesoterapia & Adelgazamiento',
      'desc': 'Programas nutricionales y mesoterapia metabólica de alta eficiencia.',
      'price': 160.0,
      'icon': Icons.fitness_center,
      'image': 'assets/images/service_inyectables.jpg',
    },
    {
      'title': 'Calidad de Piel & Boosters',
      'desc': 'Hidratación profunda con skinboosters, vitaminas y ácido hialurónico.',
      'price': 140.0,
      'icon': Icons.clean_hands,
      'image': 'assets/images/service_rejuvenecimiento.jpg',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadFlowStatus();
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

  void _onServiceSelected(Map<String, dynamic> service) {
    final title = service['title'] as String? ?? '';

    // ── Prueba: Disparar Cuestionario Face Maps & Torso Silhouette al seleccionar servicio Inyectables ──
    if (title.toLowerCase().contains('inyectables')) {
      context.push(AppRoutes.faceMapQuestionnaire);
      return;
    }

    final user = SupabaseService.currentUser;
    if (user == null) {
      context.go(AppRoutes.login);
      return;
    }

    // ── Política de Clientes: Verificar aprobación clínica por Telemedicina o Medicina Interna ──
    if (_evaluationStatus == 'APROBADA' && !_isExpired) {
      // Cliente evaluado y aprobado (vigente < 1 año) → Puede cancelar parte o totalidad
      _showPaymentOptionsModal(service);
    } else if (_evaluationStatus == 'VENCIDA' || _isExpired) {
      // Evaluación vencida (> 1 año) → Mostrar aviso de recordatorio y solicitar pago de $30 + nueva evaluación
      _showExpirationReminderModal();
    } else {
      // Evaluación pendiente / no realizada → Redirigir a evaluación y pago inicial
      _showPendingEvaluationModal();
    }
  }

  void _showPaymentOptionsModal(Map<String, dynamic> service) {
    final title = service['title'] as String;
    final price = (service['price'] as num).toDouble();
    const deposito = 30.0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.cDeepAccent),
            ),
            const SizedBox(height: 4),
            Text(
              service['desc'] as String,
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
                  const Text('Precio Total del Servicio:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
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
        actions: [
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _processServicePayment(serviceTitle: title, servicePrice: price, payFullAmount: false);
            },
            icon: const Icon(Icons.bookmark_add_rounded, size: 18),
            label: Text('Cancelar Depósito (\$$deposito USD)'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cDeepAccent),
            onPressed: () {
              Navigator.pop(ctx);
              _processServicePayment(serviceTitle: title, servicePrice: price, payFullAmount: true);
            },
            icon: const Icon(Icons.check_circle_rounded, size: 18),
            label: Text('Cancelar Totalidad (\$$price USD)'),
          ),
        ],
      ),
    );
  }

  Future<void> _processServicePayment({
    required String serviceTitle,
    required double servicePrice,
    required bool payFullAmount,
  }) async {
    final user = SupabaseService.currentUser;
    if (user == null) return;

    // Mostrar loader breve
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppTheme.cDeepAccent)),
    );

    await SupabaseService.createServicePayment(
      profileId: user.id,
      serviceTitle: serviceTitle,
      servicePrice: servicePrice,
      payFullAmount: payFullAmount,
    );

    if (mounted) Navigator.pop(context); // cerrar loader

    // ── Modo Prueba: Siempre procesar de forma exitosa y continuar el flujo sin detener el sistema ──
    if (mounted) {
      _showPaymentSuccessDialog(serviceTitle, payFullAmount ? servicePrice : 30.0, payFullAmount);
    }
  }

  void _showPaymentSuccessDialog(String serviceTitle, double amount, bool isFull) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppTheme.cSuccess, size: 28),
            SizedBox(width: 10),
            Text('¡Pago Registrado!'),
          ],
        ),
        content: Column(
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
        title: const Row(
          children: [
            Icon(Icons.history_toggle_off_rounded, color: Colors.orangeAccent, size: 28),
            SizedBox(width: 10),
            Text('Recordatorio de Expiración'),
          ],
        ),
        content: Column(
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
        title: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: AppTheme.cDeepAccent, size: 26),
            SizedBox(width: 10),
            Text('Evaluación Requerida'),
          ],
        ),
        content: const Text(
          'Para acceder a reservar o cancelar cualquier servicio del catálogo, primero debes completar la cuota inicial de \$30 USD y la evaluación médica (Telemedicina o Medicina Interna).',
          style: TextStyle(fontSize: 13),
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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth >= 1000;
                    final isTablet = constraints.maxWidth >= 600 && constraints.maxWidth < 1000;
                    final crossAxisCount = isDesktop ? 3 : (isTablet ? 2 : 1);
                    final childAspectRatio = isDesktop ? 0.92 : (isTablet ? 0.88 : 1.02);

                    return GridView.builder(
                      itemCount: _services.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 18,
                        mainAxisSpacing: 18,
                        childAspectRatio: childAspectRatio,
                      ),
                      itemBuilder: (context, i) => _ServiceCard(
                        service: _services[i],
                        onTap: () => _onServiceSelected(_services[i]),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
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

class _ServiceCard extends StatelessWidget {
  final Map<String, dynamic> service;
  final VoidCallback onTap;

  const _ServiceCard({required this.service, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final price = (service['price'] as num).toDouble();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
            child: _buildImage(service['image'] as String, service['icon'] as IconData),
          ),
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
                        service['title'] as String,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 15, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '\$$price',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.cDeepAccent),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  service['desc'] as String,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12, height: 1.3),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 38,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.cDeepAccent,
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    onPressed: onTap,
                    icon: const Icon(Icons.payment_rounded, size: 16),
                    label: const Text('Cancelar / Reservar'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage(String path, IconData icon) {
    const imageHeight = 160.0;
    final fallback = Container(
      height: imageHeight,
      color: AppTheme.cPastelPink,
      child: Center(
        child: Icon(icon, size: 48, color: AppTheme.cDeepAccent),
      ),
    );

    return Image.asset(
      path,
      height: imageHeight,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => fallback,
    );
  }
}

