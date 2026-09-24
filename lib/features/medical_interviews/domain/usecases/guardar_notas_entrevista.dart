import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../../../app/core/usecases/use_case.dart';
import '../repositories/i_medical_interviews_repository.dart';

class GuardarNotasEntrevistaParams {
  final String entrevistaId;
  final String notasClinicas;
  final String? hallazgos;

  const GuardarNotasEntrevistaParams({
    required this.entrevistaId,
    required this.notasClinicas,
    this.hallazgos,
  });
}

/// Guarda notas clínicas / hallazgos de la entrevista (admin).
class GuardarNotasEntrevista
    extends UseCase<void, GuardarNotasEntrevistaParams> {
  final IMedicalInterviewsRepository _repository;
  GuardarNotasEntrevista(this._repository);

  @override
  Future<Either<Failure, void>> call(GuardarNotasEntrevistaParams params) =>
      _repository.guardarNotasEntrevista(
        entrevistaId: params.entrevistaId,
        notasClinicas: params.notasClinicas,
        hallazgos: params.hallazgos,
      );
}
