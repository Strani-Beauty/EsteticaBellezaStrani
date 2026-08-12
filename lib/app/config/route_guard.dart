import 'package:esteticaybellezastrani/app/config/app_constants.dart';
import 'package:esteticaybellezastrani/app/config/app_routes.dart';
import 'package:esteticaybellezastrani/features/auth_users/presentation/cubits/auth_cubit.dart';

/// Lógica pura de redirect de GoRouter.
/// Devuelve la ruta a la que redirigir o `null` si se permite la navegación.
/// `onDeactivated` se invoca cuando un usuario con `activo=false` intenta usar
/// funciones protegidas (el llamador cierra la sesión).
String? resolveAuthRedirect({
  required AuthState authState,
  required String location,
  required void Function() onDeactivated,
}) {
  final publicRoutes = [
    AppRoutes.welcome,
    AppRoutes.services,
    AppRoutes.faceMapQuestionnaire,
    AppRoutes.resetPassword,
  ];

  // Si está cargando (incluido un signOut en curso), no redirigir.
  if (authState is AuthLoading || authState is AuthInitial) return null;

  // Sin autenticación → rutas públicas o login; lo demás a welcome.
  if (authState is AuthUnauthenticated) {
    if (publicRoutes.contains(location) || location == AppRoutes.login) {
      return null;
    }
    return AppRoutes.welcome;
  }

  if (authState is AuthAuthenticated) {
    final profile = authState.profile;

    // ── Guard de cuenta desactivada (item 17) ──────────────────
    // `activo=false`:
    //   * Especialista/Administrador → nacen activos; un false solo proviene
    //     del panel admin → cerrar sesión (no pueden usar la app).
    //   * Paciente → false es su estado de onboarding (dirección + cuota +
    //     evaluación). Conserva acceso SOLO a su onboarding y al catálogo;
    //     cualquier función protegida redirige a completar perfil.
    if (!profile.activo) {
      if (profile.isSpecialist || profile.isAdmin) {
        onDeactivated();
        return AppRoutes.welcome;
      }
      if (profile.isPatient &&
          location != AppRoutes.completeProfile &&
          location != AppRoutes.faceMapQuestionnaire &&
          location != AppRoutes.services &&
          location != AppRoutes.resetPassword) {
        return AppRoutes.completeProfile;
      }
    }

    // Si está en login y ya autenticado → redirigir por rol.
    if (location == AppRoutes.login) {
      return _redirectByRole(profile.rolNombre);
    }

    // ── Guards por rol (cierran deep-links con sesión de otro rol) ──
    if (_esRutaAdmin(location) && !profile.isAdmin) {
      return _redirectByRole(profile.rolNombre);
    }
    if (_esRutaEspecialista(location) && !profile.isSpecialist) {
      return _redirectByRole(profile.rolNombre);
    }
    if (location == AppRoutes.completeProfile && !profile.isPatient) {
      return _redirectByRole(profile.rolNombre);
    }
  }

  return null;
}

bool _esRutaAdmin(String location) {
  return location == AppRoutes.adminDashboard ||
      location.startsWith('${AppRoutes.adminDashboard}/');
}

bool _esRutaEspecialista(String location) {
  const rutas = [
    AppRoutes.specialistHome,
    AppRoutes.specialistOnboarding,
    AppRoutes.specialistDocuments,
    AppRoutes.specialistPatientMap,
    AppRoutes.misCitas,
    AppRoutes.misCitasDetalle,
  ];
  return rutas.contains(location) || location.startsWith(AppRoutes.specialistHome);
}

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