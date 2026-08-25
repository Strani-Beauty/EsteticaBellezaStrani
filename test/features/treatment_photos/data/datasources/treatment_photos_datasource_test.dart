import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:esteticaybellezastrani/app/config/app_constants.dart';
import 'package:esteticaybellezastrani/features/treatment_photos/data/datasources/treatment_photos_supabase_datasource.dart';
import 'package:esteticaybellezastrani/features/treatment_photos/domain/entities/fotografia_tratamiento_entity.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}

class MockPostgrestFilterBuilder<T> extends Mock
    implements PostgrestFilterBuilder<T> {}

class MockSupabaseStorageClient extends Mock implements SupabaseStorageClient {}

class MockStorageFileApi extends Mock implements StorageFileApi {}

class _FakeTransformBuilder<T> extends Mock
    implements PostgrestTransformBuilder<T> {
  _FakeTransformBuilder(this._value);

  final T _value;

  @override
  Future<U> then<U>(
    FutureOr<U> Function(T) onValue, {
    Function? onError,
  }) async {
    return onValue(_value);
  }
}

void main() {
  late MockSupabaseClient client;
  late TreatmentPhotosSupabaseDataSource dataSource;

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    client = MockSupabaseClient();
    dataSource = TreatmentPhotosSupabaseDataSource(client);
  });

  const fotoRow = <String, dynamic>{
    'id': 'foto-1',
    'tratamiento_id': 'trat-1',
    'tipo_fotografia': 'PRE',
    'archivo_url': 'trat-1/1750000000000_png',
    'fecha_captura': '2026-08-25T10:00:00.000',
    'descripcion': 'Vista frontal',
    'created_at': '2026-08-25T10:00:00.000',
    'tipo_foto': 'pre',
  };

  MockStorageFileApi stubStorage(String path) {
    final storageMock = MockSupabaseStorageClient();
    final fileApi = MockStorageFileApi();
    when(() => client.storage).thenAnswer((_) => storageMock);
    when(() => storageMock.from(AppConstants.bucketFotografias))
        .thenAnswer((_) => fileApi);
    when(() => fileApi.uploadBinary(any(), any()))
        .thenAnswer((_) async => path);
    when(() => fileApi.createSignedUrl(any(), any()))
        .thenAnswer((_) async => 'https://signed/foto.png');
    return fileApi;
  }

  group('subirFotografia', () {
    test('sube la imagen al bucket fotografias-tratamiento y la registra con tipo PRE', () async {
      final fileApi = stubStorage('trat-1/1750000000000_png');

      final qb = MockSupabaseQueryBuilder();
      final fbInsert = MockPostgrestFilterBuilder<PostgrestMap>();
      when(() => client.from('fotografias_tratamiento')).thenAnswer((_) => qb);
      when(() => qb.insert(captureAny())).thenAnswer((_) => fbInsert);
      final fbSelect = _FakeTransformBuilder<PostgrestList>(const []);
      when(() => fbInsert.select()).thenAnswer((_) => fbSelect);
      when(() => fbSelect.maybeSingle())
          .thenAnswer((_) => _FakeTransformBuilder<PostgrestMap?>(fotoRow));

      final result = await dataSource.subirFotografia(
        tratamientoId: 'trat-1',
        tipoFotografia: TipoFotografia.pre,
        bytes: Uint8List.fromList([1, 2, 3]),
        nombreArchivo: 'pre_tratamiento.png',
        descripcion: 'Vista frontal',
      );

      expect(result.id, 'foto-1');
      expect(result.tratamientoId, 'trat-1');
      expect(result.tipoFotografia, TipoFotografia.pre);

      final uploaded =
          verify(() => fileApi.uploadBinary(captureAny(), any())).captured.single
              as String;
      expect(uploaded, matches(RegExp(r'^trat-1/\d+_png$')));

      final payload = verify(() => qb.insert(captureAny())).captured.single
          as Map<String, dynamic>;
      expect(payload['tratamiento_id'], 'trat-1');
      expect(payload['tipo_fotografia'], 'PRE');
      expect(payload['tipo_foto'], 'pre');
      expect(payload['archivo_url'], 'trat-1/1750000000000_png');
    });
  });

  group('fetchFotografias', () {
    test('filtra por tratamiento_id y firma las URLs de storage', () async {
      final fileApi = stubStorage('trat-1/1750000000000_png');

      final qb = MockSupabaseQueryBuilder();
      final fb = MockPostgrestFilterBuilder<PostgrestList>();
      when(() => client.from('fotografias_tratamiento')).thenAnswer((_) => qb);
      when(() => qb.select()).thenAnswer((_) => fb);
      when(() => fb.eq('tratamiento_id', 'trat-1')).thenAnswer((_) => fb);
      when(() => fb.order('fecha_captura', ascending: false))
          .thenAnswer((_) => _FakeTransformBuilder<PostgrestList>([fotoRow]));

      final result = await dataSource.fetchFotografias('trat-1');

      expect(result, hasLength(1));
      expect(result.single.id, 'foto-1');
      expect(result.single.tratamientoId, 'trat-1');
      expect(result.single.archivoUrl, 'https://signed/foto.png');
      verify(() => fb.eq('tratamiento_id', 'trat-1')).called(1);
      verify(() => fileApi.createSignedUrl('trat-1/1750000000000_png', 3600))
          .called(1);
    });

    test('deja intactas las URLs http existentes', () async {
      final qb = MockSupabaseQueryBuilder();
      final fb = MockPostgrestFilterBuilder<PostgrestList>();
      when(() => client.from('fotografias_tratamiento')).thenAnswer((_) => qb);
      when(() => qb.select()).thenAnswer((_) => fb);
      when(() => fb.eq('tratamiento_id', 'trat-1')).thenAnswer((_) => fb);
      when(() => fb.order('fecha_captura', ascending: false)).thenAnswer((_) => 
          _FakeTransformBuilder<PostgrestList>([
        const {
          'id': 'foto-2',
          'tratamiento_id': 'trat-1',
          'tipo_fotografia': 'POST',
          'archivo_url': 'https://cdn.example.com/foto.png',
          'fecha_captura': '2026-08-25T10:00:00.000',
          'created_at': '2026-08-25T10:00:00.000',
          'tipo_foto': 'post',
        }
      ]));

      final result = await dataSource.fetchFotografias('trat-1');

      expect(result.single.archivoUrl, 'https://cdn.example.com/foto.png');
    });
  });
}