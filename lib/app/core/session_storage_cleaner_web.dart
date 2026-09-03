import 'package:web/web.dart' as web;

/// En web el token de sesión se persiste en `window.localStorage` con claves
/// `sb-<project>-auth-token`. Se eliminan esas claves (y solo esas): el code
/// verifier de PKCE vive en `flutter.supabase.auth.token-code-verifier` (vía
/// SharedPreferences) y debe quedar intacto para completar enlaces pendientes.
Future<void> clearPersistedSessionKeepingPkceVerifier() async {
  clearPersistedSessionSynchronous();
}

/// Versión 100% síncrona: se ejecuta completa antes del teardown del navegador
/// al cerrar/refrescar la pestaña (eventos `pagehide`/`beforeunload`), sin
/// depender del ciclo de vida de Flutter (AppLifecycleState.detached no llega
/// de forma fiable en todos los navegadores).
void clearPersistedSessionSynchronous() {
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