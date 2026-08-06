import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import '../../domain/entities/categoria_servicio_entity.dart';
import '../../domain/entities/servicio_entity.dart';
import '../../domain/repositories/i_catalog_repository.dart';
import '../datasources/catalog_services_supabase_datasource.dart';

/// Implementación del repositorio de catálogo usando Supabase.
class CatalogRepositoryImpl implements ICatalogRepository {
  final CatalogServicesSupabaseDataSource _dataSource;

  CatalogRepositoryImpl(this._dataSource);

  @override
  Future<Either<Failure, List<CategoriaServicioEntity>>> getCategorias() async {
    try {
      final models = await _dataSource.fetchCategorias();
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<ServicioEntity>>> getServicios({
    int? categoriaId,
  }) async {
    try {
      final models = await _dataSource.fetchServicios(categoriaId: categoriaId);
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}