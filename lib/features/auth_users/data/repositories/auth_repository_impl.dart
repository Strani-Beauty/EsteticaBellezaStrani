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
      return Left(AuthFailure(e.message, code: e.code));
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
      return Left(AuthFailure(e.message, code: e.code));
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
}
