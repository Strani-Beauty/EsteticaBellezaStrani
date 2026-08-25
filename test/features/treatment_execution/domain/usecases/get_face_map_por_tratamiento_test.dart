import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/entities/face_map_especialista_entity.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/usecases/get_face_map_por_tratamiento.dart';
import '../../mock_repository.dart';

void main() {
  late GetFaceMapPorTratamiento usecase;
  late MockITreatmentExecutionRepository repository;

  setUp(() {
    repository = MockITreatmentExecutionRepository();
    usecase = GetFaceMapPorTratamiento(repository);
  });

  final faceMap = FaceMapEspecialistaEntity(
    id: 'fm-1',
    tratamientoId: 'trat-1',
    pacienteId: 'pac-1',
    tipoMapa: 'ROSTRO',
    puntos: const [
      {'punto_id': 'p1', 'vista': 'frente', 'coordenada_x': 0.5},
    ],
  );

  test('delega en el repositorio y retorna el face map del tratamiento',
      () async {
    when(() => repository.getFaceMapPorTratamiento(any()))
        .thenAnswer((_) async => Right(faceMap));

    final result = await usecase('trat-1');

    expect(result, Right(faceMap));
    verify(() => repository.getFaceMapPorTratamiento('trat-1')).called(1);
  });

  test('retorna Right(null) cuando no hay face map', () async {
    when(() => repository.getFaceMapPorTratamiento(any()))
        .thenAnswer((_) async => const Right(null));

    final result = await usecase('trat-1');

    expect(result, const Right(null));
  });

  test('retorna Failure cuando el repositorio falla', () async {
    when(() => repository.getFaceMapPorTratamiento(any()))
        .thenAnswer((_) async => const Left(ServerFailure('boom')));

    final result = await usecase('trat-1');

    expect(result, const Left(ServerFailure('boom')));
  });
}