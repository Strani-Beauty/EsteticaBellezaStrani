import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import '../../domain/entities/profile_entity.dart';
import '../../domain/entities/role_entity.dart';
import '../../domain/repositories/i_auth_repository.dart';
import '../datasources/auth_supabase_datasource.dart';

/// Implementación del repositorio de auth usando Supabase.
class AuthRepositoryImpl implements IAuthRepository {
  final AuthSupabaseDataSource _dataSource;

  AuthRepositoryImpl(this._dataSource);

  @override
  Future<Either<Failure, ProfileEntity>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dataSource.signIn(email: email, password: password);
      final user = response.user;
      if (user == null) return const Left(AuthFailure('Credenciales inválidas.'));

      final profile = await _dataSource.fetchCurrentProfile();
      if (profile == null) {
        return const Left(AuthFailure('Perfil no encontrado. Contacta soporte.'));
      }
      return Right(profile.toEntity());
    } on sb.AuthException catch (e) {
      return Left(_authFailureFrom(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, ProfileEntity>> signUp({
    required String email,
    required String password,
    required String fullName,
    required String rolNombre,
    String? phone,
  }) async {
    try {
      final response = await _dataSource.signUp(
        email: email,
        password: password,
        fullName: fullName,
        rolNombre: rolNombre,
        phone: phone,
      );
      final user = response.user;
      if (user == null) {
        return const Left(AuthFailure('No se pudo crear el usuario.'));
      }

      // Si Supabase no devuelve sesión es porque requiere confirmación de correo.
      if (response.session == null) {
        return const Left(
          AuthFailure(
            'Debes confirmar tu correo para activar tu cuenta.',
            code: 'email_not_confirmed',
          ),
        );
      }

      final profile = await _dataSource.createProfile(
        id: user.id,
        email: email,
        fullName: fullName,
        rolNombre: rolNombre,
        phone: phone,
      );
      return Right(profile.toEntity());
    } on sb.AuthException catch (e) {
      return Left(_authFailureFrom(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    try {
      await _dataSource.signOut();
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> removeLocalSession() async {
    try {
      await _dataSource.removeLocalSession();
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> resetPassword(String email) async {
    try {
      await _dataSource.resetPassword(email);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> resendConfirmationEmail(String email) async {
    try {
      await _dataSource.resendConfirmationEmail(email);
      return const Right(null);
    } on sb.AuthException catch (e) {
      return Left(_authFailureFrom(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> changePassword(String newPassword) async {
    try {
      await _dataSource.updatePassword(newPassword);
      return const Right(null);
    } on sb.AuthException catch (e) {
      return Left(_authFailureFrom(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, ProfileEntity>> getCurrentProfile() async {
    try {
      final profile = await _dataSource.fetchCurrentProfile();
      if (profile == null) return const Left(AuthFailure('Sesión no activa.'));
      return Right(profile.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
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
  }) async {
    try {
      final data = <String, dynamic>{'id': userId};
      if (fullName != null)         data['full_name'] = fullName;
      if (phone != null)            data['phone'] = phone;
      if (address != null)          data['address'] = address;
      if (latitude != null)         data['latitude'] = latitude;
      if (longitude != null)        data['longitude'] = longitude;
      if (activo != null)           data['activo'] = activo;
      if (paymentCompleted != null) data['payment_completed'] = paymentCompleted;
      if (evaluationPassed != null) data['evaluation_passed'] = evaluationPassed;

      final profile = await _dataSource.updateProfile(data);
      return Right(profile.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<RoleEntity>>> getRoles() async {
    try {
      final data = await _dataSource.fetchRoles();
      final roles = data.map((json) => RoleEntity(
        id:          (json['id'] as num).toInt(),
        name:        json['name'] as String,
        description: json['description'] as String?,
        code:        json['code'] as String?,
        activo:      json['activo'] as bool? ?? true,
        createdAt:   DateTime.parse(json['created_at'] as String),
        updatedAt:   json['updated_at'] != null
            ? DateTime.parse(json['updated_at'] as String)
            : null,
      )).toList();
      return Right(roles);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> registerFcmToken({
    required String profileId,
    required String fcmToken,
    String? plataforma,
  }) async {
    try {
      await _dataSource.upsertFcmToken(
        profileId: profileId,
        fcmToken: fcmToken,
        plataforma: plataforma,
      );
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deactivateFcmToken(String token) async {
    try {
      await _dataSource.deactivateFcmToken(token);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  /// Mapea una [sb.AuthException] a [AuthFailure] con mensaje amigable en
  /// español, usando el `code` de GoTrue cuando está disponible (fallback al
  /// mensaje crudo). Los códigos comunes (credenciales, email duplicado,
  /// contraseña débil, recovery, SMTP) se traducen según la región de la app.
  AuthFailure _authFailureFrom(sb.AuthException e) {
    final msg = e.message.toLowerCase();
    final code = e.code?.toLowerCase() ?? '';

    // ── SMTP: GoTrue no pudo entregar el correo de confirmación/recovery ──
    final isEmailDeliveryFailure = code.contains('unexpected_failure') &&
        (msg.contains('sending confirmation email') ||
            msg.contains('send email') ||
            msg.contains('smtp') ||
            msg.contains('error sending'));
    if (isEmailDeliveryFailure) {
      return AuthFailure(
        'No se pudo enviar el correo de confirmación en este momento. '
        'Intenta de nuevo con "Reenviar correo" o, si persiste, revisa la '
        'configuración de correo en el panel de administración.',
        code: e.code,
      );
    }

    final map = <String, String>{
      'invalid_credentials': 'Credenciales inválidas. Verifica tu correo y contraseña.',
      'email_not_confirmed': 'Debes confirmar tu correo para activar tu cuenta. Revisa tu bandeja de entrada.',
      'user_already_exists': 'Este correo ya está registrado. Inicia sesión o usa "Recuperar contraseña".',
      'weak_password': 'La contraseña es demasiado débil. Usa al menos 6 caracteres con mayúsculas, minúsculas y números.',
      'email_address_invalid': 'El correo electrónico ingresado no es válido.',
      'same_password': 'La nueva contraseña debe ser distinta a la contraseña actual.',
      'new_password_should_be_different': 'La nueva contraseña debe ser distinta a la contraseña actual.',
      'over_email_send_rate_limit': 'Hemos enviado demasiados correos a esta cuenta. Espera unos minutos e inténtalo de nuevo.',
      'over_request_rate_limit': 'Demasiados intentos. Espera unos minutos e inténtalo de nuevo.',
      'user_not_found': 'No existe una cuenta con este correo.',
      'email_change_token_invalid': 'El enlace de confirmación no es válido o ya fue usado.',
      'recovery_token_invalid': 'El enlace de recuperación no es válido o ya fue usado.',
      'otp_expired': 'El código de confirmación expiró. Solicita uno nuevo.',
      'otp_disabled': 'La verificación por código está deshabilitada en esta cuenta.',
      'phone_already_exists': 'Este número de teléfono ya está registrado.',
      'phone_not_confirmed': 'Debes confirmar tu número de teléfono para continuar.',
      'provider_not_found': 'El proveedor de acceso seleccionado no está disponible.',
      'mfa_verification_rejected': 'La verificación de seguridad falló. Inténtalo de nuevo.',
    };

    final translated = map[code];
    if (translated != null) {
      return AuthFailure(translated, code: e.code);
    }

    // Fallback: si el mensaje crudo contiene patrones reconocibles sin code.
    if (msg.contains('invalid login credentials')) {
      return const AuthFailure('Credenciales inválidas. Verifica tu correo y contraseña.');
    }
    if (msg.contains('already registered') || msg.contains('already been registered')) {
      return const AuthFailure('Este correo ya está registrado. Inicia sesión o usa "Recuperar contraseña".');
    }
    if (msg.contains('password should be at least')) {
      return const AuthFailure('La contraseña es demasiado débil. Usa al menos 6 caracteres.');
    }

    return AuthFailure(e.message, code: e.code);
  }
}
