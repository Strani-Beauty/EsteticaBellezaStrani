import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/features/marketplace_citas/domain/entities/resultado_aceptacion_entity.dart';
import 'package:esteticaybellezastrani/features/marketplace_citas/domain/entities/solicitud_pendiente_entity.dart';
import 'package:esteticaybellezastrani/features/marketplace_citas/domain/usecases/aceptar_solicitud.dart';
import 'package:esteticaybellezastrani/features/marketplace_citas/domain/usecases/get_especialistas_aprobados.dart';
import 'package:esteticaybellezastrani/features/marketplace_citas/domain/usecases/get_mi_ubicacion.dart';
import 'package:esteticaybellezastrani/features/marketplace_citas/domain/usecases/get_solicitudes_pendientes.dart';
import 'package:esteticaybellezastrani/features/marketplace_citas/presentation/cubits/marketplace_cubit.dart';

class MockGetSolicitudesPendientes extends Mock
    implements GetSolicitudesPendientes {}
class MockGetEspecialistasAprobados extends Mock
    implements GetEspecialistasAprobados {}
class MockGetMiUbicacion extends Mock implements GetMiUbicacion {}
class MockAceptarSolicitud extends Mock implements AceptarSolicitud {}

void main() {
  late MockGetSolicitudesPendientes getSolicitudes;
  late MockGetEspecialistasAprobados getEspecialistas;
  late MockGetMiUbicacion getMiUbicacion;
  late MockAceptarSolicitud aceptarSolicitud;

  setUpAll(() {
    registerFallbackValue(const AceptarSolicitudParams(
      solicitudId: 'sol',
      especialistaId: 'esp',
    ));
  });

  setUp(() {
    getSolicitudes = MockGetSolicitudesPendientes();
    getEspecialistas = MockGetEspecialistasAprobados();
    getMiUbicacion = MockGetMiUbicacion();
    aceptarSolicitud = MockAceptarSolicitud();
  });

  MarketplaceCubit buildCubit() {
    return MarketplaceCubit(
      getSolicitudesPendientes: getSolicitudes,
      getEspecialistasAprobados: getEspecialistas,
      getMiUbicacion: getMiUbicacion,
      aceptarSolicitud: aceptarSolicitud,
    );
  }

  const solicitud = SolicitudPendienteEntity(
    id: 'sol-1',
    pacienteNombre: 'Ana',
    servicioNombre: 'Servicio',
    precio: 100,
    estado: 'PUBLICADA',
  );

  test('estado inicial', () {
    expect(buildCubit().state, const MarketplaceInitial());
  });

  blocTest<MarketplaceCubit, MarketplaceState>(
    'load emite Loaded con solicitudes',
    build: buildCubit,
    act: (cubit) async {
      when(() => getSolicitudes())
          .thenAnswer((_) async => const Right([solicitud]));
      when(() => getEspecialistas()).thenAnswer((_) async => const Right([]));
      when(() => getMiUbicacion('esp-1'))
          .thenAnswer((_) async => const Right((latitud: null, longitud: null)));
      await cubit.load('esp-1');
    },
    expect: () => [
      const MarketplaceLoading(),
      const MarketplaceLoaded(solicitudes: [solicitud]),
    ],
  );

  blocTest<MarketplaceCubit, MarketplaceState>(
    'MK-S-02: si el refresco falla tras una aceptación perdida, se conserva el mapa y se avisa',
    build: buildCubit,
    act: (cubit) async {
      // load OK
      when(() => getSolicitudes())
          .thenAnswer((_) async => const Right([solicitud]));
      when(() => getEspecialistas()).thenAnswer((_) async => const Right([]));
      when(() => getMiUbicacion('esp-1'))
          .thenAnswer((_) async => const Right((latitud: null, longitud: null)));
      await cubit.load('esp-1');

      // aceptar: ya asignada a otro → dispara _refrescar
      when(() => aceptarSolicitud(any())).thenAnswer((_) async =>
          const Right(ResultadoAceptacionEntity(
              aceptada: false, motivo: 'ASIGNADA')));

      // el refresco falla (sin red)
      when(() => getSolicitudes()).thenAnswer(
          (_) async => const Left(ServerFailure('Sin conexión a internet.')));
      await cubit.aceptar(solicitudId: 'sol-1', especialistaId: 'esp-1');
    },
    wait: const Duration(milliseconds: 100),
    expect: () => [
      // load
      const MarketplaceLoading(),
      const MarketplaceLoaded(solicitudes: [solicitud]),
      // aceptar: feedback de "ya asignado"
      const MarketplaceLoaded(
        solicitudes: [solicitud],
        aceptandoId: 'sol-1',
      ),
      const MarketplaceLoaded(
        solicitudes: [solicitud],
        aceptandoId: null,
        feedback:
            'Este paciente ya fue asignado a otro especialista. Se actualiza el mapa.',
      ),
      // refresco fallido: se conservan las solicitudes y se avisa (MK-S-02)
      const MarketplaceLoaded(
        solicitudes: [solicitud],
        feedback: 'No se pudo actualizar el mapa: Sin conexión a internet.',
      ),
    ],
  );
}
