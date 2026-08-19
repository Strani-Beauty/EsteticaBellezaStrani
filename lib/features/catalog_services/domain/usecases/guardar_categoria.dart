import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/app/core/usecases/use_case.dart';
import '../entities/categoria_servicio_entity.dart';
import '../repositories/i_catalog_repository.dart';

class GuardarCategoriaParams {
  final int id; // 0 = crear
  final String nombre;
  final String? descripcion;
  final bool activo;

  const GuardarCategoriaParams({
    this.id = 0,
    required this.nombre,
    this.descripcion,
    required this.activo,
  });
}

/// Crea o actualiza una categoría de servicios (solo admin).
class GuardarCategoria extends UseCase<CategoriaServicioEntity, GuardarCategoriaParams> {
  final ICatalogRepository _repository;
  GuardarCategoria(this._repository);

  @override
  Future<Either<Failure, CategoriaServicioEntity>> call(
      GuardarCategoriaParams params) {
    return _repository.guardarCategoria(
      id: params.id,
      nombre: params.nombre,
      descripcion: params.descripcion,
      activo: params.activo,
    );
  }
}