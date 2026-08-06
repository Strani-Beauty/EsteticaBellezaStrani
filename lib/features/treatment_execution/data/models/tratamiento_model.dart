import '../../domain/entities/tratamiento_entity.dart';

/// Modelo de `tratamientos`.
class TratamientoModel {
  final String id;
  final String citaId;
  final String pacienteId;
  final String especialistaId;
  final String estado;
  final String? fechaInicio;
  final String? fechaFinalizacion;
  final String? evaluacionInicial;
  final String? observacionesFinales;
  final String? recomendacionesPostTratamiento;
  final String? createdAt;

  const TratamientoModel({
    required this.id,
    required this.citaId,
    required this.pacienteId,
    required this.especialistaId,
    required this.estado,
    this.fechaInicio,
    this.fechaFinalizacion,
    this.evaluacionInicial,
    this.observacionesFinales,
    this.recomendacionesPostTratamiento,
    this.createdAt,
  });

  factory TratamientoModel.fromJson(Map<String, dynamic> json) {
    return TratamientoModel(
      id: json['id'] as String? ?? '',
      citaId: json['cita_id'] as String? ?? '',
      pacienteId: json['paciente_id'] as String? ?? '',
      especialistaId: json['especialista_id'] as String? ?? '',
      estado: json['estado'] as String? ?? 'INICIADO',
      fechaInicio: json['fecha_inicio']?.toString(),
      fechaFinalizacion: json['fecha_finalizacion']?.toString(),
      evaluacionInicial: json['evaluacion_inicial'] as String?,
      observacionesFinales: json['observaciones_finales'] as String?,
      recomendacionesPostTratamiento:
          json['recomendaciones_post_tratam'] as String?,
      createdAt: json['created_at']?.toString(),
    );
  }

  TratamientoEntity toEntity() {
    return TratamientoEntity(
      id: id,
      citaId: citaId,
      pacienteId: pacienteId,
      especialistaId: especialistaId,
      estado: EstadoTratamiento.fromDb(estado) ?? EstadoTratamiento.iniciado,
      fechaInicio: _parseDate(fechaInicio),
      fechaFinalizacion: _parseDate(fechaFinalizacion),
      evaluacionInicial: evaluacionInicial,
      observacionesFinales: observacionesFinales,
      recomendacionesPostTratamiento: recomendacionesPostTratamiento,
      createdAt: _parseDate(createdAt) ?? DateTime.now(),
    );
  }

  static DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}
