import 'web_unload_cleaner_stub.dart'
    if (dart.library.html) 'web_unload_cleaner_web.dart' as impl;

/// Registra un callback que se invoca cuando la pestaña/ventana web se cierra
/// o refresca (F5), vía listeners nativos `pagehide`/`beforeunload`. El
/// callback debe ser síncrono para completarse antes del teardown del navegador.
void registerWebUnloadCleaner(void Function() onUnload) =>
    impl.registerWebUnloadCleaner(onUnload);

/// Desregistra el callback previamente registrado con `registerWebUnloadCleaner`.
void unregisterWebUnloadCleaner(void Function() onUnload) =>
    impl.unregisterWebUnloadCleaner(onUnload);