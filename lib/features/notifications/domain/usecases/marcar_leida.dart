import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/app/core/usecases/use_case.dart';
import '../repositories/i_notifications_repository.dart';

class MarcarNotificacionLeidaParams {
  final String notificacionId;
  const MarcarNotificacionLeidaParams(this.notificacionId);
}

/// Marca una notificación como leída.
class MarcarNotificacionLeida
    extends UseCase<void, MarcarNotificacionLeidaParams> {
  final INotificationsRepository _repository;
  MarcarNotificacionLeida(this._repository);

  @override
  Future<Either<Failure, void>> call(MarcarNotificacionLeidaParams params) {
    return _repository.marcarLeida(params.notificacionId);
  }
}

class MarcarTodasLeidasParams {
  final String usuarioId;
  const MarcarTodasLeidasParams(this.usuarioId);
}

/// Marca todas las notificaciones del usuario como leídas.
class MarcarTodasLeidas extends UseCase<void, MarcarTodasLeidasParams> {
  final INotificationsRepository _repository;
  MarcarTodasLeidas(this._repository);

  @override
  Future<Either<Failure, void>> call(MarcarTodasLeidasParams params) {
    return _repository.marcarTodasLeidas(params.usuarioId);
  }
}
