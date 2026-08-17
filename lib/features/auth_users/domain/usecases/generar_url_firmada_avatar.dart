import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/app/core/usecases/use_case.dart';
import '../repositories/i_auth_repository.dart';

class GenerarUrlFirmadaAvatarParams {
  final String path;
  const GenerarUrlFirmadaAvatarParams(this.path);
}

/// Genera una URL firmada de expiración corta para leer un avatar privado.
class GenerarUrlFirmadaAvatar
    extends UseCase<String, GenerarUrlFirmadaAvatarParams> {
  final IAuthRepository _repository;
  GenerarUrlFirmadaAvatar(this._repository);

  @override
  Future<Either<Failure, String>> call(GenerarUrlFirmadaAvatarParams params) {
    return _repository.generarUrlFirmadaAvatar(params.path);
  }
}