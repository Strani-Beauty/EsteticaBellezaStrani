import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/app/core/usecases/use_case.dart';
import '../entities/servicio_entity.dart';
import '../repositories/i_catalog_repository.dart';

/// Lista todos los servicios (incl. inactivos) — mantenimiento admin.
class GetServiciosAdmin extends NoParamsUseCase<List<ServicioEntity>> {
  final ICatalogRepository _repository;
  GetServiciosAdmin(this._repository);

  @override
  Future<Either<Failure, List<ServicioEntity>>> call() {
    return _repository.getServiciosAdmin();
  }
}