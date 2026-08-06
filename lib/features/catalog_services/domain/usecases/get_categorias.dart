import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/app/core/usecases/use_case.dart';
import '../entities/categoria_servicio_entity.dart';
import '../repositories/i_catalog_repository.dart';

/// Lista las categorías activas del catálogo.
class GetCategorias
    extends NoParamsUseCase<List<CategoriaServicioEntity>> {
  final ICatalogRepository _repository;
  GetCategorias(this._repository);

  @override
  Future<Either<Failure, List<CategoriaServicioEntity>>> call() {
    return _repository.getCategorias();
  }
}