import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Mapa para poder desregistrar exactamente el mismo `JSFunction` que se
/// registró (`removeEventListener` exige la misma referencia).
final Map<void Function(), web.EventListener> _listeners = {};

web.EventListener _listenerFor(void Function() onUnload) =>
    _listeners.putIfAbsent(
      onUnload,
      () => ((web.Event _) {
        onUnload();
      }).toJS,
    );

void registerWebUnloadCleaner(void Function() onUnload) {
  final listener = _listenerFor(onUnload);
  web.window.addEventListener('pagehide', listener);
  web.window.addEventListener('beforeunload', listener);
}

void unregisterWebUnloadCleaner(void Function() onUnload) {
  final listener = _listeners.remove(onUnload);
  if (listener == null) return;
  web.window.removeEventListener('pagehide', listener);
  web.window.removeEventListener('beforeunload', listener);
}