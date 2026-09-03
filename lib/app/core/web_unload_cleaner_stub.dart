/// No-op fuera de web: los listeners nativos del navegador solo existen en
/// Flutter Web (`package:web`). Mobile/desktop usan `AppLifecycleState.detached`.
void registerWebUnloadCleaner(void Function() onUnload) {}

void unregisterWebUnloadCleaner(void Function() onUnload) {}