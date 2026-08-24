import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/app/core/usecases/use_case.dart';
import '../repositories/i_treatment_execution_repository.dart';

class RegistrarLlegadaParams {
  final String citaId;
  final double latitud;
  final double longitud;
  const RegistrarLlegadaParams({
    required this.citaId,
    required this.latitud,
    required this.longitud,
  });
}

/// Registra la llegada del especialista al domicilio (geo) y devuelve la
/// distancia recorrida en metros (o null si no se pudo calcular).
class RegistrarLlegada extends UseCase<double?, RegistrarLlegadaParams> {
  final ITreatmentExecutionRepository _repository;
  RegistrarLlegada(this._repository);

  @override
  Future<Either<Failure, double?>> call(RegistrarLlegadaParams params) {
    return _repository.registrarLlegada(
      citaId: params.citaId,
      latitud: params.latitud,
      longitud: params.longitud,
    );
  }
}
