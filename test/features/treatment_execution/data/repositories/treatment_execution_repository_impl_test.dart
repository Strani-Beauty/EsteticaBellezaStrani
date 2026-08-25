import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/data/datasources/treatment_execution_supabase_datasource.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/data/models/cita_ejecucion_model.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/data/models/consentimiento_model.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/data/models/face_map_especialista_model.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/data/models/producto_aplicado_model.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/data/models/tratamiento_model.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/data/repositories/treatment_execution_repository_impl.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/entities/cita_ejecucion_entity.dart';

class MockTreatmentExecutionDataSource extends Mock
    implements TreatmentExecutionSupabaseDataSource {}

void main() {
  late TreatmentExecutionRepositoryImpl repository;
  late MockTreatmentExecutionDataSource dataSource;

  final tratamientoModel = TratamientoModel(
    id: 'trat-1',
    citaId: 'cita-1',
    pacienteId: 'pac-1',
    especialistaId: 'esp-1',
    estado: 'EN_PROCESO',
    evaluacionInicial: 'Anamnesis ok',
    createdAt: '2026-08-25T10:00:00.000',
  );
  final citaModel = CitaEjecucionModel(
    id: 'cita-1',
    estado: 'EN_PROCESO',
    solicitudId: 'sol-1',
    pacienteNombre: 'María Pérez',
    servicioNombre: 'Botox',
    tratamiento: tratamientoModel,
  );
  final consentimientoModel = ConsentimientoModel(
    id: 'cons-1',
    tratamientoId: 'trat-1',
    pacienteId: 'pac-1',
    tipoConsentimiento: 'TRATAMIENTO_ESTETICO',
    firmaUrl: 'trat-1/firma_123.png',
    createdAt: '2026-08-25T10:00:00.000',
  );
  final productoModel = ProductoAplicadoModel(
    id: 'prod-1',
    tratamientoId: 'trat-1',
    productoNombre: 'Ácido hialurónico',
    cantidadTotal: 2,
    unidadMedida: 'jeringas',
    createdAt: '2026-08-25T10:00:00.000',
  );
  final faceMapModel = FaceMapEspecialistaModel(
    id: 'fm-1',
    tratamientoId: 'trat-1',
    pacienteId: 'pac-1',
    tipoMapa: 'ROSTRO',
    observaciones: 'notas clínicas',
    puntos: const [
      {'punto_id': 'p1', 'zona_anatomica': 'pómulos'},
    ],
  );

  setUp(() {
    dataSource = MockTreatmentExecutionDataSource();
    repository = TreatmentExecutionRepositoryImpl(dataSource);
  });

  group('getMisCitas', () {
    test('retorna las citas activas del especialista', () async {
      when(() => dataSource.fetchMisCitas('esp-1'))
          .thenAnswer((_) async => [citaModel]);

      final result = await repository.getMisCitas('esp-1');

      expect(result.getRight().toNullable(), [citaModel.toEntity()]);
      verify(() => dataSource.fetchMisCitas('esp-1')).called(1);
    });

    test('degradado a ServerFailure cuando el datasource falla', () async {
      when(() => dataSource.fetchMisCitas('esp-1'))
          .thenThrow(Exception('boom'));

      final result = await repository.getMisCitas('esp-1');

      expect(result.isLeft(), isTrue);
    });
  });

  group('getCitasHistorial', () {
    test('retorna el historial de citas del especialista', () async {
      when(() => dataSource.fetchCitasHistorial('esp-1'))
          .thenAnswer((_) async => [citaModel]);

      final result = await repository.getCitasHistorial('esp-1');

      expect(result.getRight().toNullable(), [citaModel.toEntity()]);
      verify(() => dataSource.fetchCitasHistorial('esp-1')).called(1);
    });

    test('degradado a ServerFailure cuando el datasource falla', () async {
      when(() => dataSource.fetchCitasHistorial('esp-1'))
          .thenThrow(Exception('boom'));

      final result = await repository.getCitasHistorial('esp-1');

      expect(result.isLeft(), isTrue);
    });
  });

  group('getCitaDetalle', () {
    test('retorna el detalle de la cita con su tratamiento', () async {
      when(() => dataSource.fetchCitaDetalle('cita-1'))
          .thenAnswer((_) async => citaModel);

      final result = await repository.getCitaDetalle('cita-1');

      expect(result.getRight().toNullable(), citaModel.toEntity());
      verify(() => dataSource.fetchCitaDetalle('cita-1')).called(1);
    });

    test('degradado a ServerFailure cuando el datasource falla', () async {
      when(() => dataSource.fetchCitaDetalle('cita-1'))
          .thenThrow(Exception('boom'));

      final result = await repository.getCitaDetalle('cita-1');

      expect(result.isLeft(), isTrue);
    });
  });

  group('getProductos', () {
    test('retorna los insumos registrados del tratamiento', () async {
      when(() => dataSource.fetchProductos('trat-1'))
          .thenAnswer((_) async => [productoModel]);

      final result = await repository.getProductos('trat-1');

      expect(result.getRight().toNullable(), [productoModel.toEntity()]);
      verify(() => dataSource.fetchProductos('trat-1')).called(1);
    });

    test('degradado a ServerFailure cuando el datasource falla', () async {
      when(() => dataSource.fetchProductos('trat-1'))
          .thenThrow(Exception('boom'));

      final result = await repository.getProductos('trat-1');

      expect(result.isLeft(), isTrue);
    });
  });

  group('getConsentimiento', () {
    test('retorna el consentimiento del tratamiento', () async {
      when(() => dataSource.fetchConsentimiento('trat-1'))
          .thenAnswer((_) async => consentimientoModel);

      final result = await repository.getConsentimiento('trat-1');

      expect(result.getRight().toNullable(), consentimientoModel.toEntity());
      verify(() => dataSource.fetchConsentimiento('trat-1')).called(1);
    });

    test('retorna Right(null) cuando aún no hay consentimiento', () async {
      when(() => dataSource.fetchConsentimiento('trat-1'))
          .thenAnswer((_) async => null);

      final result = await repository.getConsentimiento('trat-1');

      expect(result.getRight().toNullable(), isNull);
    });

    test('degradado a ServerFailure cuando el datasource falla', () async {
      when(() => dataSource.fetchConsentimiento('trat-1'))
          .thenThrow(Exception('boom'));

      final result = await repository.getConsentimiento('trat-1');

      expect(result.isLeft(), isTrue);
    });
  });

  group('avanzarEstadoCita', () {
    test('avanza el estado y recarga el detalle', () async {
      when(() => dataSource.actualizarEstadoCita(
        citaId: 'cita-1',
        nuevoEstado: 'EN_PROCESO',
        observaciones: null,
      )).thenAnswer((_) async {});
      when(() => dataSource.fetchCitaDetalle('cita-1'))
          .thenAnswer((_) async => citaModel);

      final result = await repository.avanzarEstadoCita(
        citaId: 'cita-1',
        nuevoEstado: EstadoCitaEjecucion.enProceso,
      );

      expect(result.getRight().toNullable(), citaModel.toEntity());
      verify(() => dataSource.actualizarEstadoCita(
        citaId: 'cita-1',
        nuevoEstado: 'EN_PROCESO',
        observaciones: null,
      )).called(1);
      verify(() => dataSource.fetchCitaDetalle('cita-1')).called(1);
    });

    test('degradado a ServerFailure cuando el datasource falla', () async {
      when(() => dataSource.actualizarEstadoCita(
        citaId: 'cita-1',
        nuevoEstado: 'EN_PROCESO',
        observaciones: null,
      )).thenThrow(Exception('boom'));

      final result = await repository.avanzarEstadoCita(
        citaId: 'cita-1',
        nuevoEstado: EstadoCitaEjecucion.enProceso,
      );

      expect(result.isLeft(), isTrue);
    });
  });

  group('iniciarTratamiento', () {
    test('asegura y retorna el tratamiento creado desde la cita', () async {
      when(() => dataSource.asegurarTratamiento(
        citaId: 'cita-1',
        evaluacionInicial: null,
      )).thenAnswer((_) async => tratamientoModel);

      final result = await repository.iniciarTratamiento(citaId: 'cita-1');

      expect(result.getRight().toNullable(), tratamientoModel.toEntity());
      verify(() => dataSource.asegurarTratamiento(
        citaId: 'cita-1',
        evaluacionInicial: null,
      )).called(1);
    });

    test('degradado a ServerFailure cuando el datasource falla', () async {
      when(() => dataSource.asegurarTratamiento(
        citaId: 'cita-1',
        evaluacionInicial: null,
      )).thenThrow(Exception('boom'));

      final result = await repository.iniciarTratamiento(citaId: 'cita-1');

      expect(result.isLeft(), isTrue);
    });
  });

  group('actualizarTratamiento', () {
    test('actualiza los campos del tratamiento', () async {
      when(() => dataSource.actualizarTratamiento(
        tratamientoId: 'trat-1',
        evaluacionInicial: 'Anamnesis ok',
        observacionesFinales: null,
        recomendacionesPostTratamiento: null,
        estado: 'COMPLETADO',
      )).thenAnswer((_) async => tratamientoModel);

      final result = await repository.actualizarTratamiento(
        tratamientoId: 'trat-1',
        evaluacionInicial: 'Anamnesis ok',
        estado: 'COMPLETADO',
      );

      expect(result.getRight().toNullable(), tratamientoModel.toEntity());
      verify(() => dataSource.actualizarTratamiento(
        tratamientoId: 'trat-1',
        evaluacionInicial: 'Anamnesis ok',
        observacionesFinales: null,
        recomendacionesPostTratamiento: null,
        estado: 'COMPLETADO',
      )).called(1);
    });

    test('degradado a ServerFailure cuando el datasource falla', () async {
      when(() => dataSource.actualizarTratamiento(
        tratamientoId: 'trat-1',
        evaluacionInicial: null,
        observacionesFinales: null,
        recomendacionesPostTratamiento: null,
        estado: null,
      )).thenThrow(Exception('boom'));

      final result = await repository.actualizarTratamiento(
        tratamientoId: 'trat-1',
      );

      expect(result.isLeft(), isTrue);
    });
  });

  group('agregarProducto', () {
    test('inserta el producto con cantidad y unidad', () async {
      when(() => dataSource.insertarProducto(
        tratamientoId: 'trat-1',
        productoNombre: 'Botox',
        fabricante: null,
        lote: null,
        cantidadTotal: 1,
        unidadMedida: 'jeringas',
        fechaVencimiento: null,
        observaciones: null,
      )).thenAnswer((_) async => productoModel);

      final result = await repository.agregarProducto(
        tratamientoId: 'trat-1',
        productoNombre: 'Botox',
        cantidadTotal: 1,
        unidadMedida: 'jeringas',
      );

      expect(result.getRight().toNullable(), productoModel.toEntity());
      verify(() => dataSource.insertarProducto(
        tratamientoId: 'trat-1',
        productoNombre: 'Botox',
        fabricante: null,
        lote: null,
        cantidadTotal: 1,
        unidadMedida: 'jeringas',
        fechaVencimiento: null,
        observaciones: null,
      )).called(1);
    });

    test('degradado a ServerFailure cuando el datasource falla', () async {
      when(() => dataSource.insertarProducto(
        tratamientoId: 'trat-1',
        productoNombre: 'Botox',
        fabricante: null,
        lote: null,
        cantidadTotal: 1,
        unidadMedida: null,
        fechaVencimiento: null,
        observaciones: null,
      )).thenThrow(Exception('boom'));

      final result = await repository.agregarProducto(
        tratamientoId: 'trat-1',
        productoNombre: 'Botox',
        cantidadTotal: 1,
      );

      expect(result.isLeft(), isTrue);
    });
  });

  group('eliminarProducto', () {
    test('elimina el producto y retorna Right(null)', () async {
      when(() => dataSource.eliminarProducto('prod-1'))
          .thenAnswer((_) async {});

      final result = await repository.eliminarProducto('prod-1');

      expect(result, const Right(null));
      verify(() => dataSource.eliminarProducto('prod-1')).called(1);
    });

    test('degradado a ServerFailure cuando el datasource falla', () async {
      when(() => dataSource.eliminarProducto('prod-1'))
          .thenThrow(Exception('boom'));

      final result = await repository.eliminarProducto('prod-1');

      expect(result.isLeft(), isTrue);
    });
  });

  group('registrarConsentimiento', () {
    test('registra el consentimiento con la firma', () async {
      when(() => dataSource.insertarConsentimiento(
        tratamientoId: 'trat-1',
        pacienteId: 'pac-1',
        tipoConsentimiento: 'TRATAMIENTO_ESTETICO',
        firmaUrl: 'trat-1/firma_123.png',
      )).thenAnswer((_) async => consentimientoModel);

      final result = await repository.registrarConsentimiento(
        tratamientoId: 'trat-1',
        pacienteId: 'pac-1',
        tipoConsentimiento: 'TRATAMIENTO_ESTETICO',
        firmaUrl: 'trat-1/firma_123.png',
      );

      expect(result.getRight().toNullable(), consentimientoModel.toEntity());
      verify(() => dataSource.insertarConsentimiento(
        tratamientoId: 'trat-1',
        pacienteId: 'pac-1',
        tipoConsentimiento: 'TRATAMIENTO_ESTETICO',
        firmaUrl: 'trat-1/firma_123.png',
      )).called(1);
    });

    test('degradado a ServerFailure cuando el datasource falla', () async {
      when(() => dataSource.insertarConsentimiento(
        tratamientoId: 'trat-1',
        pacienteId: 'pac-1',
        tipoConsentimiento: 'TRATAMIENTO_ESTETICO',
        firmaUrl: 'trat-1/firma_123.png',
      )).thenThrow(Exception('boom'));

      final result = await repository.registrarConsentimiento(
        tratamientoId: 'trat-1',
        pacienteId: 'pac-1',
        tipoConsentimiento: 'TRATAMIENTO_ESTETICO',
        firmaUrl: 'trat-1/firma_123.png',
      );

      expect(result.isLeft(), isTrue);
    });
  });

  group('subirFirma', () {
    test('sube la firma y retorna el path de storage', () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      when(() => dataSource.subirFirma(
        tratamientoId: 'trat-1',
        bytes: bytes,
      )).thenAnswer((_) async => 'trat-1/firma_123.png');

      final result = await repository.subirFirma(
        tratamientoId: 'trat-1',
        bytes: bytes,
      );

      expect(result, const Right('trat-1/firma_123.png'));
      verify(() => dataSource.subirFirma(
        tratamientoId: 'trat-1',
        bytes: bytes,
      )).called(1);
    });

    test('degradado a ServerFailure cuando el datasource falla', () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      when(() => dataSource.subirFirma(
        tratamientoId: 'trat-1',
        bytes: bytes,
      )).thenThrow(Exception('boom'));

      final result = await repository.subirFirma(
        tratamientoId: 'trat-1',
        bytes: bytes,
      );

      expect(result.isLeft(), isTrue);
    });
  });

  group('finalizarTratamiento', () {
    test('finaliza el tratamiento y la cita, retorna Right(null)', () async {
      when(() => dataSource.finalizarTratamiento(
        citaId: 'cita-1',
        tratamientoId: 'trat-1',
        observacionesFinales: 'Todo bien',
        recomendacionesPostTratamiento: null,
      )).thenAnswer((_) async {});

      final result = await repository.finalizarTratamiento(
        citaId: 'cita-1',
        tratamientoId: 'trat-1',
        observacionesFinales: 'Todo bien',
      );

      expect(result, const Right(null));
      verify(() => dataSource.finalizarTratamiento(
        citaId: 'cita-1',
        tratamientoId: 'trat-1',
        observacionesFinales: 'Todo bien',
        recomendacionesPostTratamiento: null,
      )).called(1);
    });

    test('degradado a ServerFailure cuando el datasource falla', () async {
      when(() => dataSource.finalizarTratamiento(
        citaId: 'cita-1',
        tratamientoId: 'trat-1',
        observacionesFinales: null,
        recomendacionesPostTratamiento: null,
      )).thenThrow(Exception('boom'));

      final result = await repository.finalizarTratamiento(
        citaId: 'cita-1',
        tratamientoId: 'trat-1',
      );

      expect(result.isLeft(), isTrue);
    });
  });

  group('registrarLlegada', () {
    test('registra la llegada y retorna la distancia en metros', () async {
      when(() => dataSource.registrarLlegada(
        citaId: 'cita-1',
        latitud: 19.4,
        longitud: -99.1,
      )).thenAnswer((_) async => 350.5);

      final result = await repository.registrarLlegada(
        citaId: 'cita-1',
        latitud: 19.4,
        longitud: -99.1,
      );

      expect(result, const Right(350.5));
      verify(() => dataSource.registrarLlegada(
        citaId: 'cita-1',
        latitud: 19.4,
        longitud: -99.1,
      )).called(1);
    });

    test('degradado a ServerFailure cuando el datasource falla', () async {
      when(() => dataSource.registrarLlegada(
        citaId: 'cita-1',
        latitud: 19.4,
        longitud: -99.1,
      )).thenThrow(Exception('boom'));

      final result = await repository.registrarLlegada(
        citaId: 'cita-1',
        latitud: 19.4,
        longitud: -99.1,
      );

      expect(result.isLeft(), isTrue);
    });
  });

  group('cancelarCita', () {
    test('cancela la cita y retorna Right(null)', () async {
      when(() => dataSource.cancelarCita(
        citaId: 'cita-1',
        motivo: 'El paciente canceló',
      )).thenAnswer((_) async {});

      final result = await repository.cancelarCita(
        citaId: 'cita-1',
        motivo: 'El paciente canceló',
      );

      expect(result, const Right(null));
      verify(() => dataSource.cancelarCita(
        citaId: 'cita-1',
        motivo: 'El paciente canceló',
      )).called(1);
    });

    test('degradado a ServerFailure cuando el datasource falla', () async {
      when(() => dataSource.cancelarCita(
        citaId: 'cita-1',
        motivo: null,
      )).thenThrow(Exception('boom'));

      final result = await repository.cancelarCita(citaId: 'cita-1');

      expect(result.isLeft(), isTrue);
    });
  });

  group('getFaceMapPorTratamiento', () {
    test('retorna el face map vinculado al tratamiento', () async {
      when(() => dataSource.fetchFaceMapPorTratamiento('trat-1'))
          .thenAnswer((_) async => faceMapModel);

      final result = await repository.getFaceMapPorTratamiento('trat-1');

      expect(result.getRight().toNullable(), faceMapModel.toEntity());
      verify(() => dataSource.fetchFaceMapPorTratamiento('trat-1')).called(1);
    });

    test('retorna Right(null) cuando no existe face map', () async {
      when(() => dataSource.fetchFaceMapPorTratamiento('trat-1'))
          .thenAnswer((_) async => null);

      final result = await repository.getFaceMapPorTratamiento('trat-1');

      expect(result.getRight().toNullable(), isNull);
    });

    test('degradado a ServerFailure cuando el datasource falla', () async {
      when(() => dataSource.fetchFaceMapPorTratamiento('trat-1'))
          .thenThrow(Exception('boom'));

      final result = await repository.getFaceMapPorTratamiento('trat-1');

      expect(result.isLeft(), isTrue);
    });
  });

  group('guardarFaceMapPorTratamiento', () {
    test('guarda el face map del tratamiento, retorna Right(null)', () async {
      when(() => dataSource.guardarFaceMapPorTratamiento(
        tratamientoId: 'trat-1',
        pacienteId: 'pac-1',
        puntos: const [
          {'punto_id': 'p1'},
        ],
        observaciones: 'notas',
      )).thenAnswer((_) async {});

      final result = await repository.guardarFaceMapPorTratamiento(
        tratamientoId: 'trat-1',
        pacienteId: 'pac-1',
        puntos: const [
          {'punto_id': 'p1'},
        ],
        observaciones: 'notas',
      );

      expect(result, const Right(null));
      verify(() => dataSource.guardarFaceMapPorTratamiento(
        tratamientoId: 'trat-1',
        pacienteId: 'pac-1',
        puntos: const [
          {'punto_id': 'p1'},
        ],
        observaciones: 'notas',
      )).called(1);
    });

    test('degradado a ServerFailure cuando el datasource falla', () async {
      when(() => dataSource.guardarFaceMapPorTratamiento(
        tratamientoId: 'trat-1',
        pacienteId: 'pac-1',
        puntos: const [],
        observaciones: null,
      )).thenThrow(Exception('boom'));

      final result = await repository.guardarFaceMapPorTratamiento(
        tratamientoId: 'trat-1',
        pacienteId: 'pac-1',
        puntos: const [],
      );

      expect(result.isLeft(), isTrue);
    });
  });
}