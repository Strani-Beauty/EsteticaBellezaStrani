import 'session_storage_cleaner_stub.dart'
    if (dart.library.html) 'session_storage_cleaner_web.dart' as impl;

/// Elimina SOLO el token de sesión persistido de Supabase, preservando el
/// code verifier de PKCE. Al cerrar la pestaña web no debe quedar un "usuario
/// activo" en caché, pero un link de confirmación/recovery pendiente debe
/// seguir funcionando en ese browser (necesita el verifier intacto).
Future<void> clearPersistedSessionKeepingPkceVerifier() =>
    impl.clearPersistedSessionKeepingPkceVerifier();

/// Variante síncrona para usar en listeners nativos del navegador
/// (`pagehide`/`beforeunload`), donde el código debe ejecutarse completo
/// antes del teardown de la página.
void clearPersistedSessionSynchronous() =>
    impl.clearPersistedSessionSynchronous();