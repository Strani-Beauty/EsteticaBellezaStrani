import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:esteticaybellezastrani/app/config/app_constants.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/data/datasources/treatment_execution_supabase_datasource.dart';

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
  late TreatmentExecutionSupabaseDataSource dataSource;

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    client = MockSupabaseClient();
    dataSource = TreatmentExecutionSupabaseDataSource(client);
  });

  const citaRow = <String, dynamic>{
    'id': 'cita-1',
    'especialista_id': 'esp-1',
    'solicitudes': <String, dynamic>{'paciente_id': 'pac-1'},
  };

  const tratamientoRow = <String, dynamic>{
    'id': 'trat-1',
    'cita_id': 'cita-1',
    'paciente_id': 'pac-1',
    'especialista_id': 'esp-1',
    'estado': 'PENDIENTE_FIRMA',
    'fecha_inicio': '2026-08-25T10:00:00.000',
    'created_at': '2026-08-25T10:00:00.000',
    'updated_at': '2026-08-25T10:00:00.000',
  };

  void stubCitaLectura() {
    final qbCitas = MockSupabaseQueryBuilder();
    final fbCitas = MockPostgrestFilterBuilder<PostgrestList>();
    when(() => client.from('citas')).thenAnswer((_) => qbCitas);
    when(() => qbCitas.select('id, especialista_id, solicitudes(paciente_id)'))
        .thenAnswer((_) => fbCitas);
    when(() => fbCitas.eq('id', 'cita-1')).thenAnswer((_) => fbCitas);
    when(() => fbCitas.maybeSingle())
        .thenAnswer((_) => _FakeTransformBuilder<PostgrestMap?>(citaRow));
  }

  group('asegurarTratamiento', () {
    test('crea un tratamiento en PENDIENTE_FIRMA vinculado a la cita cuando no existe', () async {
      stubCitaLectura();

      final qbTrat = MockSupabaseQueryBuilder();
      final fbTrat = MockPostgrestFilterBuilder<PostgrestList>();
      final fbInsert = MockPostgrestFilterBuilder<PostgrestMap>();
      when(() => client.from('tratamientos')).thenAnswer((_) => qbTrat);
      when(() => qbTrat.select()).thenAnswer((_) => fbTrat);
      when(() => fbTrat.eq('cita_id', 'cita-1')).thenAnswer((_) => fbTrat);
      when(() => fbTrat.maybeSingle())
          .thenAnswer((_) => _FakeTransformBuilder<PostgrestMap?>(null));
      when(() => qbTrat.insert(captureAny())).thenAnswer((_) => fbInsert);
      final fbSelect = _FakeTransformBuilder<PostgrestList>(const []);
      when(() => fbInsert.select()).thenAnswer((_) => fbSelect);
      when(() => fbSelect.maybeSingle())
          .thenAnswer((_) => _FakeTransformBuilder<PostgrestMap?>(tratamientoRow));

      final result = await dataSource.asegurarTratamiento(citaId: 'cita-1');

      expect(result.id, 'trat-1');
      expect(result.citaId, 'cita-1');
      expect(result.pacienteId, 'pac-1');
      expect(result.especialistaId, 'esp-1');
      expect(result.estado, AppConstants.tratamientoPendienteFirma);

      final payload = verify(() => qbTrat.insert(captureAny())).captured.single
          as Map<String, dynamic>;
      expect(payload['cita_id'], 'cita-1');
      expect(payload['paciente_id'], 'pac-1');
      expect(payload['especialista_id'], 'esp-1');
      expect(payload['estado'], AppConstants.tratamientoPendienteFirma);
    });

    test('devuelve el tratamiento existente sin volver a insertar', () async {
      stubCitaLectura();

      final qbTrat = MockSupabaseQueryBuilder();
      final fbTrat = MockPostgrestFilterBuilder<PostgrestList>();
      when(() => client.from('tratamientos')).thenAnswer((_) => qbTrat);
      when(() => qbTrat.select()).thenAnswer((_) => fbTrat);
      when(() => fbTrat.eq('cita_id', 'cita-1')).thenAnswer((_) => fbTrat);
      when(() => fbTrat.maybeSingle())
          .thenAnswer((_) => _FakeTransformBuilder<PostgrestMap?>(tratamientoRow));

      final result = await dataSource.asegurarTratamiento(citaId: 'cita-1');

      expect(result.id, 'trat-1');
      expect(result.citaId, 'cita-1');
      expect(result.estado, AppConstants.tratamientoPendienteFirma);
      verifyNever(() => qbTrat.insert(any()));
    });
  });

  group('subirFirma', () {
    test('sube la firma al bucket firmas-consentimiento con el path del tratamiento', () async {
      final storageMock = MockSupabaseStorageClient();
      final fileApi = MockStorageFileApi();
      when(() => client.storage).thenAnswer((_) => storageMock);
      when(() => storageMock.from(AppConstants.bucketFirmas))
          .thenAnswer((_) => fileApi);
      when(() => fileApi.uploadBinary(any(), any()))
          .thenAnswer((_) async => 'path-de-retorno');

      final bytes = Uint8List.fromList([1, 2, 3]);
      final path = await dataSource.subirFirma(tratamientoId: 'trat-1', bytes: bytes);

      expect(path, matches(RegExp(r'^trat-1/firma_\d+\.png$')));

      final uploaded = verify(() => fileApi.uploadBinary(captureAny(), any()))
          .captured
          .single as String;
      expect(uploaded, matches(RegExp(r'^trat-1/firma_\d+\.png$')));
    });
  });
}