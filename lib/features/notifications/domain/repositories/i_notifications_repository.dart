import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import '../entities/notificacion_entity.dart';

/// Contrato del repositorio de notificaciones in-app.
abstract class INotificationsRepository {
  Future<Either<Failure, List<NotificacionEntity>>> getNotificaciones(
    String usuarioId,
  );

  Future<Either<Failure, void>> marcarLeida(String notificacionId);

  Future<Either<Failure, void>> marcarTodasLeidas(String usuarioId);
}
