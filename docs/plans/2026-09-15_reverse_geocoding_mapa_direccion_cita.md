# Plan — Reverse geocoding al tocar el mapa + label "Dirección de la cita"

Fecha: 2026-09-15
Estado: APROBADO por el usuario (m0310: "aprobado"). Sin commit.

## Objetivo

Al hacer clic dentro del mapa (modal o inline) de las 5 pantallas de captura de
dirección, extraer la **dirección exacta** del punto (reverse geocoding con
Nominatim) y **colocarla en el campo de texto**. Los labels del lado **paciente**
pasan a **"Dirección de la cita"**; el especialista conserva "Dirección".

Decisiones confirmadas (m0296): reverse en las 5 pantallas; labels paciente →
"Dirección de la cita" (3 pantallas); el texto se reemplaza en cada clic.

## Cambios

### 1. Edge function `supabase/functions/geocode-address/index.ts`
- Nuevo `reverseGeocodeWithNominatim(lat, lng)`: GET
  `https://nominatim.openstreetmap.org/reverse?lat=..&lon=..&format=json&accept-language=es&countrycodes=us`
  con User-Agent existente → `{found:true, address: display_name, provider:'nominatim'}`
  o `{found:false, status}`.
- `Deno.serve`: body con `lat`/`lng` numéricos → reverse; body con `address` →
  forward (ruta actual); sin ambos → 400.

### 2. `lib/app/core/network/supabase_service.dart`
- `static Future<String?> reverseGeocodeAddress(double lat, double lng)`:
  caché por coords (5 decimales) + `_respectRateLimit()` + edge function primero
  (`_reverseViaEdgeFunction`) + fallback directo Nominatim `/reverse`
  (`_reverseViaNominatimFallback`). Reutiliza `_edgeRetryAfter`.

### 3. `lib/features/patients_compliance/presentation/widgets/patient_map_picker.dart`
- Nuevos parámetros opcionales: `Future<String?> Function(LatLng)? resolveAddress`
  y `ValueChanged<String>? onAddressResolved`.
- En `_handleLocationChanged`: tras mover el PIN, si `resolveAddress != null`
  lo invoca y notifica `onAddressResolved` con la dirección (spinner breve).

### 4. Las 5 pantallas de captura
| Pantalla | Wiring | Label |
|---|---|---|
| `patient_address_screen.dart` | `resolveAddress` + `onAddressResolved` → `_addressCtrl.text` | 'Dirección de Residencia'→'Dirección de la cita'; 'Dirección Completa'→'Dirección de la cita' |
| `profile_screen.dart` | ídem | 'Dirección'→'Dirección de la cita' |
| `complete_profile_screen.dart` | ídem | 'Dirección de Habitación'→'Dirección de la cita' |
| `specialist_profile_screen.dart` | ídem (inline) | 'Dirección' (se conserva) |
| `specialist_onboarding_screen.dart` | ídem (inline) | 'Dirección *' (se conserva) |

`specialist_map_screen.dart` NO se toca (RN-018, no es captura).

## Verificación

- [x] `flutter analyze` limpio.
- [x] `flutter test` (366 tests).
- [ ] Manual en `flutter run -d chrome`: tocar el mapa en cada pantalla → el campo
      se llena con la dirección exacta; labels paciente 'Dirección de la cita';
      especialista conserva 'Dirección'.
- [ ] Deploy de la edge function pendiente (`supabase functions deploy geocode-address`
      requiere `supabase login`; el fallback directo a Nominatim funciona sin auth).

## Notas

- Sin commit (regla del proyecto: preguntar antes de commitear).
- El display_name de Nominatim se muestra solo en el campo del propio usuario.
- `_respectRateLimit` (1100 ms) cumple el TOS de Nominatim (1 req/s).