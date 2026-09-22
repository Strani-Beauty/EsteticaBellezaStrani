import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../../../app/core/usecases/use_case.dart';
import '../entities/cuestionario_entity.dart';
import '../repositories/i_patients_compliance_repository.dart';

class CrearPreguntaParams {
  final String texto;
  final TipoRespuestaPregunta tipo;
  final bool obligatoria;
  final List<String>? opciones;
  final Map<String, dynamic>? riesgo;
  final bool activo;

  const CrearPreguntaParams({
    required this.texto,
    required this.tipo,
    this.obligatoria = false,
    this.opciones,
    this.riesgo,
    this.activo = true,
  });
}

/// Crea una pregunta nueva en el catálogo (`preguntas`) y devuelve su `id`.
class CrearPregunta extends UseCase<int, CrearPreguntaParams> {
  final IPatientsComplianceRepository _repository;
  CrearPregunta(this._repository);

  @override
  Future<Either<Failure, int>> call(CrearPreguntaParams params) {
    return _repository.crearPregunta(
      texto: params.texto,
      tipoRespuesta: params.tipo.toDb(),
      obligatoria: params.obligatoria,
      opciones: params.opciones,
      riesgo: params.riesgo,
      activo: params.activo,
    );
  }
}