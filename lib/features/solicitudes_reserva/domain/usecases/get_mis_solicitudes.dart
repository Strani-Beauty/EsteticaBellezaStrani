import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../../../app/core/usecases/use_case.dart';
import '../entities/seguimiento_solicitud_entity.dart';
import '../repositories/i_solicitudes_reserva_repository.dart';

/// Obtiene las solicitudes del paciente con su estado, servicios, pago y cita.
class GetMisSolicitudes
    extends UseCase<List<SeguimientoSolicitudEntity>, String> {
  final ISolicitudesReservaRepository _repository;

  GetMisSolicitudes(this._repository);

  @override
  Future<Either<Failure, List<SeguimientoSolicitudEntity>>> call(
      String profileId) async {
    try {
      return await _repository.getMisSolicitudes(profileId);
    } catch (e) {
      return Left(ServerFailure('No se pudieron cargar tus solicitudes: $e'));
    }
  }
}
