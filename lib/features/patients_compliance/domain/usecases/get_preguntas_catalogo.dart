import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../../../app/core/usecases/use_case.dart';
import '../entities/cuestionario_entity.dart';
import '../repositories/i_patients_compliance_repository.dart';

/// Catálogo completo de preguntas (`preguntas`) para asociar existentes.
class GetPreguntasCatalogo
    extends UseCase<List<PreguntaEntity>, NoParams> {
  final IPatientsComplianceRepository _repository;
  GetPreguntasCatalogo(this._repository);

  @override
  Future<Either<Failure, List<PreguntaEntity>>> call(NoParams params) {
    return _repository.getPreguntasCatalogo();
  }
}