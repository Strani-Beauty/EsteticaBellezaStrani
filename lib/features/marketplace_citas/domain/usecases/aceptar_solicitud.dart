import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/app/core/usecases/use_case.dart';
import '../entities/resultado_aceptacion_entity.dart';
import '../repositories/i_marketplace_repository.dart';

class AceptarSolicitudParams {
  final String solicitudId;
  final String especialistaId;
  const AceptarSolicitudParams({
    required this.solicitudId,
    required this.especialistaId,
  });
}

/// Acepta una solicitud de forma atómica ("primer aviso gana").
class AceptarSolicitud
    extends UseCase<ResultadoAceptacionEntity, AceptarSolicitudParams> {
  final IMarketplaceRepository _repository;
  AceptarSolicitud(this._repository);

  @override
  Future<Either<Failure, ResultadoAceptacionEntity>> call(
      AceptarSolicitudParams params) {
    return _repository.aceptarSolicitud(
      solicitudId: params.solicitudId,
      especialistaId: params.especialistaId,
    );
  }
}
