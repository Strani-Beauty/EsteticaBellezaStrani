import 'package:flutter/material.dart';
import 'package:esteticaybellezastrani/app/config/app_theme.dart';

/// Tarjeta de selección de rol en la pantalla de login.
/// Extrae el widget _buildDashboardCard() del monolito original.
class RoleSelectorCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color badgeColor;
  final Color iconColor;
  final VoidCallback onSignIn;
  final VoidCallback onSignUp;

  const RoleSelectorCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.badgeColor,
    required this.iconColor,
    required this.onSignIn,
    required this.onSignUp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(description,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onSignIn,
                  icon: const Icon(Icons.login_rounded, size: 16),
                  label: const Text('Iniciar Sesión'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    minimumSize: Size.zero,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onSignUp,
                  icon: const Icon(Icons.person_add_outlined, size: 16),
                  label: const Text('Registrarse'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    minimumSize: Size.zero,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
