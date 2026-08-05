import '../../domain/entities/ubicacion_especialista_entity.dart';

class UbicacionEspecialistaModel {
  final String id;
  final String especialistaId;
  final double latitud;
  final double longitud;
  final double precisionMetros;
  final DateTime? fechaActualizacion;
  final DateTime createdAt;

  const UbicacionEspecialistaModel({
    required this.id,
    required this.especialistaId,
    required this.latitud,
    required this.longitud,
    required this.precisionMetros,
    this.fechaActualizacion,
    required this.createdAt,
  });

  factory UbicacionEspecialistaModel.fromJson(Map<String, dynamic> json) {
    return UbicacionEspecialistaModel(
      id: json['id'] as String,
      especialistaId: json['especialista_id'] as String,
      latitud: ((json['latitud'] as num?)?.toDouble()) ?? 0,
      longitud: ((json['longitud'] as num?)?.toDouble()) ?? 0,
      precisionMetros: ((json['precision_metros'] as num?)?.toDouble()) ?? 0,
      fechaActualizacion: _parseDate(json['fecha_actualizacion']),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'especialista_id': especialistaId,
      'latitud': latitud,
      'longitud': longitud,
      'precision_metros': precisionMetros,
      'fecha_actualizacion': fechaActualizacion?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  UbicacionEspecialistaEntity toEntity() {
    return UbicacionEspecialistaEntity(
      id: id,
      especialistaId: especialistaId,
      latitud: latitud,
      longitud: longitud,
      precisionMetros: precisionMetros,
      fechaActualizacion: fechaActualizacion,
      createdAt: createdAt,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}