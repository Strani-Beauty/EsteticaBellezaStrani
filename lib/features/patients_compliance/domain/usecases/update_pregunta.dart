import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../../../app/core/usecases/use_case.dart';
import '../repositories/i_patients_compliance_repository.dart';

class UpdatePreguntaParams {
  final int preguntaId;
  final String? texto;
  final String? tipoRespuesta;
  final bool? obligatoria;
  final List<String>? opciones;
  final Map<String, dynamic>? riesgo;
  final bool? activo;

  const UpdatePreguntaParams({
    required this.preguntaId,
    this.texto,
    this.tipoRespuesta,
    this.obligatoria,
    this.opciones,
    this.riesgo,
    this.activo,
  });
}

/// Edita una pregunta del catálogo (solo admin). Requisitos 3-5.
class UpdatePregunta extends UseCase<void, UpdatePreguntaParams> {
  final IPatientsComplianceRepository _repository;
  UpdatePregunta(this._repository);

  @override
  Future<Either<Failure, void>> call(UpdatePreguntaParams params) {
    return _repository.updatePregunta(
      preguntaId: params.preguntaId,
      texto: params.texto,
      tipoRespuesta: params.tipoRespuesta,
      obligatoria: params.obligatoria,
      opciones: params.opciones,
      riesgo: params.riesgo,
      activo: params.activo,
    );
  }
}