import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Los usecases se inyectan por nombre; esta regla no aplica aquí.
// ignore_for_file: prefer_initializing_formals

import '../../domain/entities/seguimiento_solicitud_entity.dart';
import '../../domain/entities/servicio_seleccionado_entity.dart';
import '../../domain/entities/solicitud_reserva_entity.dart';
import '../../domain/usecases/confirmar_pago_deposito.dart';
import '../../domain/usecases/crear_solicitud_reserva.dart';
import '../../domain/usecases/get_config_reserva.dart';
import '../../domain/usecases/get_mi_direccion_principal.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ESTADOS
// ─────────────────────────────────────────────────────────────────────────────

abstract class SolicitudReservaState extends Equatable {
  const SolicitudReservaState();
  @override
  List<Object?> get props => [];
}

class SolicitudReservaInitial extends SolicitudReservaState {
  const SolicitudReservaInitial();
}

class SolicitudReservaLoadingConfig extends SolicitudReservaState {
  const SolicitudReservaLoadingConfig();
}

class SolicitudReservaReady extends SolicitudReservaState {
  final ConfigReservaEntity config;
  final DireccionPrincipalEntity? direccion;

  const SolicitudReservaReady({required this.config, this.direccion});

  @override
  List<Object?> get props => [config, direccion];
}

class SolicitudReservaError extends SolicitudReservaState {
  final String message;
  const SolicitudReservaError(this.message);
  @override
  List<Object?> get props => [message];
}

class SolicitudReservaCreating extends SolicitudReservaState {
  const SolicitudReservaCreating();
}

class SolicitudReservaCreated extends SolicitudReservaState {
  final SolicitudReservaEntity reserva;
  const SolicitudReservaCreated(this.reserva);
  @override
  List<Object?> get props => [reserva];
}

class SolicitudReservaConfirming extends SolicitudReservaState {
  const SolicitudReservaConfirming();
}

/// Confirmado: `motivo` = 'CONFIRMADA' (publicada) o 'PENDIENTE_WEBHOOK'
/// (el pago se cobró y la publicación llegará vía webhook).
class SolicitudReservaConfirmed extends SolicitudReservaState {
  final String motivo;
  const SolicitudReservaConfirmed(this.motivo);
  @override
  List<Object?> get props => [motivo];
}

// ─────────────────────────────────────────────────────────────────────────────
// CUBIT
// ─────────────────────────────────────────────────────────────────────────────

class SolicitudReservaCubit extends Cubit<SolicitudReservaState> {
  final GetConfigReserva _getConfigReserva;
  final GetMiDireccionPrincipal _getMiDireccionPrincipal;
  final CrearSolicitudReserva _crearSolicitudReserva;
  final ConfirmarPagoDeposito _confirmarPagoDeposito;

  SolicitudReservaCubit({
    required GetConfigReserva getConfigReserva,
    required GetMiDireccionPrincipal getMiDireccionPrincipal,
    required CrearSolicitudReserva crearSolicitudReserva,
    required ConfirmarPagoDeposito confirmarPagoDeposito,
  })  : _getConfigReserva = getConfigReserva,
        _getMiDireccionPrincipal = getMiDireccionPrincipal,
        _crearSolicitudReserva = crearSolicitudReserva,
        _confirmarPagoDeposito = confirmarPagoDeposito,
        super(const SolicitudReservaInitial());

  Future<void> loadConfig(String profileId) async {
    emit(const SolicitudReservaLoadingConfig());

    ConfigReservaEntity? config;
    DireccionPrincipalEntity? direccion;
    String? error;

    final configRes = await _getConfigReserva();
    final dirRes = await _getMiDireccionPrincipal(profileId);

    configRes.fold((f) => error ??= f.message, (v) => config = v);
    dirRes.fold((f) => error ??= f.message, (v) => direccion = v);

    if (error != null) {
      emit(SolicitudReservaError(error!));
      return;
    }

    emit(SolicitudReservaReady(
      config: config ?? const ConfigReservaEntity(radioKm: 10, enforcePagoReal: false),
      direccion: direccion,
    ));
  }

  Future<void> crear({
    required String profileId,
    required List<ServicioSeleccionadoEntity> servicios,
    required String direccionId,
    DateTime? fechaProgramada,
    double? radioKm,
    String? observaciones,
    required bool pagoTotal,
  }) async {
    emit(const SolicitudReservaCreating());

    final result = await _crearSolicitudReserva(CrearSolicitudReservaParams(
      profileId: profileId,
      servicios: servicios,
      direccionId: direccionId,
      fechaProgramada: fechaProgramada,
      radioKm: radioKm,
      observaciones: observaciones,
      pagoTotal: pagoTotal,
    ));

    result.fold(
      (f) => emit(SolicitudReservaError(f.message)),
      (reserva) => emit(SolicitudReservaCreated(reserva)),
    );
  }

  Future<void> confirmar({
    required String solicitudId,
    required String stripePaymentId,
    required String concepto,
    required double monto,
  }) async {
    emit(const SolicitudReservaConfirming());

    final result = await _confirmarPagoDeposito(ConfirmarPagoDepositoParams(
      solicitudId: solicitudId,
      stripePaymentId: stripePaymentId,
      concepto: concepto,
      monto: monto,
    ));

    result.fold(
      (f) => emit(SolicitudReservaError(f.message)),
      (motivo) => emit(SolicitudReservaConfirmed(motivo)),
    );
  }

  void reset() => emit(const SolicitudReservaInitial());
}
