import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseClient _client = Supabase.instance.client;

  static SupabaseClient get client => _client;
  static User? get currentUser => _client.auth.currentUser;

  /// Autenticación e ingreso de usuario
  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Registro de un nuevo Usuario (Paciente, Especialista o Administrador) en Supabase
  static Future<AuthResponse> signUpUser({
    required String email,
    required String password,
    required String fullName,
    required String role,
    String? phone,
  }) async {
    // 1. Crear el usuario en Supabase Auth
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'role': role,
      },
    );

    final user = response.user;
    if (user != null) {
      // 2. Registrar/actualizar en la tabla `profiles`
      try {
        await _client.from('profiles').upsert({
          'id': user.id,
          'email': email,
          'full_name': fullName,
          'role': role,
          'activo': false,
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {}

      // 3. Si es Paciente/Cliente, registrar en la tabla `clients`
      if (role.toLowerCase() == 'paciente' || role.toLowerCase() == 'cliente') {
        try {
          await _client.from('clients').upsert({
            'id': user.id,
            'email': email,
            'full_name': fullName,
            'phone': phone ?? '',
            'created_at': DateTime.now().toIso8601String(),
          });
        } catch (_) {}
      }
    }

    return response;
  }

  /// Actualizar los datos del perfil del cliente (Profiles en Supabase)
  static Future<void> updateProfileData({
    required String userId,
    required String fullName,
    required String phone,
    required String address,
    required double latitude,
    required double longitude,
    bool? activo,
    bool? paymentCompleted,
    bool? evaluationPassed,
  }) async {
    final Map<String, dynamic> updateData = {
      'id': userId,
      'full_name': fullName,
      'phone': phone,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (activo != null) updateData['activo'] = activo;
    if (paymentCompleted != null) updateData['payment_completed'] = paymentCompleted;
    if (evaluationPassed != null) updateData['evaluation_passed'] = evaluationPassed;

    try {
      await _client.from('profiles').upsert(updateData);
    } catch (e) {
      // Fallback si la tabla profiles aún no tiene la columna address creada
      final Map<String, dynamic> fallbackData = {
        'id': userId,
        'full_name': fullName,
        'phone': phone,
      };
      if (activo != null) fallbackData['activo'] = activo;
      await _client.from('profiles').upsert(fallbackData);
    }
  }

  /// Obtener los roles disponibles de la tabla `roles` en Supabase
  static Future<List<Map<String, dynamic>>> fetchRoles() async {
    try {
      final data = await _client.from('roles').select().eq('activo', true);
      return List<Map<String, dynamic>>.from(data);
    } catch (_) {
      try {
        final fallback = await _client.from('roles').select();
        return List<Map<String, dynamic>>.from(fallback);
      } catch (_) {
        return [];
      }
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

  /// Cerrar sesión (SignOut)
  static Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Enviar enlace de restablecimiento de contraseña
  static Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }
}
