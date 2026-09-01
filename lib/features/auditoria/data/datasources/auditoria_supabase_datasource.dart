import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/auditoria_entity.dart';

/// Datasource de Supabase para la auditoría (tabla `public.auditoria`).
/// Policy `auditoria_admin_select` garantiza que solo un Administrador
/// obtenga filas.
class AuditoriaSupabaseDataSource {
  final SupabaseClient _client;

  AuditoriaSupabaseDataSource(this._client);

  /// Consulta registros de auditoría con filtros opcionales (entidad, acción,
  /// rango de fechas), orden cronológico descendente.
  Future<List<AuditoriaEntity>> fetchAuditoria({
    String? entidad,
    String? accion,
    DateTime? desde,
    DateTime? hasta,
    int? limite,
  }) async {
    var query = _client
        .from('auditoria')
        .select('*, profiles(full_name, email)');

    if (entidad != null && entidad.isNotEmpty) {
      query = query.eq('entidad', entidad);
    }
    if (accion != null && accion.isNotEmpty) {
      query = query.eq('accion', accion);
    }
    if (desde != null) {
      query = query.gte('fecha', desde.toIso8601String());
    }
    if (hasta != null) {
      query = query.lte('fecha', hasta.toIso8601String());
    }

    var ordered = query.order('fecha', ascending: false);
    if (limite != null) {
      ordered = ordered.limit(limite);
    }

    final res = await ordered;
    return res
        .map((json) => _fromJson(Map<String, dynamic>.from(json as Map)))
        .toList();
  }

  AuditoriaEntity _fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? profile;
    final profiles = json['profiles'];
    if (profiles is Map) {
      profile = Map<String, dynamic>.from(profiles);
    } else if (profiles is List && profiles.isNotEmpty) {
      profile = Map<String, dynamic>.from(profiles.first as Map);
    }

    return AuditoriaEntity(
      id: json['id']?.toString() ?? '',
      usuarioId: json['usuario_id']?.toString(),
      usuarioNombre: profile?['full_name'] as String?,
      accion: json['accion']?.toString() ?? '',
      entidad: json['entidad']?.toString() ?? '',
      entidadId: json['entidad_id']?.toString(),
      detalle: json['detalle'] is Map
          ? Map<String, dynamic>.from(json['detalle'] as Map)
          : null,
      fecha: DateTime.tryParse(json['fecha']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}