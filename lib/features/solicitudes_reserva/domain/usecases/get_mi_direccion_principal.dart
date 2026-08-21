import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../../../app/core/usecases/use_case.dart';
import '../entities/seguimiento_solicitud_entity.dart';
import '../repositories/i_solicitudes_reserva_repository.dart';

/// Dirección principal del paciente para la zona de prestación.
class GetMiDireccionPrincipal
    extends UseCase<DireccionPrincipalEntity?, String> {
  final ISolicitudesReservaRepository _repository;

  GetMiDireccionPrincipal(this._repository);

  @override
  Future<Either<Failure, DireccionPrincipalEntity?>> call(
      String profileId) async {
    try {
      return await _repository.getMiDireccionPrincipal(profileId);
    } catch (e) {
      return Left(ServerFailure('No se pudo cargar tu dirección: $e'));
    }
  }
}
