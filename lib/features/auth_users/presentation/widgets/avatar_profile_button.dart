import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:esteticaybellezastrani/app/config/app_routes.dart';
import '../cubits/auth_cubit.dart';
import 'avatar_view.dart';

/// Botón de acceso al perfil con el avatar/foto del usuario autenticado.
///
/// Reemplaza al icono genérico "Mi perfil" como identificador al tope-derecho del
/// AppBar: muestra el retrato/foto del paciente (o el ícono de rol para
/// especialista/admin). Los especialistas se dirigen a su perfil ampliado.
class AvatarProfileButton extends StatelessWidget {
  /// Diámetro del avatar en píxeles.
  final double diameter;

  /// Color del anillo de contraste (visible sobre AppBar morados).
  final Color ringColor;

  const AvatarProfileButton({
    super.key,
    this.diameter = 36,
    this.ringColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthCubit>().currentProfile;
    if (profile == null) return const SizedBox.shrink();

    return Tooltip(
      message: 'Mi perfil',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          context.go(
            profile.isSpecialist ? AppRoutes.specialistProfile : AppRoutes.profile,
          );
        },
        child: Container(
          width: diameter,
          height: diameter,
          padding: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ringColor,
          ),
          child: AvatarView(
            avatarUrl: profile.avatarUrl,
            isPatient: profile.isPatient,
            isAdmin: profile.isAdmin,
            isSpecialist: profile.isSpecialist,
            seed: profile.id,
            diameter: diameter - 3,
            showBorder: false,
          ),
        ),
      ),
    );
  }
}