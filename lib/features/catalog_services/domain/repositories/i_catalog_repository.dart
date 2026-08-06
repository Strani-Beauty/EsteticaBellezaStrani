import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import '../entities/categoria_servicio_entity.dart';
import '../entities/servicio_entity.dart';

/// Contrato del catálogo de servicios.
/// Se usa fpdart [Either] para errores tipados.
/// La implementación vive en data/repositories/catalog_repository_impl.dart
abstract class ICatalogRepository {
  /// Categorías activas del catálogo.
  Future<Either<Failure, List<CategoriaServicioEntity>>> getCategorias();

  /// Servicios activos, opcionalmente filtrados por categoría.
  Future<Either<Failure, List<ServicioEntity>>> getServicios({
    int? categoriaId,
  });
}