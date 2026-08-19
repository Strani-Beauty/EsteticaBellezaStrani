import 'package:equatable/equatable.dart';

/// Entidad de dominio: `servicio_cuestionarios` (relación M:N servicio -> cuestionario).
/// Determina qué cuestionario/requisitos de salud corresponden a cada servicio.
class ServicioCuestionarioEntity extends Equatable {
  final int cuestionarioId; // FK cuestionarios.id
  final String? nombre; // join cuestionarios.nombre
  final bool obligatorio;
  final int orden;

  const ServicioCuestionarioEntity({
    required this.cuestionarioId,
    this.nombre,
    required this.obligatorio,
    this.orden = 0,
  });

  @override
  List<Object?> get props => [cuestionarioId, nombre, obligatorio, orden];
}

/// Requisitos configurados de un servicio (`servicio_especialidades` +
/// `servicio_cuestionarios`). Se usa en la consulta del catálogo y en la
/// validación previa a la solicitud.
class ServicioRequisitosEntity extends Equatable {
  final List<int> especialidadIds;
  final List<ServicioCuestionarioEntity> cuestionarios;

  const ServicioRequisitosEntity({
    this.especialidadIds = const [],
    this.cuestionarios = const [],
  });

  /// Cuestionarios obligatorios vinculados al servicio.
  List<ServicioCuestionarioEntity> get cuestionariosObligatorios =>
      cuestionarios.where((c) => c.obligatorio).toList();

  @override
  List<Object?> get props => [especialidadIds, cuestionarios];
}