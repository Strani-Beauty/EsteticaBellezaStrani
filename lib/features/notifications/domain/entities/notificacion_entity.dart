import 'package:equatable/equatable.dart';

/// Entidad de dominio: `notificaciones`.
class NotificacionEntity extends Equatable {
  final String id;
  final String usuarioId;
  final String titulo;
  final String mensaje;
  final String tipo;
  final bool leida;
  final DateTime fechaEnvio;
  final DateTime createdAt;

  const NotificacionEntity({
    required this.id,
    required this.usuarioId,
    required this.titulo,
    required this.mensaje,
    this.tipo = 'SISTEMA',
    required this.leida,
    required this.fechaEnvio,
    required this.createdAt,
  });

  NotificacionEntity copyWith({bool? leida}) {
    return NotificacionEntity(
      id: id,
      usuarioId: usuarioId,
      titulo: titulo,
      mensaje: mensaje,
      tipo: tipo,
      leida: leida ?? this.leida,
      fechaEnvio: fechaEnvio,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [id, usuarioId, titulo, leida, fechaEnvio];
}
