import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../../../app/core/usecases/use_case.dart';
import '../entities/entrevista_medica_entity.dart';
import '../repositories/i_medical_interviews_repository.dart';

/// Última entrevista médica del paciente autenticado.
class GetMiEntrevista
    extends UseCase<EntrevistaMedicaEntity?, NoParams> {
  final IMedicalInterviewsRepository _repository;
  GetMiEntrevista(this._repository);

  @override
  Future<Either<Failure, EntrevistaMedicaEntity?>> call(NoParams params) =>
      _repository.getMiEntrevista();
}
