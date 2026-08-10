// Los usecases se inyectan por nombre; esta regla no aplica aquí.
// ignore_for_file: prefer_initializing_formals

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/pago_entity.dart';
import '../../domain/entities/payment_intent_entity.dart';
import '../../domain/usecases/consultar_pago.dart';
import '../../domain/usecases/crear_payment_intent.dart';
import '../../domain/usecases/crear_solicitud_deposito.dart';
import '../../domain/usecases/pagar_servicio.dart';
import '../../domain/usecases/registrar_pago_inicial.dart';
import '../../domain/usecases/registrar_saldo.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ESTADOS
// ─────────────────────────────────────────────────────────────────────────────

abstract class PaymentsState {
  const PaymentsState();
}

class PaymentsInitial extends PaymentsState {
  const PaymentsInitial();
}

class PaymentsLoading extends PaymentsState {
  const PaymentsLoading();
}

/// PaymentIntent listo en el backend; la UI presenta el PaymentSheet.
class PaymentsIntentReady extends PaymentsState {
  final PaymentIntentEntity intent;
  const PaymentsIntentReady({required this.intent});
}

class PaymentsError extends PaymentsState {
  final String message;
  const PaymentsError(this.message);
}

// ─────────────────────────────────────────────────────────────────────────────
// CUBIT
// ─────────────────────────────────────────────────────────────────────────────

class PaymentsCubit extends Cubit<PaymentsState> {
  final CrearPaymentIntent _crearPaymentIntent;
  final RegistrarPagoInicial _registrarPagoInicial;
  final CrearSolicitudDeposito _crearSolicitudDeposito;
  final PagarServicio _pagarServicio;
  final RegistrarSaldo _registrarSaldo;
  final ConsultarPago _consultarPago;

  PaymentsCubit({
    required CrearPaymentIntent crearPaymentIntent,
    required RegistrarPagoInicial registrarPagoInicial,
    required CrearSolicitudDeposito crearSolicitudDeposito,
    required PagarServicio pagarServicio,
    required RegistrarSaldo registrarSaldo,
    required ConsultarPago consultarPago,
  })  : _crearPaymentIntent = crearPaymentIntent,
        _registrarPagoInicial = registrarPagoInicial,
        _crearSolicitudDeposito = crearSolicitudDeposito,
        _pagarServicio = pagarServicio,
        _registrarSaldo = registrarSaldo,
        _consultarPago = consultarPago,
        super(const PaymentsInitial());

  /// Crea el PaymentIntent en el backend. Devuelve `null` si falla.
  Future<PaymentIntentEntity?> crearIntent({
    required double monto,
    required String concepto,
    String? solicitudId,
    String? citaId,
  }) async {
    emit(const PaymentsLoading());
    final result = await _crearPaymentIntent(CrearPaymentIntentParams(
      amount: monto,
      concepto: concepto,
      solicitudId: solicitudId,
      citaId: citaId,
    ));
    return result.fold(
      (f) {
        emit(PaymentsError(f.message));
        return null;
      },
      (intent) {
        emit(PaymentsIntentReady(intent: intent));
        return intent;
      },
    );
  }

  /// Registra la cuota inicial del onboarding. Devuelve `true` si se marcó.
  Future<bool> pagarCuotaInicial({
    required String profileId,
    required double amount,
    required String paymentReference,
  }) async {
    final result = await _registrarPagoInicial(RegistrarPagoInicialParams(
      profileId: profileId,
      amount: amount,
      paymentReference: paymentReference,
    ));
    return result.fold(
      (f) {
        emit(PaymentsError(f.message));
        return false;
      },
      (_) => true,
    );
  }

  /// Crea solicitud + pago + transacción al aprobarse Qualify.
  Future<String?> crearSolicitudDeposito({
    required String profileId,
    required String stripePaymentRef,
    String? servicioId,
  }) async {
    final result = await _crearSolicitudDeposito(CrearSolicitudDepositoParams(
      profileId: profileId,
      stripePaymentRef: stripePaymentRef,
      servicioId: servicioId,
    ));
    return result.fold(
      (f) {
        emit(PaymentsError(f.message));
        return null;
      },
      (id) => id,
    );
  }

  /// Reserva un servicio del catálogo (depósito o totalidad).
  Future<String?> pagarServicio({
    required String profileId,
    required String servicioId,
    required String serviceTitle,
    required double servicePrice,
    required bool payFullAmount,
    required String stripePaymentRef,
  }) async {
    final result = await _pagarServicio(PagarServicioParams(
      profileId: profileId,
      servicioId: servicioId,
      serviceTitle: serviceTitle,
      servicePrice: servicePrice,
      payFullAmount: payFullAmount,
      stripePaymentRef: stripePaymentRef,
    ));
    return result.fold(
      (f) {
        emit(PaymentsError(f.message));
        return null;
      },
      (id) => id,
    );
  }

  /// Cobra el saldo restante al finalizar tratamiento.
  Future<bool> registrarSaldo({
    required String citaId,
    required String solicitudId,
    required double monto,
    required String stripePaymentRef,
  }) async {
    final result = await _registrarSaldo(RegistrarSaldoParams(
      citaId: citaId,
      solicitudId: solicitudId,
      monto: monto,
      stripePaymentRef: stripePaymentRef,
    ));
    return result.fold(
      (f) {
        emit(PaymentsError(f.message));
        return false;
      },
      (ok) => ok,
    );
  }

  /// Consulta el pago (obligación) de una solicitud.
  Future<PagoEntity?> consultarPago({required String solicitudId}) async {
    final result = await _consultarPago(ConsultarPagoParams(solicitudId: solicitudId));
    return result.fold(
      (f) {
        emit(PaymentsError(f.message));
        return null;
      },
      (pago) => pago,
    );
  }
}