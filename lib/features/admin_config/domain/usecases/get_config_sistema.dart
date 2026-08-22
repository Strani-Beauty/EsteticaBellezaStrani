import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../../../app/core/usecases/use_case.dart';
import '../entities/config_sistema_entity.dart';
import '../repositories/i_admin_config_repository.dart';

/// Obtiene las claves de configuración del sistema.
class GetConfigSistema extends NoParamsUseCase<List<ConfigSistemaEntity>> {
  final IAdminConfigRepository _repository;

  GetConfigSistema(this._repository);

  @override
  Future<Either<Failure, List<ConfigSistemaEntity>>> call() async {
    try {
      return await _repository.getConfiguracion();
    } catch (e) {
      return Left(ServerFailure('No se pudo cargar la configuración: $e'));
    }
  }
}
