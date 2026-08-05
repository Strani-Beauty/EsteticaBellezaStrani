import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:esteticaybellezastrani/app/core/di/injection.dart';
import 'package:esteticaybellezastrani/features/auth_users/presentation/cubits/auth_cubit.dart';
import 'package:esteticaybellezastrani/features/auth_users/presentation/screens/login_screen.dart';
import 'package:esteticaybellezastrani/features/auth_users/presentation/screens/complete_profile_screen.dart';
import 'package:esteticaybellezastrani/features/catalog_services/presentation/screens/services_dashboard_screen.dart';
import 'package:esteticaybellezastrani/features/specialists/presentation/cubits/specialists_cubit.dart';
import 'package:esteticaybellezastrani/features/specialists/presentation/screens/specialist_home_screen.dart';
import 'package:esteticaybellezastrani/features/specialists/presentation/screens/specialist_documents_screen.dart';
import 'package:esteticaybellezastrani/features/admin_config/presentation/screens/admin_dashboard_screen.dart';
import 'package:esteticaybellezastrani/features/auth_users/presentation/screens/welcome_screen.dart';
import 'package:esteticaybellezastrani/app/config/app_constants.dart';

import 'package:esteticaybellezastrani/features/patients_compliance/presentation/screens/face_map_questionnaire_screen.dart';
import 'package:esteticaybellezastrani/features/treatment_photos/presentation/cubits/treatment_photos_cubit.dart';
import 'package:esteticaybellezastrani/features/treatment_photos/presentation/screens/fotografias_screen.dart';

/// Rutas nombradas de la aplicación
class AppRoutes {
  AppRoutes._();

  static const String welcome              = '/';
  static const String login                = '/login';
  static const String completeProfile      = '/complete-profile';
  static const String services             = '/services';
  static const String appointments         = '/appointments';
  static const String treatment            = '/treatment/:id';
  static const String payment              = '/payment/:id';
  static const String adminDashboard       = '/admin';
  static const String specialistHome       = '/specialist';
  static const String specialistDocuments  = '/specialist/documents';
  static const String profile              = '/profile';
  static const String faceMapQuestionnaire = '/face-map-questionnaire';
  static const String fotografiasTratamiento = '/tratamiento/:id/fotos';
}

/// GoRouter con guards de navegación basados en estado de AuthCubit
final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.welcome,
  debugLogDiagnostics: false,
  redirect: (BuildContext context, GoRouterState state) {
    final authCubit = context.read<AuthCubit>();
    final authState = authCubit.state;
    final location = state.matchedLocation;

    // Rutas públicas que no requieren autenticación
    final publicRoutes = [AppRoutes.welcome, AppRoutes.services, AppRoutes.faceMapQuestionnaire];

    // Si está cargando, no redirigir
    if (authState is AuthLoading || authState is AuthInitial) return null;

    // Si no está autenticado → permitir rutas públicas, sino ir a welcome
    if (authState is AuthUnauthenticated || authState is AuthInitial) {
      if (publicRoutes.contains(location) || location == AppRoutes.login) return null;
      return AppRoutes.welcome;
    }

    // Si está autenticado
    if (authState is AuthAuthenticated) {
      final profile = authState.profile;

      // Si está en login y ya autenticado → redirigir por rol
      if (location == AppRoutes.login) {
        return _redirectByRole(profile.rolNombre);
      }

      // Si el perfil no está completo → completar perfil (solo pacientes)
      if (profile.isPatient &&
          !profile.activo &&
          location != AppRoutes.completeProfile &&
          location != AppRoutes.faceMapQuestionnaire) {
        return AppRoutes.completeProfile;
      }
    }

    return null;
  },
  routes: [
    GoRoute(
      path: AppRoutes.welcome,
      name: 'welcome',
      builder: (context, state) => const WelcomeScreen(),
    ),
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
      builder: (context, state) => BlocProvider<SpecialistsCubit>(
        create: (_) => sl<SpecialistsCubit>(),
        child: const SpecialistHomeScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.specialistDocuments,
      name: 'specialistDocuments',
      builder: (context, state) => BlocProvider<SpecialistsCubit>(
        create: (_) => sl<SpecialistsCubit>(),
        child: SpecialistDocumentsScreen(
          especialistaId: state.extra as String? ?? '',
          isOnboarding: true,
        ),
      ),
    ),
    GoRoute(
      path: AppRoutes.adminDashboard,
      name: 'adminDashboard',
      builder: (context, state) => BlocProvider<SpecialistsCubit>(
        create: (_) => sl<SpecialistsCubit>(),
        child: const AdminDashboardScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.faceMapQuestionnaire,
      name: 'faceMapQuestionnaire',
      builder: (context, state) {
        final tratamientoId = state.extra as String?;
        return FaceMapQuestionnaireScreen(tratamientoId: tratamientoId);
      },
    ),
    GoRoute(
      path: AppRoutes.fotografiasTratamiento,
      name: 'fotografiasTratamiento',
      builder: (context, state) {
        final tratamientoId = state.pathParameters['id'] ?? '';
        return BlocProvider<TreatmentPhotosCubit>(
          create: (_) => sl<TreatmentPhotosCubit>(),
          child: FotografiasScreen(tratamientoId: tratamientoId),
        );
      },
    ),
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
