import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../../../app/core/usecases/use_case.dart';
import '../entities/evaluacion_salud_entity.dart';
import '../repositories/i_patients_compliance_repository.dart';

class GuardarRespuestasEvaluacionParams {
  final int cuestionarioId;
  final Map<int, String> respuestas;
  const GuardarRespuestasEvaluacionParams({
    required this.cuestionarioId,
    required this.respuestas,
  });
}

/// Persiste las respuestas del cuestionario vía RPC segura. Conserva la versión
/// del cuestionario y devuelve el resultado/riesgos calculados en BD.
class GuardarRespuestasEvaluacion
    extends UseCase<ResultadoEvaluacionRegistrada, GuardarRespuestasEvaluacionParams> {
  final IPatientsComplianceRepository _repository;
  GuardarRespuestasEvaluacion(this._repository);

  @override
  Future<Either<Failure, ResultadoEvaluacionRegistrada>> call(
      GuardarRespuestasEvaluacionParams params) {
    return _repository.guardarRespuestasEvaluacion(
      cuestionarioId: params.cuestionarioId,
      respuestas: params.respuestas,
    );
  }
}