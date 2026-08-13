import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:esteticaybellezastrani/app/config/app_routes.dart';
import '../cubits/auth_cubit.dart';

/// Botón de acceso a la pantalla de perfil del usuario autenticado.
/// Reutilizado en los AppBar de cada rol (paciente, especialista, admin).
/// Los especialistas se dirigen a su perfil ampliado (datos profesionales).
class ProfileMenuButton extends StatelessWidget {
  final Color? iconColor;
  const ProfileMenuButton({super.key, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () {
        final isSpecialist =
            context.read<AuthCubit>().currentProfile?.isSpecialist == true;
        context.go(isSpecialist ? AppRoutes.specialistProfile : AppRoutes.profile);
      },
      tooltip: 'Mi perfil',
      icon: Icon(Icons.account_circle_rounded,
          color: iconColor ?? Colors.white),
    );
  }
}