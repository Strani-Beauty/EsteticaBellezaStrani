import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../../../app/core/usecases/use_case.dart';
import '../repositories/i_admin_config_repository.dart';

class UpdateConfigSistemaParams {
  final String clave;
  final String valor;

  const UpdateConfigSistemaParams({required this.clave, required this.valor});
}

/// Actualiza el valor de una clave de configuración.
class UpdateConfigSistema
    extends UseCase<void, UpdateConfigSistemaParams> {
  final IAdminConfigRepository _repository;

  UpdateConfigSistema(this._repository);

  @override
  Future<Either<Failure, void>> call(UpdateConfigSistemaParams params) async {
    try {
      return await _repository.updateConfiguracion(params.clave, params.valor);
    } catch (e) {
      return Left(ServerFailure('No se pudo guardar la configuración: $e'));
    }
  }
}
