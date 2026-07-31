import 'dart:async';

/// Debouncer para búsquedas y eventos frecuentes.
/// Evita llamadas excesivas a la API cuando el usuario escribe.
///
/// Uso:
/// ```dart
/// final _debouncer = Debouncer(delay: AppConstants.debounceDuration);
/// _debouncer.run(() => _searchSpecialists(query));
/// ```
class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({this.delay = const Duration(milliseconds: 500)});

  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void dispose() {
    _timer?.cancel();
  }
}
