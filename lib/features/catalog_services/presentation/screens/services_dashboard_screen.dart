import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:esteticaybellezastrani/app/config/app_routes.dart';
import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import 'package:esteticaybellezastrani/features/auth_users/presentation/cubits/auth_cubit.dart';

/// Dashboard de catálogo de servicios — Vista post-evaluación para pacientes.
/// TODO Fase 4: Conectar con CatalogServicesCubit y datos reales de Supabase.
class ServicesDashboardScreen extends StatelessWidget {
  const ServicesDashboardScreen({super.key});

  static const _services = [
    {
      'title': 'Inyectables',
      'desc': 'Toxina botulínica, ácido hialurónico y bioestimuladores de colágeno.',
      'icon': Icons.local_hospital,
      'image': 'assets/images/service_inyectables.jpg',
    },
    {
      'title': 'Rejuvenecimiento Facial',
      'desc': 'Peelings médicos, microneedling y terapias celulares avanzadas.',
      'icon': Icons.face,
      'image': 'assets/images/service_rejuvenecimiento.jpg',
    },
    {
      'title': 'Corporal',
      'desc': 'Moldeamiento, drenaje linfático y tratamientos reductores.',
      'icon': Icons.accessibility_new,
      'image': 'assets/images/service_inyectables.jpg',
    },
    {
      'title': 'Láser',
      'desc': 'Depilación médica definitiva y rejuvenecimiento láser de alta precisión.',
      'icon': Icons.wb_incandescent,
      'image': 'assets/images/service_rejuvenecimiento.jpg',
    },
    {
      'title': 'Adelgazamiento',
      'desc': 'Programas nutricionales y mesoterapia metabólica.',
      'icon': Icons.fitness_center,
      'image': 'assets/images/service_inyectables.jpg',
    },
    {
      'title': 'Calidad de Piel',
      'desc': 'Hidratación profunda con skinboosters y vitaminas.',
      'icon': Icons.clean_hands,
      'image': 'assets/images/service_rejuvenecimiento.jpg',
    },
  ];

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
                context.go(AppRoutes.login);
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
              tooltip: 'Editar / Ver Perfil de Paciente',
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.cBrandGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(
                    color: AppTheme.cBrandGreen.withValues(alpha: 0.25)),
              ),
              child: const Row(children: [
                Icon(Icons.verified_rounded, color: AppTheme.cBrandGreen, size: 18),
                SizedBox(width: 8),
                Text('Perfil Activo · Selecciona el servicio deseado',
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.cBrandGreen,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth >= 1000;
                  final isTablet = constraints.maxWidth >= 600 && constraints.maxWidth < 1000;
                  final crossAxisCount = isDesktop ? 3 : (isTablet ? 2 : 1);
                  final childAspectRatio = isDesktop ? 0.95 : (isTablet ? 0.90 : 1.05);

                  return GridView.builder(
                    itemCount: _services.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 18,
                      mainAxisSpacing: 18,
                      childAspectRatio: childAspectRatio,
                    ),
                    itemBuilder: (context, i) => _ServiceCard(service: _services[i]),
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
}

class _ServiceCard extends StatelessWidget {
  final Map<String, dynamic> service;
  const _ServiceCard({required this.service});

  @override
  Widget build(BuildContext context) {
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
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppTheme.radiusLg)),
            child: _buildImage(service['image'] as String, service['icon'] as IconData),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(service['title'] as String,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(service['desc'] as String,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13, height: 1.3)),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity, height: 38,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    onPressed: () {
                      context.push(AppRoutes.completeProfile);
                    },
                    child: const Text('Seleccionar'),
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
    final isNetwork = path.startsWith('http');
    const imageHeight = 200.0;
    final fallback = Container(
      height: imageHeight,
      color: AppTheme.cPastelPink,
      child: Center(
        child: Icon(icon, size: 48, color: AppTheme.cDeepAccent),
      ),
    );

    if (isNetwork) {
      return Image.network(
        path,
        height: imageHeight,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      );
    }

    return Image.asset(
      path,
      height: imageHeight,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => fallback,
    );
  }
}
