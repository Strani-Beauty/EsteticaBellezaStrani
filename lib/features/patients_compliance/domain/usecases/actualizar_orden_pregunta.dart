import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../../../app/core/usecases/use_case.dart';
import '../repositories/i_patients_compliance_repository.dart';

class ActualizarOrdenPreguntaParams {
  final int cuestionarioId;
  final int preguntaId;
  final int orden;
  const ActualizarOrdenPreguntaParams({
    required this.cuestionarioId,
    required this.preguntaId,
    required this.orden,
  });
}

/// Actualiza el orden de una pregunta dentro de su cuestionario.
class ActualizarOrdenPregunta
    extends UseCase<void, ActualizarOrdenPreguntaParams> {
  final IPatientsComplianceRepository _repository;
  ActualizarOrdenPregunta(this._repository);

  @override
  Future<Either<Failure, void>> call(ActualizarOrdenPreguntaParams params) {
    return _repository.actualizarOrdenPregunta(
      cuestionarioId: params.cuestionarioId,
      preguntaId: params.preguntaId,
      orden: params.orden,
    );
  }
}