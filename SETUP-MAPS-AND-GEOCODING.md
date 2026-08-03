# Mapas, Ubicación y Búsqueda de Direcciones — Guía de Instalación

> Guía extraída del proyecto **MBO Roofing** (Flutter). Stack: **flutter_map + OpenStreetMap + Nominatim**, **sin API keys** para el mapa base.

---

## 0. TL;DR — qué se usa

| Pieza | Librería / Servicio | ¿Requiere API key? |
|---|---|---|
| Mapa (vista) | `flutter_map` (tiles raster tipo Leaflet) | No |
| Tiles del mapa | OpenStreetMap (`tile.openstreetmap.org`) | No (gratis) |
| Coordenadas (lat/lng) | `latlong2` | No |
| Geocoding (dirección → coords) | Supabase Edge Function + **Nominatim** | No (gratis, ~1 req/s) |
| Abrir mapas externos | `url_launcher` (Google Maps URL) | No |
| (Opcional) Google Maps/Geocoding | Google Maps APIs | Sí |

**No se usa**: Google Maps SDK nativo, Mapbox, `geolocator` (GPS del dispositivo), ni paquete `geocoding`. No hay "mi ubicación". No hay reverse geocoding. No hay Google Places autocomplete (la dirección se escribe a mano).

---

## 1. Dependencias (pubspec.yaml)

Añade estas dependencias:

```yaml
dependencies:
  flutter_map: ^7.0.2      # el widget de mapa
  latlong2: ^0.9.1         # tipo LatLng para coordenadas
  url_launcher: ^6.3.1     # abrir Google Maps externo
  supabase_flutter: ^2.5.0 # invocar la Edge Function de geocoding
```

Instalación por línea de comandos:

```bash
flutter pub add flutter_map:^7.0.2 latlong2:^0.9.1 url_launcher:^6.3.1
# supabase_flutter si tu app aún no lo tiene:
flutter pub add supabase_flutter:^2.5.0
```

> Versiones verificadas en MBO Roofing (Flutter SDK >=3.4.0). `flutter_map` 7.x usa la API de `children: [TileLayer(...), MarkerLayer(...)]`.

---

## 2. Configuración central (`lib/core/config/map_config.dart`)

Un único archivo controla el motor de mapa y las constantes de geocoding:

```dart
/// Motor de mapa. Cambiar a MapEngine.google cuando IT habilite las keys.
enum MapEngine {
  openStreetMap, // tiles gratis de OSM vía flutter_map
  google,        // requiere API keys (placeholder, no activo)
}

const kActiveMapEngine = MapEngine.openStreetMap;

/// Tiles raster estándar de OSM (gratis, sin API key).
const kOsmTileUrlTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

/// User-Agent para Nominatim (política del servidor).
const kNominatimUserAgent = 'MiApp/1.0';

/// Delay mínimo entre requests de geocoding (política Nominatim ~1 req/s).
const kGeocodeMinIntervalMs = 1100;
```

---

## 3. Tipo de coordenada (`lib/features/map/domain/map_location.dart`)

Alias provider-agnostic para `LatLng`, así el resto del código no depende del motor de mapa:

```dart
import 'package:latlong2/latlong.dart';

typedef MapLocation = LatLng;

const kDefaultMapCenter = MapLocation(28.5383, -81.3792); // Orlando, FL
const kDefaultMapZoom = 10.0;
const kFocusMapZoom = 16.0;

/// Valida coords antes de poner un pin.
bool isValidMapCoordinate(double? lat, double? lng) {
  if (lat == null || lng == null) return false;
  if (lat == 0 && lng == 0) return false;
  return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
}
```

---

## 4. Widget del mapa mínimo (`flutter_map`)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class OsmMap extends StatelessWidget {
  const OsmMap({super.key});

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      options: MapOptions(
        initialCenter: const LatLng(28.5383, -81.3792),
        initialZoom: 10,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.miempresa.app', // OBLIGATORIO para OSM
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: const LatLng(28.5383, -81.3792),
              width: 36,
              height: 36,
              child: const Icon(Icons.location_on, size: 36, color: Colors.red),
            ),
          ],
        ),
        RichAttributionWidget(
          attributions: [
            TextSourceAttribution(
              'OpenStreetMap contributors',
              onTap: () => launchUrl(Uri.parse('https://openstreetmap.org/copyright')),
            ),
          ],
        ),
      ],
    );
  }
}
```

**Notas clave**:
- `userAgentPackageName` es **obligatorio** por la política de OSM (identifica tu app).
- `RichAttributionWidget` con la atribución a OpenStreetMap es **requerido** legalmente.
- Para centrar la cámara: `MapController.move(latLng, zoom)` y `controller.fitCamera(CameraFit.coordinates(coordinates: [...], padding: ...))`.

---

## 5. Geocoding — dirección → coordenadas

### 5.1. El concepto
El geocoding se hace **server-side** (no directo desde la app a Nominatim) por dos razones:
1. Evitar exponer lógica/rate-limit en el cliente.
2. Que funcione igual offline-first (la app solo llama a la Edge Function de Supabase).

Flujo: **App → Supabase Edge Function → Nominatim → lat/lng → se guarda en BD**.

### 5.2. Edge Function de Supabase (`supabase/functions/geocode-address/index.ts`)

Crea la carpeta `supabase/functions/geocode-address/` con un `index.ts` (Deno):

```typescript
// Requiere _shared/cors.ts (handleOptions/jsonResponse) y _shared/auth.ts
import { handleOptions, jsonResponse } from '../_shared/cors.ts';
import { getUserFromRequest } from '../_shared/auth.ts';

async function geocodeWithNominatim(address: string) {
  const url = new URL('https://nominatim.openstreetmap.org/search');
  url.searchParams.set('q', address);
  url.searchParams.set('format', 'json');
  url.searchParams.set('limit', '1');
  url.searchParams.set('countrycodes', 'us'); // ajusta a tu país

  const response = await fetch(url.toString(), {
    headers: {
      'User-Agent': Deno.env.get('NOMINATIM_USER_AGENT') ?? 'MiApp/1.0',
    },
  });
  if (!response.ok) return { found: false, status: `HTTP_${response.status}` };

  const results = await response.json();
  if (!Array.isArray(results) || results.length === 0) {
    return { found: false, status: 'NO_RESULTS' };
  }
  const first = results[0];
  return {
    found: true,
    latitude: parseFloat(first.lat),
    longitude: parseFloat(first.lon),
    provider: 'nominatim',
  };
}

Deno.serve(async (req) => {
  const options = handleOptions(req);
  if (options) return options;

  if (req.method !== 'POST') return jsonResponse({ error: 'Method not allowed' }, 405);
  await getUserFromRequest(req); // valida JWT del usuario

  const body = await req.json();
  const address = body.address?.trim();
  if (!address) return jsonResponse({ error: 'address is required' }, 400);

  const result = await geocodeWithNominatim(address);
  return jsonResponse(result);
});
```

**Despliegue**:

```bash
# 1. Definir secrets
supabase secrets set NOMINATIM_USER_AGENT="MiApp/1.0 (contacto@miempresa.com)"

# 2. Desplegar la función
supabase functions deploy geocode-address
```

> Nominatim recomienda un User-Agent con contacto real para uso intensivo. Para producción seria valora un mirror propio o un proveedor de pago.

### 5.3. Cliente Flutter (`lib/core/services/geocoding_service.dart`)

Servicio singleton con caché de sesión y rate-limit:

```dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const kGeocodeMinIntervalMs = 1100;

class GeocodingService {
  GeocodingService._();
  static final GeocodingService instance = GeocodingService._();

  final Map<String, LatLng> _cache = {};
  DateTime? _lastGeocodeAt;
  DateTime? _edgeRetryAfter;

  /// Geocodifica una dirección libre a coordenadas.
  Future<LatLng?> geocodeAddress(String address) async {
    final sanitized = _sanitize(address);
    if (sanitized == null) return null;

    final cached = _cache[sanitized.toLowerCase()];
    if (cached != null) return cached;

    await _respectRateLimit();
    final position = await _geocodeViaEdgeFunction(sanitized);
    if (position != null) _cache[sanitized.toLowerCase()] = position;
    return position;
  }

  String? _sanitize(String? address) {
    if (address == null) return null;
    final cleaned = address.trim();
    if (cleaned.isEmpty || cleaned.length < 5) return null;
    return cleaned;
  }

  Future<void> _respectRateLimit() async {
    final last = _lastGeocodeAt;
    if (last == null) { _lastGeocodeAt = DateTime.now(); return; }
    final elapsed = DateTime.now().difference(last).inMilliseconds;
    if (elapsed < kGeocodeMinIntervalMs) {
      await Future.delayed(Duration(milliseconds: kGeocodeMinIntervalMs - elapsed));
    }
    _lastGeocodeAt = DateTime.now();
  }

  Future<LatLng?> _geocodeViaEdgeFunction(String address) async {
    // Back-off si la función ya falló (evita timeouts repetidos offline).
    final retryAfter = _edgeRetryAfter;
    if (retryAfter != null && DateTime.now().isBefore(retryAfter)) return null;

    try {
      final response = await Supabase.instance.client.functions
          .invoke('geocode-address', body: {'address': address})
          .timeout(const Duration(seconds: 6));

      final data = response.data;
      if (data is! Map<String, dynamic> || data['found'] != true) return null;

      final lat = (data['latitude'] as num?)?.toDouble();
      final lng = (data['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) return null;
      return LatLng(lat, lng);
    } catch (e) {
      // Back off 60s si falla (offline / función caída).
      _edgeRetryAfter = DateTime.now().add(const Duration(seconds: 60));
      debugPrint('Geocoding edge function unavailable: $e');
      return null;
    }
  }

  void clearSessionCache() => _cache.clear();
}
```

### 5.4. Uso típico
```dart
final coords = await GeocodingService.instance.geocodeAddress('1800 Pembrook Dr, Orlando, FL');
if (coords != null) {
  // guardar en BD: projects.latitude / longitude
  // mostrar pin en el mapa
}
```

**En MBO Roofing** el geocoding se dispara al **crear/editar** un proyecto (background, `unawaited`) y en la **pantalla del mapa** (lotes de 5). El resultado se persiste en columnas `latitude real, longitude real`.

---

## 6. Búsqueda de proyectos por texto (NO es geocoding)

Filtrado local de la lista existente por dirección/estado/tipo. No llama a ningún servicio:

```dart
bool projectMatchesSearch(Project p, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  return [p.address, p.state, p.type].any((v) => (v ?? '').toLowerCase().contains(q));
}
```

> **Importante**: en MBO Roofing la dirección se captura como **texto libre** en un `TextFormField`. **No hay autocomplete** de direcciones (Google Places). Si lo necesitas, añade el paquete `google_places_flutter` o una llamada a la API Places.

---

## 7. Abrir mapas externos (`lib/core/utils/map_navigation_utils.dart`)

```dart
import 'package:url_launcher/url_launcher.dart';

/// Cómo llegar (turn-by-turn) en la app de mapas del dispositivo.
Future<bool> openMapDirections({required double lat, required double lng, String? label}) async {
  final dest = (label != null && label.trim().isNotEmpty)
      ? Uri.encodeComponent(label.trim())
      : '$lat,$lng';
  return launchUrl(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$dest'));
}

/// Vista satélite externa.
Future<bool> openMapSatellite(double lat, double lng) {
  return launchUrl(Uri.parse(
    'https://www.google.com/maps/@?api=1&map_action=map&center=$lat,$lng&zoom=19&basemap=satellite'));
}

/// Buscar una dirección suelta en Google Maps.
Future<bool> openAddressSearch(String address) {
  final q = Uri.encodeComponent(address.trim());
  return launchUrl(Uri.parse('https://www.google.com/maps/search/?api=1&query=$q'));
}
```

---

## 8. (Opcional) Migrar a Google Maps

Si más adelante quieres Google Maps/Geocoding:

1. **Mapa**: cambia `flutter_map` por `google_maps_flutter`. En MBO Roofing está preparado con `kActiveMapEngine = MapEngine.google` (placeholder).
2. **Geocoding**: la Edge Function ya soporta Google. Solo pon secrets:
   ```bash
   supabase secrets set GEOCODING_PROVIDER=google GOOGLE_MAPS_API_KEY=tu_key
   supabase functions deploy geocode-address
   ```
3. La función usará `https://maps.googleapis.com/maps/api/geocode/json` automáticamente.
4. **Tiles/attribution** ya no aplican (Google las gestiona).

---

## 9. Checklist de instalación rápida

```bash
# 1. Dependencias
flutter pub add flutter_map:^7.0.2 latlong2:^0.9.1 url_launcher:^6.3.1

# 2. (si geocoding) Supabase
flutter pub add supabase_flutter:^2.5.0

# 3. Copiar archivos del proyecto de referencia:
#    - lib/core/config/map_config.dart
#    - lib/features/map/domain/map_location.dart
#    - lib/core/services/geocoding_service.dart
#    - supabase/functions/geocode-address/index.ts  (+ _shared/cors.ts, _shared/auth.ts)

# 4. Desplegar Edge Function
supabase functions deploy geocode-address
supabase secrets set NOMINATIM_USER_AGENT="MiApp/1.0 (contacto@miempresa.com)"

# 5. Permisos (Android) — solo si abres mapas/navegación; flutter_map no requiere permisos
#    AndroidManifest: <uses-permission android:name="android.permission.INTERNET"/>

# 6. Probar
flutter run
```

---

## 10. Reglas de oro / advertencias

- **`userAgentPackageName` en `TileLayer` es obligatorio** (política OSM).
- **Atribución a OpenStreetMap requerida** (usa `RichAttributionWidget`).
- **Respeta el rate limit de Nominatim** (máx ~1 req/s). El `GeocodingService` ya lo throttlea.
- **Geocoding = enriquecimiento no crítico**: ejecútalo con `unawaited(...)` para no bloquear la UI; offline simplemente no-op.
- **Persiste lat/lng en BD** para no re-geocodificar lo mismo.
- **No hay GPS del dispositivo** ("mi ubicación"). Si lo necesitas, añade `geolocator` + `permission_handler`.
- **No hay autocomplete de direcciones**. Si lo necesitas, integra Google Places.
