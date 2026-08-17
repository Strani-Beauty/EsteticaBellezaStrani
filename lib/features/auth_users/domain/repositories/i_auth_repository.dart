import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import '../entities/profile_entity.dart';
import '../entities/role_entity.dart';

/// Contrato del repositorio de autenticación y perfiles.
/// La implementación vive en data/repositories/auth_repository_impl.dart
abstract class IAuthRepository {
  // ── Auth ────────────────────────────────────────────────────
  Future<Either<Failure, ProfileEntity>> signIn({
    required String email,
    required String password,
  });

  Future<Either<Failure, ProfileEntity>> signUp({
    required String email,
    required String password,
    required String fullName,
    required String rolNombre,
    String? phone,
  });

  Future<Either<Failure, void>> signOut();

  /// Limpia la sesión local (sin revocar en servidor). Para cierre de app/web.
  Future<Either<Failure, void>> removeLocalSession();

  Future<Either<Failure, void>> resetPassword(String email);

  /// Reenvía el correo de confirmación de cuenta (OTP de registro).
  Future<Either<Failure, void>> resendConfirmationEmail(String email);

  /// Cambia la contraseña del usuario autenticado.
  Future<Either<Failure, void>> changePassword(String newPassword);

  // ── Profile ─────────────────────────────────────────────────
  Future<Either<Failure, ProfileEntity>> getCurrentProfile();

  Future<Either<Failure, ProfileEntity>> updateProfile({
    required String userId,
    String? fullName,
    String? phone,
    String? address,
    double? latitude,
    double? longitude,
    bool? activo,
    bool? paymentCompleted,
    bool? evaluationPassed,
  });

  // ── Roles ────────────────────────────────────────────────────
  Future<Either<Failure, List<RoleEntity>>> getRoles();

  // ── Avatar (storage privado) ────────────────────────────────
  /// Genera una URL firmada de expiración corta para leer un avatar privado.
  Future<Either<Failure, String>> generarUrlFirmadaAvatar(String path);

  // ── Dispositivos / FCM ───────────────────────────────────────
  Future<Either<Failure, void>> registerFcmToken({
    required String profileId,
    required String fcmToken,
    String? plataforma,
  });

  Future<Either<Failure, void>> deactivateFcmToken(String token);
}
