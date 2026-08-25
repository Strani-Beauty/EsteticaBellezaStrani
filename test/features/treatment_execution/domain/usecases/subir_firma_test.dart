import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/usecases/subir_firma.dart';
import '../../mock_repository.dart';

void main() {
  late SubirFirma usecase;
  late MockITreatmentExecutionRepository repository;

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    repository = MockITreatmentExecutionRepository();
    usecase = SubirFirma(repository);
  });

  final bytes = Uint8List.fromList([1, 2, 3]);

  test('delega en el repositorio y retorna el path de la firma subida',
      () async {
    when(() => repository.subirFirma(
        tratamientoId: any(named: 'tratamientoId'),
        bytes: any(named: 'bytes')))
        .thenAnswer((_) async => const Right('trat-1/firma_1.png'));

    final result = await usecase(
        SubirFirmaParams(tratamientoId: 'trat-1', bytes: bytes));

    expect(result, const Right('trat-1/firma_1.png'));
    verify(() => repository.subirFirma(
        tratamientoId: 'trat-1', bytes: bytes)).called(1);
  });

  test('retorna Failure cuando el repositorio falla', () async {
    when(() => repository.subirFirma(
        tratamientoId: any(named: 'tratamientoId'),
        bytes: any(named: 'bytes')))
        .thenAnswer((_) async => const Left(ServerFailure('boom')));

    final result = await usecase(
        SubirFirmaParams(tratamientoId: 'trat-1', bytes: bytes));

    expect(result, const Left(ServerFailure('boom')));
  });
}