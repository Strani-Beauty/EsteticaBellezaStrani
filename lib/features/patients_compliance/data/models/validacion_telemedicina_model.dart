import '../../domain/entities/evaluacion_salud_entity.dart';

/// Modelo de `validaciones_telemedicina`.
class ValidacionTelemedicinaModel {
  final String id;
  final String pacienteId;
  final String proveedor;
  final String estado;
  final String? codigoReferencia;
  final String? observaciones;
  final DateTime? fechaValidacion;
  final DateTime? fechaVencimiento;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const ValidacionTelemedicinaModel({
    required this.id,
    required this.pacienteId,
    required this.proveedor,
    required this.estado,
    this.codigoReferencia,
    this.observaciones,
    this.fechaValidacion,
    this.fechaVencimiento,
    required this.createdAt,
    this.updatedAt,
  });

  factory ValidacionTelemedicinaModel.fromJson(Map<String, dynamic> json) =>
      ValidacionTelemedicinaModel(
        id: (json['id'] as String?) ?? '',
        pacienteId: (json['paciente_id'] as String?) ?? '',
        proveedor: (json['proveedor'] as String?) ?? '',
        estado: (json['estado'] as String?) ?? 'PENDIENTE',
        codigoReferencia: json['codigo_referencia'] as String?,
        observaciones: json['observaciones'] as String?,
        fechaValidacion: json['fecha_validacion'] != null
            ? DateTime.tryParse(json['fecha_validacion'].toString())
            : null,
        fechaVencimiento: json['fecha_vencimiento'] != null
            ? DateTime.tryParse(json['fecha_vencimiento'].toString())
            : null,
        createdAt:
            DateTime.tryParse((json['created_at'] as String?) ?? '') ?? DateTime.now(),
        updatedAt: json['updated_at'] != null
            ? DateTime.tryParse(json['updated_at'].toString())
            : null,
      );

  ValidacionTelemedicinaEntity toEntity() => ValidacionTelemedicinaEntity(
        id: id,
        pacienteId: pacienteId,
        proveedor: proveedor,
        estado: estado,
        codigoReferencia: codigoReferencia,
        observaciones: observaciones,
        fechaValidacion: fechaValidacion,
        fechaVencimiento: fechaVencimiento,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}