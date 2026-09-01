import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import '../datasources/auditoria_supabase_datasource.dart';
import '../../domain/entities/auditoria_entity.dart';
import '../../domain/repositories/i_auditoria_repository.dart';

/// Implementación del repositorio de auditoría sobre Supabase.
class AuditoriaRepositoryImpl implements IAuditoriaRepository {
  final AuditoriaSupabaseDataSource _dataSource;

  const AuditoriaRepositoryImpl(this._dataSource);

  @override
  Future<Either<Failure, List<AuditoriaEntity>>> getAuditoria(
      AuditoriaFiltros filtros) async {
    try {
      return Right(await _dataSource.fetchAuditoria(
        entidad: filtros.entidad,
        accion: filtros.accion,
        desde: filtros.desde,
        hasta: filtros.hasta,
        limite: filtros.limite,
      ));
    } catch (e) {
      return Left(ServerFailure('No se pudo cargar la auditoría: $e'));
    }
  }
}