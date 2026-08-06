import '../../domain/entities/resultado_aceptacion_entity.dart';

class ResultadoAceptacionModel {
  final bool aceptada;
  final String? citaId;
  final String? motivo;

  const ResultadoAceptacionModel({
    required this.aceptada,
    this.citaId,
    this.motivo,
  });

  factory ResultadoAceptacionModel.fromJson(Map<String, dynamic> json) {
    return ResultadoAceptacionModel(
      aceptada: json['aceptada'] as bool? ?? false,
      citaId: json['cita_id'] as String?,
      motivo: json['motivo'] as String?,
    );
  }

  ResultadoAceptacionEntity toEntity() {
    return ResultadoAceptacionEntity(
      aceptada: aceptada,
      citaId: citaId,
      motivo: motivo,
    );
  }
}
