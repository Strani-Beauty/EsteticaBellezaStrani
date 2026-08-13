import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/config/app_constants.dart';
import '../models/especialista_mapa_model.dart';
import '../models/resultado_aceptacion_model.dart';
import '../models/solicitud_pendiente_model.dart';

/// Datasource de Supabase para el módulo marketplace_citas.
/// Solo habla con Supabase y devuelve Models.
class MarketplaceSupabaseDataSource {
  final SupabaseClient _client;

  MarketplaceSupabaseDataSource(this._client);

  // ── Solicitudes pendientes ─────────────────────────────────

  /// Obtiene las solicitudes publicadas con ubicación APROXIMADA del paciente
  /// (RN-018): el RPC `obtener_solicitudes_publicadas_geo` trunca las
  /// coordenadas a 3 decimales (~110 m) y no devuelve la dirección exacta.
  Future<List<SolicitudPendienteModel>> fetchSolicitudesPendientes() async {
    final res = await _client.rpc(
      AppConstants.rpcObtenerSolicitudesPublicadasGeo,
    );
    if (res == null) return [];
    return (res as List)
        .map((json) => SolicitudPendienteModel.fromJson(
            Map<String, dynamic>.from(json as Map)))
        .toList();
  }

  // ── Especialistas aprobados ────────────────────────────────

  Future<List<EspecialistaMapaModel>> fetchEspecialistasAprobados() async {
    final cutoff = DateTime.now()
        .subtract(const Duration(seconds: AppConstants.umbralOnlineSegundos))
        .toUtc()
        .toIso8601String();
    final res = await _client
        .from('especialistas')
        .select(
          'id, disponible, activo, en_linea, '
          'profiles(full_name), '
          'ubicaciones_especialista(id, latitud, longitud, order=created_at.desc, limit=1)',
        )
        .eq('estado_verificacion', AppConstants.estadoAprobado)
        .eq('activo', true)
        .eq('disponible', true)
        .eq('en_linea', true)
        .gt('ultima_conexion', cutoff);
    return res
        .map((json) => EspecialistaMapaModel.fromJson(json))
        .toList();
  }

  // ── Ubicación del especialista actual ─────────────────────

  Future<(double?, double?)> fetchMiUbicacion(String especialistaId) async {
    final res = await _client
        .from('ubicaciones_especialista')
        .select('latitud, longitud')
        .eq('especialista_id', especialistaId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (res == null) return (null, null);
    return ((res['latitud'] as num?)?.toDouble(),
        (res['longitud'] as num?)?.toDouble());
  }

  // ── Aceptar solicitud (primer aviso gana) ─────────────────

  Future<ResultadoAceptacionModel> aceptarSolicitud({
    required String solicitudId,
    required String especialistaId,
  }) async {
    final res = await _client.rpc(
      AppConstants.rpcAceptarSolicitud,
      params: {
        'p_solicitud_id': solicitudId,
        'p_especialista_id': especialistaId,
      },
    );
    if (res == null) {
      throw Exception('No se pudo aceptar la solicitud');
    }
    return ResultadoAceptacionModel.fromJson(
        Map<String, dynamic>.from(res as Map));
  }
}
