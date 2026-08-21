import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/config/app_constants.dart';
import '../../domain/entities/adelanto_servicio_entity.dart';
import '../models/pago_model.dart';
import '../models/payment_intent_model.dart';

/// Datasource de Supabase para el módulo de pagos (payments_stripe).
/// Solo habla con Supabase y devuelve Models.
class PaymentsSupabaseDataSource {
  final SupabaseClient _client;

  PaymentsSupabaseDataSource(this._client);

  // ── Helpers ─────────────────────────────────────────────────

  Future<String?> _ensurePaciente(String profileId) async {
    final res = await _client
        .from('pacientes')
        .select('id')
        .eq('usuario_id', profileId)
        .maybeSingle();
    return res?['id'] as String?;
  }

  /// Lee el depósito configurado en `configuracion_sistema` (default $30).
  /// Solo aplica a la cuota inicial de Qualify (telemedicina/medicina interna).
  Future<double> _getDepositoReserva() async {
    try {
      final res = await _client
          .from('configuracion_sistema')
          .select('valor')
          .eq('clave', 'deposito_reserva')
          .maybeSingle();
      return double.tryParse(res?['valor']?.toString() ?? '')
              ?? AppConstants.depositoInicial;
    } catch (_) {
      return AppConstants.depositoInicial;
    }
  }

  /// Lee el porcentaje de adelanto de servicios en `configuracion_sistema`
  /// (default 50%).
  Future<double> _getAdelantoPorcentaje() async {
    try {
      final res = await _client
          .from('configuracion_sistema')
          .select('valor')
          .eq('clave', 'adelanto_porcentaje')
          .maybeSingle();
      final pct = double.tryParse(res?['valor']?.toString() ?? '');
      return (pct == null || pct <= 0) ? 50.0 : pct;
    } catch (_) {
      return 50.0;
    }
  }

  /// Calcula el adelanto de un servicio: porcentaje configurado aplicado al
  /// precio total, redondeado a 2 decimales.
  Future<AdelantoServicioEntity> calcularAdelanto(
      double servicePrice) async {
    final pct = await _getAdelantoPorcentaje();
    final monto = (servicePrice * pct / 100 * 100).round() / 100;
    return AdelantoServicioEntity(porcentaje: pct, monto: monto);
  }

  Future<String?> _getDireccionPrincipal(String pacienteId) async {
    try {
      final res = await _client
          .from('direcciones_paciente')
          .select('id')
          .eq('paciente_id', pacienteId)
          .eq('es_principal', true)
          .maybeSingle();
      return res?['id'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Usa el servicio indicado o, si no viene, el primer servicio activo.
  Future<String?> _resolveServicioId(String? servicioId) async {
    if (servicioId != null && servicioId.isNotEmpty) return servicioId;
    try {
      final res = await _client
          .from('servicios')
          .select('id')
          .eq('activo', true)
          .limit(1)
          .maybeSingle();
      return res?['id'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<double?> _precioServicio(String servicioId) async {
    try {
      final res = await _client
          .from('servicios')
          .select('precio_base')
          .eq('id', servicioId)
          .maybeSingle();
      return (res?['precio_base'] as num?)?.toDouble();
    } catch (_) {
      return null;
    }
  }

  // ── Stripe (edge function) ────────────────────────────────

  /// Invoca `create-payment-intent` y devuelve el modelo con el client_secret.
  Future<PaymentIntentModel> crearPaymentIntent({
    required double amount,
    required String concepto,
    String? solicitudId,
    String? citaId,
  }) async {
    final res = await _client.functions.invoke('create-payment-intent', body: {
      'amount': amount,
      'concepto': concepto,
      'solicitud_id': solicitudId,
      'cita_id': citaId,
    });
    if (res.status < 200 || res.status >= 300 || res.data == null) {
      final msg = res.data is Map
          ? (res.data['error']?.toString() ?? 'No se pudo iniciar el pago.')
          : 'No se pudo iniciar el pago.';
      throw Exception(msg);
    }
    return PaymentIntentModel.fromJson(Map<String, dynamic>.from(res.data));
  }

  // ── Cuota inicial (onboarding $30) ───────────────────────

  /// Marca payment_completed en profiles y activa el paciente.
  Future<void> registerInitialPayment({
    required String profileId,
    required double amount,
    required String paymentReference,
  }) async {
    final now = DateTime.now().toIso8601String();
    await _client.from('profiles').update({
      'payment_completed': true,
      'updated_at': now,
    }).eq('id', profileId);
    await _client.from('pacientes').update({
      'activo': true,
      'updated_at': now,
    }).eq('usuario_id', profileId);
  }

  // ── Solicitud + pago + transacción (al aprobarse Qualify) ─

  /// Crea la cadena `solicitudes` → `pagos` → `transacciones`.
  /// Se llama una única vez al aprobarse Qualify (depósito $30 ya cobrado).
  Future<String?> createSolicitudAndPayment({
    required String profileId,
    required String stripePaymentRef,
    String? servicioId,
  }) async {
    final pacienteId = await _ensurePaciente(profileId);
    if (pacienteId == null) {
      throw Exception('No se encontró el registro del paciente.');
    }

    final resolvedServicioId = await _resolveServicioId(servicioId);
    if (resolvedServicioId == null) {
      throw Exception('No hay servicios activos disponibles.');
    }

    final direccionId = await _getDireccionPrincipal(pacienteId);
    final deposito = await _getDepositoReserva();
    final precio = await _precioServicio(resolvedServicioId) ?? 0.0;
    final now = DateTime.now().toIso8601String();

    final solRes = await _client.from('solicitudes').insert({
      'paciente_id': pacienteId,
      'servicio_id': resolvedServicioId,
      'direccion_id': direccionId,
      'estado': AppConstants.solicitudBorrador,
      'fecha_solicitud': now,
      'deposito_requerido': deposito,
      'deposito_pagado': true,
    }).select('id').maybeSingle();
    final solicitudId = solRes?['id'] as String?;
    if (solicitudId == null) {
      throw Exception('No se pudo crear la solicitud.');
    }

    await _client.from('pagos').insert({
      'solicitud_id': solicitudId,
      'monto_total': precio,
      'deposito': deposito,
      'saldo_pendiente': (precio - deposito).clamp(0.0, double.infinity),
      'estado': precio <= deposito ? 'PAGADO' : 'PARCIAL',
    });

    await _client.from('transacciones').insert({
      'solicitud_id': solicitudId,
      'paciente_id': pacienteId,
      'tipo_transaccion': AppConstants.txDeposito,
      'monto': deposito,
      'moneda': 'USD',
      'estado': 'APROBADO',
      'stripe_payment_id': stripePaymentRef,
      'stripe_payment_intent': stripePaymentRef,
      'fecha_transaccion': now,
    });

    return solicitudId;
  }

  // ── Pago de servicio del catálogo (depósito o totalidad) ──

  /// Reserva un servicio específico: adelanto parcial o pago total.
  /// `montoAPagar` es el monto ya cobrado por Stripe (adelanto o totalidad).
  Future<String?> createServicePayment({
    required String profileId,
    required String servicioId,
    required double servicePrice,
    required bool payFullAmount,
    required double montoAPagar,
    required String stripePaymentRef,
  }) async {
    final pacienteId = await _ensurePaciente(profileId);
    if (pacienteId == null) {
      throw Exception('No se encontró el registro del paciente.');
    }

    final resolvedServicioId = await _resolveServicioId(servicioId);
    if (resolvedServicioId == null) {
      throw Exception('No hay servicios activos disponibles.');
    }

    final direccionId = await _getDireccionPrincipal(pacienteId);
    final saldoPendiente =
        (servicePrice - montoAPagar).clamp(0.0, double.infinity);
    final now = DateTime.now().toIso8601String();

    final solRes = await _client.from('solicitudes').insert({
      'paciente_id': pacienteId,
      'servicio_id': resolvedServicioId,
      'direccion_id': direccionId,
      'estado': payFullAmount
          ? AppConstants.solicitudPublicada
          : AppConstants.solicitudBorrador,
      'fecha_solicitud': now,
      'deposito_requerido': montoAPagar,
      'deposito_pagado': true,
    }).select('id').maybeSingle();
    final solicitudId = solRes?['id'] as String?;
    if (solicitudId == null) {
      throw Exception('No se pudo crear la solicitud.');
    }

    await _client.from('pagos').insert({
      'solicitud_id': solicitudId,
      'monto_total': servicePrice,
      'deposito': montoAPagar,
      'saldo_pendiente': saldoPendiente,
      'estado': montoAPagar >= servicePrice ? 'PAGADO' : 'PARCIAL',
    });

    await _client.from('transacciones').insert({
      'solicitud_id': solicitudId,
      'paciente_id': pacienteId,
      'tipo_transaccion':
          payFullAmount ? 'PAGO_TOTAL' : AppConstants.txDeposito,
      'monto': montoAPagar,
      'moneda': 'USD',
      'estado': 'APROBADO',
      'stripe_payment_id': stripePaymentRef,
      'stripe_payment_intent': stripePaymentRef,
      'fecha_transaccion': now,
    });

    // Vincula el face map (guardado antes del pago) a esta solicitud para poder
    // trazarlo hacia el tratamiento/pago al re-seleccionar el servicio.
    try {
      await _client
          .from('face_maps')
          .update({'solicitud_id': solicitudId})
          .eq('paciente_id', pacienteId)
          .eq('servicio_id', resolvedServicioId)
          .isFilter('solicitud_id', null);
    } catch (e) {
      debugPrint('⚠️ [createServicePayment] Nota DB (vincular face map): $e');
    }

    return solicitudId;
  }

  // ── Saldo final al terminar tratamiento ───────────────────

  /// Cobra el saldo pendiente: actualiza `pagos` a PAGADO y registra la
  /// transacción SALDO vinculada a la cita.
  /// Devuelve `false` si no había saldo pendiente (nada que cobrar).
  Future<bool> registrarPagoSaldo({
    required String citaId,
    required String solicitudId,
    required double monto,
    required String stripePaymentRef,
  }) async {
    final sol = await _client
        .from('solicitudes')
        .select('paciente_id')
        .eq('id', solicitudId)
        .maybeSingle();
    final pacienteId = sol?['paciente_id'] as String?;
    if (pacienteId == null) {
      throw Exception('No se encontró la solicitud de la cita.');
    }

    final pagoRes = await _client
        .from('pagos')
        .select('saldo_pendiente')
        .eq('solicitud_id', solicitudId)
        .maybeSingle();
    final saldo = (pagoRes?['saldo_pendiente'] as num?)?.toDouble() ?? 0.0;
    if (saldo <= 0) return false; // ya está cubierto

    final now = DateTime.now().toIso8601String();
    await _client.from('pagos').update({
      'estado': 'PAGADO',
      'saldo_pendiente': 0,
      'updated_at': now,
    }).eq('solicitud_id', solicitudId);

    await _client.from('transacciones').insert({
      'solicitud_id': solicitudId,
      'cita_id': citaId,
      'paciente_id': pacienteId,
      'tipo_transaccion': AppConstants.txSaldo,
      'monto': monto,
      'moneda': 'USD',
      'estado': 'APROBADO',
      'stripe_payment_id': stripePaymentRef,
      'stripe_payment_intent': stripePaymentRef,
      'fecha_transaccion': now,
    });

    return true;
  }

  // ── Lecturas ──────────────────────────────────────────────

  Future<PagoModel?> consultarPago({required String solicitudId}) async {
    final res = await _client
        .from('pagos')
        .select()
        .eq('solicitud_id', solicitudId)
        .maybeSingle();
    if (res == null) return null;
    return PagoModel.fromJson(Map<String, dynamic>.from(res));
  }
}