import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:esteticaybellezastrani/app/core/di/injection.dart';
import 'package:esteticaybellezastrani/features/auth_users/presentation/cubits/auth_cubit.dart';
import 'package:esteticaybellezastrani/features/auth_users/presentation/screens/login_screen.dart';
import 'package:esteticaybellezastrani/features/auth_users/presentation/screens/complete_profile_screen.dart';
import 'package:esteticaybellezastrani/features/auth_users/presentation/screens/profile_screen.dart';
import 'package:esteticaybellezastrani/features/auth_users/presentation/screens/change_password_screen.dart';
import 'package:esteticaybellezastrani/features/auth_users/presentation/screens/reset_password_screen.dart';
import 'package:esteticaybellezastrani/features/admin_users/presentation/screens/admin_users_screen.dart';
import 'package:esteticaybellezastrani/features/admin_users/presentation/cubits/admin_users_cubit.dart';
import 'package:esteticaybellezastrani/features/catalog_services/presentation/cubits/catalog_cubit.dart';
import 'package:esteticaybellezastrani/features/catalog_services/presentation/screens/services_dashboard_screen.dart';
import 'package:esteticaybellezastrani/features/specialists/presentation/cubits/specialists_cubit.dart';
import 'package:esteticaybellezastrani/features/specialists/presentation/screens/specialist_home_screen.dart';
import 'package:esteticaybellezastrani/features/specialists/presentation/screens/specialist_documents_screen.dart';
import 'package:esteticaybellezastrani/features/specialists/presentation/screens/specialist_onboarding_screen.dart';
import 'package:esteticaybellezastrani/features/specialists/presentation/screens/specialist_profile_screen.dart';
import 'package:esteticaybellezastrani/features/specialists/presentation/screens/contract_signature_screen.dart';
import 'package:esteticaybellezastrani/features/admin_config/presentation/screens/admin_dashboard_screen.dart';
import 'package:esteticaybellezastrani/features/auth_users/presentation/screens/welcome_screen.dart';
import 'package:esteticaybellezastrani/app/config/route_guard.dart';

import 'package:esteticaybellezastrani/features/patients_compliance/presentation/screens/face_map_questionnaire_screen.dart';
import 'package:esteticaybellezastrani/features/treatment_photos/presentation/cubits/treatment_photos_cubit.dart';
import 'package:esteticaybellezastrani/features/treatment_photos/presentation/screens/fotografias_screen.dart';
import 'package:esteticaybellezastrani/features/marketplace_citas/presentation/cubits/marketplace_cubit.dart';
import 'package:esteticaybellezastrani/features/marketplace_citas/presentation/screens/specialist_map_screen.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/presentation/cubits/treatment_execution_cubit.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/presentation/screens/mis_citas_screen.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/presentation/screens/cita_detalle_screen.dart';

/// Rutas nombradas de la aplicación
class AppRoutes {
  AppRoutes._();

  static const String welcome              = '/';
  static const String login                = '/login';
  static const String resetPassword        = '/auth/reset-password';
  static const String completeProfile      = '/complete-profile';
  static const String services             = '/services';
  static const String appointments         = '/appointments';
  static const String treatment            = '/treatment/:id';
  static const String payment              = '/payment/:id';
  static const String adminDashboard       = '/admin';
  static const String adminUsuarios        = '/admin/usuarios';
  static const String specialistHome       = '/specialist';
  static const String specialistProfile    = '/specialist/profile';
  static const String specialistDocuments  = '/specialist/documents';
  static const String specialistContract   = '/specialist/contract';
  static const String specialistOnboarding = '/specialist/onboarding';
  static const String profile              = '/profile';
  static const String changePassword       = '/change-password';
  static const String faceMapQuestionnaire = '/face-map-questionnaire';
  static const String fotografiasTratamiento = '/tratamiento/:id/fotos';

  /// Ruta concreta de fotografías de un tratamiento (sustituye `:id`).
  static String fotografiasTratamientoDe(String tratamientoId) =>
      '/tratamiento/$tratamientoId/fotos';
  static const String specialistPatientMap = '/specialist/map';
  static const String misCitas = '/specialist/mis-citas';
  static const String misCitasDetalle = '/specialist/mis-citas/:id';

  /// Ruta concreta del detalle de una cita (sustituye el parámetro `:id`).
  static String misCitasDetalleDe(String citaId) => '$misCitas/$citaId';
}

/// GoRouter con guards de navegación basados en estado de AuthCubit
final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.welcome,
  debugLogDiagnostics: false,
  redirect: (BuildContext context, GoRouterState state) {
    final authCubit = context.read<AuthCubit>();
    return resolveAuthRedirect(
      authState: authCubit.state,
      location: state.matchedLocation,
      onDeactivated: () => authCubit.signOut(),
    );
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
      builder: (context, state) => LoginScreen(
        registroPaciente: state.uri.queryParameters['registro'] == 'paciente',
      ),
    ),
    GoRoute(
      path: AppRoutes.resetPassword,
      name: 'resetPassword',
      builder: (context, state) => const ResetPasswordScreen(),
    ),
    GoRoute(
      path: AppRoutes.completeProfile,
      name: 'completeProfile',
      builder: (context, state) => const CompleteProfileScreen(),
    ),
    GoRoute(
      path: AppRoutes.profile,
      name: 'profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: AppRoutes.changePassword,
      name: 'changePassword',
      builder: (context, state) => const ChangePasswordScreen(),
    ),
    GoRoute(
      path: AppRoutes.services,
      name: 'services',
      builder: (context, state) => BlocProvider<CatalogCubit>.value(
        value: sl<CatalogCubit>(),
        child: const ServicesDashboardScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.specialistHome,
      name: 'specialistHome',
      builder: (context, state) => BlocProvider<SpecialistsCubit>.value(
        value: sl<SpecialistsCubit>(),
        child: const SpecialistHomeScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.specialistProfile,
      name: 'specialistProfile',
      builder: (context, state) => BlocProvider<SpecialistsCubit>.value(
        value: sl<SpecialistsCubit>(),
        child: const SpecialistProfileScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.specialistDocuments,
      name: 'specialistDocuments',
      builder: (context, state) => BlocProvider<SpecialistsCubit>.value(
        value: sl<SpecialistsCubit>(),
        child: SpecialistDocumentsScreen(
          especialistaId: state.extra as String? ?? '',
          isOnboarding: true,
        ),
      ),
    ),
    GoRoute(
      path: AppRoutes.specialistContract,
      name: 'specialistContract',
      builder: (context, state) => BlocProvider<SpecialistsCubit>.value(
        value: sl<SpecialistsCubit>(),
        child: ContractSignatureScreen(
          especialistaId: state.extra as String? ?? '',
        ),
      ),
    ),
    GoRoute(
      path: AppRoutes.specialistOnboarding,
      name: 'specialistOnboarding',
      builder: (context, state) => BlocProvider<SpecialistsCubit>.value(
        value: sl<SpecialistsCubit>(),
        child: SpecialistOnboardingScreen(
          especialistaId: state.extra as String? ?? '',
        ),
      ),
    ),
    GoRoute(
      path: AppRoutes.adminDashboard,
      name: 'adminDashboard',
      builder: (context, state) => BlocProvider<SpecialistsCubit>.value(
        value: sl<SpecialistsCubit>(),
        child: const AdminDashboardScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.adminUsuarios,
      name: 'adminUsuarios',
      builder: (context, state) => BlocProvider<AdminUsersCubit>.value(
        value: sl<AdminUsersCubit>(),
        child: const AdminUsersScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.faceMapQuestionnaire,
      name: 'faceMapQuestionnaire',
      builder: (context, state) {
        final extra = state.extra;
        if (extra is FaceMapParams) {
          return FaceMapQuestionnaireScreen(
            tratamientoId: extra.tratamientoId,
            servicioId: extra.servicioId,
            soloLectura: extra.soloLectura,
            puntosIniciales: extra.puntosIniciales,
          );
        }
        // Retro-compatibilidad: el extra solía ser el tratamientoId.
        return FaceMapQuestionnaireScreen(tratamientoId: extra as String?);
      },
    ),
    GoRoute(
      path: AppRoutes.fotografiasTratamiento,
      name: 'fotografiasTratamiento',
      builder: (context, state) {
        final tratamientoId = state.pathParameters['id'] ?? '';
        return BlocProvider<TreatmentPhotosCubit>.value(
          value: sl<TreatmentPhotosCubit>(),
          child: FotografiasScreen(tratamientoId: tratamientoId),
        );
      },
    ),
    GoRoute(
      path: AppRoutes.specialistPatientMap,
      name: 'specialistPatientMap',
      builder: (context, state) => MultiBlocProvider(
        providers: [
          BlocProvider<SpecialistsCubit>.value(value: sl<SpecialistsCubit>()),
          BlocProvider<MarketplaceCubit>.value(value: sl<MarketplaceCubit>()),
        ],
        child: SpecialistMapScreen(
          especialistaId: state.extra as String? ?? '',
        ),
      ),
    ),
    GoRoute(
      path: AppRoutes.misCitas,
      name: 'misCitas',
      builder: (context, state) => BlocProvider<TreatmentExecutionCubit>.value(
        value: sl<TreatmentExecutionCubit>(),
        child: MisCitasScreen(
          especialistaId: state.extra as String? ?? '',
        ),
      ),
    ),
    GoRoute(
      path: AppRoutes.misCitasDetalle,
      name: 'misCitasDetalle',
      builder: (context, state) => BlocProvider<TreatmentExecutionCubit>.value(
        value: sl<TreatmentExecutionCubit>(),
        child: CitaDetalleScreen(
          citaId: state.pathParameters['id'] ?? '',
        ),
      ),
    ),
  ],
);
