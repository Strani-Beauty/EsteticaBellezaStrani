import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/app/core/usecases/use_case.dart';
import '../entities/notificacion_entity.dart';
import '../repositories/i_notifications_repository.dart';

class GetNotificacionesParams {
  final String usuarioId;
  const GetNotificacionesParams(this.usuarioId);
}

/// Lista las notificaciones de un usuario (más recientes primero).
class GetNotificaciones
    extends UseCase<List<NotificacionEntity>, GetNotificacionesParams> {
  final INotificationsRepository _repository;
  GetNotificaciones(this._repository);

  @override
  Future<Either<Failure, List<NotificacionEntity>>> call(
      GetNotificacionesParams params) {
    return _repository.getNotificaciones(params.usuarioId);
  }
}
