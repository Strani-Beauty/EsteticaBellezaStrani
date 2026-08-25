import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/features/treatment_photos/domain/entities/fotografia_tratamiento_entity.dart';
import 'package:esteticaybellezastrani/features/treatment_photos/domain/usecases/subir_fotografia.dart';
import '../../mock_repository.dart';

void main() {
  late SubirFotografia usecase;
  late MockITreatmentPhotosRepository repository;

  setUpAll(() {
    registerFallbackValue(TipoFotografia.pre);
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    repository = MockITreatmentPhotosRepository();
    usecase = SubirFotografia(repository);
  });

  final bytes = Uint8List.fromList([1, 2, 3]);

  final foto = FotografiaTratamientoEntity(
    id: 'foto-1',
    tratamientoId: 'trat-1',
    tipoFotografia: TipoFotografia.pre,
    archivoUrl: 'trat-1/123.png',
    fechaCaptura: DateTime(2026, 8, 25),
    createdAt: DateTime(2026, 8, 25),
  );

  test('delega en el repositorio y retorna la fotografía subida', () async {
    when(() => repository.subirFotografia(
        tratamientoId: any(named: 'tratamientoId'),
        tipoFotografia: any(named: 'tipoFotografia'),
        bytes: any(named: 'bytes'),
        nombreArchivo: any(named: 'nombreArchivo'),
        descripcion: any(named: 'descripcion')))
        .thenAnswer((_) async => Right(foto));

    final result = await usecase(SubirFotografiaParams(
      tratamientoId: 'trat-1',
      tipoFotografia: TipoFotografia.pre,
      bytes: bytes,
      nombreArchivo: 'pre.png',
    ));

    expect(result, Right(foto));
    verify(() => repository.subirFotografia(
        tratamientoId: 'trat-1',
        tipoFotografia: TipoFotografia.pre,
        bytes: bytes,
        nombreArchivo: 'pre.png',
        descripcion: null)).called(1);
  });

  test('retorna Failure cuando el repositorio falla', () async {
    when(() => repository.subirFotografia(
        tratamientoId: any(named: 'tratamientoId'),
        tipoFotografia: any(named: 'tipoFotografia'),
        bytes: any(named: 'bytes'),
        nombreArchivo: any(named: 'nombreArchivo'),
        descripcion: any(named: 'descripcion')))
        .thenAnswer((_) async => const Left(ServerFailure('boom')));

    final result = await usecase(SubirFotografiaParams(
      tratamientoId: 'trat-1',
      tipoFotografia: TipoFotografia.pre,
      bytes: bytes,
      nombreArchivo: 'pre.png',
    ));

    expect(result, const Left(ServerFailure('boom')));
  });
}