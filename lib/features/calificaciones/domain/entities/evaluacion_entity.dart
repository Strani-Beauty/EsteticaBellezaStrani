import 'package:equatable/equatable.dart';

/// Calificación emitida por un participante de la cita sobre el otro.
class EvaluacionEntity extends Equatable {
  final String id;
  final String citaId;
  final String evaluadorId;

  /// Especialista evaluado (cuando el paciente califica).
  final String? evaluadoEspecialistaId;

  /// Paciente evaluado (cuando el especialista califica).
  final String? evaluadoPacienteId;
  final int puntuacion;
  final String? comentario;

  const EvaluacionEntity({
    required this.id,
    required this.citaId,
    required this.evaluadorId,
    this.evaluadoEspecialistaId,
    this.evaluadoPacienteId,
    required this.puntuacion,
    this.comentario,
  });

  @override
  List<Object?> get props => [id, citaId, evaluadorId];
}

/// Promedio y total de calificaciones recibidas por un especialista.
class PromedioEspecialistaEntity extends Equatable {
  final double promedio;
  final int total;

  const PromedioEspecialistaEntity({this.promedio = 0, this.total = 0});

  @override
  List<Object?> get props => [promedio, total];
}