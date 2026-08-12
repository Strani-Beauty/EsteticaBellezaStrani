import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import '../repositories/i_auth_repository.dart';

/// Registra el token FCM del dispositivo en `dispositivos_usuario`.
class RegisterFcmToken {
  final IAuthRepository _repository;

  RegisterFcmToken(this._repository);

  Future<Either<Failure, void>> call({
    required String profileId,
    required String fcmToken,
    String? plataforma,
  }) {
    return _repository.registerFcmToken(
      profileId: profileId,
      fcmToken: fcmToken,
      plataforma: plataforma,
    );
  }
}