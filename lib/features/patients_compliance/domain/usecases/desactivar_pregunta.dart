import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../../../app/core/usecases/use_case.dart';
import '../repositories/i_patients_compliance_repository.dart';

class DesactivarPreguntaParams {
  final int cuestionarioId;
  final int preguntaId;
  final bool activo;
  const DesactivarPreguntaParams({
    required this.cuestionarioId,
    required this.preguntaId,
    required this.activo,
  });
}

/// Activa/desactiva (soft) la presencia de una pregunta en una versión.
class DesactivarPregunta extends UseCase<void, DesactivarPreguntaParams> {
  final IPatientsComplianceRepository _repository;
  DesactivarPregunta(this._repository);

  @override
  Future<Either<Failure, void>> call(DesactivarPreguntaParams params) {
    return _repository.desactivarPregunta(
      cuestionarioId: params.cuestionarioId,
      preguntaId: params.preguntaId,
      activo: params.activo,
    );
  }
}