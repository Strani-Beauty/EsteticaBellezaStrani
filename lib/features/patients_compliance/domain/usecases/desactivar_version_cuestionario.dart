import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../../../app/core/usecases/use_case.dart';
import '../repositories/i_patients_compliance_repository.dart';

class DesactivarVersionCuestionarioParams {
  final int cuestionarioId;
  const DesactivarVersionCuestionarioParams(this.cuestionarioId);
}

/// Desactiva una versión de cuestionario sin borrarla (conserva histórico y
/// evaluaciones ePHI).
class DesactivarVersionCuestionario
    extends UseCase<void, DesactivarVersionCuestionarioParams> {
  final IPatientsComplianceRepository _repository;
  DesactivarVersionCuestionario(this._repository);

  @override
  Future<Either<Failure, void>> call(DesactivarVersionCuestionarioParams params) {
    return _repository.desactivarVersionCuestionario(params.cuestionarioId);
  }
}
