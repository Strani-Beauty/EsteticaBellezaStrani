import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/app/core/usecases/use_case.dart';
import '../entities/ubicacion_especialista_entity.dart';
import '../repositories/i_specialists_repository.dart';

class SaveUbicacionParams {
  final String especialistaId;
  final double latitud;
  final double longitud;
  final double precisionMetros;
  const SaveUbicacionParams({
    required this.especialistaId,
    required this.latitud,
    required this.longitud,
    this.precisionMetros = 0,
  });
}

/// Guarda la ubicación geográfica del especialista.
class SaveUbicacion extends UseCase<UbicacionEspecialistaEntity, SaveUbicacionParams> {
  final ISpecialistsRepository _repository;
  SaveUbicacion(this._repository);

  @override
  Future<Either<Failure, UbicacionEspecialistaEntity>> call(
      SaveUbicacionParams params) {
    return _repository.saveUbicacion(
      params.especialistaId,
      latitud: params.latitud,
      longitud: params.longitud,
      precisionMetros: params.precisionMetros,
    );
  }
}