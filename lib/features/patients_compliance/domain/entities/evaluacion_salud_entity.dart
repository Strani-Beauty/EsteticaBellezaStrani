import 'package:equatable/equatable.dart';

enum EstadoEvaluacion { pendiente, aprobada, rechazada, vencida }

class RespuestaSaludEntity extends Equatable {
  final String id;             // UUID
  final String evaluacionId;   // FK evaluaciones_salud.id
  final String preguntaId;     // FK preguntas.id
  final String respuesta;      // texto libre o opcion seleccionada
  final DateTime createdAt;

  const RespuestaSaludEntity({
    required this.id,
    required this.evaluacionId,
    required this.preguntaId,
    required this.respuesta,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, evaluacionId, preguntaId];
}

/// Evaluación completa de salud del paciente.
/// Vinculada obligatoriamente a solicitudes (trazabilidad médica)
class EvaluacionSaludEntity extends Equatable {
  final String id;              // UUID
  final String pacienteId;      // FK pacientes.id
  final String cuestionarioId;  // FK cuestionarios.id
  final EstadoEvaluacion estado;
  final List<RespuestaSaludEntity> respuestas;
  final DateTime createdAt;
  final DateTime? validaHasta;

  const EvaluacionSaludEntity({
    required this.id,
    required this.pacienteId,
    required this.cuestionarioId,
    required this.estado,
    required this.respuestas,
    required this.createdAt,
    this.validaHasta,
  });

  bool get isValid =>
      estado == EstadoEvaluacion.aprobada &&
      (validaHasta == null || validaHasta!.isAfter(DateTime.now()));

  @override
  List<Object?> get props => [id, pacienteId, cuestionarioId, estado];
}

/// Validación médica externa (Qualify) — RN-020, RN-022
class ValidacionTelemedinaEntity extends Equatable {
  final String id;            // UUID
  final String pacienteId;    // FK pacientes.id
  final String proveedor;     // 'Qualify' u otro
  final String estado;        // 'PENDIENTE' | 'APROBADA' | 'RECHAZADA' | 'VENCIDA'
  final String? referencia;   // ID externo del proveedor
  final String? notas;
  final DateTime? fechaVencimiento;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const ValidacionTelemedinaEntity({
    required this.id,
    required this.pacienteId,
    required this.proveedor,
    required this.estado,
    this.referencia,
    this.notas,
    this.fechaVencimiento,
    required this.createdAt,
    this.updatedAt,
  });

  /// RN-020 / RN-022: Bloquear reserva si no es válida
  bool get bloqueaReserva {
    if (estado == 'RECHAZADA') return true;
    if (estado == 'VENCIDA') return true;
    if (fechaVencimiento != null && fechaVencimiento!.isBefore(DateTime.now())) return true;
    return false;
  }

  @override
  List<Object?> get props => [id, pacienteId, estado, fechaVencimiento];
}
