import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../../../app/core/usecases/use_case.dart';
import '../repositories/i_patients_compliance_repository.dart';

class AsociarPreguntaParams {
  final int cuestionarioId;
  final int preguntaId;
  const AsociarPreguntaParams({required this.cuestionarioId, required this.preguntaId});
}

/// Asocia una pregunta del catálogo a un cuestionario (reactiva si ya estaba).
class AsociarPregunta extends UseCase<void, AsociarPreguntaParams> {
  final IPatientsComplianceRepository _repository;
  AsociarPregunta(this._repository);

  @override
  Future<Either<Failure, void>> call(AsociarPreguntaParams params) {
    return _repository.asociarPregunta(
      cuestionarioId: params.cuestionarioId,
      preguntaId: params.preguntaId,
    );
  }
}