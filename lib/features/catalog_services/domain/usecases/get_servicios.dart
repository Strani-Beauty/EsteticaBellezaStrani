import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/app/core/usecases/use_case.dart';
import '../entities/servicio_entity.dart';
import '../repositories/i_catalog_repository.dart';

class GetServiciosParams {
  final int? categoriaId;
  const GetServiciosParams({this.categoriaId});
}

/// Lista los servicios activos, opcionalmente filtrados por categoría.
class GetServicios extends UseCase<List<ServicioEntity>, GetServiciosParams> {
  final ICatalogRepository _repository;
  GetServicios(this._repository);

  @override
  Future<Either<Failure, List<ServicioEntity>>> call(
      GetServiciosParams params) {
    return _repository.getServicios(categoriaId: params.categoriaId);
  }
}