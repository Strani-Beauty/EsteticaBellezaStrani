import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// Los usecases se inyectan por nombre; esta regla no aplica aquí.
// ignore_for_file: prefer_initializing_formals
import '../../domain/entities/notificacion_entity.dart';
import '../../domain/usecases/get_notificaciones.dart';
import '../../domain/usecases/marcar_leida.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ESTADOS
// ─────────────────────────────────────────────────────────────────────────────

abstract class NotificationsState extends Equatable {
  const NotificationsState();
  @override
  List<Object?> get props => [];
}

class NotificationsInitial extends NotificationsState {
  const NotificationsInitial();
}

class NotificationsLoading extends NotificationsState {
  const NotificationsLoading();
}

class NotificationsLoaded extends NotificationsState {
  final List<NotificacionEntity> notificaciones;
  const NotificationsLoaded({this.notificaciones = const []});

  int get noLeidas => notificaciones.where((n) => !n.leida).length;

  @override
  List<Object?> get props => [notificaciones];
}

class NotificationsError extends NotificationsState {
  final String message;
  const NotificationsError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─────────────────────────────────────────────────────────────────────────────
// CUBIT
// ─────────────────────────────────────────────────────────────────────────────

class NotificationsCubit extends Cubit<NotificationsState> {
  final GetNotificaciones _getNotificaciones;
  final MarcarNotificacionLeida _marcarLeida;
  final MarcarTodasLeidas _marcarTodasLeidas;

  NotificationsCubit({
    required GetNotificaciones getNotificaciones,
    required MarcarNotificacionLeida marcarLeida,
    required MarcarTodasLeidas marcarTodasLeidas,
  })  : _getNotificaciones = getNotificaciones,
        _marcarLeida = marcarLeida,
        _marcarTodasLeidas = marcarTodasLeidas,
        super(const NotificationsInitial());

  @override
  void emit(NotificationsState state) {
    if (isClosed) return;
    super.emit(state);
  }

  Future<void> load(String usuarioId) async {
    emit(const NotificationsLoading());
    final result =
        await _getNotificaciones(GetNotificacionesParams(usuarioId));
    result.fold(
      (f) => emit(NotificationsError(f.message)),
      (list) => emit(NotificationsLoaded(notificaciones: list)),
    );
  }

  Future<void> markRead(String notificacionId) async {
    final current = state;
    if (current is! NotificationsLoaded) return;
    await _marcarLeida(MarcarNotificacionLeidaParams(notificacionId));
    emit(NotificationsLoaded(notificaciones: [
      for (final n in current.notificaciones)
        if (n.id == notificacionId) n.copyWith(leida: true) else n,
    ]));
  }

  Future<void> markAllRead() async {
    final current = state;
    if (current is! NotificationsLoaded || current.notificaciones.isEmpty) {
      return;
    }
    await _marcarTodasLeidas(
      MarcarTodasLeidasParams(current.notificaciones.first.usuarioId),
    );
    emit(NotificationsLoaded(notificaciones: [
      for (final n in current.notificaciones) n.copyWith(leida: true),
    ]));
  }
}
