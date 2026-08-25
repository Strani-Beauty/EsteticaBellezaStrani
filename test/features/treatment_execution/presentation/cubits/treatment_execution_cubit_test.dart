import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/entities/cita_ejecucion_entity.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/entities/consentimiento_tratamiento_entity.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/entities/face_map_especialista_entity.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/entities/producto_aplicado_entity.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/entities/tratamiento_entity.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/usecases/actualizar_tratamiento.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/usecases/agregar_producto.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/usecases/avanzar_estado_cita.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/usecases/cancelar_cita.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/usecases/eliminar_producto.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/usecases/finalizar_tratamiento.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/usecases/get_cita_detalle.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/usecases/get_citas_historial.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/usecases/get_consentimiento.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/usecases/get_face_map_por_tratamiento.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/usecases/get_mis_citas.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/usecases/get_productos.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/usecases/guardar_face_map_por_tratamiento.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/usecases/iniciar_tratamiento.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/usecases/registrar_consentimiento.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/usecases/registrar_llegada.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/usecases/subir_firma.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/presentation/cubits/treatment_execution_cubit.dart';
import 'package:esteticaybellezastrani/features/treatment_photos/domain/entities/fotografia_tratamiento_entity.dart';
import 'package:esteticaybellezastrani/features/treatment_photos/domain/usecases/get_fotografias.dart';
import '../../mock_repository.dart';

TreatmentExecutionCubit _buildCubit(
  MockITreatmentExecutionRepository repo,
  MockITreatmentPhotosRepository photosRepo,
) {
  return TreatmentExecutionCubit(
    getMisCitas: GetMisCitas(repo),
    getCitaDetalle: GetCitaDetalle(repo),
    getProductos: GetProductos(repo),
    getConsentimiento: GetConsentimiento(repo),
    avanzarEstadoCita: AvanzarEstadoCita(repo),
    iniciarTratamiento: IniciarTratamiento(repo),
    actualizarTratamiento: ActualizarTratamiento(repo),
    agregarProducto: AgregarProducto(repo),
    eliminarProducto: EliminarProducto(repo),
    registrarConsentimiento: RegistrarConsentimiento(repo),
    subirFirma: SubirFirma(repo),
    finalizarTratamiento: FinalizarTratamiento(repo),
    getCitasHistorial: GetCitasHistorial(repo),
    registrarLlegada: RegistrarLlegada(repo),
    cancelarCita: CancelarCita(repo),
    getFotografias: GetFotografias(photosRepo),
    getFaceMapPorTratamiento: GetFaceMapPorTratamiento(repo),
    guardarFaceMapPorTratamiento: GuardarFaceMapPorTratamiento(repo),
  );
}

void main() {
  late MockITreatmentExecutionRepository repo;
  late MockITreatmentPhotosRepository photosRepo;

  final tratamientoPendiente = TratamientoEntity(
    id: 'trat-1',
    citaId: 'cita-1',
    pacienteId: 'pac-1',
    especialistaId: 'esp-1',
    estado: EstadoTratamiento.pendienteFirma,
    createdAt: DateTime(2026, 8, 25),
  );
  final tratamientoEnProceso =
      tratamientoPendiente.copyWith(estado: EstadoTratamiento.enProceso);
  final tratamientoConEvaluacion =
      tratamientoPendiente.copyWith(evaluacionInicial: 'Anamnesis ok');
  final citaPendiente = CitaEjecucionEntity(
    id: 'cita-1',
    estado: EstadoCitaEjecucion.enProceso,
    solicitudId: 'sol-1',
    pacienteNombre: 'María Pérez',
    servicioNombre: 'Botox',
    tratamiento: tratamientoPendiente,
  );
  final citaEnProceso = citaPendiente.copyWith(tratamiento: tratamientoEnProceso);
  final citaEnCamino = CitaEjecucionEntity(
    id: 'cita-1',
    estado: EstadoCitaEjecucion.enCamino,
    solicitudId: 'sol-1',
    pacienteNombre: 'María Pérez',
    servicioNombre: 'Botox',
    tratamiento: tratamientoPendiente,
  );
  final consentimiento = ConsentimientoTratamientoEntity(
    id: 'cons-1',
    tratamientoId: 'trat-1',
    pacienteId: 'pac-1',
    tipoConsentimiento: 'TRATAMIENTO_ESTETICO',
    firmaUrl: 'trat-1/firma_1.png',
    fechaFirma: DateTime(2026, 8, 25),
    createdAt: DateTime(2026, 8, 25),
  );
  final producto = ProductoAplicadoEntity(
    id: 'prod-1',
    tratamientoId: 'trat-1',
    productoNombre: 'Ácido hialurónico',
    cantidadTotal: 2,
    unidadMedida: 'jeringas',
    createdAt: DateTime(2026, 8, 25),
  );
  final faceMap = FaceMapEspecialistaEntity(
    id: 'fm-1',
    tratamientoId: 'trat-1',
    pacienteId: 'pac-1',
    tipoMapa: 'ROSTRO',
    observaciones: 'notas clínicas',
    puntos: const [
      {'punto_id': 'p1'},
    ],
  );
  final foto = FotografiaTratamientoEntity(
    id: 'foto-1',
    tratamientoId: 'trat-1',
    tipoFotografia: TipoFotografia.pre,
    archivoUrl: 'trat-1/123.png',
    fechaCaptura: DateTime(2026, 8, 25),
    createdAt: DateTime(2026, 8, 25),
  );

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    repo = MockITreatmentExecutionRepository();
    photosRepo = MockITreatmentPhotosRepository();
  });

  group('loadCitas', () {
    blocTest<TreatmentExecutionCubit, TreatmentExecutionState>(
      'carga las citas activas del especialista',
      build: () => _buildCubit(repo, photosRepo),
      setUp: () {
        when(() => repo.getMisCitas('esp-1'))
            .thenAnswer((_) async => Right([citaPendiente]));
      },
      act: (cubit) => cubit.loadCitas(especialistaId: 'esp-1'),
      expect: () => [
        isA<TreatmentExecutionLoading>(),
        isA<TreatmentExecutionLoaded>()
            .having((s) => s.citas, 'citas', [citaPendiente]),
      ],
    );

    blocTest<TreatmentExecutionCubit, TreatmentExecutionState>(
      'emite Error cuando falla la carga',
      build: () => _buildCubit(repo, photosRepo),
      setUp: () {
        when(() => repo.getMisCitas('esp-1'))
            .thenAnswer((_) async => const Left(ServerFailure('boom')));
      },
      act: (cubit) => cubit.loadCitas(especialistaId: 'esp-1'),
      expect: () => [
        isA<TreatmentExecutionLoading>(),
        isA<TreatmentExecutionError>()
            .having((s) => s.message, 'message', 'boom'),
      ],
    );
  });

  group('loadCitasHistorial', () {
    blocTest<TreatmentExecutionCubit, TreatmentExecutionState>(
      'carga el historial de citas del especialista',
      build: () => _buildCubit(repo, photosRepo),
      setUp: () {
        when(() => repo.getCitasHistorial('esp-1'))
            .thenAnswer((_) async => Right([citaPendiente]));
      },
      act: (cubit) => cubit.loadCitasHistorial(especialistaId: 'esp-1'),
      expect: () => [
        isA<TreatmentExecutionLoading>(),
        isA<TreatmentExecutionLoaded>()
            .having((s) => s.citasHistorial, 'citasHistorial', [citaPendiente]),
      ],
    );
  });

  group('loadDetalle', () {
    blocTest<TreatmentExecutionCubit, TreatmentExecutionState>(
      'carga cita, productos, consentimiento y fotos vinculadas al tratamiento',
      build: () => _buildCubit(repo, photosRepo),
      setUp: () {
        when(() => repo.getCitaDetalle('cita-1'))
            .thenAnswer((_) async => Right(citaPendiente));
        when(() => repo.getProductos('trat-1'))
            .thenAnswer((_) async => Right([producto]));
        when(() => repo.getConsentimiento('trat-1'))
            .thenAnswer((_) async => Right(consentimiento));
        when(() => photosRepo.getFotografias('trat-1'))
            .thenAnswer((_) async => Right([foto]));
      },
      act: (cubit) => cubit.loadDetalle(citaId: 'cita-1'),
      expect: () => [
        isA<TreatmentExecutionLoading>(),
        isA<TreatmentExecutionLoaded>()
            .having((s) => s.cita, 'cita', citaPendiente)
            .having((s) => s.productos, 'productos', [producto])
            .having((s) => s.consentimiento, 'consentimiento', consentimiento)
            .having((s) => s.fotografias, 'fotografias', [foto]),
      ],
    );

    blocTest<TreatmentExecutionCubit, TreatmentExecutionState>(
      'no carga productos ni fotos si la cita aún no tiene tratamiento',
      build: () => _buildCubit(repo, photosRepo),
      setUp: () {
        const citaSinTratamiento = CitaEjecucionEntity(
          id: 'cita-1',
          estado: EstadoCitaEjecucion.enProceso,
          solicitudId: 'sol-1',
          pacienteNombre: 'María Pérez',
          servicioNombre: 'Botox',
        );
        when(() => repo.getCitaDetalle('cita-1'))
            .thenAnswer((_) async => Right(citaSinTratamiento));
      },
      act: (cubit) => cubit.loadDetalle(citaId: 'cita-1'),
      expect: () => [
        isA<TreatmentExecutionLoading>(),
        isA<TreatmentExecutionLoaded>()
            .having((s) => s.productos, 'productos', isEmpty)
            .having((s) => s.fotografias, 'fotografias', isEmpty),
      ],
      verify: (_) {
        verifyNever(() => repo.getProductos(any()));
        verifyNever(() => photosRepo.getFotografias(any()));
      },
    );

    blocTest<TreatmentExecutionCubit, TreatmentExecutionState>(
      'emite Error cuando falla el detalle',
      build: () => _buildCubit(repo, photosRepo),
      setUp: () {
        when(() => repo.getCitaDetalle('cita-1'))
            .thenAnswer((_) async => const Left(ServerFailure('boom')));
      },
      act: (cubit) => cubit.loadDetalle(citaId: 'cita-1'),
      expect: () => [
        isA<TreatmentExecutionLoading>(),
        isA<TreatmentExecutionError>()
            .having((s) => s.message, 'message', 'boom'),
      ],
    );
  });

  group('avanzar', () {
    blocTest<TreatmentExecutionCubit, TreatmentExecutionState>(
      'avanza el estado de la cita y refleja la nueva cita',
      build: () => _buildCubit(repo, photosRepo),
      seed: () => const TreatmentExecutionLoaded(cita: null),
      setUp: () {
        when(() => repo.avanzarEstadoCita(
          citaId: 'cita-1',
          nuevoEstado: EstadoCitaEjecucion.enCamino,
          observaciones: null,
        )).thenAnswer((_) async => Right(citaEnCamino));
      },
      act: (cubit) => cubit.avanzar(
        citaId: 'cita-1',
        nuevoEstado: EstadoCitaEjecucion.enCamino,
      ),
      expect: () => [
        isA<TreatmentExecutionLoaded>()
            .having((s) => s.trabajando, 'trabajando', true),
        isA<TreatmentExecutionLoaded>()
            .having((s) => s.cita?.estado, 'estado', EstadoCitaEjecucion.enCamino)
            .having((s) => s.trabajando, 'trabajando', false),
      ],
    );
  });

  group('iniciarTratamiento', () {
    blocTest<TreatmentExecutionCubit, TreatmentExecutionState>(
      'crea el tratamiento desde la cita y lo deja en PENDIENTE_FIRMA',
      build: () => _buildCubit(repo, photosRepo),
      seed: () => TreatmentExecutionLoaded(
        cita: citaPendiente.copyWith(tratamiento: null),
      ),
      setUp: () {
        when(() => repo.iniciarTratamiento(
          citaId: 'cita-1',
          evaluacionInicial: null,
        )).thenAnswer((_) async => Right(tratamientoPendiente));
        when(() => repo.getCitaDetalle('cita-1'))
            .thenAnswer((_) async => Right(citaPendiente));
      },
      act: (cubit) => cubit.iniciarTratamiento(citaId: 'cita-1'),
      expect: () => [
        isA<TreatmentExecutionLoaded>()
            .having((s) => s.trabajando, 'trabajando', true),
        isA<TreatmentExecutionLoaded>()
            .having(
              (s) => s.cita?.tratamiento?.estado,
              'estado tratamiento',
              EstadoTratamiento.pendienteFirma,
            )
            .having((s) => s.trabajando, 'trabajando', false),
      ],
      verify: (_) {
        verify(() => repo.iniciarTratamiento(
          citaId: 'cita-1',
          evaluacionInicial: null,
        )).called(1);
      },
    );

    blocTest<TreatmentExecutionCubit, TreatmentExecutionState>(
      'emite Error cuando no se puede crear el tratamiento',
      build: () => _buildCubit(repo, photosRepo),
      seed: () => TreatmentExecutionLoaded(cita: citaPendiente),
      setUp: () {
        when(() => repo.iniciarTratamiento(
          citaId: 'cita-1',
          evaluacionInicial: null,
        )).thenAnswer((_) async => const Left(ServerFailure('boom')));
      },
      act: (cubit) => cubit.iniciarTratamiento(citaId: 'cita-1'),
      expect: () => [
        isA<TreatmentExecutionLoaded>()
            .having((s) => s.trabajando, 'trabajando', true),
        isA<TreatmentExecutionError>()
            .having((s) => s.message, 'message', 'boom'),
      ],
    );
  });

  group('firmarConsulta', () {
    blocTest<TreatmentExecutionCubit, TreatmentExecutionState>(
      'sube la firma, registra el consentimiento y pasa el tratamiento a EN_PROCESO',
      build: () => _buildCubit(repo, photosRepo),
      seed: () => TreatmentExecutionLoaded(cita: citaPendiente),
      setUp: () {
        final bytes = Uint8List.fromList([1, 2, 3]);
        when(() => repo.subirFirma(
          tratamientoId: 'trat-1',
          bytes: bytes,
        )).thenAnswer((_) async => Right('trat-1/firma_1.png'));
        when(() => repo.registrarConsentimiento(
          tratamientoId: 'trat-1',
          pacienteId: 'pac-1',
          tipoConsentimiento: 'TRATAMIENTO_ESTETICO',
          firmaUrl: 'trat-1/firma_1.png',
        )).thenAnswer((_) async => Right(consentimiento));
        when(() => repo.actualizarTratamiento(
          tratamientoId: 'trat-1',
          evaluacionInicial: null,
          observacionesFinales: null,
          recomendacionesPostTratamiento: null,
          estado: 'EN_PROCESO',
        )).thenAnswer((_) async => Right(tratamientoEnProceso));
      },
      act: (cubit) => cubit.firmarConsulta(
        tratamientoId: 'trat-1',
        pacienteId: 'pac-1',
        tipoConsentimiento: 'TRATAMIENTO_ESTETICO',
        bytesFirma: Uint8List.fromList([1, 2, 3]),
      ),
      expect: () => [
        isA<TreatmentExecutionLoaded>()
            .having((s) => s.trabajando, 'trabajando', true),
        isA<TreatmentExecutionLoaded>()
            .having((s) => s.consentimiento?.firmado, 'firmado', true)
            .having(
              (s) => s.cita?.tratamiento?.estado,
              'estado tratamiento',
              EstadoTratamiento.enProceso,
            )
            .having((s) => s.trabajando, 'trabajando', false),
      ],
      verify: (_) {
        verify(() => repo.subirFirma(
          tratamientoId: 'trat-1',
          bytes: Uint8List.fromList([1, 2, 3]),
        )).called(1);
        verify(() => repo.registrarConsentimiento(
          tratamientoId: 'trat-1',
          pacienteId: 'pac-1',
          tipoConsentimiento: 'TRATAMIENTO_ESTETICO',
          firmaUrl: 'trat-1/firma_1.png',
        )).called(1);
        verify(() => repo.actualizarTratamiento(
          tratamientoId: 'trat-1',
          evaluacionInicial: null,
          observacionesFinales: null,
          recomendacionesPostTratamiento: null,
          estado: 'EN_PROCESO',
        )).called(1);
      },
    );

    blocTest<TreatmentExecutionCubit, TreatmentExecutionState>(
      'emite Error cuando falla la subida de la firma',
      build: () => _buildCubit(repo, photosRepo),
      seed: () => TreatmentExecutionLoaded(cita: citaPendiente),
      setUp: () {
        when(() => repo.subirFirma(
          tratamientoId: 'trat-1',
          bytes: any(named: 'bytes'),
        )).thenAnswer((_) async => const Left(ServerFailure('boom')));
      },
      act: (cubit) => cubit.firmarConsulta(
        tratamientoId: 'trat-1',
        pacienteId: 'pac-1',
        tipoConsentimiento: 'TRATAMIENTO_ESTETICO',
        bytesFirma: Uint8List.fromList([1, 2, 3]),
      ),
      expect: () => [
        isA<TreatmentExecutionLoaded>()
            .having((s) => s.trabajando, 'trabajando', true),
        isA<TreatmentExecutionError>()
            .having((s) => s.message, 'message', 'boom'),
        isA<TreatmentExecutionLoaded>()
            .having((s) => s.trabajando, 'trabajando', false),
      ],
    );
  });

  group('guardarEvaluacion', () {
    blocTest<TreatmentExecutionCubit, TreatmentExecutionState>(
      'guarda las notas de evaluación inicial en el tratamiento',
      build: () => _buildCubit(repo, photosRepo),
      seed: () => TreatmentExecutionLoaded(cita: citaPendiente),
      setUp: () {
        when(() => repo.actualizarTratamiento(
          tratamientoId: 'trat-1',
          evaluacionInicial: 'Anamnesis ok',
          observacionesFinales: null,
          recomendacionesPostTratamiento: null,
          estado: null,
        )).thenAnswer((_) async => Right(tratamientoConEvaluacion));
      },
      act: (cubit) => cubit.guardarEvaluacion(
        tratamientoId: 'trat-1',
        evaluacionInicial: 'Anamnesis ok',
      ),
      expect: () => [
        isA<TreatmentExecutionLoaded>().having(
          (s) => s.cita?.tratamiento?.evaluacionInicial,
          'evaluacionInicial',
          'Anamnesis ok',
        ),
      ],
    );

    blocTest<TreatmentExecutionCubit, TreatmentExecutionState>(
      'emite Error cuando falla la actualización',
      build: () => _buildCubit(repo, photosRepo),
      seed: () => TreatmentExecutionLoaded(cita: citaPendiente),
      setUp: () {
        when(() => repo.actualizarTratamiento(
          tratamientoId: 'trat-1',
          evaluacionInicial: 'Anamnesis ok',
          observacionesFinales: null,
          recomendacionesPostTratamiento: null,
          estado: null,
        )).thenAnswer((_) async => const Left(ServerFailure('boom')));
      },
      act: (cubit) => cubit.guardarEvaluacion(
        tratamientoId: 'trat-1',
        evaluacionInicial: 'Anamnesis ok',
      ),
      expect: () => [
        isA<TreatmentExecutionError>()
            .having((s) => s.message, 'message', 'boom'),
      ],
    );
  });

  group('agregarProducto', () {
    blocTest<TreatmentExecutionCubit, TreatmentExecutionState>(
      'agrega el producto con cantidad y unidad al estado',
      build: () => _buildCubit(repo, photosRepo),
      seed: () => const TreatmentExecutionLoaded(productos: []),
      setUp: () {
        when(() => repo.agregarProducto(
          tratamientoId: 'trat-1',
          productoNombre: 'Botox',
          fabricante: null,
          lote: null,
          cantidadTotal: 2,
          unidadMedida: 'jeringas',
          fechaVencimiento: null,
          observaciones: null,
        )).thenAnswer((_) async => Right(producto));
      },
      act: (cubit) => cubit.agregarProducto(
        tratamientoId: 'trat-1',
        productoNombre: 'Botox',
        cantidadTotal: 2,
        unidadMedida: 'jeringas',
      ),
      expect: () => [
        isA<TreatmentExecutionLoaded>()
            .having((s) => s.productos, 'productos', [producto]),
      ],
      verify: (_) {
        verify(() => repo.agregarProducto(
          tratamientoId: 'trat-1',
          productoNombre: 'Botox',
          fabricante: null,
          lote: null,
          cantidadTotal: 2,
          unidadMedida: 'jeringas',
          fechaVencimiento: null,
          observaciones: null,
        )).called(1);
      },
    );

    blocTest<TreatmentExecutionCubit, TreatmentExecutionState>(
      'emite Error cuando falla el registro del producto',
      build: () => _buildCubit(repo, photosRepo),
      seed: () => const TreatmentExecutionLoaded(productos: []),
      setUp: () {
        when(() => repo.agregarProducto(
          tratamientoId: 'trat-1',
          productoNombre: 'Botox',
          fabricante: null,
          lote: null,
          cantidadTotal: 1,
          unidadMedida: null,
          fechaVencimiento: null,
          observaciones: null,
        )).thenAnswer((_) async => const Left(ServerFailure('boom')));
      },
      act: (cubit) => cubit.agregarProducto(
        tratamientoId: 'trat-1',
        productoNombre: 'Botox',
        cantidadTotal: 1,
      ),
      expect: () => [
        isA<TreatmentExecutionError>()
            .having((s) => s.message, 'message', 'boom'),
      ],
    );
  });

  group('eliminarProducto', () {
    blocTest<TreatmentExecutionCubit, TreatmentExecutionState>(
      'elimina el producto del estado',
      build: () => _buildCubit(repo, photosRepo),
      seed: () => TreatmentExecutionLoaded(productos: [producto]),
      setUp: () {
        when(() => repo.eliminarProducto('prod-1'))
            .thenAnswer((_) async => const Right(null));
      },
      act: (cubit) => cubit.eliminarProducto('prod-1'),
      expect: () => [
        isA<TreatmentExecutionLoaded>()
            .having((s) => s.productos, 'productos', isEmpty),
      ],
    );
  });

  group('finalizar', () {
    blocTest<TreatmentExecutionCubit, TreatmentExecutionState>(
      'finaliza el tratamiento y la cita',
      build: () => _buildCubit(repo, photosRepo),
      seed: () => TreatmentExecutionLoaded(cita: citaEnProceso),
      setUp: () {
        when(() => repo.finalizarTratamiento(
          citaId: 'cita-1',
          tratamientoId: 'trat-1',
          observacionesFinales: 'Todo bien',
          recomendacionesPostTratamiento: null,
        )).thenAnswer((_) async => const Right(null));
      },
      act: (cubit) => cubit.finalizar(
        citaId: 'cita-1',
        tratamientoId: 'trat-1',
        observacionesFinales: 'Todo bien',
      ),
      expect: () => [
        isA<TreatmentExecutionLoaded>()
            .having((s) => s.trabajando, 'trabajando', true),
        isA<TreatmentExecutionLoaded>()
            .having((s) => s.trabajando, 'trabajando', false),
      ],
      verify: (_) {
        verify(() => repo.finalizarTratamiento(
          citaId: 'cita-1',
          tratamientoId: 'trat-1',
          observacionesFinales: 'Todo bien',
          recomendacionesPostTratamiento: null,
        )).called(1);
      },
    );
  });

  group('registrarLlegada', () {
    test('registra la llegada y devuelve la distancia recorrida', () async {
      when(() => repo.registrarLlegada(
        citaId: 'cita-1',
        latitud: 19.4,
        longitud: -99.1,
      )).thenAnswer((_) async => Right(350.5));

      final cubit = _buildCubit(repo, photosRepo);
      cubit.emit(const TreatmentExecutionLoaded());

      final distancia =
          await cubit.registrarLlegada(citaId: 'cita-1', latitud: 19.4, longitud: -99.1);

      expect(distancia, 350.5);
      expect(
        cubit.state,
        isA<TreatmentExecutionLoaded>()
            .having((s) => s.trabajando, 'trabajando', false),
      );
      await cubit.close();
    });
  });

  group('cancelar', () {
    blocTest<TreatmentExecutionCubit, TreatmentExecutionState>(
      'cancela la cita registrando el motivo',
      build: () => _buildCubit(repo, photosRepo),
      seed: () => TreatmentExecutionLoaded(cita: citaPendiente),
      setUp: () {
        when(() => repo.cancelarCita(
          citaId: 'cita-1',
          motivo: 'El paciente canceló',
        )).thenAnswer((_) async => const Right(null));
      },
      act: (cubit) => cubit.cancelar(
        citaId: 'cita-1',
        motivo: 'El paciente canceló',
      ),
      expect: () => [
        isA<TreatmentExecutionLoaded>()
            .having((s) => s.trabajando, 'trabajando', true),
        isA<TreatmentExecutionLoaded>()
            .having((s) => s.trabajando, 'trabajando', false),
      ],
    );
  });

  group('loadFaceMap', () {
    blocTest<TreatmentExecutionCubit, TreatmentExecutionState>(
      'carga el face map del tratamiento',
      build: () => _buildCubit(repo, photosRepo),
      seed: () => const TreatmentExecutionLoaded(),
      setUp: () {
        when(() => repo.getFaceMapPorTratamiento('trat-1'))
            .thenAnswer((_) async => Right(faceMap));
      },
      act: (cubit) => cubit.loadFaceMap(tratamientoId: 'trat-1'),
      expect: () => [
        isA<TreatmentExecutionLoaded>()
            .having((s) => s.trabajando, 'trabajando', true),
        isA<TreatmentExecutionLoaded>()
            .having((s) => s.faceMap, 'faceMap', faceMap)
            .having((s) => s.trabajando, 'trabajando', false),
      ],
    );
  });

  group('guardarFaceMap', () {
    blocTest<TreatmentExecutionCubit, TreatmentExecutionState>(
      'guarda el face map y recarga el mapa guardado',
      build: () => _buildCubit(repo, photosRepo),
      seed: () => const TreatmentExecutionLoaded(),
      setUp: () {
        when(() => repo.guardarFaceMapPorTratamiento(
          tratamientoId: 'trat-1',
          pacienteId: 'pac-1',
          puntos: const [
            {'punto_id': 'p1'},
          ],
          observaciones: 'notas',
        )).thenAnswer((_) async => const Right(null));
        when(() => repo.getFaceMapPorTratamiento('trat-1'))
            .thenAnswer((_) async => Right(faceMap));
      },
      act: (cubit) => cubit.guardarFaceMap(
        tratamientoId: 'trat-1',
        pacienteId: 'pac-1',
        puntos: const [
          {'punto_id': 'p1'},
        ],
        observaciones: 'notas',
      ),
      expect: () => [
        isA<TreatmentExecutionLoaded>()
            .having((s) => s.trabajando, 'trabajando', true),
        isA<TreatmentExecutionLoaded>()
            .having((s) => s.faceMap, 'faceMap', faceMap)
            .having((s) => s.trabajando, 'trabajando', false),
      ],
      verify: (_) {
        verify(() => repo.guardarFaceMapPorTratamiento(
          tratamientoId: 'trat-1',
          pacienteId: 'pac-1',
          puntos: const [
            {'punto_id': 'p1'},
          ],
          observaciones: 'notas',
        )).called(1);
      },
    );
  });
}