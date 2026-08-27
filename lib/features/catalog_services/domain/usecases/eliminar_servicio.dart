import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/app/core/usecases/use_case.dart';
import '../repositories/i_catalog_repository.dart';

/// Elimina un servicio del catálogo (solo admin).
/// Devuelve Failure si el servicio tiene historial en solicitudes.
class EliminarServicio extends UseCase<void, String> {
  final ICatalogRepository _repository;
  EliminarServicio(this._repository);

  @override
  Future<Either<Failure, void>> call(String servicioId) {
    return _repository.eliminarServicio(servicioId);
  }
}