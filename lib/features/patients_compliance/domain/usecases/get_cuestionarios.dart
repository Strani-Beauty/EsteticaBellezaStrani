import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../../../app/core/usecases/use_case.dart';
import '../entities/cuestionario_entity.dart';
import '../repositories/i_patients_compliance_repository.dart';

class GetCuestionariosParams {
  final bool soloActivos;
  const GetCuestionariosParams({this.soloActivos = false});
}

/// Lista los cuestionarios (con sus versiones).
class GetCuestionarios extends UseCase<List<CuestionarioEntity>, GetCuestionariosParams> {
  final IPatientsComplianceRepository _repository;
  GetCuestionarios(this._repository);

  @override
  Future<Either<Failure, List<CuestionarioEntity>>> call(GetCuestionariosParams params) {
    return _repository.getCuestionarios(soloActivos: params.soloActivos);
  }
}