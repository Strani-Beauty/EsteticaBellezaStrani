import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import '../../domain/entities/especialista_mapa_entity.dart';
import '../../domain/entities/resultado_aceptacion_entity.dart';
import '../../domain/entities/solicitud_pendiente_entity.dart';
import '../../domain/repositories/i_marketplace_repository.dart';
import '../datasources/marketplace_supabase_datasource.dart';

/// Implementación del repositorio de marketplace usando Supabase.
class MarketplaceRepositoryImpl implements IMarketplaceRepository {
  final MarketplaceSupabaseDataSource _dataSource;

  MarketplaceRepositoryImpl(this._dataSource);

  @override
  Future<Either<Failure, List<SolicitudPendienteEntity>>>
      getSolicitudesPendientes() async {
    try {
      final models = await _dataSource.fetchSolicitudesPendientes();
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<EspecialistaMapaEntity>>>
      getEspecialistasAprobados() async {
    try {
      final models = await _dataSource.fetchEspecialistasAprobados();
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, ({double? latitud, double? longitud})>>
      getMiUbicacion(String especialistaId) async {
    try {
      final (latitud, longitud) =
          await _dataSource.fetchMiUbicacion(especialistaId);
      return Right((latitud: latitud, longitud: longitud));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, ResultadoAceptacionEntity>> aceptarSolicitud({
    required String solicitudId,
    required String especialistaId,
  }) async {
    try {
      final model = await _dataSource.aceptarSolicitud(
        solicitudId: solicitudId,
        especialistaId: especialistaId,
      );
      return Right(model.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
