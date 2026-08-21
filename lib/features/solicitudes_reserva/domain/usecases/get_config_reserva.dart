import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../../../app/core/usecases/use_case.dart';
import '../entities/seguimiento_solicitud_entity.dart';
import '../repositories/i_solicitudes_reserva_repository.dart';

/// Configuración del flujo de reserva (radio y confirmación por webhook).
class GetConfigReserva extends NoParamsUseCase<ConfigReservaEntity> {
  final ISolicitudesReservaRepository _repository;

  GetConfigReserva(this._repository);

  @override
  Future<Either<Failure, ConfigReservaEntity>> call() async {
    try {
      return await _repository.getConfigReserva();
    } catch (e) {
      return Left(ServerFailure('No se pudo cargar la configuración: $e'));
    }
  }
}
