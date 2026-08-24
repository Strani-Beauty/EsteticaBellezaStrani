import 'package:geolocator/geolocator.dart';

/// Resultado de la ubicación en vivo del dispositivo.
class GeoResult {
  final double latitud;
  final double longitud;
  final double? precisionMetros;
  const GeoResult({
    required this.latitud,
    required this.longitud,
    this.precisionMetros,
  });
}

/// Captura la posición GPS actual del dispositivo (geolocator).
class GeoService {
  /// Solicita permisos de ubicación y devuelve la posición actual.
  /// Lanza una [GeoPermissionDeniedException] si el permiso es denegado
  /// permanentemente, o [GeoServiceException] si no hay posición disponible.
  Future<GeoResult> obtenerPosicionActual() async {
    final servicio = await Geolocator.isLocationServiceEnabled();
    if (!servicio) {
      throw const GeoServiceException(
          'El servicio de ubicación está desactivado. Actívalo para registrar tu llegada.');
    }

    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }

    if (permiso == LocationPermission.denied) {
      throw const GeoServiceException(
          'Permiso de ubicación denegado. Habilítalo para registrar tu llegada.');
    }
    if (permiso == LocationPermission.deniedForever) {
      throw const GeoPermissionDeniedException();
    }

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );

    return GeoResult(
      latitud: pos.latitude,
      longitud: pos.longitude,
      precisionMetros: pos.accuracy,
    );
  }

  /// Devuelve el permiso actual sin abrir diálogos (para checks rápidos).
  Future<LocationPermission> checkPermiso() => Geolocator.checkPermission();
}

class GeoServiceException implements Exception {
  final String message;
  const GeoServiceException(this.message);

  @override
  String toString() => message;
}

class GeoPermissionDeniedException extends GeoServiceException {
  const GeoPermissionDeniedException()
      : super(
            'Permiso de ubicación denegado permanentemente. Habilítalo en los ajustes del dispositivo.');
}