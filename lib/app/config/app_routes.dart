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
import 'package:esteticaybellezastrani/features/catalog_services/presentation/cubits/admin_catalog_cubit.dart';
import 'package:esteticaybellezastrani/features/catalog_services/presentation/screens/admin_catalog_screen.dart';
import 'package:esteticaybellezastrani/features/catalog_services/presentation/screens/admin_servicio_detail_screen.dart';
import 'package:esteticaybellezastrani/features/catalog_services/domain/entities/servicio_entity.dart';
import 'package:esteticaybellezastrani/features/auth_users/presentation/screens/welcome_screen.dart';
import 'package:esteticaybellezastrani/app/config/route_guard.dart';

import 'package:esteticaybellezastrani/features/patients_compliance/presentation/screens/face_map_questionnaire_screen.dart';
import 'package:esteticaybellezastrani/features/patients_compliance/presentation/screens/estado_salud_screen.dart';
import 'package:esteticaybellezastrani/features/patients_compliance/presentation/screens/admin_cuestionario_screen.dart';
import 'package:esteticaybellezastrani/features/treatment_photos/presentation/cubits/treatment_photos_cubit.dart';
import 'package:esteticaybellezastrani/features/treatment_photos/presentation/screens/fotografias_screen.dart';
import 'package:esteticaybellezastrani/features/marketplace_citas/presentation/cubits/marketplace_cubit.dart';
import 'package:esteticaybellezastrani/features/marketplace_citas/presentation/screens/specialist_map_screen.dart';
import 'package:esteticaybellezastrani/features/notifications/presentation/cubits/notifications_cubit.dart';
import 'package:esteticaybellezastrani/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/presentation/cubits/treatment_execution_cubit.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/presentation/screens/mis_citas_screen.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/presentation/screens/cita_detalle_screen.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/presentation/screens/face_map_especialista_screen.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/presentation/screens/revision_final_screen.dart';
import 'package:esteticaybellezastrani/features/solicitudes_reserva/domain/entities/servicio_seleccionado_entity.dart';
import 'package:esteticaybellezastrani/features/solicitudes_reserva/presentation/cubits/solicitud_reserva_cubit.dart';
import 'package:esteticaybellezastrani/features/solicitudes_reserva/presentation/cubits/mis_solicitudes_cubit.dart';
import 'package:esteticaybellezastrani/features/solicitudes_reserva/presentation/screens/solicitud_resumen_screen.dart';
import 'package:esteticaybellezastrani/features/solicitudes_reserva/presentation/screens/mis_solicitudes_screen.dart';
import 'package:esteticaybellezastrani/features/admin_config/presentation/cubits/admin_dashboard_cubit.dart';
import 'package:esteticaybellezastrani/features/admin_config/presentation/cubits/admin_configuracion_cubit.dart';
import 'package:esteticaybellezastrani/features/admin_config/presentation/screens/admin_licencias_screen.dart';
import 'package:esteticaybellezastrani/features/admin_config/presentation/screens/admin_configuracion_screen.dart';
import 'package:esteticaybellezastrani/features/admin_master_data/presentation/cubits/admin_roles_cubit.dart';
import 'package:esteticaybellezastrani/features/admin_master_data/presentation/cubits/admin_especialidades_cubit.dart';
import 'package:esteticaybellezastrani/features/admin_master_data/presentation/cubits/admin_comisiones_cubit.dart';
import 'package:esteticaybellezastrani/features/admin_master_data/presentation/cubits/admin_medicos_regentes_cubit.dart';
import 'package:esteticaybellezastrani/features/admin_master_data/presentation/screens/admin_datos_maestros_screen.dart';
import 'package:esteticaybellezastrani/features/admin_master_data/presentation/screens/admin_roles_screen.dart';
import 'package:esteticaybellezastrani/features/admin_master_data/presentation/screens/admin_especialidades_screen.dart';
import 'package:esteticaybellezastrani/features/admin_master_data/presentation/screens/admin_comisiones_screen.dart';
import 'package:esteticaybellezastrani/features/admin_master_data/presentation/screens/admin_medicos_regentes_screen.dart';
import 'package:esteticaybellezastrani/features/payments_stripe/presentation/cubits/admin_conciliacion_cubit.dart';
import 'package:esteticaybellezastrani/features/payments_stripe/presentation/screens/admin_conciliacion_screen.dart';

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
  static const String adminCuestionario    = '/admin/cuestionario';
  static const String adminCatalog         = '/admin/catalog';
  static const String adminCatalogServicio = '/admin/catalog/servicio';
  static const String adminLicencias       = '/admin/licencias';
  static const String adminConfiguracion   = '/admin/configuracion';
  static const String adminConciliacion     = '/admin/conciliacion';
  static const String adminDatosMaestros   = '/admin/datos-maestros';
  static const String adminRoles           = '/admin/datos-maestros/roles';
  static const String adminComisiones      = '/admin/datos-maestros/comisiones';
  static const String adminEspecialidades  = '/admin/datos-maestros/especialidades';
  static const String adminMedicosRegentes = '/admin/datos-maestros/medicos-regentes';
  static const String specialistHome       = '/specialist';
  static const String specialistProfile    = '/specialist/profile';
  static const String specialistDocuments  = '/specialist/documents';
  static const String specialistContract   = '/specialist/contract';
  static const String specialistOnboarding = '/specialist/onboarding';
  static const String notifications = '/specialist/notificaciones';
  static const String profile              = '/profile';
  static const String changePassword       = '/change-password';
  static const String faceMapQuestionnaire = '/face-map-questionnaire';
  static const String estadoSalud = '/estado-salud';
  static const String fotografiasTratamiento = '/tratamiento/:id/fotos';
  static const String faceMapEspecialista = '/tratamiento/:id/face-map';
  static const String revisionFinal = '/tratamiento/:tratamientoId/revision/:citaId';

  /// Ruta concreta de fotografías de un tratamiento (sustituye `:id`).
  static String fotografiasTratamientoDe(String tratamientoId) =>
      '/tratamiento/$tratamientoId/fotos';

  /// Ruta concreta del face map del especialista para un tratamiento.
  static String faceMapEspecialistaDe(String tratamientoId) =>
      '/tratamiento/$tratamientoId/face-map';

  /// Ruta concreta de la revisión final de un tratamiento.
  static String revisionFinalDe(String tratamientoId, String citaId) =>
      '/tratamiento/$tratamientoId/revision/$citaId';
  static const String specialistPatientMap = '/specialist/map';
  static const String misCitas = '/specialist/mis-citas';
  static const String misCitasDetalle = '/specialist/mis-citas/:id';
  static const String misSolicitudes = '/mis-solicitudes';
  static const String solicitudResumen = '/solicitud/resumen';

  /// Ruta concreta del detalle de una cita (sustituye el parámetro `:id`).
  static String misCitasDetalleDe(String citaId) => '$misCitas/$citaId';
}

/// Observador de rutas para que las pantallas reaccionen al volver a quedar
/// visibles (p.ej. el catálogo re-valida el estado médico tras la renovación).
final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

/// GoRouter con guards de navegación basados en estado de AuthCubit
final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.welcome,
  debugLogDiagnostics: false,
  observers: [routeObserver],
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
      path: AppRoutes.notifications,
      name: 'notifications',
      builder: (context, state) => BlocProvider<NotificationsCubit>.value(
        value: sl<NotificationsCubit>(),
        child: const NotificationsScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.adminDashboard,
      name: 'adminDashboard',
      builder: (context, state) => BlocProvider<AdminDashboardCubit>.value(
        value: sl<AdminDashboardCubit>(),
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
      path: AppRoutes.adminCuestionario,
      name: 'adminCuestionario',
      builder: (context, state) => const AdminCuestionarioScreen(),
    ),
    GoRoute(
      path: AppRoutes.adminCatalog,
      name: 'adminCatalog',
      builder: (context, state) => BlocProvider<AdminCatalogCubit>.value(
        value: sl<AdminCatalogCubit>(),
        child: const AdminCatalogScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.adminCatalogServicio,
      name: 'adminCatalogServicio',
      builder: (context, state) => AdminServicioDetailScreen(
        servicio: state.extra is ServicioEntity ? state.extra as ServicioEntity : null,
      ),
    ),
    GoRoute(
      path: AppRoutes.adminLicencias,
      name: 'adminLicencias',
      builder: (context, state) => BlocProvider<SpecialistsCubit>.value(
        value: sl<SpecialistsCubit>(),
        child: const AdminLicenciasScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.adminConfiguracion,
      name: 'adminConfiguracion',
      builder: (context, state) =>
          BlocProvider<AdminConfiguracionCubit>.value(
        value: sl<AdminConfiguracionCubit>(),
        child: const AdminConfiguracionScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.adminConciliacion,
      name: 'adminConciliacion',
      builder: (context, state) => BlocProvider<AdminConciliacionCubit>.value(
        value: sl<AdminConciliacionCubit>(),
        child: const AdminConciliacionScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.adminDatosMaestros,
      name: 'adminDatosMaestros',
      builder: (context, state) => const AdminDatosMaestrosScreen(),
    ),
    GoRoute(
      path: AppRoutes.adminRoles,
      name: 'adminRoles',
      builder: (context, state) => BlocProvider<AdminRolesCubit>.value(
        value: sl<AdminRolesCubit>(),
        child: const AdminRolesScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.adminComisiones,
      name: 'adminComisiones',
      builder: (context, state) => BlocProvider<AdminComisionesCubit>.value(
        value: sl<AdminComisionesCubit>(),
        child: const AdminComisionesScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.adminEspecialidades,
      name: 'adminEspecialidades',
      builder: (context, state) =>
          BlocProvider<AdminEspecialidadesCubit>.value(
        value: sl<AdminEspecialidadesCubit>(),
        child: const AdminEspecialidadesScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.adminMedicosRegentes,
      name: 'adminMedicosRegentes',
      builder: (context, state) =>
          BlocProvider<AdminMedicosRegentesCubit>.value(
        value: sl<AdminMedicosRegentesCubit>(),
        child: const AdminMedicosRegentesScreen(),
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
      path: AppRoutes.faceMapEspecialista,
      name: 'faceMapEspecialista',
      builder: (context, state) {
        final tratamientoId = state.pathParameters['id'] ?? '';
        return BlocProvider<TreatmentExecutionCubit>.value(
          value: sl<TreatmentExecutionCubit>(),
          child: FaceMapEspecialistaScreen(tratamientoId: tratamientoId),
        );
      },
    ),
    GoRoute(
      path: AppRoutes.revisionFinal,
      name: 'revisionFinal',
      builder: (context, state) {
        final tratamientoId = state.pathParameters['tratamientoId'] ?? '';
        final citaId = state.pathParameters['citaId'] ?? '';
        return BlocProvider<TreatmentExecutionCubit>.value(
          value: sl<TreatmentExecutionCubit>(),
          child: RevisionFinalScreen(
            citaId: citaId,
            tratamientoId: tratamientoId,
          ),
        );
      },
    ),
    GoRoute(
      path: AppRoutes.estadoSalud,
      name: 'estadoSalud',
      builder: (context, state) => const EstadoSaludScreen(),
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
    GoRoute(
      path: AppRoutes.misSolicitudes,
      name: 'misSolicitudes',
      builder: (context, state) => BlocProvider<MisSolicitudesCubit>.value(
        value: sl<MisSolicitudesCubit>(),
        child: const MisSolicitudesScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.solicitudResumen,
      name: 'solicitudResumen',
      builder: (context, state) => BlocProvider<SolicitudReservaCubit>.value(
        value: sl<SolicitudReservaCubit>(),
        child: SolicitudResumenScreen(
          servicios: state.extra is List<ServicioSeleccionadoEntity>
              ? (state.extra as List<ServicioSeleccionadoEntity>)
              : const [],
        ),
      ),
    ),
  ],
);
