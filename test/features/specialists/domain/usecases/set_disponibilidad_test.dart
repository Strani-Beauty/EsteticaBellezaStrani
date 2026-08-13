import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/entities/disponibilidad_entity.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/usecases/set_disponibilidad.dart';
import '../../mock_repository.dart';

void main() {
  late MockISpecialistsRepository repository;

  setUpAll(() {
    registerFallbackValue(EstadoDisponibilidad.disponible);
  });

  setUp(() {
    repository = MockISpecialistsRepository();
  });

  final disponibilidad = DisponibilidadEntity(
    id: 'disp-1',
    especialistaId: 'esp-1',
    estado: EstadoDisponibilidad.disponible,
    createdAt: DateTime(2026, 8, 13),
  );

  group('SetDisponibilidad', () {
    late SetDisponibilidad usecase;

    setUp(() {
      usecase = SetDisponibilidad(repository);
    });

    test('fija la disponibilidad y retorna la entidad', () async {
      when(() => repository.setDisponibilidad(
            any(),
            any(),
            fechaInicio: any(named: 'fechaInicio'),
            fechaFin: any(named: 'fechaFin'),
          )).thenAnswer((_) async => Right(disponibilidad));

      final result = await usecase(const SetDisponibilidadParams(
        especialistaId: 'esp-1',
        estado: EstadoDisponibilidad.disponible,
      ));

      expect(result, Right(disponibilidad));
    });

    test('retorna Failure cuando el repo falla', () async {
      when(() => repository.setDisponibilidad(
            any(),
            any(),
            fechaInicio: any(named: 'fechaInicio'),
            fechaFin: any(named: 'fechaFin'),
          )).thenAnswer((_) async => const Left(ServerFailure('error')));

      final result = await usecase(const SetDisponibilidadParams(
        especialistaId: 'esp-1',
        estado: EstadoDisponibilidad.ocupado,
      ));

      expect(result, const Left(ServerFailure('error')));
    });
  });

  group('UpsertDisponibilidad', () {
    late UpsertDisponibilidad usecase;

    setUp(() {
      usecase = UpsertDisponibilidad(repository);
    });

    test('hace upsert de la disponibilidad y retorna la entidad', () async {
      when(() => repository.upsertDisponibilidad(
            any(),
            any(),
            fechaInicio: any(named: 'fechaInicio'),
            fechaFin: any(named: 'fechaFin'),
          )).thenAnswer((_) async => Right(disponibilidad));

      final result = await usecase(const SetDisponibilidadParams(
        especialistaId: 'esp-1',
        estado: EstadoDisponibilidad.noDisponible,
      ));

      expect(result, Right(disponibilidad));
      verify(() => repository.upsertDisponibilidad(
            'esp-1',
            EstadoDisponibilidad.noDisponible,
            fechaInicio: null,
            fechaFin: null,
          )).called(1);
    });

    test('retorna Failure cuando el repo falla', () async {
      when(() => repository.upsertDisponibilidad(
            any(),
            any(),
            fechaInicio: any(named: 'fechaInicio'),
            fechaFin: any(named: 'fechaFin'),
          )).thenAnswer((_) async => const Left(ServerFailure('error')));

      final result = await usecase(const SetDisponibilidadParams(
        especialistaId: 'esp-1',
        estado: EstadoDisponibilidad.disponible,
      ));

      expect(result, const Left(ServerFailure('error')));
    });
  });
}
