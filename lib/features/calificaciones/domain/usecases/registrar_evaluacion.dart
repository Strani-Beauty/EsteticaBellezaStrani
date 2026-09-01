import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../../../app/core/usecases/use_case.dart';
import '../repositories/i_calificaciones_repository.dart';

class RegistrarEvaluacionParams {
  final String citaId;
  final int puntuacion;
  final String? comentario;

  const RegistrarEvaluacionParams({
    required this.citaId,
    required this.puntuacion,
    this.comentario,
  });
}

class RegistrarEvaluacion
    extends UseCase<String, RegistrarEvaluacionParams> {
  final ICalificacionesRepository _repository;

  RegistrarEvaluacion(this._repository);

  @override
  Future<Either<Failure, String>> call(RegistrarEvaluacionParams params) async {
    try {
      return await _repository.registrarEvaluacion(
        citaId: params.citaId,
        puntuacion: params.puntuacion,
        comentario: params.comentario,
      );
    } catch (e) {
      return Left(ServerFailure('No se pudo registrar la calificación: $e'));
    }
  }
}