import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import 'package:esteticaybellezastrani/app/config/map_config.dart';

/// Widget interactivo compacto de mapa FlutterMap con OpenStreetMap para selección de dirección.
class PatientMapPicker extends StatefulWidget {
  final LatLng selectedLocation;
  final ValueChanged<LatLng> onLocationChanged;
  final MapController? mapController;
  final double height;

  const PatientMapPicker({
    super.key,
    required this.selectedLocation,
    required this.onLocationChanged,
    this.mapController,
    this.height = 200,
  });

  @override
  State<PatientMapPicker> createState() => _PatientMapPickerState();
}

class _PatientMapPickerState extends State<PatientMapPicker> {
  late MapController _internalController;
  late LatLng _location;

  MapController get _controller => widget.mapController ?? _internalController;

  @override
  void initState() {
    super.initState();
    _location = widget.selectedLocation;
    if (widget.mapController == null) {
      _internalController = MapController();
    }
  }

  @override
  void didUpdateWidget(covariant PatientMapPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si el padre cambia la ubicación (p. ej. tras geocodificar), sincronizar el PIN.
    if (!_sameLocation(oldWidget.selectedLocation, widget.selectedLocation)) {
      _location = widget.selectedLocation;
    }
  }

  bool _sameLocation(LatLng a, LatLng b) =>
      a.latitude == b.latitude && a.longitude == b.longitude;

  void _handleLocationChanged(LatLng point) {
    // Actualiza el PIN localmente para que se mueva al instante,
    // y notifica al padre para que capture el valor final al confirmar.
    setState(() => _location = point);
    widget.onLocationChanged(point);
  }

  void _recenterCagua() {
    _controller.move(kDefaultCaguaLocation, kDefaultMapZoom);
    _handleLocationChanged(kDefaultCaguaLocation);
  }

  void _zoomIn() {
    final currentZoom = _controller.camera.zoom;
    _controller.move(_controller.camera.center, currentZoom + 1);
  }

  void _zoomOut() {
    final currentZoom = _controller.camera.zoom;
    _controller.move(_controller.camera.center, currentZoom - 1);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: Colors.grey.shade300, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: widget.selectedLocation,
              initialZoom: kDefaultMapZoom,
              minZoom: 5.0,
              maxZoom: 18.0,
              onTap: (tapPosition, point) {
                _handleLocationChanged(point);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: kOsmTileUrlTemplate,
                userAgentPackageName: kUserAgentPackageName,
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _location,
                    width: 36,
                    height: 36,
                    alignment: Alignment.topCenter,
                    child: Tooltip(
                      message: 'Ubicación seleccionada\n(Toca el mapa para mover)',
                      child: Icon(
                        Icons.location_on_rounded,
                        size: 34,
                        color: AppTheme.cDeepAccent,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    'OpenStreetMap',
                    onTap: () => launchUrl(
                      Uri.parse('https://openstreetmap.org/copyright'),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Banner instructivo superior compacto
          Positioned(
            top: 6,
            left: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 3,
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.touch_app_rounded, size: 14, color: AppTheme.cDeepAccent),
                  SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'Toca el mapa para ajustar la posición del PIN',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Botones de Control compactos en lateral derecho
          Positioned(
            right: 6,
            bottom: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 30,
                  height: 30,
                  child: FloatingActionButton.small(
                    heroTag: 'recenter_cagua_btn',
                    tooltip: 'Centrar en Cagua, Aragua',
                    elevation: 1,
                    backgroundColor: AppTheme.cDeepAccent,
                    onPressed: _recenterCagua,
                    child: const Icon(Icons.location_city_rounded, color: Colors.white, size: 15),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: 30,
                  height: 30,
                  child: FloatingActionButton.small(
                    heroTag: 'zoom_in_btn',
                    tooltip: 'Acercar',
                    elevation: 1,
                    backgroundColor: Colors.white,
                    onPressed: _zoomIn,
                    child: const Icon(Icons.add, color: AppTheme.cDeepAccent, size: 15),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: 30,
                  height: 30,
                  child: FloatingActionButton.small(
                    heroTag: 'zoom_out_btn',
                    tooltip: 'Alejar',
                    elevation: 1,
                    backgroundColor: Colors.white,
                    onPressed: _zoomOut,
                    child: const Icon(Icons.remove, color: AppTheme.cDeepAccent, size: 15),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
