import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:esteticaybellezastrani/app/config/app_routes.dart';

/// Botón de acceso a la pantalla de perfil del usuario autenticado.
/// Reutilizado en los AppBar de cada rol (paciente, especialista, admin).
class ProfileMenuButton extends StatelessWidget {
  final Color? iconColor;
  const ProfileMenuButton({super.key, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => context.go(AppRoutes.profile),
      tooltip: 'Mi perfil',
      icon: Icon(Icons.account_circle_rounded,
          color: iconColor ?? Colors.white),
    );
  }
}