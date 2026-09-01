import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../../../app/core/usecases/use_case.dart';
import '../entities/evaluacion_entity.dart';
import '../repositories/i_calificaciones_repository.dart';

class GetPromedioEspecialistaParams {
  final String especialistaId;

  const GetPromedioEspecialistaParams({required this.especialistaId});
}

class GetPromedioEspecialista
    extends UseCase<PromedioEspecialistaEntity, GetPromedioEspecialistaParams> {
  final ICalificacionesRepository _repository;

  GetPromedioEspecialista(this._repository);

  @override
  Future<Either<Failure, PromedioEspecialistaEntity>> call(
      GetPromedioEspecialistaParams params) async {
    try {
      return await _repository.getPromedioEspecialista(params.especialistaId);
    } catch (e) {
      return Left(ServerFailure('No se pudo cargar el promedio: $e'));
    }
  }
}