import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/app/core/usecases/use_case.dart';
import '../entities/tratamiento_entity.dart';
import '../repositories/i_treatment_execution_repository.dart';

class ActualizarTratamientoParams {
  final String tratamientoId;
  final String? evaluacionInicial;
  final String? observacionesFinales;
  final String? recomendacionesPostTratamiento;
  final String? estado;
  const ActualizarTratamientoParams({
    required this.tratamientoId,
    this.evaluacionInicial,
    this.observacionesFinales,
    this.recomendacionesPostTratamiento,
    this.estado,
  });
}

/// Actualiza campos clínicos del tratamiento (evaluación/recomendaciones/estado).
class ActualizarTratamiento
    extends UseCase<TratamientoEntity, ActualizarTratamientoParams> {
  final ITreatmentExecutionRepository _repository;
  ActualizarTratamiento(this._repository);

  @override
  Future<Either<Failure, TratamientoEntity>> call(
      ActualizarTratamientoParams params) {
    return _repository.actualizarTratamiento(
      tratamientoId: params.tratamientoId,
      evaluacionInicial: params.evaluacionInicial,
      observacionesFinales: params.observacionesFinales,
      recomendacionesPostTratamiento: params.recomendacionesPostTratamiento,
      estado: params.estado,
    );
  }
}