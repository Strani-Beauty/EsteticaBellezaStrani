import 'package:latlong2/latlong.dart';

/// Motor de mapa.
enum MapEngine {
  openStreetMap,
  google,
}

const kActiveMapEngine = MapEngine.openStreetMap;

/// Tiles raster de OpenStreetMap (gratis, sin API key).
const kOsmTileUrlTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

/// User-Agent de aplicación para Nominatim.
const kNominatimUserAgent = 'EsteticaBellezaStrani/2.0';

/// Package name para TileLayer de OSM.
const kUserAgentPackageName = 'com.esteticaybellezastrani.app';

/// Delay mínimo entre solicitudes de geocoding (rate limit Nominatim ~1 req/s).
const kGeocodeMinIntervalMs = 1100;

/// Ubicación por defecto centrada en Houston, Texas, USA (mercado de la app).
const kDefaultLocation = LatLng(29.7604, -95.3698);
const kDefaultMapZoom = 13.0;
const kFocusMapZoom = 16.0;

/// Validador de coordenadas
bool isValidMapCoordinate(double? lat, double? lng) {
  if (lat == null || lng == null) return false;
  if (lat == 0 && lng == 0) return false;
  return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
}
