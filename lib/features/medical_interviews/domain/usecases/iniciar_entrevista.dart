import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../../../app/core/usecases/use_case.dart';
import '../repositories/i_medical_interviews_repository.dart';

class IniciarEntrevistaParams {
  final String entrevistaId;
  const IniciarEntrevistaParams({required this.entrevistaId});
}

/// Marca la entrevista médica como `EN_CURSO` (admin).
class IniciarEntrevista extends UseCase<void, IniciarEntrevistaParams> {
  final IMedicalInterviewsRepository _repository;
  IniciarEntrevista(this._repository);

  @override
  Future<Either<Failure, void>> call(IniciarEntrevistaParams params) =>
      _repository.iniciarEntrevista(params.entrevistaId);
}
