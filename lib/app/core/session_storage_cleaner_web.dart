// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// En web el token de sesión se persiste en `window.localStorage` con claves
/// `sb-<project>-auth-token`. Se eliminan esas claves (y solo esas): el code
/// verifier de PKCE vive en `flutter.supabase.auth.token-code-verifier` (vía
/// SharedPreferences) y debe quedar intacto para completar enlaces pendientes.
Future<void> clearPersistedSessionKeepingPkceVerifier() async {
  final storage = html.window.localStorage;
  final staleKeys = storage.keys
      .where((key) => RegExp(r'^sb-.*-auth-token$').hasMatch(key))
      .toList();
  for (final key in staleKeys) {
    storage.remove(key);
  }
}