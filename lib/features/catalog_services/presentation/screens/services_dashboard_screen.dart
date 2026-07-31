import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
      'image': 'https://images.unsplash.com/photo-1570172619644-dfd03ed5d881?auto=format&fit=crop&w=600&q=80',
    },
    {
      'title': 'Rejuvenecimiento Facial',
      'desc': 'Peelings médicos, microneedling y terapias celulares avanzadas.',
      'icon': Icons.face,
      'image': 'https://images.unsplash.com/photo-1512290900673-70020d20d43a?auto=format&fit=crop&w=600&q=80',
    },
    {
      'title': 'Corporal',
      'desc': 'Moldeamiento, drenaje linfático y tratamientos reductores.',
      'icon': Icons.accessibility_new,
      'image': 'https://images.unsplash.com/photo-1540555700478-4be289fbecef?auto=format&fit=crop&w=600&q=80',
    },
    {
      'title': 'Láser',
      'desc': 'Depilación médica definitiva y rejuvenecimiento láser de alta precisión.',
      'icon': Icons.wb_incandescent,
      'image': 'https://images.unsplash.com/photo-1560750588-73207b1ef5b8?auto=format&fit=crop&w=600&q=80',
    },
    {
      'title': 'Adelgazamiento',
      'desc': 'Programas nutricionales y mesoterapia metabólica.',
      'icon': Icons.fitness_center,
      'image': 'https://images.unsplash.com/photo-1518611012118-696072aa579a?auto=format&fit=crop&w=600&q=80',
    },
    {
      'title': 'Calidad de Piel',
      'desc': 'Hidratación profunda con skinboosters y vitaminas.',
      'icon': Icons.clean_hands,
      'image': 'https://images.unsplash.com/photo-1522337360788-8b13dee7a37e?auto=format&fit=crop&w=600&q=80',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthCubit>().currentProfile;
    final name = profile?.fullName ?? profile?.email ?? 'Paciente';

    return Scaffold(
      appBar: AppBar(
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
              child: GridView.builder(
                itemCount: _services.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.82,
                ),
                itemBuilder: (context, i) => _ServiceCard(service: _services[i]),
              ),
            ),
          ],
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
            child: Image.network(
              service['image'] as String,
              height: 110, width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 110, color: AppTheme.cPastelPink,
                child: Center(child: Icon(
                    service['icon'] as IconData,
                    size: 40, color: AppTheme.cDeepAccent)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(service['title'] as String,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14)),
                const SizedBox(height: 4),
                Text(service['desc'] as String,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity, height: 32,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        textStyle: const TextStyle(fontSize: 12)),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Seleccionado: ${service['title']}'),
                        backgroundColor: AppTheme.cDeepAccent,
                      ));
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
}
