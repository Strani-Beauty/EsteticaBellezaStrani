import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:esteticaybellezastrani/app/config/app_routes.dart';
import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import 'package:esteticaybellezastrani/app/core/di/injection.dart';
import 'package:esteticaybellezastrani/features/auth_users/presentation/cubits/auth_cubit.dart';
import 'package:esteticaybellezastrani/features/auth_users/presentation/widgets/avatar_profile_button.dart';
import 'package:esteticaybellezastrani/features/catalog_services/domain/entities/servicio_entity.dart';
import 'package:esteticaybellezastrani/features/catalog_services/domain/usecases/validar_requisitos_servicio.dart';
import 'package:esteticaybellezastrani/features/catalog_services/presentation/cubits/catalog_cubit.dart';
import 'package:esteticaybellezastrani/features/catalog_services/presentation/widgets/service_image_hero.dart';
import 'package:esteticaybellezastrani/features/patients_compliance/domain/repositories/i_patients_compliance_repository.dart';
import 'package:esteticaybellezastrani/features/patients_compliance/domain/usecases/validar_acceso_rn020.dart';
import 'package:esteticaybellezastrani/features/patients_compliance/presentation/screens/face_map_questionnaire_screen.dart';
import 'package:esteticaybellezastrani/features/solicitudes_reserva/domain/entities/servicio_seleccionado_entity.dart';

/// Dashboard de catálogo de servicios — Vista post-evaluación para clientes/pacientes.
/// Los servicios y categorías se cargan desde Supabase (`servicios`, `categorias_servicio`).
/// Permite ingresar a cualquier servicio para cancelar un adelanto (porcentaje del
/// total) o la totalidad, condicionado a contar con evaluación médica vigente (< 1 año).
class ServicesDashboardScreen extends StatefulWidget {
  const ServicesDashboardScreen({super.key});

  @override
  State<ServicesDashboardScreen> createState() => _ServicesDashboardScreenState();
}

class _ServicesDashboardScreenState extends State<ServicesDashboardScreen> with RouteAware {
  bool _isLoadingStatus = true;
  String _evaluationStatus = 'PENDIENTE';
  bool _isExpired = false;

  @override
  void initState() {
    super.initState();
    _loadFlowStatus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CatalogCubit>().load();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  /// Al volver a quedar visible (p.ej. tras la renovación/evaluación) se
  /// re-valida el estado médico para que el banner no quede desactualizado.
  @override
  void didPopNext() {
    _loadFlowStatus();
  }

  Future<void> _loadFlowStatus() async {
    final profile = context.read<AuthCubit>().currentProfile;
    if (profile == null) {
      if (mounted) setState(() => _isLoadingStatus = false);
      return;
    }

    try {
      final res = await sl<ValidarAccesoRN020>()();
      if (mounted) {
        setState(() {
          final result = res.fold((f) => null, (r) => r);
          _evaluationStatus = result?.reason ?? 'PENDIENTE';
          _isExpired = result?.reason == 'VENCIDA';
          _isLoadingStatus = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingStatus = false);
    }
  }

  Future<void> _onServiceSelected(ServicioEntity service) async {
    final title = service.nombre;
    final profile = context.read<AuthCubit>().currentProfile;

    if (profile == null) {
      context.go('${AppRoutes.login}?login=paciente');
      return;
    }

    // ── Vista a página completa del detalle (antes del flujo de reserva) ──
    final detalleResultado = await context.push(
      AppRoutes.serviceDetail,
      extra: service,
    );
    if (!mounted) return;
    if (detalleResultado != 'reservar') return;

    // ── REGLA ESTRICTA RN-020 / RN-022: Validar acceso (capa limpia) ──
    final ruleRes = await sl<ValidarAccesoRN020>()();
    if (!mounted) return;

    final bool allowed = ruleRes.fold((f) => false, (r) => r.allowed);
    final String reason = ruleRes.fold(
      (f) => 'PENDIENTE',
      (r) => r.reason,
    );

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
      // Si el paciente ya tiene un mapa y su tratamiento aún no está cerrado,
      // mostrar los puntos ya seleccionados (solo lectura); solo se pide
      // editar al iniciar otro tratamiento del mismo tipo (previo cerrado).
      final mapData = await sl<IPatientsComplianceRepository>()
          .getFaceMapPorServicio(profileId: profile.id, servicioId: service.id);
      if (!mounted) return;

      final puntos = reconstruirPuntosFaceMap(mapData?['puntos'] ?? []);
      final tratamientoCerrado = mapData?['tratamientoCerrado'] == true;
      final tieneMapa = puntos.isNotEmpty;

      if (tieneMapa && !tratamientoCerrado) {
        final resultado = await context.push(
          AppRoutes.faceMapQuestionnaire,
          extra: FaceMapParams(
            servicioId: service.id,
            soloLectura: true,
            puntosIniciales: puntos,
          ),
        );
        if (resultado == 'continuar' && mounted) {
          _irAResumen(service);
        }
      } else {
        final resultado = await context.push(
          AppRoutes.faceMapQuestionnaire,
          extra: FaceMapParams(
            servicioId: service.id,
            puntosIniciales: tieneMapa ? puntos : null,
          ),
        );
        if (resultado == 'continuar' && mounted) {
          _irAResumen(service);
        }
      }
      return;
    }

    // ── 3. Requisitos de salud por servicio (cuestionarios obligatorios) ──
    final reqRes = await sl<ValidarRequisitosServicio>()(
      ValidarRequisitosServicioParams(
        servicioId: service.id,
        requiereFotos: service.requiereFotos,
        requiereConsentimiento: service.requiereConsentimiento,
      ),
    );
    if (!mounted) return;
    final requisitos = reqRes.fold((_) => null, (r) => r);
    if (requisitos != null && !requisitos.cumple) {
      _showRequisitoSaludModal(requisitos);
      return;
    }

    // ── 4. Si la evaluación está APROBADA y VIGENTE (< 1 año) → Resumen de solicitud ──
    _irAResumen(service);
  }

  /// Navega al resumen de la solicitud de reserva (Act. 4): el paciente revisa
  /// servicios, precio estimado, fecha/hora y ubicación antes de pagar el
  /// depósito y publicar la solicitud.
  void _irAResumen(ServicioEntity service) {
    context.push(
      AppRoutes.solicitudResumen,
      extra: [
        ServicioSeleccionadoEntity(
          servicioId: service.id,
          nombre: service.nombre,
          precioBase: service.precioBase,
        ),
      ],
    );
  }

  /// Modal cuando el servicio tiene cuestionarios de salud obligatorios sin
  /// evaluación APTO vigente del paciente (Act. 10). Ofrece completar el
  /// cuestionario para desbloquear la reserva.
  void _showRequisitoSaludModal(ValidarRequisitosServicioResult requisitos) {
    final nombres = requisitos.cuestionariosPendientes
        .map((c) => c.nombre ?? 'Cuestionario')
        .toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        title: const Row(
          children: [
            Icon(Icons.health_and_safety_rounded, color: AppTheme.cDeepAccent),
            SizedBox(width: 10),
            Expanded(child: Text('Requisito de salud pendiente')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Para reservar este servicio necesitas completar tu evaluación de salud:',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 10),
              for (final nombre in nombres)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline,
                          size: 18, color: AppTheme.cGoldAccent),
                      const SizedBox(width: 8),
                      Expanded(child: Text(nombre)),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              const Text(
                'Al completarla con evaluación APTO, podrás continuar con la reserva.',
                style: TextStyle(fontSize: 12, color: AppTheme.cMutedText),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Más tarde'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.cDeepAccent),
            onPressed: () {
              Navigator.pop(ctx);
              context.push(AppRoutes.estadoSalud);
            },
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: const Text('Completar cuestionario'),
          ),
        ],
      ),
    );
  }

  /// Aviso para visitantes sin cuenta: para seleccionar un servicio deben
  /// registrarse como pacientes. Ofrece "Registrar" (va al alta de paciente) o
  /// "Seguir explorando" (permanece en el catálogo).
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
                'Tu Evaluación Médica Interna ha cumplido 1 año de validez (365 días).',
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
              context.push('${AppRoutes.completeProfile}?pago=1');
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
            'Para acceder a reservar o cancelar cualquier servicio del catálogo, primero debes completar la cuota inicial de \$30 USD y la Evaluación Médica Interna.',
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
    final isLogged = profile != null;

    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthUnauthenticated) {
          context.go('${AppRoutes.login}?login=paciente');
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
              if (isLogged)
                Text('Bienvenido/a, $name',
                    style: const TextStyle(fontSize: 11, color: AppTheme.cMutedText)),
            ],
          ),
          actions: isLogged
              ? [
                  IconButton(
                    onPressed: () => context.push(AppRoutes.misSolicitudes),
                    icon: const Icon(Icons.receipt_long_rounded, color: AppTheme.cDeepAccent),
                    tooltip: 'Mis Solicitudes',
                  ),
                  IconButton(
                    onPressed: () => context.push(AppRoutes.estadoSalud),
                    icon: const Icon(Icons.monitor_heart_rounded, color: AppTheme.cDeepAccent),
                    tooltip: 'Estado de Salud',
                  ),
                  const AvatarProfileButton(diameter: 34, ringColor: AppTheme.cPastelPurple),
                  IconButton(
                    onPressed: () => context.read<AuthCubit>().signOut(),
                    icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                    tooltip: 'Cerrar Sesión',
                  ),
                ]
              : [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.cDeepAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onPressed: () => context.go('${AppRoutes.login}?login=paciente'),
                      child: const Text('Iniciar sesión'),
                    ),
                  ),
                ],
        ),
        body: BlocConsumer<CatalogCubit, CatalogState>(
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
              return Stack(
                children: [
                  _buildCatalog(state, isLogged: isLogged),
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
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildCatalog(CatalogLoaded state, {required bool isLogged}) {
    final servicios = state.servicios;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildCatalogHero()),
        if (isLogged) ...[
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildStatusBanner(),
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildCategoryChips(state),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: servicios.isEmpty
              ? SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      'No hay servicios disponibles en este momento.',
                      style: TextStyle(color: AppTheme.cMutedText),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : SliverLayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.crossAxisExtent >= 1000 ? 3 : 2;
                    final rows = <List<ServicioEntity>>[];
                    for (var i = 0; i < servicios.length; i += columns) {
                      final end =
                          i + columns < servicios.length ? i + columns : servicios.length;
                      rows.add(servicios.sublist(i, end));
                    }

                    return SliverList.builder(
                      itemCount: rows.length,
                      itemBuilder: (context, rowIndex) {
                        final row = rows[rowIndex];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (var i = 0; i < row.length; i++) ...[
                                  if (i > 0) const SizedBox(width: 18),
                                  Expanded(
                                    child: _ServiceCard(
                                      service: row[i],
                                      onTap: () => _onServiceSelected(row[i]),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  Widget _buildCatalogHero() {
    final isDesktop = MediaQuery.sizeOf(context).width >= 1000;
    final height = isDesktop ? 300.0 : 210.0;

    return Container(
      height: height,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppTheme.cPastelPurple,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/Imagen_cat.jpg',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                const ColoredBox(color: AppTheme.cPastelPurple),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, Colors.black54],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text.rich(
                TextSpan(
                  children: const [
                    TextSpan(text: 'Donde la ciencia\n'),
                    TextSpan(
                      text: 'encuentra ',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                    TextSpan(text: 'tu belleza'),
                  ],
                ),
                style: GoogleFonts.gfsDidot(
                  fontSize: isDesktop ? 34 : 26,
                  fontWeight: FontWeight.w400,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
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
                    'Evaluación Médica Interna Aprobada',
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
              'Evaluación aplicada · dictamen médico pendiente (entrevista F2F por videollamada).',
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
    final descripcionMostrada =
        service.descripcionCorta ?? service.descripcion;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: _buildHero(),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.nombre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                  ),
                  if (descripcionMostrada != null &&
                      descripcionMostrada.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      descripcionMostrada,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(fontSize: 11, height: 1.35, color: AppTheme.cMutedText),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    formatPrecioServicio(service),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.cDeepAccent,
                    ),
                  ),
                  if (service.duracionEstimada != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.schedule_rounded,
                            size: 12, color: AppTheme.cMutedText),
                        const SizedBox(width: 3),
                        Text(
                          '${service.duracionEstimada} min',
                          style: const TextStyle(fontSize: 10, color: AppTheme.cMutedText),
                        ),
                      ],
                    ),
                  ],
                  if (service.nombreCategoria != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.cPastelPurple,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        service.nombreCategoria!,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.cDeepAccent,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero() {
    return ServiceImageHero(service: service, fit: BoxFit.cover);
  }
}
