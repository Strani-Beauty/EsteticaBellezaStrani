import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import '../entities/evaluacion_entity.dart';

/// Contrato del módulo de calificaciones de servicio.
abstract class ICalificacionesRepository {
  /// Registra una evaluación (paciente→especialista o especialista→paciente).
  /// Devuelve el id de la evaluación creada.
  Future<Either<Failure, String>> registrarEvaluacion({
    required String citaId,
    required int puntuacion,
    String? comentario,
  });

  /// Promedio y total de calificaciones recibidas por un especialista.
  Future<Either<Failure, PromedioEspecialistaEntity>> getPromedioEspecialista(
      String especialistaId);
}