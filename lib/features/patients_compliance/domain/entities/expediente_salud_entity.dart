import 'package:equatable/equatable.dart';
import 'paciente_entity.dart';
import 'evaluacion_salud_entity.dart';

/// Expediente de salud de un paciente (ePHI): datos del perfil + datos clínicos +
/// todas sus evaluaciones con respuestas + su validación médica más reciente.
class ExpedienteSaludEntity extends Equatable {
  final PacienteEntity paciente;
  final String? fullName;
  final String? email;
  final String? phone;
  final List<EvaluacionExpedienteEntity> evaluaciones;
  final ValidacionTelemedicinaEntity? validacion;

  const ExpedienteSaludEntity({
    required this.paciente,
    this.fullName,
    this.email,
    this.phone,
    this.evaluaciones = const [],
    this.validacion,
  });

  @override
  List<Object?> get props => [paciente, fullName, email, phone, evaluaciones, validacion];
}

/// Evaluación de un paciente con el nombre/versión del cuestionario y sus respuestas.
class EvaluacionExpedienteEntity extends Equatable {
  final EvaluacionSaludEntity evaluacion;
  final String? cuestionarioNombre;
  final int? version;
  final List<RespuestaSaludEntity> respuestas;

  const EvaluacionExpedienteEntity({
    required this.evaluacion,
    this.cuestionarioNombre,
    this.version,
    this.respuestas = const [],
  });

  @override
  List<Object?> get props => [evaluacion, cuestionarioNombre, version, respuestas];
}