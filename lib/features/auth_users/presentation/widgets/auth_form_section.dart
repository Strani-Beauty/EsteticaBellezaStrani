import 'package:flutter/material.dart';
import 'package:esteticaybellezastrani/app/config/app_theme.dart';

/// Encabezado de la sección del formulario con el rol seleccionado.
class AuthFormSection extends StatelessWidget {
  final bool isSignIn;
  final String rolNombre;
  final dynamic selectedType;

  const AuthFormSection({
    super.key,
    required this.isSignIn,
    required this.rolNombre,
    required this.selectedType,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _badgeColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: Icon(_icon, color: _iconColor, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isSignIn ? 'Iniciar Sesión' : 'Crear Cuenta',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Text(
                'Perfil: $rolNombre',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.cDeepAccent,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color get _badgeColor {
    if (rolNombre == 'Especialista') return AppTheme.cPastelBlue;
    if (rolNombre == 'Administrador') return AppTheme.cPastelGold;
    return AppTheme.cPastelPink;
  }

  Color get _iconColor {
    if (rolNombre == 'Especialista') return AppTheme.cBrandGreen;
    if (rolNombre == 'Administrador') return AppTheme.cGoldAccent;
    return AppTheme.cDeepAccent;
  }

  IconData get _icon {
    if (rolNombre == 'Especialista') return Icons.medical_services_rounded;
    if (rolNombre == 'Administrador') return Icons.admin_panel_settings_rounded;
    return Icons.person_rounded;
  }
}
