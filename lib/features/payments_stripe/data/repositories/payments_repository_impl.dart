import 'package:flutter/foundation.dart';

import '../../domain/entities/adelanto_servicio_entity.dart';
import '../../domain/entities/comision_entity.dart';
import '../../domain/entities/detalle_financiero_entity.dart';
import '../../domain/entities/pago_entity.dart';
import '../../domain/entities/payment_intent_entity.dart';
import '../../domain/entities/transaccion_entity.dart';
import '../../domain/repositories/i_payments_repository.dart';
import '../datasources/payments_supabase_datasource.dart';

/// Implementación del repositorio de pagos sobre el datasource de Supabase.
class PaymentsRepositoryImpl implements IPaymentsRepository {
  final PaymentsSupabaseDataSource _dataSource;

  const PaymentsRepositoryImpl(this._dataSource);

  @override
  Future<String?> createSolicitudAndPayment({
    required String profileId,
    required String stripePaymentRef,
    String? servicioId,
  }) async {
    try {
      return await _dataSource.createSolicitudAndPayment(
        profileId: profileId,
        stripePaymentRef: stripePaymentRef,
        servicioId: servicioId,
      );
    } catch (e) {
      debugPrint('❌ [createSolicitudAndPayment] $e');
      rethrow;
    }
  }

  @override
  Future<void> registerInitialPayment({
    required String profileId,
    required double amount,
    required String paymentReference,
  }) async {
    try {
      await _dataSource.registerInitialPayment(
        profileId: profileId,
        amount: amount,
        paymentReference: paymentReference,
      );
    } catch (e) {
      debugPrint('❌ [registerInitialPayment] $e');
      rethrow;
    }
  }

  @override
  Future<String?> createServicePayment({
    required String profileId,
    required String servicioId,
    required double servicePrice,
    required bool payFullAmount,
    required double montoAPagar,
    required String stripePaymentRef,
  }) async {
    try {
      return await _dataSource.createServicePayment(
        profileId: profileId,
        servicioId: servicioId,
        servicePrice: servicePrice,
        payFullAmount: payFullAmount,
        montoAPagar: montoAPagar,
        stripePaymentRef: stripePaymentRef,
      );
    } catch (e) {
      debugPrint('❌ [createServicePayment] $e');
      rethrow;
    }
  }

  @override
  Future<AdelantoServicioEntity> calcularAdelanto(double servicePrice) async {
    try {
      return await _dataSource.calcularAdelanto(servicePrice);
    } catch (e) {
      debugPrint('❌ [calcularAdelanto] $e');
      rethrow;
    }
  }

  @override
  Future<String> confirmarPagoSaldo({
    required String citaId,
    required String solicitudId,
    required double monto,
    required String stripePaymentRef,
  }) async {
    try {
      return await _dataSource.confirmarPagoSaldo(
        citaId: citaId,
        solicitudId: solicitudId,
        monto: monto,
        stripePaymentRef: stripePaymentRef,
      );
    } catch (e) {
      debugPrint('❌ [confirmarPagoSaldo] $e');
      rethrow;
    }
  }

  @override
  Future<String> registrarPagoFallido({
    required String citaId,
    required String solicitudId,
    required double monto,
    required String stripePaymentRef,
    required String motivo,
    required String tipo,
  }) async {
    try {
      return await _dataSource.registrarPagoFallido(
        citaId: citaId,
        solicitudId: solicitudId,
        monto: monto,
        stripePaymentRef: stripePaymentRef,
        motivo: motivo,
        tipo: tipo,
      );
    } catch (e) {
      debugPrint('❌ [registrarPagoFallido] $e');
      rethrow;
    }
  }

  @override
  Future<PagoEntity?> consultarPago({required String solicitudId}) async {
    try {
      final model =
          await _dataSource.consultarPago(solicitudId: solicitudId);
      return model?.toEntity();
    } catch (e) {
      debugPrint('❌ [consultarPago] $e');
      rethrow;
    }
  }

  @override
  Future<PaymentIntentEntity> crearPaymentIntent({
    required double amount,
    required String concepto,
    String? solicitudId,
    String? citaId,
  }) async {
    try {
      final model = await _dataSource.crearPaymentIntent(
        amount: amount,
        concepto: concepto,
        solicitudId: solicitudId,
        citaId: citaId,
      );
      return model.toEntity();
    } catch (e) {
      debugPrint('❌ [crearPaymentIntent] $e');
      rethrow;
    }
  }

  @override
  Future<List<TransaccionEntity>> getTransaccionesAdmin({
    String? estado,
    String? tipo,
    DateTime? desde,
    DateTime? hasta,
  }) async {
    try {
      final models = await _dataSource.fetchTransaccionesAdmin(
        estado: estado,
        tipo: tipo,
        desde: desde,
        hasta: hasta,
      );
      return models.map((m) => m.toEntity()).toList();
    } catch (e) {
      debugPrint('❌ [getTransaccionesAdmin] $e');
      rethrow;
    }
  }

  @override
  Future<List<ComisionEntity>> getComisionesAdmin() async {
    try {
      return await _dataSource.fetchComisionesAdmin();
    } catch (e) {
      debugPrint('❌ [getComisionesAdmin] $e');
      rethrow;
    }
  }

  @override
  Future<DetalleFinancieroCitaEntity?> getDetalleFinancieroCita(
      String citaId) async {
    try {
      return await _dataSource.fetchDetalleFinancieroCita(citaId);
    } catch (e) {
      debugPrint('❌ [getDetalleFinancieroCita] $e');
      rethrow;
    }
  }

  @override
  Future<GenerarLiquidacionesEntity> generarLiquidaciones({
    required DateTime fechaInicio,
    required DateTime fechaFin,
  }) async {
    try {
      return await _dataSource.generarLiquidaciones(
        fechaInicio: fechaInicio,
        fechaFin: fechaFin,
      );
    } catch (e) {
      debugPrint('❌ [generarLiquidaciones] $e');
      rethrow;
    }
  }
}