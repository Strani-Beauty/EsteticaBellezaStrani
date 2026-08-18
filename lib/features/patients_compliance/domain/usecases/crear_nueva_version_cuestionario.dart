import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../../../app/core/usecases/use_case.dart';
import '../entities/cuestionario_entity.dart';
import '../repositories/i_patients_compliance_repository.dart';

class CrearNuevaVersionCuestionarioParams {
  final int versionActualId;
  const CrearNuevaVersionCuestionarioParams(this.versionActualId);
}

/// Crea una nueva versión (fila) de un cuestionario copiando la relación de
/// preguntas. La nueva versión nace inactiva (la activa el administrador).
class CrearNuevaVersionCuestionario
    extends UseCase<CuestionarioEntity, CrearNuevaVersionCuestionarioParams> {
  final IPatientsComplianceRepository _repository;
  CrearNuevaVersionCuestionario(this._repository);

  @override
  Future<Either<Failure, CuestionarioEntity>> call(
      CrearNuevaVersionCuestionarioParams params) {
    return _repository.crearNuevaVersionCuestionario(params.versionActualId);
  }
}