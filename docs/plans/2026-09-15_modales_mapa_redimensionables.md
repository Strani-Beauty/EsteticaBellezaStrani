# Plan — Ventanas modales de mapa redimensionables y uniformes

Fecha: 2026-09-15
Estado: COMPLETADO (solicitud del usuario: "las ventanas modales del mapa se puedan cambiar de tamaño, y que todas sean iguales"). Sin commit.

## Objetivo

Las 3 ventanas modales de mapa de captura de dirección (paciente) deben:
1. Poder **cambiarse de tamaño** arrastrando la esquina inferior derecha.
2. Ser **todas iguales** (mismo tamaño inicial y mismo layout), extrayendo el
   diálogo duplicado a un único widget compartido `ResizableMapDialog`.

## Cambios

### 1. Nuevo `lib/features/patients_compliance/presentation/widgets/resizable_map_dialog.dart`
- Widget `ResizableMapDialog` (StatefulWidget) con params: `initialLocation`
  (LatLng), `title` (default 'Mapa (Houston, TX)'), `mapController?`,
  `resolveAddress?`, `onAddressResolved?`, `initialWidth?`/`initialHeight?`.
- Tamaño inicial uniforme: `ancho = (media.width*0.9).clamp(280, 440)`,
  `alto = (media.height*0.7).clamp(320, 560)`.
- Layout idéntico al actual: header cDeepAccent (título + close), `Expanded`
  con `PatientMapPicker` (height = `_height - 46 - 54`, passthrough de
  `resolveAddress`/`onAddressResolved`), footer grey50 con botón
  'Confirmar Posición del PIN' → `Navigator.pop(context, _location)`.
- **Redimensionar**: manija 36x36 en el footer (derecha del botón) con
  `GestureDetector.onPanUpdate` que ajusta `_width`/`_height` (clamped entre
  mínimos 280x320 y el tamaño de la pantalla).
- Elimina las duplicaciones de tamaño/layout de las 3 pantallas.

### 2. `patient_address_screen.dart`
- `_openSquareMapDialog()` → `Future<void> _openMapModalDialog()` usando
  `showDialog<LatLng>` + `ResizableMapDialog(title: 'Seleccionar Posición del PIN')`.
- Tras el pop: si `result != null`, `setState { _selectedLocation = result;
  _ubicacionConfirmada = true; _statusMessage = 'PIN actualizado en el formulario.'; }`.
- Import del widget nuevo.

### 3. `profile_screen.dart`
- `_openMapModalDialog()` → `showDialog<LatLng>` + `ResizableMapDialog(title: 'Mapa (Houston, TX)')`.
- Tras el pop: si `result != null`, `setState { _selectedLocation = result;
  _ubicacionConfirmada = true; }`.
- Import del widget nuevo.

### 4. `complete_profile_screen.dart`
- Igual que profile_screen con `ResizableMapDialog(title: 'Mapa (Houston, TX)')`.
- Import del widget nuevo.

## Verificación

- [x] `flutter analyze` limpio.
- [x] `flutter test` (366 tests).
- [ ] Manual en `flutter run -d chrome`: las 3 ventanas modales iguales,
      arrastrable la esquina para cambiar tamaño, confirmar devuelve el PIN.

## Notas

- Sin commit (regla del proyecto: preguntar antes de commitear).
- El reverse geocoding ya integrado se conserva vía passthrough.