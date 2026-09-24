import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../../../app/core/usecases/use_case.dart';
import '../repositories/i_medical_interviews_repository.dart';

class EmitirDictamenEntrevistaParams {
  final String entrevistaId;
  final bool aprobado;
  final String observaciones;
  final String? hallazgos;

  const EmitirDictamenEntrevistaParams({
    required this.entrevistaId,
    required this.aprobado,
    required this.observaciones,
    this.hallazgos,
  });
}

/// Emite el dictamen del examen médico total (desbloquea RN-020).
class EmitirDictamenEntrevista
    extends UseCase<void, EmitirDictamenEntrevistaParams> {
  final IMedicalInterviewsRepository _repository;
  EmitirDictamenEntrevista(this._repository);

  @override
  Future<Either<Failure, void>> call(EmitirDictamenEntrevistaParams params) =>
      _repository.emitirDictamenEntrevista(
        entrevistaId: params.entrevistaId,
        aprobado: params.aprobado,
        observaciones: params.observaciones,
        hallazgos: params.hallazgos,
      );
}
