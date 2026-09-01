import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../domain/entities/evaluacion_entity.dart';
import '../../domain/repositories/i_calificaciones_repository.dart';
import '../datasources/calificaciones_supabase_datasource.dart';

class CalificacionesRepositoryImpl implements ICalificacionesRepository {
  final CalificacionesSupabaseDataSource _dataSource;

  const CalificacionesRepositoryImpl(this._dataSource);

  @override
  Future<Either<Failure, String>> registrarEvaluacion({
    required String citaId,
    required int puntuacion,
    String? comentario,
  }) async {
    try {
      final id = await _dataSource.fetchRegistrarEvaluacion(
        citaId: citaId,
        puntuacion: puntuacion,
        comentario: comentario,
      );
      return Right(id);
    } catch (e) {
      return Left(ServerFailure('No se pudo registrar la calificación: $e'));
    }
  }

  @override
  Future<Either<Failure, PromedioEspecialistaEntity>> getPromedioEspecialista(
      String especialistaId) async {
    try {
      final promedio =
          await _dataSource.fetchPromedioEspecialista(especialistaId);
      return Right(promedio);
    } catch (e) {
      return Left(ServerFailure('No se pudo cargar el promedio: $e'));
    }
  }
}