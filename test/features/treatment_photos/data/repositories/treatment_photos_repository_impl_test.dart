import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/features/treatment_photos/data/datasources/treatment_photos_supabase_datasource.dart';
import 'package:esteticaybellezastrani/features/treatment_photos/data/models/fotografia_tratamiento_model.dart';
import 'package:esteticaybellezastrani/features/treatment_photos/data/repositories/treatment_photos_repository_impl.dart';
import 'package:esteticaybellezastrani/features/treatment_photos/domain/entities/fotografia_tratamiento_entity.dart';

class MockTreatmentPhotosDataSource extends Mock
    implements TreatmentPhotosSupabaseDataSource {}

void main() {
  late TreatmentPhotosRepositoryImpl repository;
  late MockTreatmentPhotosDataSource dataSource;

  final fechaCaptura = DateTime(2026, 8, 25, 10, 0);
  final fotoModel = FotografiaTratamientoModel(
    id: 'foto-1',
    tratamientoId: 'trat-1',
    tipoFotografia: TipoFotografia.pre,
    archivoUrl: 'trat-1/1750000000000_png.png',
    fechaCaptura: fechaCaptura,
    createdAt: fechaCaptura,
    descripcion: 'Vista frontal',
    tipoFoto: 'pre',
  );

  setUp(() {
    dataSource = MockTreatmentPhotosDataSource();
    repository = TreatmentPhotosRepositoryImpl(dataSource);
  });

  group('getFotografias', () {
    test('retorna las fotografías del tratamiento', () async {
      when(() => dataSource.fetchFotografias('trat-1'))
          .thenAnswer((_) async => [fotoModel]);

      final result = await repository.getFotografias('trat-1');

      expect(result.getRight().toNullable(), [fotoModel.toEntity()]);
      verify(() => dataSource.fetchFotografias('trat-1')).called(1);
    });

    test('degradado a ServerFailure cuando el datasource falla', () async {
      when(() => dataSource.fetchFotografias('trat-1'))
          .thenThrow(Exception('boom'));

      final result = await repository.getFotografias('trat-1');

      expect(result.isLeft(), isTrue);
      expect(result.fold((l) => l, (r) => null), isA<ServerFailure>());
    });
  });

  group('subirFotografia', () {
    test('sube la foto y la registra vinculada al tratamiento', () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      when(() => dataSource.subirFotografia(
        tratamientoId: 'trat-1',
        tipoFotografia: TipoFotografia.pre,
        bytes: bytes,
        nombreArchivo: 'pre.png',
        descripcion: null,
      )).thenAnswer((_) async => fotoModel);

      final result = await repository.subirFotografia(
        tratamientoId: 'trat-1',
        tipoFotografia: TipoFotografia.pre,
        bytes: bytes,
        nombreArchivo: 'pre.png',
      );

      expect(result.getRight().toNullable(), fotoModel.toEntity());
      verify(() => dataSource.subirFotografia(
        tratamientoId: 'trat-1',
        tipoFotografia: TipoFotografia.pre,
        bytes: bytes,
        nombreArchivo: 'pre.png',
        descripcion: null,
      )).called(1);
    });

    test('degradado a StorageFailure cuando el datasource falla', () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      when(() => dataSource.subirFotografia(
        tratamientoId: 'trat-1',
        tipoFotografia: TipoFotografia.pre,
        bytes: bytes,
        nombreArchivo: 'pre.png',
        descripcion: null,
      )).thenThrow(Exception('boom'));

      final result = await repository.subirFotografia(
        tratamientoId: 'trat-1',
        tipoFotografia: TipoFotografia.pre,
        bytes: bytes,
        nombreArchivo: 'pre.png',
      );

      expect(result.isLeft(), isTrue);
      expect(result.fold((l) => l, (r) => null), isA<StorageFailure>());
    });
  });

  group('registrarPorUrl', () {
    test('registra una fotografía por URL vinculada al tratamiento',
        () async {
      when(() => dataSource.registrarPorUrl(
        tratamientoId: 'trat-1',
        tipoFotografia: TipoFotografia.post,
        archivoUrl: 'https://ejemplo.com/foto.png',
        descripcion: null,
      )).thenAnswer((_) async => fotoModel);

      final result = await repository.registrarPorUrl(
        tratamientoId: 'trat-1',
        tipoFotografia: TipoFotografia.post,
        archivoUrl: 'https://ejemplo.com/foto.png',
      );

      expect(result.getRight().toNullable(), fotoModel.toEntity());
      verify(() => dataSource.registrarPorUrl(
        tratamientoId: 'trat-1',
        tipoFotografia: TipoFotografia.post,
        archivoUrl: 'https://ejemplo.com/foto.png',
        descripcion: null,
      )).called(1);
    });

    test('degradado a ServerFailure cuando el datasource falla', () async {
      when(() => dataSource.registrarPorUrl(
        tratamientoId: 'trat-1',
        tipoFotografia: TipoFotografia.post,
        archivoUrl: 'https://ejemplo.com/foto.png',
        descripcion: null,
      )).thenThrow(Exception('boom'));

      final result = await repository.registrarPorUrl(
        tratamientoId: 'trat-1',
        tipoFotografia: TipoFotografia.post,
        archivoUrl: 'https://ejemplo.com/foto.png',
      );

      expect(result.isLeft(), isTrue);
      expect(result.fold((l) => l, (r) => null), isA<ServerFailure>());
    });
  });

  group('eliminarFotografia', () {
    test('elimina la foto y su objeto en storage, retorna Right(null)',
        () async {
      when(() => dataSource.eliminarFotografia(
        'foto-1',
        pathEnStorage: 'trat-1/1750000000000_png.png',
      )).thenAnswer((_) async {});

      final result = await repository.eliminarFotografia(
        'foto-1',
        pathEnStorage: 'trat-1/1750000000000_png.png',
      );

      expect(result, const Right(null));
      verify(() => dataSource.eliminarFotografia(
        'foto-1',
        pathEnStorage: 'trat-1/1750000000000_png.png',
      )).called(1);
    });

    test('degradado a ServerFailure cuando el datasource falla', () async {
      when(() => dataSource.eliminarFotografia('foto-1', pathEnStorage: null))
          .thenThrow(Exception('boom'));

      final result = await repository.eliminarFotografia('foto-1');

      expect(result.isLeft(), isTrue);
      expect(result.fold((l) => l, (r) => null), isA<ServerFailure>());
    });
  });
}