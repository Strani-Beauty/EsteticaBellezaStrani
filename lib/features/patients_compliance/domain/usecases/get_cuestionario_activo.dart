import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../../../app/core/usecases/use_case.dart';
import '../entities/cuestionario_entity.dart';
import '../repositories/i_patients_compliance_repository.dart';

/// Obtiene el cuestionario activo (producto: un solo cuestionario de salud).
class GetCuestionarioActivo extends NoParamsUseCase<CuestionarioEntity?> {
  final IPatientsComplianceRepository _repository;
  GetCuestionarioActivo(this._repository);

  @override
  Future<Either<Failure, CuestionarioEntity?>> call() =>
      _repository.getCuestionarioActivo();
}