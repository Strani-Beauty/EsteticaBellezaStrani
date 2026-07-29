import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseClient _client = Supabase.instance.client;

  static SupabaseClient get client => _client;
  static User? get currentUser => _client.auth.currentUser;

  /// Autenticación e ingreso de usuarios/empleados/clientes
  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Registro de un nuevo Cliente en Supabase (Auth + Tabla Clients + Profiles)
  static Future<AuthResponse> signUpClient({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    // 1. Crear el usuario en Supabase Auth
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'role': 'client',
      },
    );

    final user = response.user;
    if (user != null) {
      // 2. Registrar en la tabla `Profiles`
      await _client.from('profiles').upsert({
        'id': user.id,
        'email': email,
        'full_name': fullName,
        'role': 'client',
        'created_at': DateTime.now().toIso8601String(),
      });

      // 3. Registrar en la tabla `Clients`
      await _client.from('clients').upsert({
        'id': user.id,
        'email': email,
        'full_name': fullName,
        'phone': phone ?? '',
        'created_at': DateTime.now().toIso8601String(),
      });
    }

    return response;
  }

  /// Obtener los roles disponibles de la tabla `roles` en Supabase
  static Future<List<Map<String, dynamic>>> fetchRoles() async {
    try {
      final data = await _client.from('roles').select();
      return List<Map<String, dynamic>>.from(data);
    } catch (_) {
      return [];
    }
  }

  /// Obtener el perfil del usuario actual desde la tabla `profiles`
  static Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      return response;
    } catch (_) {
      return null;
    }
  }

  /// Cerrar sesión
  static Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Enviar enlace de restablecimiento de contraseña
  static Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }
}
