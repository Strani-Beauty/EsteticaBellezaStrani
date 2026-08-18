import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notificacion_model.dart';

/// Datasource de Supabase para el módulo notifications.
/// Solo habla con Supabase y devuelve Models.
class NotificationsSupabaseDataSource {
  final SupabaseClient _client;

  NotificationsSupabaseDataSource(this._client);

  Future<List<NotificacionModel>> fetchNotificaciones(String usuarioId) async {
    final res = await _client
        .from('notificaciones')
        .select()
        .eq('usuario_id', usuarioId)
        .order('fecha_envio', ascending: false);
    return res
        .map((json) => NotificacionModel.fromJson(json))
        .toList();
  }

  Future<void> marcarLeida(String notificacionId) async {
    await _client
        .from('notificaciones')
        .update({'leida': true})
        .eq('id', notificacionId);
  }

  Future<void> marcarTodasLeidas(String usuarioId) async {
    await _client
        .from('notificaciones')
        .update({'leida': true})
        .eq('usuario_id', usuarioId)
        .eq('leida', false);
  }
}
