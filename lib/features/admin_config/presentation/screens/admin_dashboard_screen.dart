import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import 'package:esteticaybellezastrani/features/auth_users/presentation/cubits/auth_cubit.dart';

/// Panel de administración — se completa en Fase 7.
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthCubit>().currentProfile;
    return Scaffold(
      appBar: AppBar(
        title: Text('Panel Admin — ${profile?.fullName ?? 'Administrador'}'),
        actions: [
          IconButton(
            onPressed: () => context.read<AuthCubit>().signOut(),
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
          ),
        ],
      ),
      body: const Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.admin_panel_settings_rounded, size: 80,
              color: AppTheme.cGoldAccent),
          SizedBox(height: 20),
          Text('Panel de Administrador', style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text('Implementación completa en Fase 7',
              style: TextStyle(color: AppTheme.cMutedText)),
        ]),
      ),
    );
  }
}
