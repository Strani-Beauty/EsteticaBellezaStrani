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

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String rolNombre,
    String? phone,
  }) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'role': rolNombre,
      },
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  // ── Profile ─────────────────────────────────────────────────

  Future<ProfileModel?> fetchCurrentProfile() async {
    final user = currentUser;
    if (user == null) return null;

    final data = await _client
        .from('profiles')
        .select('*, roles(name)')
        .eq('id', user.id)
        .maybeSingle();

    if (data == null) return null;
    return ProfileModel.fromJson(data);
  }

  Future<ProfileModel> fetchProfileById(String id) async {
    final data = await _client
        .from('profiles')
        .select('*, roles(name)')
        .eq('id', id)
        .single();
    return ProfileModel.fromJson(data);
  }

  Future<ProfileModel> createProfile({
    required String id,
    required String email,
    required String fullName,
    required String rolNombre,
    String? phone,
  }) async {
    final payload = {
      'id':        id,
      'email':     email,
      'full_name': fullName,
      'phone':     phone,
      'activo':    false,
      'payment_completed': false,
      'evaluation_passed': false,
      'created_at': DateTime.now().toIso8601String(),
    };

    final data = await _client
        .from('profiles')
        .upsert(payload)
        .select('*, roles(name)')
        .single();

    return ProfileModel.fromJson(data);
  }

  Future<ProfileModel> updateProfile(Map<String, dynamic> updateData) async {
    final id = updateData['id'] as String;
    updateData.remove('id'); // id no debe ir en el update body
    updateData['updated_at'] = DateTime.now().toIso8601String();

    final data = await _client
        .from('profiles')
        .update(updateData)
        .eq('id', id)
        .select('*, roles(name)')
        .single();

    return ProfileModel.fromJson(data);
  }

  // ── Roles ────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchRoles() async {
    final data = await _client
        .from('roles')
        .select()
        .eq('activo', true)
        .order('name');
    return List<Map<String, dynamic>>.from(data);
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
