import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:esteticaybellezastrani/features/auth_users/presentation/cubits/auth_cubit.dart';
import 'package:esteticaybellezastrani/features/auth_users/presentation/screens/login_screen.dart';
import 'package:esteticaybellezastrani/features/auth_users/presentation/screens/complete_profile_screen.dart';
import 'package:esteticaybellezastrani/features/catalog_services/presentation/screens/services_dashboard_screen.dart';
import 'package:esteticaybellezastrani/features/specialists/presentation/screens/specialist_home_screen.dart';
import 'package:esteticaybellezastrani/features/admin_config/presentation/screens/admin_dashboard_screen.dart';
import 'package:esteticaybellezastrani/app/config/app_constants.dart';

/// Rutas nombradas de la aplicación
class AppRoutes {
  AppRoutes._();

  static const String login           = '/login';
  static const String completeProfile = '/complete-profile';
  static const String services        = '/services';
  static const String appointments    = '/appointments';
  static const String treatment       = '/treatment/:id';
  static const String payment         = '/payment/:id';
  static const String adminDashboard  = '/admin';
  static const String specialistHome  = '/specialist';
  static const String profile         = '/profile';
}

/// GoRouter con guards de navegación basados en estado de AuthCubit
final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.login,
  debugLogDiagnostics: false,
  redirect: (BuildContext context, GoRouterState state) {
    final authCubit = context.read<AuthCubit>();
    final authState = authCubit.state;
    final location = state.matchedLocation;

    // Si está cargando, no redirigir
    if (authState is AuthLoading || authState is AuthInitial) return null;

    // Si no está autenticado → forzar login
    if (authState is AuthUnauthenticated || authState is AuthInitial) {
      if (location != AppRoutes.login) return AppRoutes.login;
      return null;
    }

    // Si está autenticado
    if (authState is AuthAuthenticated) {
      final profile = authState.profile;

      // Si está en login y ya autenticado → redirigir por rol
      if (location == AppRoutes.login) {
        return _redirectByRole(profile.rolNombre);
      }

      // Si el perfil no está completo → completar perfil
      if (!profile.activo && location != AppRoutes.completeProfile) {
        return AppRoutes.completeProfile;
      }
    }

    return null;
  },
  routes: [
    GoRoute(
      path: AppRoutes.login,
      name: 'login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: AppRoutes.completeProfile,
      name: 'completeProfile',
      builder: (context, state) => const CompleteProfileScreen(),
    ),
    GoRoute(
      path: AppRoutes.services,
      name: 'services',
      builder: (context, state) => const ServicesDashboardScreen(),
    ),
    GoRoute(
      path: AppRoutes.specialistHome,
      name: 'specialistHome',
      builder: (context, state) => const SpecialistHomeScreen(),
    ),
    GoRoute(
      path: AppRoutes.adminDashboard,
      name: 'adminDashboard',
      builder: (context, state) => const AdminDashboardScreen(),
    ),
    // TODO Fase 3-7: registrar rutas de marketplace, tratamientos, pagos
  ],
);

String _redirectByRole(String role) {
  switch (role) {
    case AppConstants.rolAdministrador:
      return AppRoutes.adminDashboard;
    case AppConstants.rolEspecialista:
      return AppRoutes.specialistHome;
    case AppConstants.rolPaciente:
    default:
      return AppRoutes.services;
  }
}
