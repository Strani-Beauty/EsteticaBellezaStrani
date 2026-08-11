import 'package:flutter_test/flutter_test.dart';
import 'package:esteticaybellezastrani/app/config/app_routes.dart';
import 'package:esteticaybellezastrani/app/config/route_guard.dart';
import 'package:esteticaybellezastrani/features/auth_users/domain/entities/profile_entity.dart';
import 'package:esteticaybellezastrani/features/auth_users/presentation/cubits/auth_cubit.dart';

ProfileEntity _perfil({
  required String rol,
  bool activo = true,
}) {
  return ProfileEntity(
    id: 'user-1',
    email: 'test@example.com',
    fullName: 'Usuario de prueba',
    rolNombre: rol,
    activo: activo,
    paymentCompleted: true,
    evaluationPassed: true,
    createdAt: DateTime(2026, 1, 1),
  );
}

String? _guard({
  required AuthState state,
  required String location,
  bool Function()? onDeactivated,
}) {
  return resolveAuthRedirect(
    authState: state,
    location: location,
    onDeactivated: () => onDeactivated?.call(),
  );
}

void main() {
  group('Acceso sin autenticación', () {
    test('permite rutas públicas y login', () {
      const state = AuthUnauthenticated();
      expect(_guard(state: state, location: AppRoutes.welcome), isNull);
      expect(_guard(state: state, location: AppRoutes.services), isNull);
      expect(
        _guard(state: state, location: AppRoutes.faceMapQuestionnaire),
        isNull,
      );
      expect(_guard(state: state, location: AppRoutes.login), isNull);
    });

    test('protege rutas privadas', () {
      const state = AuthUnauthenticated();
      expect(_guard(state: state, location: AppRoutes.adminDashboard),
          AppRoutes.welcome);
      expect(_guard(state: state, location: AppRoutes.specialistHome),
          AppRoutes.welcome);
      expect(_guard(state: state, location: AppRoutes.misCitas),
          AppRoutes.welcome);
    });
  });

  group('Item 18: acceso de cada rol a su ruta', () {
    test('Paciente activo accede a su catálogo y no a rutas de admin/especialista',
        () {
      final state = AuthAuthenticated(_perfil(rol: 'Paciente'));
      expect(_guard(state: state, location: AppRoutes.services), isNull);
      expect(_guard(state: state, location: AppRoutes.completeProfile), isNull);
      expect(_guard(state: state, location: AppRoutes.adminDashboard),
          AppRoutes.services);
      expect(_guard(state: state, location: AppRoutes.adminUsuarios),
          AppRoutes.services);
      expect(_guard(state: state, location: AppRoutes.specialistHome),
          AppRoutes.services);
      expect(_guard(state: state, location: AppRoutes.misCitas),
          AppRoutes.services);
    });

    test('Especialista activo accede a su panel y no a rutas de admin', () {
      final state = AuthAuthenticated(_perfil(rol: 'Especialista'));
      expect(_guard(state: state, location: AppRoutes.specialistHome), isNull);
      expect(
        _guard(state: state, location: AppRoutes.specialistOnboarding),
        isNull,
      );
      expect(_guard(state: state, location: AppRoutes.adminDashboard),
          AppRoutes.specialistHome);
      expect(_guard(state: state, location: AppRoutes.adminUsuarios),
          AppRoutes.specialistHome);
      expect(_guard(state: state, location: AppRoutes.completeProfile),
          AppRoutes.specialistHome);
    });

    test('Administrador activo accede a su panel y no a rutas de especialista', () {
      final state = AuthAuthenticated(_perfil(rol: 'Administrador'));
      expect(_guard(state: state, location: AppRoutes.adminDashboard), isNull);
      expect(_guard(state: state, location: AppRoutes.adminUsuarios), isNull);
      expect(_guard(state: state, location: AppRoutes.specialistHome),
          AppRoutes.adminDashboard);
      expect(_guard(state: state, location: AppRoutes.completeProfile),
          AppRoutes.adminDashboard);
    });

    test('autenticado en /login es redirigido a la ruta de su rol', () {
      expect(
        _guard(
          state: AuthAuthenticated(_perfil(rol: 'Paciente')),
          location: AppRoutes.login,
        ),
        AppRoutes.services,
      );
      expect(
        _guard(
          state: AuthAuthenticated(_perfil(rol: 'Especialista')),
          location: AppRoutes.login,
        ),
        AppRoutes.specialistHome,
      );
      expect(
        _guard(
          state: AuthAuthenticated(_perfil(rol: 'Administrador')),
          location: AppRoutes.login,
        ),
        AppRoutes.adminDashboard,
      );
    });
  });

  group('Item 17: usuario desactivado no usa funciones protegidas', () {
    test('especialista desactivado es desconectado', () {
      var signedOut = false;
      final state = AuthAuthenticated(_perfil(rol: 'Especialista', activo: false));
      expect(
        _guard(
          state: state,
          location: AppRoutes.specialistHome,
          onDeactivated: () => signedOut = true,
        ),
        AppRoutes.welcome,
      );
      expect(signedOut, isTrue);
    });

    test('administrador desactivado es desconectado', () {
      var signedOut = false;
      final state = AuthAuthenticated(_perfil(rol: 'Administrador', activo: false));
      expect(
        _guard(
          state: state,
          location: AppRoutes.adminDashboard,
          onDeactivated: () => signedOut = true,
        ),
        AppRoutes.welcome,
      );
      expect(signedOut, isTrue);
    });

    test('paciente inactivo redirige a completar perfil, sin cerrar sesión', () {
      var signedOut = false;
      final state = AuthAuthenticated(_perfil(rol: 'Paciente', activo: false));
      expect(
        _guard(
          state: state,
          location: AppRoutes.misCitas,
          onDeactivated: () => signedOut = true,
        ),
        AppRoutes.completeProfile,
      );
      expect(signedOut, isFalse);
    });

    test('paciente inactivo conserva onboarding y catálogo', () {
      final state = AuthAuthenticated(_perfil(rol: 'Paciente', activo: false));
      expect(_guard(state: state, location: AppRoutes.completeProfile), isNull);
      expect(_guard(state: state, location: AppRoutes.services), isNull);
      expect(
        _guard(state: state, location: AppRoutes.faceMapQuestionnaire),
        isNull,
      );
    });
  });

  group('Item 19: deep-links cruzados cerrados por rol', () {
    test('paciente no entra a /admin ni a rutas especialista por URL', () {
      final state = AuthAuthenticated(_perfil(rol: 'Paciente'));
      expect(_guard(state: state, location: AppRoutes.adminUsuarios),
          AppRoutes.services);
      expect(_guard(state: state, location: AppRoutes.misCitasDetalle),
          AppRoutes.services);
      expect(_guard(state: state, location: AppRoutes.specialistOnboarding),
          AppRoutes.services);
    });

    test('especialista no entra a /admin/usuarios por URL', () {
      final state = AuthAuthenticated(_perfil(rol: 'Especialista'));
      expect(_guard(state: state, location: AppRoutes.adminUsuarios),
          AppRoutes.specialistHome);
    });

    test('admin no entra a /specialist por URL', () {
      final state = AuthAuthenticated(_perfil(rol: 'Administrador'));
      expect(_guard(state: state, location: AppRoutes.specialistHome),
          AppRoutes.adminDashboard);
      expect(_guard(state: state, location: AppRoutes.misCitas),
          AppRoutes.adminDashboard);
    });
  });
}
