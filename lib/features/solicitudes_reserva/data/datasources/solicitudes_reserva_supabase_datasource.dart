import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/config/app_constants.dart';
import '../../domain/entities/seguimiento_solicitud_entity.dart';
import '../../domain/entities/servicio_seleccionado_entity.dart';
import '../../domain/entities/solicitud_reserva_entity.dart';
import '../models/seguimiento_solicitud_model.dart';

/// Datasource de Supabase para el flujo de reserva del paciente.
/// Solo habla con Supabase y devuelve Models/entidades ligeras.
class SolicitudesReservaSupabaseDataSource {
  final SupabaseClient _client;

  SolicitudesReservaSupabaseDataSource(this._client);

  // ── Helpers ─────────────────────────────────────────────────

  Future<String?> _ensurePaciente(String profileId) async {
    final res = await _client
        .from('pacientes')
        .select('id')
        .eq('usuario_id', profileId)
        .maybeSingle();
    return res?['id'] as String?;
  }

  // ── Crear solicitud de reserva (RPC) ────────────────────────

  /// Llama a `crear_solicitud_reserva`: solicitud PENDIENTE_PAGO +
  /// solicitud_detalles + pagos PARCIAL. Devuelve el id y el depósito a cobrar.
  Future<SolicitudReservaEntity> crearSolicitudReserva({
    required String profileId,
    required List<ServicioSeleccionadoEntity> servicios,
    required String direccionId,
    DateTime? fechaProgramada,
    double? radioKm,
    String? observaciones,
    required bool pagoTotal,
  }) async {
    final pacienteId = await _ensurePaciente(profileId);
    if (pacienteId == null) {
      throw Exception('No se encontró el registro del paciente.');
    }
    if (servicios.isEmpty) {
      throw Exception('Selecciona al menos un servicio.');
    }

    final items = servicios
        .map((s) => {
              'servicio_id': s.servicioId,
              'cantidad': s.cantidad,
              'observaciones': null,
            })
        .toList();

    final res = await _client.rpc(
      AppConstants.rpcCrearSolicitudReserva,
      params: {
        'p_paciente_id': pacienteId,
        'p_items': items,
        'p_direccion_id': direccionId,
        'p_fecha_programada': fechaProgramada?.toUtc().toIso8601String(),
        'p_radio_km': radioKm,
        'p_observaciones': observaciones,
        'p_pago_total': pagoTotal,
      },
    );
    if (res == null) {
      throw Exception('No se pudo crear la solicitud.');
    }
    final json = Map<String, dynamic>.from(res as Map);
    return SolicitudReservaEntity(
      solicitudId: json['solicitud_id']?.toString() ?? '',
      total: (json['total'] as num?)?.toDouble() ?? 0,
      depositoRequerido: (json['deposito_requerido'] as num?)?.toDouble() ?? 0,
      saldoPendiente: (json['saldo_pendiente'] as num?)?.toDouble() ?? 0,
      moneda: json['moneda']?.toString() ?? 'USD',
    );
  }

  // ── Confirmar depósito (RPC) ────────────────────────────────

  /// Confirma el depósito y publica la solicitud. Devuelve 'CONFIRMADA' o
  /// 'PENDIENTE_WEBHOOK' (cuando la producción exige confirmación por webhook).
  Future<String> confirmarPagoDeposito({
    required String solicitudId,
    required String stripePaymentId,
    required String concepto,
    required double monto,
  }) async {
    try {
      final res = await _client.rpc(
        AppConstants.rpcConfirmarDepositoSolicitud,
        params: {
          'p_solicitud_id': solicitudId,
          'p_stripe_payment_id': stripePaymentId,
          'p_concepto': concepto,
          'p_monto': monto,
        },
      );
      if (res == null) {
        throw Exception('No se pudo confirmar el pago.');
      }
      final json = Map<String, dynamic>.from(res as Map);
      if (json['ok'] == true) {
        return 'CONFIRMADA';
      }
      throw Exception(json['motivo']?.toString() ?? 'Pago no confirmado');
    } on PostgrestException catch (e) {
      final message = e.message.toLowerCase();
      if (message.contains('webhook')) {
        return 'PENDIENTE_WEBHOOK';
      }
      rethrow;
    }
  }

  // ── Lecturas: mis solicitudes ───────────────────────────────

  Future<List<SeguimientoSolicitudModel>> fetchMisSolicitudes(
      String profileId) async {
    final pacienteId = await _ensurePaciente(profileId);
    if (pacienteId == null) return const [];

    final res = await _client
        .from('solicitudes')
        .select('''
          *,
          solicitud_detalles(id, servicio_id, cantidad, precio_unitario, servicios(nombre)),
          pagos(monto_total, deposito, saldo_pendiente, estado),
          citas(estado, fecha_aceptacion),
          direcciones_paciente(ciudad)
        ''')
        .eq('paciente_id', pacienteId)
        .order('fecha_solicitud', ascending: false);
    return res
        .map((json) =>
            SeguimientoSolicitudModel.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  Future<DireccionPrincipalEntity?> fetchMiDireccionPrincipal(
      String profileId) async {
    final pacienteId = await _ensurePaciente(profileId);
    if (pacienteId == null) return null;

    var res = await _client
        .from('direcciones_paciente')
        .select()
        .eq('paciente_id', pacienteId)
        .eq('es_principal', true)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    res ??= await _client
        .from('direcciones_paciente')
        .select()
        .eq('paciente_id', pacienteId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (res == null) return null;
    return DireccionPrincipalEntity(
      id: res['id']?.toString() ?? '',
      direccion: res['direccion']?.toString() ?? '',
      ciudad: res['ciudad']?.toString(),
      latitud: (res['latitud'] as num?)?.toDouble() ?? 0,
      longitud: (res['longitud'] as num?)?.toDouble() ?? 0,
    );
  }

  Future<ConfigReservaEntity> fetchConfigReserva() async {
    double radioKm = AppConstants.radioDefaultKm;
    bool enforcePagoReal = false;
    try {
      final rows = await _client
          .from('configuracion_sistema')
          .select('clave, valor')
          .inFilter('clave', ['radio_busqueda_km', 'enforce_pago_real']);
      for (final row in rows) {
        final clave = row['clave']?.toString();
        final valor = row['valor']?.toString();
        if (clave == 'radio_busqueda_km') {
          radioKm = double.tryParse(valor ?? '') ?? radioKm;
        } else if (clave == 'enforce_pago_real') {
          enforcePagoReal = valor?.toLowerCase() == 'true';
        }
      }
    } catch (e) {
      debugPrint('⚠️ [getConfigReserva] $e');
    }
    return ConfigReservaEntity(
      radioKm: radioKm,
      enforcePagoReal: enforcePagoReal,
    );
  }
}
