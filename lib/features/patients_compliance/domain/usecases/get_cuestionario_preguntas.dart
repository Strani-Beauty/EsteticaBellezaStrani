import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../../../app/core/usecases/use_case.dart';
import '../entities/cuestionario_entity.dart';
import '../repositories/i_patients_compliance_repository.dart';

class GetCuestionarioPreguntasParams {
  final int cuestionarioId;
  const GetCuestionarioPreguntasParams(this.cuestionarioId);
}

/// Preguntas de un cuestionario (join `cuestionario_preguntas` -> `preguntas`).
class GetCuestionarioPreguntas
    extends UseCase<List<PreguntaEntity>, GetCuestionarioPreguntasParams> {
  final IPatientsComplianceRepository _repository;
  GetCuestionarioPreguntas(this._repository);

  @override
  Future<Either<Failure, List<PreguntaEntity>>> call(
      GetCuestionarioPreguntasParams params) {
    return _repository.getCuestionarioPreguntas(params.cuestionarioId);
  }
}