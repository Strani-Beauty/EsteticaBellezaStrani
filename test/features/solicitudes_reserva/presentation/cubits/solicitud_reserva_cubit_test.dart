import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/features/solicitudes_reserva/domain/entities/seguimiento_solicitud_entity.dart';
import 'package:esteticaybellezastrani/features/solicitudes_reserva/domain/entities/servicio_seleccionado_entity.dart';
import 'package:esteticaybellezastrani/features/solicitudes_reserva/domain/entities/solicitud_reserva_entity.dart';
import 'package:esteticaybellezastrani/features/solicitudes_reserva/domain/usecases/confirmar_pago_deposito.dart';
import 'package:esteticaybellezastrani/features/solicitudes_reserva/domain/usecases/crear_solicitud_reserva.dart';
import 'package:esteticaybellezastrani/features/solicitudes_reserva/domain/usecases/get_config_reserva.dart';
import 'package:esteticaybellezastrani/features/solicitudes_reserva/domain/usecases/get_mi_direccion_principal.dart';
import 'package:esteticaybellezastrani/features/solicitudes_reserva/presentation/cubits/solicitud_reserva_cubit.dart';

class MockGetConfigReserva extends Mock implements GetConfigReserva {}
class MockGetMiDireccionPrincipal extends Mock
    implements GetMiDireccionPrincipal {}
class MockCrearSolicitudReserva extends Mock implements CrearSolicitudReserva {}
class MockConfirmarPagoDeposito extends Mock implements ConfirmarPagoDeposito {}

void main() {
  late MockGetConfigReserva getConfigReserva;
  late MockGetMiDireccionPrincipal getMiDireccionPrincipal;
  late MockCrearSolicitudReserva crearSolicitudReserva;
  late MockConfirmarPagoDeposito confirmarPagoDeposito;

  setUp(() {
    getConfigReserva = MockGetConfigReserva();
    getMiDireccionPrincipal = MockGetMiDireccionPrincipal();
    crearSolicitudReserva = MockCrearSolicitudReserva();
    confirmarPagoDeposito = MockConfirmarPagoDeposito();
  });

  setUpAll(() {
    registerFallbackValue(const CrearSolicitudReservaParams(
      profileId: 'p',
      servicios: [],
      direccionId: 'd',
    ));
    registerFallbackValue(const ConfirmarPagoDepositoParams(
      solicitudId: 's',
      stripePaymentId: 'pi',
      concepto: 'ADELANTO',
      monto: 0,
    ));
  });

  SolicitudReservaCubit buildCubit() {
    return SolicitudReservaCubit(
      getConfigReserva: getConfigReserva,
      getMiDireccionPrincipal: getMiDireccionPrincipal,
      crearSolicitudReserva: crearSolicitudReserva,
      confirmarPagoDeposito: confirmarPagoDeposito,
    );
  }

  const config = ConfigReservaEntity(radioKm: 10, enforcePagoReal: true);
  const direccion = DireccionPrincipalEntity(
    id: 'dir-1',
    direccion: 'Main St 123',
    latitud: 29.76,
    longitud: -95.36,
  );

  test('estado inicial', () {
    expect(buildCubit().state, const SolicitudReservaInitial());
  });

  blocTest<SolicitudReservaCubit, SolicitudReservaState>(
    'loadConfig emite Ready con config y dirección',
    build: buildCubit,
    act: (cubit) async {
      when(() => getConfigReserva())
          .thenAnswer((_) async => const Right(config));
      when(() => getMiDireccionPrincipal('profile-1'))
          .thenAnswer((_) async => const Right(direccion));
      await cubit.loadConfig('profile-1');
    },
    expect: () => [
      const SolicitudReservaLoadingConfig(),
      const SolicitudReservaReady(config: config, direccion: direccion),
    ],
  );

  blocTest<SolicitudReservaCubit, SolicitudReservaState>(
    'crear emite Created con la reserva',
    build: buildCubit,
    act: (cubit) async {
      const reserva = SolicitudReservaEntity(
        solicitudId: 'sol-1',
        total: 100,
        depositoRequerido: 50,
        saldoPendiente: 50,
        moneda: 'USD',
      );
      when(() => crearSolicitudReserva(any())).thenAnswer(
          (_) async => const Right(reserva));
      await cubit.crear(
        profileId: 'profile-1',
        servicios: const [
          ServicioSeleccionadoEntity(
            servicioId: 'svc-1',
            nombre: 'Toxina',
            precioBase: 50,
          ),
        ],
        direccionId: 'dir-1',
        pagoTotal: false,
      );
    },
    expect: () => [
      const SolicitudReservaCreating(),
      const SolicitudReservaCreated(SolicitudReservaEntity(
        solicitudId: 'sol-1',
        total: 100,
        depositoRequerido: 50,
        saldoPendiente: 50,
        moneda: 'USD',
      )),
    ],
  );

  blocTest<SolicitudReservaCubit, SolicitudReservaState>(
    'confirmar emite Confirmed con motivo',
    build: buildCubit,
    act: (cubit) async {
      when(() => confirmarPagoDeposito(any()))
          .thenAnswer((_) async => const Right('CONFIRMADA'));
      await cubit.confirmar(
        solicitudId: 'sol-1',
        stripePaymentId: 'pi_123',
        concepto: 'ADELANTO',
        monto: 50,
      );
    },
    expect: () => [
      const SolicitudReservaConfirming(),
      const SolicitudReservaConfirmed('CONFIRMADA'),
    ],
  );

  blocTest<SolicitudReservaCubit, SolicitudReservaState>(
    'confirmar emite Error cuando falla',
    build: buildCubit,
    act: (cubit) async {
      when(() => confirmarPagoDeposito(any())).thenAnswer(
          (_) async => const Left(PaymentFailure('Pago rechazado')));
      await cubit.confirmar(
        solicitudId: 'sol-1',
        stripePaymentId: 'pi_123',
        concepto: 'ADELANTO',
        monto: 50,
      );
    },
    expect: () => [
      const SolicitudReservaConfirming(),
      const SolicitudReservaError('Pago rechazado'),
    ],
  );
}
