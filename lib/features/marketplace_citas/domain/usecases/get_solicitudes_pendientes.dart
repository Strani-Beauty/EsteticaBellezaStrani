import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/app/core/usecases/use_case.dart';
import '../entities/solicitud_pendiente_entity.dart';
import '../repositories/i_marketplace_repository.dart';

/// Lista las solicitudes pendientes de asignación.
class GetSolicitudesPendientes
    extends NoParamsUseCase<List<SolicitudPendienteEntity>> {
  final IMarketplaceRepository _repository;
  GetSolicitudesPendientes(this._repository);

  @override
  Future<Either<Failure, List<SolicitudPendienteEntity>>> call() {
    return _repository.getSolicitudesPendientes();
  }
}
