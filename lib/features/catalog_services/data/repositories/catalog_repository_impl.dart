import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import '../../domain/entities/categoria_servicio_entity.dart';
import '../../domain/entities/servicio_cuestionario_entity.dart';
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

  @override
  Future<Either<Failure, List<CategoriaServicioEntity>>>
      getCategoriasAdmin() async {
    try {
      final models = await _dataSource.fetchCategoriasAdmin();
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, CategoriaServicioEntity>> guardarCategoria({
    int id = 0,
    required String nombre,
    String? descripcion,
    required bool activo,
  }) async {
    try {
      final model = id > 0
          ? await _dataSource.updateCategoria(
              id: id,
              nombre: nombre,
              descripcion: descripcion,
              activo: activo,
            )
          : await _dataSource.insertCategoria(
              nombre: nombre,
              descripcion: descripcion,
              activo: activo,
            );
      return Right(model.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<ServicioEntity>>> getServiciosAdmin() async {
    try {
      final models = await _dataSource.fetchServiciosAdmin();
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, ServicioEntity>> guardarServicio({
    String id = '',
    int? categoriaId,
    required String nombre,
    String? descripcion,
    required double precioBase,
    required TipoPrecio tipoPrecio,
    int? duracionEstimada,
    bool requiereTelemedicina = false,
    bool requiereFaceMap = false,
    bool requiereFotos = false,
    bool requiereConsentimiento = false,
    bool activo = true,
  }) async {
    try {
      final model = id.isEmpty
          ? await _dataSource.insertServicio(
              categoriaId: categoriaId,
              nombre: nombre,
              descripcion: descripcion,
              precioBase: precioBase,
              tipoPrecio: tipoPrecio,
              duracionEstimada: duracionEstimada,
              requiereTelemedicina: requiereTelemedicina,
              requiereFaceMap: requiereFaceMap,
              requiereFotos: requiereFotos,
              requiereConsentimiento: requiereConsentimiento,
              activo: activo,
            )
          : await _dataSource.updateServicio(
              id: id,
              categoriaId: categoriaId,
              nombre: nombre,
              descripcion: descripcion,
              precioBase: precioBase,
              tipoPrecio: tipoPrecio,
              duracionEstimada: duracionEstimada,
              requiereTelemedicina: requiereTelemedicina,
              requiereFaceMap: requiereFaceMap,
              requiereFotos: requiereFotos,
              requiereConsentimiento: requiereConsentimiento,
              activo: activo,
            );
      return Right(model.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, ServicioRequisitosEntity>> getRequisitosServicio(
      String servicioId) async {
    try {
      final requisitos = await _dataSource.fetchRequisitosServicio(servicioId);
      return Right(requisitos);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> guardarEspecialidadesServicio(
    String servicioId,
    List<int> especialidadIds,
  ) async {
    try {
      await _dataSource.reemplazarEspecialidadesServicio(
        servicioId,
        especialidadIds,
      );
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> guardarCuestionariosServicio(
    String servicioId,
    List<ServicioCuestionarioEntity> items,
  ) async {
    try {
      await _dataSource.reemplazarCuestionariosServicio(servicioId, items);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}