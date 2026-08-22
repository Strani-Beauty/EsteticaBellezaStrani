import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/config/app_constants.dart';
import '../../domain/entities/admin_kpis_entity.dart';
import '../../domain/entities/config_sistema_entity.dart';

/// Datasource de Supabase para el panel de administración (admin_config).
/// Solo habla con Supabase y devuelve entidades/Models.
class AdminConfigSupabaseDataSource {
  final SupabaseClient _client;

  AdminConfigSupabaseDataSource(this._client);

  Future<AdminKpisEntity> fetchKpis() async {
    final res = await _client.rpc(AppConstants.rpcAdminResumenKpis);
    if (res == null) {
      throw Exception('No se pudieron cargar los indicadores.');
    }
    return AdminKpisEntity.fromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<List<ConfigSistemaEntity>> fetchConfiguracion() async {
    final res = await _client
        .from('configuracion_sistema')
        .select()
        .order('clave');
    return res
        .map((json) => ConfigSistemaEntity(
              id: json['id']?.toString() ?? '',
              clave: json['clave']?.toString() ?? '',
              valor: json['valor']?.toString() ?? '',
              tipoDato: json['tipo_dato']?.toString() ?? '',
              descripcion: json['descripcion']?.toString(),
              activo: json['activo'] == true,
            ))
        .toList();
  }

  Future<void> updateConfiguracion(String clave, String valor) async {
    await _client.from('configuracion_sistema').update({
      'valor': valor,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('clave', clave);
  }
}
