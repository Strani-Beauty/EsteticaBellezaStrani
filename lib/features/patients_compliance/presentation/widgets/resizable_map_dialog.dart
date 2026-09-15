import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import 'package:esteticaybellezastrani/features/patients_compliance/presentation/widgets/patient_map_picker.dart';

/// Ventana modal de mapa uniforme para las pantallas de captura de dirección.
///
/// Header con título, mapa interactivo (`PatientMapPicker`) y botón
/// "Confirmar Posición del PIN". El usuario puede **redimensionar** la ventana
/// arrastrando la manija inferior derecha.
///
/// Devuelve `LatLng` al confirmar (o `null` si se cierra sin confirmar).
class ResizableMapDialog extends StatefulWidget {
  const ResizableMapDialog({
    super.key,
    required this.initialLocation,
    this.title = 'Mapa (Houston, TX)',
    this.mapController,
    this.resolveAddress,
    this.onAddressResolved,
    this.initialWidth,
    this.initialHeight,
  });

  /// Posición inicial del PIN en el mapa.
  final LatLng initialLocation;

  /// Título del header de la ventana.
  final String title;

  /// Controlador opcional del mapa (reutilizado por la pantalla anfitriona).
  final MapController? mapController;

  /// Reverse geocoding: convierte el punto tocado en dirección.
  final Future<String?> Function(LatLng point)? resolveAddress;

  /// Callback con la dirección resuelta al tocar el mapa.
  final ValueChanged<String>? onAddressResolved;

  /// Tamaño inicial opcional de la ventana (si no se envían, se usan
  /// dimensiones uniformes adaptadas a la pantalla).
  final double? initialWidth;
  final double? initialHeight;

  @override
  State<ResizableMapDialog> createState() => _ResizableMapDialogState();
}

class _ResizableMapDialogState extends State<ResizableMapDialog> {
  static const double _headerHeight = 46;
  static const double _bottomHeight = 54;
  static const double _minWidth = 280;
  static const double _minHeight = 320;
  static const double _maxWidth = 440;
  static const double _maxHeight = 560;

  late LatLng _location;
  late double _width;
  late double _height;
  bool _sized = false;

  @override
  void initState() {
    super.initState();
    _location = widget.initialLocation;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sized) return;
    _sized = true;
    final media = MediaQuery.sizeOf(context);
    _width = (widget.initialWidth ??
            (media.width * 0.9).clamp(_minWidth, _maxWidth))
        .clamp(_minWidth, _maxWidth)
        .toDouble();
    _height = (widget.initialHeight ??
            (media.height * 0.7).clamp(_minHeight, _maxHeight))
        .clamp(_minHeight, _maxHeight)
        .toDouble();
  }

  void _onResizePanUpdate(DragUpdateDetails details) {
    final media = MediaQuery.sizeOf(context);
    final maxW = (media.width - 40).clamp(_minWidth, _maxWidth);
    final maxH = (media.height - 48).clamp(_minHeight, _maxHeight);
    setState(() {
      _width = (_width + details.delta.dx).clamp(_minWidth, maxW).toDouble();
      _height = (_height + details.delta.dy).clamp(_minHeight, maxH).toDouble();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: SizedBox(
        width: _width,
        height: _height,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: PatientMapPicker(
                selectedLocation: _location,
                mapController: widget.mapController,
                height: _height - _headerHeight - _bottomHeight,
                onLocationChanged: (newLoc) {
                  setState(() => _location = newLoc);
                },
                resolveAddress: widget.resolveAddress,
                onAddressResolved: widget.onAddressResolved,
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: AppTheme.cDeepAccent,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.map_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.close, color: Colors.white, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.grey.shade50,
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 38,
              child: ElevatedButton.icon(
                style:
                    ElevatedButton.styleFrom(backgroundColor: AppTheme.cDeepAccent),
                onPressed: () => Navigator.pop(context, _location),
                icon: const Icon(Icons.check, size: 16),
                label: const Text(
                  'Confirmar Posición del PIN',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: _onResizePanUpdate,
            child: Tooltip(
              message: 'Arrastra para cambiar el tamaño',
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.cPastelPurple,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: const Icon(
                  Icons.open_in_full_rounded,
                  size: 18,
                  color: AppTheme.cDeepAccent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}