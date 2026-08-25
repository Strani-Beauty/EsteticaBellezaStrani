import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/features/treatment_photos/domain/entities/fotografia_tratamiento_entity.dart';
import 'package:esteticaybellezastrani/features/treatment_photos/domain/usecases/eliminar_fotografia.dart';
import 'package:esteticaybellezastrani/features/treatment_photos/domain/usecases/get_fotografias.dart';
import 'package:esteticaybellezastrani/features/treatment_photos/domain/usecases/registrar_fotografia_por_url.dart';
import 'package:esteticaybellezastrani/features/treatment_photos/domain/usecases/subir_fotografia.dart';
import 'package:esteticaybellezastrani/features/treatment_photos/presentation/cubits/treatment_photos_cubit.dart';
import '../../mock_repository.dart';

TreatmentPhotosCubit _buildCubit(MockITreatmentPhotosRepository repo) {
  return TreatmentPhotosCubit(
    getFotografias: GetFotografias(repo),
    subirFotografia: SubirFotografia(repo),
    registrarFotografiaPorUrl: RegistrarFotografiaPorUrl(repo),
    eliminarFotografia: EliminarFotografia(repo),
  );
}

void main() {
  late MockITreatmentPhotosRepository repo;

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  final foto = FotografiaTratamientoEntity(
    id: 'foto-1',
    tratamientoId: 'trat-1',
    tipoFotografia: TipoFotografia.pre,
    archivoUrl: 'trat-1/123.png',
    fechaCaptura: DateTime(2026, 8, 25, 10, 0),
    createdAt: DateTime(2026, 8, 25, 10, 0),
  );

  setUp(() {
    repo = MockITreatmentPhotosRepository();
  });

  group('loadFotografias', () {
    blocTest<TreatmentPhotosCubit, TreatmentPhotosState>(
      'carga las fotografías del tratamiento',
      build: () => _buildCubit(repo),
      setUp: () {
        when(() => repo.getFotografias('trat-1'))
            .thenAnswer((_) async => Right([foto]));
      },
      act: (cubit) => cubit.loadFotografias('trat-1'),
      expect: () => [
        isA<TreatmentPhotosLoading>(),
        TreatmentPhotosLoaded(fotografias: [foto]),
      ],
    );

    blocTest<TreatmentPhotosCubit, TreatmentPhotosState>(
      'emite Error cuando falla la carga',
      build: () => _buildCubit(repo),
      setUp: () {
        when(() => repo.getFotografias('trat-1'))
            .thenAnswer((_) async => const Left(ServerFailure('boom')));
      },
      act: (cubit) => cubit.loadFotografias('trat-1'),
      expect: () => [
        isA<TreatmentPhotosLoading>(),
        const TreatmentPhotosError('boom'),
      ],
    );
  });

  group('subirFotografia', () {
    blocTest<TreatmentPhotosCubit, TreatmentPhotosState>(
      'sube la foto PRE, marca uploading y la antepone a la lista',
      build: () => _buildCubit(repo),
      seed: () => const TreatmentPhotosLoaded(fotografias: []),
      setUp: () {
        when(() => repo.subirFotografia(
          tratamientoId: 'trat-1',
          tipoFotografia: TipoFotografia.pre,
          bytes: any(named: 'bytes'),
          nombreArchivo: 'pre.png',
          descripcion: null,
        )).thenAnswer((_) async => Right(foto));
      },
      act: (cubit) => cubit.subirFotografia(
        tratamientoId: 'trat-1',
        tipoFotografia: TipoFotografia.pre,
        bytes: Uint8List.fromList([1, 2, 3]),
        nombreArchivo: 'pre.png',
      ),
      expect: () => [
        const TreatmentPhotosLoaded(fotografias: [], uploading: true),
        TreatmentPhotosLoaded(fotografias: [foto], uploading: false),
      ],
      verify: (_) {
        verify(() => repo.subirFotografia(
          tratamientoId: 'trat-1',
          tipoFotografia: TipoFotografia.pre,
          bytes: Uint8List.fromList([1, 2, 3]),
          nombreArchivo: 'pre.png',
          descripcion: null,
        )).called(1);
      },
    );

    blocTest<TreatmentPhotosCubit, TreatmentPhotosState>(
      'emite Error cuando falla la subida',
      build: () => _buildCubit(repo),
      seed: () => const TreatmentPhotosLoaded(fotografias: []),
      setUp: () {
        when(() => repo.subirFotografia(
          tratamientoId: 'trat-1',
          tipoFotografia: TipoFotografia.pre,
          bytes: any(named: 'bytes'),
          nombreArchivo: 'pre.png',
          descripcion: null,
        )).thenAnswer((_) async => const Left(ServerFailure('boom')));
      },
      act: (cubit) => cubit.subirFotografia(
        tratamientoId: 'trat-1',
        tipoFotografia: TipoFotografia.pre,
        bytes: Uint8List.fromList([1, 2, 3]),
        nombreArchivo: 'pre.png',
      ),
      expect: () => [
        const TreatmentPhotosLoaded(fotografias: [], uploading: true),
        const TreatmentPhotosError('boom'),
      ],
    );
  });

  group('registrarPorUrl', () {
    blocTest<TreatmentPhotosCubit, TreatmentPhotosState>(
      'registra una foto por URL y la antepone a la lista',
      build: () => _buildCubit(repo),
      seed: () => const TreatmentPhotosLoaded(fotografias: []),
      setUp: () {
        when(() => repo.registrarPorUrl(
          tratamientoId: 'trat-1',
          tipoFotografia: TipoFotografia.post,
          archivoUrl: 'https://cdn/x.png',
          descripcion: null,
        )).thenAnswer((_) async => Right(foto));
      },
      act: (cubit) => cubit.registrarPorUrl(
        tratamientoId: 'trat-1',
        tipoFotografia: TipoFotografia.post,
        archivoUrl: 'https://cdn/x.png',
      ),
      expect: () => [
        TreatmentPhotosLoaded(fotografias: [foto]),
      ],
    );
  });

  group('eliminarFotografia', () {
    blocTest<TreatmentPhotosCubit, TreatmentPhotosState>(
      'elimina la fotografía de la lista',
      build: () => _buildCubit(repo),
      seed: () => TreatmentPhotosLoaded(fotografias: [foto]),
      setUp: () {
        when(() => repo.eliminarFotografia('foto-1', pathEnStorage: null))
            .thenAnswer((_) async => const Right(null));
      },
      act: (cubit) => cubit.eliminarFotografia('foto-1'),
      expect: () => [
        const TreatmentPhotosLoaded(fotografias: []),
      ],
    );

    blocTest<TreatmentPhotosCubit, TreatmentPhotosState>(
      'emite Error cuando falla la eliminación',
      build: () => _buildCubit(repo),
      seed: () => TreatmentPhotosLoaded(fotografias: [foto]),
      setUp: () {
        when(() => repo.eliminarFotografia('foto-1', pathEnStorage: null))
            .thenAnswer((_) async => const Left(ServerFailure('boom')));
      },
      act: (cubit) => cubit.eliminarFotografia('foto-1'),
      expect: () => [
        const TreatmentPhotosError('boom'),
      ],
    );
  });
}