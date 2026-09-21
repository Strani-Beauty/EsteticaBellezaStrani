import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import '../../domain/entities/ventas_entities.dart';
import '../../domain/repositories/i_reports_repository.dart';
import '../datasources/reports_supabase_datasource.dart';

/// Implementación del repositorio de reportes del dashboard de ventas.
class ReportsRepositoryImpl implements IReportsRepository {
  final ReportsSupabaseDataSource _dataSource;

  ReportsRepositoryImpl(this._dataSource);

  @override
  Future<Either<Failure, ResumenVentasEntity>> getResumenVentas({
    required DateTime desde,
    required DateTime hasta,
  }) async {
    try {
      final model =
          await _dataSource.fetchResumenVentas(desde: desde, hasta: hasta);
      return Right(model.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<VentaPorServicioEntity>>> getVentasPorServicio({
    required DateTime desde,
    required DateTime hasta,
  }) async {
    try {
      final models = await _dataSource.fetchVentasPorServicio(
        desde: desde,
        hasta: hasta,
      );
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<VentaPorEspecialistaEntity>>>
      getVentasPorEspecialista({
    required DateTime desde,
    required DateTime hasta,
  }) async {
    try {
      final models = await _dataSource.fetchVentasPorEspecialista(
        desde: desde,
        hasta: hasta,
      );
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<PuntoSerieVentasEntity>>> getSerieVentas({
    required DateTime desde,
    required DateTime hasta,
    String agrupacion = 'day',
  }) async {
    try {
      final models = await _dataSource.fetchSerieVentas(
        desde: desde,
        hasta: hasta,
        agrupacion: agrupacion,
      );
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}