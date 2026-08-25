import '../../domain/entities/face_map_especialista_entity.dart';

/// Modelo del face map del especialista (espejo del domain entity).
class FaceMapEspecialistaModel {
  final String? id;
  final String? tratamientoId;
  final String? pacienteId;
  final String? servicioId;
  final String? tipoMapa;
  final String? imagenBaseUrl;
  final String? observaciones;
  final List<Map<String, dynamic>> puntos;

  const FaceMapEspecialistaModel({
    this.id,
    this.tratamientoId,
    this.pacienteId,
    this.servicioId,
    this.tipoMapa,
    this.imagenBaseUrl,
    this.observaciones,
    this.puntos = const [],
  });

  factory FaceMapEspecialistaModel.fromJson(Map<String, dynamic> json) {
    return FaceMapEspecialistaModel(
      id: json['id'] as String?,
      tratamientoId: json['tratamiento_id'] as String?,
      pacienteId: json['paciente_id'] as String?,
      servicioId: json['servicio_id'] as String?,
      tipoMapa: json['tipo_mapa'] as String?,
      imagenBaseUrl: json['imagen_base_url'] as String?,
      observaciones: json['observaciones'] as String?,
    );
  }

  FaceMapEspecialistaEntity toEntity() {
    return FaceMapEspecialistaEntity(
      id: id,
      tratamientoId: tratamientoId,
      pacienteId: pacienteId,
      servicioId: servicioId,
      tipoMapa: tipoMapa,
      imagenBaseUrl: imagenBaseUrl,
      observaciones: observaciones,
      puntos: puntos,
    );
  }
}