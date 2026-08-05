import '../../domain/entities/disponibilidad_entity.dart';

class DisponibilidadModel {
  final String id;
  final String especialistaId;
  final EstadoDisponibilidad estado;
  final DateTime? fechaInicio;
  final DateTime? fechaFin;
  final DateTime createdAt;

  const DisponibilidadModel({
    required this.id,
    required this.especialistaId,
    required this.estado,
    this.fechaInicio,
    this.fechaFin,
    required this.createdAt,
  });

  factory DisponibilidadModel.fromJson(Map<String, dynamic> json) {
    return DisponibilidadModel(
      id: json['id'] as String,
      especialistaId: json['especialista_id'] as String,
      estado: EstadoDisponibilidad.fromDb(json['estado'] as String?) ??
          EstadoDisponibilidad.noDisponible,
      fechaInicio: _parseDate(json['fecha_inicio']),
      fechaFin: _parseDate(json['fecha_fin']),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'especialista_id': especialistaId,
      'estado': estado.toDb,
      'fecha_inicio': fechaInicio?.toIso8601String(),
      'fecha_fin': fechaFin?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  DisponibilidadEntity toEntity() {
    return DisponibilidadEntity(
      id: id,
      especialistaId: especialistaId,
      estado: estado,
      fechaInicio: fechaInicio,
      fechaFin: fechaFin,
      createdAt: createdAt,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}