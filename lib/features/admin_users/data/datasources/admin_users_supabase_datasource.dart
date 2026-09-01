import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/paciente_admin_model.dart';
import '../models/usuario_admin_model.dart';

/// Datasource de Supabase para la administración de usuarios.
/// Solo habla con Supabase y devuelve Models.
class AdminUsersSupabaseDataSource {
  final SupabaseClient _client;

  AdminUsersSupabaseDataSource(this._client);

  /// Lista todos los perfiles. Las policies `profiles_admin_select`
  /// garantizan que solo un Administrador obtenga filas.
  Future<List<UsuarioAdminModel>> fetchUsuarios() async {
    final res = await _client
        .from('profiles')
        .select('id, email, full_name, phone, role, activo, created_at')
        .order('created_at', ascending: true);

    return res
        .map((json) => UsuarioAdminModel.fromJson(
            Map<String, dynamic>.from(json as Map)))
        .toList();
  }

  /// Activa/desactiva la cuenta de un usuario (política `profiles_admin_update`).
  Future<void> setActivo(String userId, bool activo) async {
    await _client
        .from('profiles')
        .update({'activo': activo})
        .eq('id', userId);
  }

  /// Lista pacientes con su perfil embebido. Policies `pacientes_admin_select`
  /// (00300) garantizan que solo un Administrador obtenga filas.
  Future<List<PacienteAdminModel>> fetchPacientesAdmin() async {
    final res = await _client
        .from('pacientes')
        .select('id, usuario_id, activo, profiles(full_name, email, phone, activo)')
        .order('created_at', ascending: true);

    return res
        .map((json) => PacienteAdminModel.fromJson(
            Map<String, dynamic>.from(json as Map)))
        .toList();
  }
}