import 'package:web/web.dart' as web;

/// En web el token de sesión se persiste en `window.localStorage` con claves
/// `sb-<project>-auth-token`. Se eliminan esas claves (y solo esas): el code
/// verifier de PKCE vive en `flutter.supabase.auth.token-code-verifier` (vía
/// SharedPreferences) y debe quedar intacto para completar enlaces pendientes.
Future<void> clearPersistedSessionKeepingPkceVerifier() async {
  final storage = web.window.localStorage;
  final staleKeys = <String>[];
  for (var i = 0; i < storage.length; i++) {
    final key = storage.key(i);
    if (key != null && RegExp(r'^sb-.*-auth-token$').hasMatch(key)) {
      staleKeys.add(key);
    }
  }
  for (final key in staleKeys) {
    storage.removeItem(key);
  }
}