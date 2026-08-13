import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/entities/disponibilidad_entity.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/entities/especialista_entity.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/entities/medico_regente_entity.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/entities/ubicacion_especialista_entity.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/usecases/aprobar_medico_regente.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/usecases/asignar_especialidades.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/usecases/create_especialista.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/usecases/create_medico_regente.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/usecases/get_all_especialistas.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/usecases/get_contrato.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/usecases/get_disponibilidad.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/usecases/get_documentos.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/usecases/get_especialidades.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/usecases/get_medicos_regentes.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/usecases/get_my_specialist.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/usecases/revisar_documento.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/usecases/save_ubicacion.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/usecases/set_disponibilidad.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/usecases/solicitar_verificacion.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/usecases/update_especialista.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/usecases/update_perfil_especialista.dart';
import 'package:esteticaybellezastrani/features/specialists/presentation/cubits/specialists_cubit.dart';
import '../../mock_repository.dart';

SpecialistsCubit _buildCubit(MockISpecialistsRepository repo) {
  return SpecialistsCubit(
    getMySpecialist: GetMySpecialist(repo),
    createEspecialista: CreateEspecialista(repo),
    getMedicosRegentes: GetMedicosRegentes(repo),
    getEspecialidades: GetEspecialidades(repo),
    getDisponibilidad: GetDisponibilidad(repo),
    getDocumentos: GetDocumentos(repo),
    registerDocumento: RegisterDocumento(repo),
    subirDocumento: SubirDocumento(repo),
    upsertDisponibilidad: UpsertDisponibilidad(repo),
    getContrato: GetContrato(repo),
    firmarContrato: FirmarContrato(repo),
    subirFirmaContrato: SubirFirmaContrato(repo),
    saveUbicacion: SaveUbicacion(repo),
    updateEspecialista: UpdateEspecialista(repo),
    getAllEspecialistas: GetAllEspecialistas(repo),
    asignarEspecialidades: AsignarEspecialidades(repo),
    createMedicoRegente: CreateMedicoRegente(repo),
    aprobarMedicoRegente: AprobarMedicoRegente(repo),
    updatePerfilEspecialista: UpdatePerfilEspecialista(repo),
    getEspecialidadesDelEspecialista: GetEspecialistaEspecialidades(repo),
    solicitarVerificacion: SolicitarVerificacion(repo),
    revisarDocumento: RevisarDocumento(repo),
  );
}

void main() {
  late MockISpecialistsRepository repo;

  setUpAll(() {
    registerFallbackValue(EstadoDisponibilidad.disponible);
  });

  setUp(() {
    repo = MockISpecialistsRepository();
  });

  final especialista = EspecialistaEntity(
    id: 'esp-1',
    usuarioId: 'user-1',
    numeroLicencia: 'LIC-123',
    estadoVerificacion: EstadoVerificacion.pendiente,
    disponible: false,
    activo: false,
    createdAt: DateTime(2026, 8, 13),
  );

  group('createSpecialist', () {
    blocTest<SpecialistsCubit, SpecialistsState>(
      'emite Loading y luego Loaded con el especialista creado',
      build: () => _buildCubit(repo),
      setUp: () {
        when(() => repo.createEspecialista(
              usuarioId: any(named: 'usuarioId'),
              numeroLicencia: any(named: 'numeroLicencia'),
              medicoRegenteId: any(named: 'medicoRegenteId'),
            )).thenAnswer((_) async => Right(especialista));
      },
      act: (cubit) =>
          cubit.createSpecialist(usuarioId: 'user-1', numeroLicencia: 'LIC-123'),
      expect: () => [
        isA<SpecialistsLoading>(),
        isA<SpecialistsLoaded>()
            .having((s) => s.especialista, 'especialista', especialista),
      ],
    );

    blocTest<SpecialistsCubit, SpecialistsState>(
      'emite Loading y luego Error cuando la creación falla',
      build: () => _buildCubit(repo),
      setUp: () {
        when(() => repo.createEspecialista(
              usuarioId: any(named: 'usuarioId'),
              numeroLicencia: any(named: 'numeroLicencia'),
              medicoRegenteId: any(named: 'medicoRegenteId'),
            )).thenAnswer((_) async => const Left(ServerFailure('boom')));
      },
      act: (cubit) => cubit.createSpecialist(usuarioId: 'user-1'),
      expect: () => [
        isA<SpecialistsLoading>(),
        isA<SpecialistsError>().having((s) => s.message, 'message', 'boom'),
      ],
    );
  });

  group('toggleDisponibilidad', () {
    final dispDisponible = DisponibilidadEntity(
      id: 'disp-1',
      especialistaId: 'esp-1',
      estado: EstadoDisponibilidad.disponible,
      createdAt: DateTime(2026, 8, 13),
    );

    blocTest<SpecialistsCubit, SpecialistsState>(
      'activa disponibilidad y sincroniza el flag disponible',
      build: () => _buildCubit(repo),
      seed: () => const SpecialistsLoaded(especialista: null),
      setUp: () {
        when(() => repo.upsertDisponibilidad(
              any(),
              any(),
              fechaInicio: any(named: 'fechaInicio'),
              fechaFin: any(named: 'fechaFin'),
            )).thenAnswer((_) async => Right(dispDisponible));
        when(() => repo.updateEspecialista(any(), any()))
            .thenAnswer((_) async => Right(especialista.copyWith(disponible: true)));
      },
      act: (cubit) => cubit.toggleDisponibilidad(especialistaId: 'esp-1'),
      expect: () => [
        isA<SpecialistsLoaded>()
            .having((s) => s.disponibilidad?.isAvailable, 'disponibilidad', true)
            .having((s) => s.especialista?.disponible, 'disponible', true),
      ],
    );

    blocTest<SpecialistsCubit, SpecialistsState>(
      'emite Error cuando el upsert de disponibilidad falla',
      build: () => _buildCubit(repo),
      seed: () => const SpecialistsLoaded(especialista: null),
      setUp: () {
        when(() => repo.upsertDisponibilidad(
              any(),
              any(),
              fechaInicio: any(named: 'fechaInicio'),
              fechaFin: any(named: 'fechaFin'),
            )).thenAnswer((_) async => const Left(ServerFailure('upsert falló')));
      },
      act: (cubit) => cubit.toggleDisponibilidad(especialistaId: 'esp-1'),
      expect: () => [
        isA<SpecialistsError>().having((s) => s.message, 'message', 'upsert falló'),
      ],
    );
  });

  group('saveLocation', () {
    final ubicacion = UbicacionEspecialistaEntity(
      id: 'ubi-1',
      especialistaId: 'esp-1',
      latitud: 29.7604,
      longitud: -95.3698,
      precisionMetros: 10,
      createdAt: DateTime(2026, 8, 13),
    );

    blocTest<SpecialistsCubit, SpecialistsState>(
      'guarda la ubicación y la refleja en el estado',
      build: () => _buildCubit(repo),
      seed: () => const SpecialistsLoaded(especialista: null),
      setUp: () {
        when(() => repo.saveUbicacion(
              any(),
              latitud: any(named: 'latitud'),
              longitud: any(named: 'longitud'),
              precisionMetros: any(named: 'precisionMetros'),
            )).thenAnswer((_) async => Right(ubicacion));
      },
      act: (cubit) => cubit.saveLocation(
        especialistaId: 'esp-1',
        latitud: 29.7604,
        longitud: -95.3698,
        precisionMetros: 10,
      ),
      expect: () => [
        isA<SpecialistsLoaded>().having((s) => s.ubicacion, 'ubicacion', ubicacion),
      ],
    );
  });

  group('createMedicoRegente', () {
    final medico = MedicoRegenteEntity(
      id: 'med-2',
      nombre: 'Dr. Pérez',
      estado: 'PENDIENTE',
      activo: false,
      createdAt: DateTime(2026, 8, 13),
    );

    blocTest<SpecialistsCubit, SpecialistsState>(
      'agrega el médico regente a la lista del estado',
      build: () => _buildCubit(repo),
      seed: () => SpecialistsLoaded(
        especialista: especialista,
        medicosRegentes: const [],
      ),
      setUp: () {
        when(() => repo.createMedicoRegente(
              nombre: any(named: 'nombre'),
              numeroLicencia: any(named: 'numeroLicencia'),
              telefono: any(named: 'telefono'),
              correo: any(named: 'correo'),
            )).thenAnswer((_) async => Right(medico));
      },
      act: (cubit) => cubit.createMedicoRegente(nombre: 'Dr. Pérez'),
      expect: () => [
        isA<SpecialistsLoaded>().having(
          (s) => s.medicosRegentes,
          'medicosRegentes',
          [medico],
        ),
      ],
    );
  });

  group('guardarEspecialidades', () {
    blocTest<SpecialistsCubit, SpecialistsState>(
      'reemplaza los ids de especialidades en el estado',
      build: () => _buildCubit(repo),
      seed: () => const SpecialistsLoaded(
        especialista: null,
        especialidadIds: [1],
      ),
      setUp: () {
        when(() => repo.reemplazarEspecialidades(any(), any()))
            .thenAnswer((_) async => const Right([]));
      },
      act: (cubit) => cubit.guardarEspecialidades(
        especialistaId: 'esp-1',
        especialidadIds: const [10, 20],
      ),
      expect: () => [
        isA<SpecialistsLoaded>()
            .having((s) => s.especialidadIds, 'especialidadIds', [10, 20]),
      ],
    );
  });

  group('actualizarDatosProfesionales', () {
    blocTest<SpecialistsCubit, SpecialistsState>(
      'delega en updateEspecialista con el mapa de datos correcto',
      build: () => _buildCubit(repo),
      seed: () => SpecialistsLoaded(especialista: especialista),
      setUp: () {
        when(() => repo.updateEspecialista(any(), any())).thenAnswer(
          (_) async => Right(especialista.copyWith(numeroLicencia: 'LIC-999')),
        );
      },
      act: (cubit) => cubit.actualizarDatosProfesionales(
        especialistaId: 'esp-1',
        numeroLicencia: 'LIC-999',
        medicoRegenteId: 'med-9',
      ),
      verify: (_) {
        verify(() => repo.updateEspecialista('esp-1', {
              'numero_licencia': 'LIC-999',
              'medico_regente_id': 'med-9',
            })).called(1);
      },
    );
  });
}
