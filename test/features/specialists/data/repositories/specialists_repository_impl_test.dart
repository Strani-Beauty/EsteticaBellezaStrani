import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/features/specialists/data/datasources/specialists_supabase_datasource.dart';
import 'package:esteticaybellezastrani/features/specialists/data/models/especialista_model.dart';
import 'package:esteticaybellezastrani/features/specialists/data/models/ubicacion_especialista_model.dart';
import 'package:esteticaybellezastrani/features/specialists/data/repositories/specialists_repository_impl.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/entities/especialista_entity.dart';

class MockSpecialistsDataSource extends Mock
    implements SpecialistsSupabaseDataSource {}

void main() {
  late SpecialistsRepositoryImpl repository;
  late MockSpecialistsDataSource dataSource;

  setUp(() {
    dataSource = MockSpecialistsDataSource();
    repository = SpecialistsRepositoryImpl(dataSource);
  });

  final especialistaModel = EspecialistaModel(
    id: 'esp-1',
    usuarioId: 'user-1',
    numeroLicencia: 'LIC-123',
    estadoVerificacion: EstadoVerificacion.pendiente,
    disponible: false,
    activo: false,
    createdAt: DateTime(2026, 8, 13),
  );

  group('getEspecialistaByUsuarioId', () {
    test('retorna Right(entity) cuando el datasource devuelve un modelo', () async {
      when(() => dataSource.fetchEspecialistaByUsuarioId(any()))
          .thenAnswer((_) async => especialistaModel);

      final result = await repository.getEspecialistaByUsuarioId('user-1');

      expect(result, Right(especialistaModel.toEntity()));
    });

    test('retorna Right(null) cuando no existe el especialista', () async {
      when(() => dataSource.fetchEspecialistaByUsuarioId(any()))
          .thenAnswer((_) async => null);

      final result = await repository.getEspecialistaByUsuarioId('user-x');

      expect(result, const Right(null));
    });

    test('retorna Left(ServerFailure) cuando el datasource lanza excepción', () async {
      when(() => dataSource.fetchEspecialistaByUsuarioId(any()))
          .thenThrow(Exception('boom'));

      final result = await repository.getEspecialistaByUsuarioId('user-1');

      expect(result, isA<Left<Failure, EspecialistaEntity?>>());
    });
  });

  group('createEspecialista', () {
    test('retorna Right(entity) cuando el datasource tiene éxito', () async {
      when(() => dataSource.createEspecialista(
            usuarioId: any(named: 'usuarioId'),
            numeroLicencia: any(named: 'numeroLicencia'),
            medicoRegenteId: any(named: 'medicoRegenteId'),
          )).thenAnswer((_) async => especialistaModel);

      final result = await repository.createEspecialista(
        usuarioId: 'user-1',
        numeroLicencia: 'LIC-123',
      );

      expect(result, Right(especialistaModel.toEntity()));
    });

    test('retorna Left(ServerFailure) cuando el datasource falla', () async {
      when(() => dataSource.createEspecialista(
            usuarioId: any(named: 'usuarioId'),
            numeroLicencia: any(named: 'numeroLicencia'),
            medicoRegenteId: any(named: 'medicoRegenteId'),
          )).thenThrow(Exception('insert fallido'));

      final result = await repository.createEspecialista(usuarioId: 'user-1');

      expect(result.isLeft(), isTrue);
    });
  });

  group('marcarPresencia', () {
    test('retorna Right(null) cuando el datasource completa sin error', () async {
      when(() => dataSource.marcarPresencia(any(), enLinea: any(named: 'enLinea')))
          .thenAnswer((_) async {});

      final result = await repository.marcarPresencia('esp-1', enLinea: true);

      expect(result, const Right(null));
    });
  });

  group('saveUbicacion', () {
    final ubicacionModel = UbicacionEspecialistaModel(
      id: 'ubi-1',
      especialistaId: 'esp-1',
      latitud: 29.7604,
      longitud: -95.3698,
      precisionMetros: 10,
      createdAt: DateTime(2026, 8, 13),
    );

    test('retorna Right(entity) cuando el datasource guarda con éxito', () async {
      when(() => dataSource.saveUbicacion(
            any(),
            latitud: any(named: 'latitud'),
            longitud: any(named: 'longitud'),
            precisionMetros: any(named: 'precisionMetros'),
          )).thenAnswer((_) async => ubicacionModel);

      final result = await repository.saveUbicacion(
        'esp-1',
        latitud: 29.7604,
        longitud: -95.3698,
        precisionMetros: 10,
      );

      expect(result, Right(ubicacionModel.toEntity()));
    });

    test('retorna Left(ServerFailure) cuando el datasource falla', () async {
      when(() => dataSource.saveUbicacion(
            any(),
            latitud: any(named: 'latitud'),
            longitud: any(named: 'longitud'),
            precisionMetros: any(named: 'precisionMetros'),
          )).thenThrow(Exception('ubicacion fallida'));

      final result = await repository.saveUbicacion(
        'esp-1',
        latitud: 29.7604,
        longitud: -95.3698,
      );

      expect(result.isLeft(), isTrue);
    });
  });
}
