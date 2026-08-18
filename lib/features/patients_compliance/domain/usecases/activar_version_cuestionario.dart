import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../../../app/core/usecases/use_case.dart';
import '../repositories/i_patients_compliance_repository.dart';

class ActivarVersionCuestionarioParams {
  final int cuestionarioId;
  const ActivarVersionCuestionarioParams(this.cuestionarioId);
}

/// Activa una versión de cuestionario (desactiva las demás del mismo nombre).
class ActivarVersionCuestionario
    extends UseCase<void, ActivarVersionCuestionarioParams> {
  final IPatientsComplianceRepository _repository;
  ActivarVersionCuestionario(this._repository);

  @override
  Future<Either<Failure, void>> call(ActivarVersionCuestionarioParams params) {
    return _repository.activarVersionCuestionario(params.cuestionarioId);
  }
}