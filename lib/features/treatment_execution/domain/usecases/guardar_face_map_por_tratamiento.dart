import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/app/core/usecases/use_case.dart';
import '../repositories/i_treatment_execution_repository.dart';

class GuardarFaceMapPorTratamientoParams {
  final String tratamientoId;
  final String pacienteId;
  final List<Map<String, dynamic>> puntos;
  final String? observaciones;
  const GuardarFaceMapPorTratamientoParams({
    required this.tratamientoId,
    required this.pacienteId,
    required this.puntos,
    this.observaciones,
  });
}

/// Guarda el face map del especialista vinculado al tratamiento.
class GuardarFaceMapPorTratamiento
    extends UseCase<void, GuardarFaceMapPorTratamientoParams> {
  final ITreatmentExecutionRepository _repository;
  GuardarFaceMapPorTratamiento(this._repository);

  @override
  Future<Either<Failure, void>> call(GuardarFaceMapPorTratamientoParams params) {
    return _repository.guardarFaceMapPorTratamiento(
      tratamientoId: params.tratamientoId,
      pacienteId: params.pacienteId,
      puntos: params.puntos,
      observaciones: params.observaciones,
    );
  }
}