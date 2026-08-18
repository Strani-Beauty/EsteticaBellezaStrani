import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import '../../domain/entities/notificacion_entity.dart';
import '../../domain/repositories/i_notifications_repository.dart';
import '../datasources/notifications_supabase_datasource.dart';

/// Implementación del repositorio de notificaciones usando Supabase.
class NotificationsRepositoryImpl implements INotificationsRepository {
  final NotificationsSupabaseDataSource _dataSource;

  NotificationsRepositoryImpl(this._dataSource);

  @override
  Future<Either<Failure, List<NotificacionEntity>>> getNotificaciones(
    String usuarioId,
  ) async {
    try {
      final models = await _dataSource.fetchNotificaciones(usuarioId);
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> marcarLeida(String notificacionId) async {
    try {
      await _dataSource.marcarLeida(notificacionId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> marcarTodasLeidas(String usuarioId) async {
    try {
      await _dataSource.marcarTodasLeidas(usuarioId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
