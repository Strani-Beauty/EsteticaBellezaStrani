import '../../domain/entities/notificacion_entity.dart';

class NotificacionModel {
  final String id;
  final String usuarioId;
  final String titulo;
  final String mensaje;
  final String tipo;
  final bool leida;
  final DateTime fechaEnvio;
  final DateTime createdAt;

  const NotificacionModel({
    required this.id,
    required this.usuarioId,
    required this.titulo,
    required this.mensaje,
    required this.tipo,
    required this.leida,
    required this.fechaEnvio,
    required this.createdAt,
  });

  factory NotificacionModel.fromJson(Map<String, dynamic> json) {
    return NotificacionModel(
      id: json['id'] as String,
      usuarioId: json['usuario_id'] as String,
      titulo: json['titulo'] as String? ?? 'Notificación',
      mensaje: json['mensaje'] as String? ?? '',
      tipo: json['tipo'] as String? ?? 'SISTEMA',
      leida: json['leida'] as bool? ?? false,
      fechaEnvio: DateTime.parse(json['fecha_envio'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  NotificacionEntity toEntity() {
    return NotificacionEntity(
      id: id,
      usuarioId: usuarioId,
      titulo: titulo,
      mensaje: mensaje,
      tipo: tipo,
      leida: leida,
      fechaEnvio: fechaEnvio,
      createdAt: createdAt,
    );
  }
}
