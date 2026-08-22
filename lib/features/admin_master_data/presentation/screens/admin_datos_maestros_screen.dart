import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:esteticaybellezastrani/app/config/app_routes.dart';
import 'package:esteticaybellezastrani/app/config/app_theme.dart';

/// Hub de Datos Maestros — accesos a roles, configuración, comisiones,
/// especialidades y médicos regentes.
class AdminDatosMaestrosScreen extends StatelessWidget {
  const AdminDatosMaestrosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Datos Maestros'),
        backgroundColor: AppTheme.cDeepAccent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _NavCard(
            icon: Icons.admin_panel_settings_outlined,
            color: AppTheme.cPastelPurple,
            title: 'Roles y Permisos',
            subtitle: 'Catálogo RBAC: roles, permisos y asignación',
            onTap: () => context.push(AppRoutes.adminRoles),
          ),
          _NavCard(
            icon: Icons.settings_rounded,
            color: AppTheme.cPastelPink,
            title: 'Configuración del Sistema',
            subtitle: 'Depósito, radio, comisión, adelanto y claves generales',
            onTap: () => context.push(AppRoutes.adminConfiguracion),
          ),
          _NavCard(
            icon: Icons.account_balance_wallet_outlined,
            color: AppTheme.cGoldAccent.withValues(alpha: 0.2),
            title: 'Comisiones y Liquidaciones',
            subtitle: 'Liquidaciones y pagos a especialistas',
            onTap: () => context.push(AppRoutes.adminComisiones),
          ),
          _NavCard(
            icon: Icons.category_outlined,
            color: AppTheme.cBrandGreen.withValues(alpha: 0.15),
            title: 'Especialidades',
            subtitle: 'Catálogo de especialidades',
            onTap: () => context.push(AppRoutes.adminEspecialidades),
          ),
          _NavCard(
            icon: Icons.medical_information_outlined,
            color: AppTheme.cPastelBlue.withValues(alpha: 0.4),
            title: 'Médicos Regentes',
            subtitle: 'Registro y validación de médicos regentes',
            onTap: () => context.push(AppRoutes.adminMedicosRegentes),
          ),
        ],
      ),
    );
  }
}

class _NavCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _NavCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppTheme.cSurface,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        side: const BorderSide(color: Colors.black12),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color,
          child: Icon(icon, color: AppTheme.cDeepAccent),
        ),
        title: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w600, color: AppTheme.cDarkText)),
        subtitle: Text(subtitle,
            style: const TextStyle(color: AppTheme.cMutedText, fontSize: 12)),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}
