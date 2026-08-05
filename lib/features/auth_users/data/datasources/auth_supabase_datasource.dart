import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_model.dart';

/// Datasource de Supabase para el módulo auth_users.
/// Solo habla con Supabase y devuelve Models.
class AuthSupabaseDataSource {
  final SupabaseClient _client;

  AuthSupabaseDataSource(this._client);

  // ── Auth ────────────────────────────────────────────────────

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Registrar usuario en auth + crear perfil + crear paciente
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String rolNombre,
    String? phone,
  }) async {
    final String role = (rolNombre.toLowerCase() == 'paciente' ||
            rolNombre.toLowerCase() == 'cliente')
        ? 'Paciente'
        : rolNombre;

    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'role': role,
      },
    );

    return response;
  }

  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      // gotrue ya limpia la sesión local antes del revoke en servidor.
      // Si el revoke falla (red/servidor), no debe bloquear el logout.
      debugPrint('⚠️ signOut revoke en servidor falló (se ignora): $e');
    }
  }

  /// Limpia la sesión local sin revocar tokens en el servidor.
  /// Usado al cerrar la app/web para no depender de red.
  Future<void> removeLocalSession() async {
    try {
      await _client.auth.signOut(scope: SignOutScope.local);
    } catch (e) {
      debugPrint('⚠️ removeLocalSession falló (se ignora): $e');
    }
  }

  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  // ── Helper de Selección Tolerante ────────────────────────────

  Future<Map<String, dynamic>?> _selectProfileQuery(String id) async {
    try {
      final res = await _client
          .from('profiles')
          .select()
          .eq('id', id)
          .maybeSingle();
      return res;
    } catch (e) {
      debugPrint('⚠️ Error consultando perfil id=$id: $e');
      return null;
    }
  }

  // ── Profile ─────────────────────────────────────────────────

  Future<ProfileModel?> fetchCurrentProfile() async {
    final user = currentUser;
    if (user == null) return null;

    final data = await _selectProfileQuery(user.id);
    if (data == null) return null;
    return ProfileModel.fromJson(data);
  }

  Future<ProfileModel> fetchProfileById(String id) async {
    final data = await _selectProfileQuery(id);
    if (data == null) {
      throw Exception('Perfil $id no encontrado');
    }
    return ProfileModel.fromJson(data);
  }

  /// Crear perfil en `profiles` y registro en `pacientes`.
  /// Llamado inmediatamente después del signUp exitoso.
  /// El trigger `handle_new_user` de la BD ya crea perfil y paciente;
  /// este método es un respaldo tolerante para usuarios pre-trigger.
  Future<ProfileModel> createProfile({
    required String id,
    required String email,
    required String fullName,
    required String rolNombre,
    String? phone,
  }) async {
    final String role = (rolNombre.toLowerCase() == 'paciente' ||
            rolNombre.toLowerCase() == 'cliente')
        ? 'Paciente'
        : rolNombre;

    debugPrint('📝 [createProfile] Creando perfil para id=$id role=$role');

    // 1. UPSERT en profiles
    final profilePayload = {
      'id': id,
      'email': email,
      'full_name': fullName,
      'role': role,
      'phone': phone ?? '',
      'activo': false,
      'payment_completed': false,
      'evaluation_passed': false,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    try {
      await _client.from('profiles').upsert(profilePayload, onConflict: 'id');
      debugPrint('✅ [createProfile] profiles upsertado correctamente');
    } catch (e) {
      debugPrint('❌ [createProfile] ERROR en profiles.upsert: $e');
      // Intentar update si la fila ya existe
      try {
        await _client.from('profiles').update({
          'full_name': fullName,
          'role': role,
          'phone': phone ?? '',
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', id);
        debugPrint('✅ [createProfile] profiles.update fallback ok');
      } catch (e2) {
        debugPrint('❌ [createProfile] FALLBACK profiles.update ERROR: $e2');
      }
    }

    // 2. UPSERT en pacientes si es Paciente (columna canónica: usuario_id)
    if (role == 'Paciente') {
      try {
        await _client.from('pacientes').upsert({
          'usuario_id': id,
          'activo': false,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'usuario_id');
        debugPrint('✅ [createProfile] pacientes upsertado correctamente');
      } catch (e) {
        debugPrint('❌ [createProfile] ERROR en pacientes.upsert: $e');
        try {
          await _client.from('pacientes').insert({
            'usuario_id': id,
            'activo': false,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
          debugPrint('✅ [createProfile] pacientes.insert fallback ok');
        } catch (e2) {
          debugPrint('❌ [createProfile] FALLBACK pacientes.insert ERROR: $e2');
        }
      }
    }

    final data = await _selectProfileQuery(id) ?? profilePayload;
    return ProfileModel.fromJson(data);
  }

  Future<ProfileModel> updateProfile(Map<String, dynamic> updateData) async {
    final id = updateData['id'] as String;
    final dataToUpdate = Map<String, dynamic>.from(updateData)..remove('id');
    dataToUpdate['updated_at'] = DateTime.now().toIso8601String();

    // Normalizar rol
    if (dataToUpdate.containsKey('role')) {
      final r = dataToUpdate['role'].toString().toLowerCase();
      if (r == 'paciente' || r == 'cliente') {
        dataToUpdate['role'] = 'Paciente';
      }
    }

    debugPrint('📝 [updateProfile] Actualizando profile para id=$id');
    debugPrint('📝 [updateProfile] Datos: $dataToUpdate');

    try {
      await _client.from('profiles').update(dataToUpdate).eq('id', id);
      debugPrint('✅ [updateProfile] profiles actualizado correctamente');
    } catch (e) {
      debugPrint('❌ [updateProfile] ERROR en profiles.update: $e');
      // Fallback: upsert completo
      try {
        final upsertData = Map<String, dynamic>.from(dataToUpdate);
        upsertData['id'] = id;
        await _client.from('profiles').upsert(upsertData, onConflict: 'id');
        debugPrint('✅ [updateProfile] profiles.upsert fallback ok');
      } catch (err) {
        debugPrint('❌ [updateProfile] FALLBACK upsert ERROR: $err');
      }
    }

    // Sincronización en la tabla pacientes (columna canónica: usuario_id)
    try {
      await _client.from('pacientes').upsert({
        'usuario_id': id,
        'activo': dataToUpdate['activo'] ?? false,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'usuario_id');
      debugPrint('✅ [updateProfile] pacientes sincronizado para $id');
    } catch (e) {
      debugPrint('❌ [updateProfile] ERROR pacientes.upsert: $e');
      try {
        await _client.from('pacientes').insert({
          'usuario_id': id,
          'activo': dataToUpdate['activo'] ?? false,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
        debugPrint('✅ [updateProfile] pacientes.insert fallback ok');
      } catch (e2) {
        debugPrint('❌ [updateProfile] FALLBACK pacientes.insert ERROR: $e2');
      }
    }

    final data = await _selectProfileQuery(id);
    if (data == null) {
      return ProfileModel(
        id: id,
        email: '',
        fullName: dataToUpdate['full_name'] as String?,
        rolNombre: 'Paciente',
        phone: dataToUpdate['phone'] as String?,
        address: dataToUpdate['address'] as String?,
        latitude: (dataToUpdate['latitude'] as num?)?.toDouble(),
        longitude: (dataToUpdate['longitude'] as num?)?.toDouble(),
        activo: dataToUpdate['activo'] as bool? ?? false,
        paymentCompleted: dataToUpdate['payment_completed'] as bool? ?? false,
        evaluationPassed: dataToUpdate['evaluation_passed'] as bool? ?? false,
        createdAt: DateTime.now(),
      );
    }
    return ProfileModel.fromJson(data);
  }

  // ── Roles ────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchRoles() async {
    try {
      final data = await _client
          .from('roles')
          .select()
          .eq('activo', true)
          .order('name');
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

  // ── Dispositivos / FCM ───────────────────────────────────────

  Future<void> upsertFcmToken({
    required String profileId,
    required String fcmToken,
    String? plataforma,
  }) async {
    await _client.from('dispositivos_usuario').upsert({
      'profile_id': profileId,
      'fcm_token':  fcmToken,
      'plataforma': plataforma,
      'activo':     true,
      'last_seen_at': DateTime.now().toIso8601String(),
    }, onConflict: 'fcm_token');
  }

  Future<void> deactivateFcmToken(String token) async {
    await _client
        .from('dispositivos_usuario')
        .update({'activo': false})
        .eq('fcm_token', token);
  }
}
