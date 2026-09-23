import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../../../app/core/usecases/use_case.dart';
import '../repositories/i_patients_compliance_repository.dart';

class EliminarCuestionarioParams {
  final int cuestionarioId;
  const EliminarCuestionarioParams(this.cuestionarioId);
}

/// Elimina un cuestionario y sus relaciones (solo admin). Bloqueado si el
/// cuestionario tiene evaluaciones de salud (retención ePHI/HIPAA).
class EliminarCuestionario extends UseCase<void, EliminarCuestionarioParams> {
  final IPatientsComplianceRepository _repository;
  EliminarCuestionario(this._repository);

  @override
  Future<Either<Failure, void>> call(EliminarCuestionarioParams params) {
    return _repository.eliminarCuestionario(params.cuestionarioId);
  }
}
