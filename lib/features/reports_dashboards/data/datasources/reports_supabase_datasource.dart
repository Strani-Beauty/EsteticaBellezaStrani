import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:esteticaybellezastrani/app/config/app_constants.dart';
import '../models/ventas_models.dart';

/// Datasource de Supabase para el módulo reports_dashboards.
///
/// Solo habla con Supabase (RPCs agregadores SECURITY DEFINER del dashboard
/// de ventas) y devuelve Models.
class ReportsSupabaseDataSource {
  final SupabaseClient _client;

  ReportsSupabaseDataSource(this._client);

  Future<ResumenVentasModel> fetchResumenVentas({
    required DateTime desde,
    required DateTime hasta,
  }) async {
    final res = await _client.rpc(
      AppConstants.rpcDashboardVentasResumen,
      params: {
        'p_desde': desde.toUtc().toIso8601String(),
        'p_hasta': hasta.toUtc().toIso8601String(),
      },
    );
    if (res is Map<String, dynamic>) {
      if (res['error'] == 'NO_AUTORIZADO') {
        throw Exception('No autorizado para consultar ventas.');
      }
      return ResumenVentasModel.fromJson(res);
    }
    if (res is List && res.isNotEmpty && res.first is Map<String, dynamic>) {
      return ResumenVentasModel.fromJson(res.first as Map<String, dynamic>);
    }
    return const ResumenVentasModel(
      montosRecibidos: 0,
      montosPagados: 0,
      comisionPorcentaje: 20,
      netoEspecialistas: 0,
      citasRealizadas: 0,
      serviciosAplicados: 0,
      solicitudes: 0,
      usuariosActivos: 0,
    );
  }

  Future<List<VentaPorServicioModel>> fetchVentasPorServicio({
    required DateTime desde,
    required DateTime hasta,
  }) async {
    final res = await _client.rpc(
      AppConstants.rpcDashboardVentasPorServicio,
      params: {
        'p_desde': desde.toUtc().toIso8601String(),
        'p_hasta': hasta.toUtc().toIso8601String(),
      },
    );
    return _parseList<VentaPorServicioModel>(
      res,
      VentaPorServicioModel.fromJson,
    );
  }

  Future<List<VentaPorEspecialistaModel>> fetchVentasPorEspecialista({
    required DateTime desde,
    required DateTime hasta,
  }) async {
    final res = await _client.rpc(
      AppConstants.rpcDashboardVentasPorEspecialista,
      params: {
        'p_desde': desde.toUtc().toIso8601String(),
        'p_hasta': hasta.toUtc().toIso8601String(),
      },
    );
    return _parseList<VentaPorEspecialistaModel>(
      res,
      VentaPorEspecialistaModel.fromJson,
    );
  }

  Future<List<PuntoSerieVentasModel>> fetchSerieVentas({
    required DateTime desde,
    required DateTime hasta,
    String agrupacion = 'day',
  }) async {
    final res = await _client.rpc(
      AppConstants.rpcDashboardVentasSerie,
      params: {
        'p_desde': desde.toUtc().toIso8601String(),
        'p_hasta': hasta.toUtc().toIso8601String(),
        'p_agrupacion': agrupacion,
      },
    );
    return _parseList<PuntoSerieVentasModel>(
      res,
      PuntoSerieVentasModel.fromJson,
    );
  }

  List<T> _parseList<T>(
    dynamic res,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (res is List) {
      return [
        for (final item in res)
          if (item is Map<String, dynamic>) fromJson(item),
      ];
    }
    return const [];
  }
}