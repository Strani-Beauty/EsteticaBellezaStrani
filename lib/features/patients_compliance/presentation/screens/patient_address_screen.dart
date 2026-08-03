import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import 'package:esteticaybellezastrani/app/config/map_config.dart';
import 'package:esteticaybellezastrani/supabase_service.dart';
import 'package:esteticaybellezastrani/features/patients_compliance/presentation/widgets/patient_map_picker.dart';

/// Pantalla del formulario de dirección del paciente con mapa en ventana emergente cuadrada.
class PatientAddressScreen extends StatefulWidget {
  final String? initialAddress;
  final double? initialLat;
  final double? initialLng;

  const PatientAddressScreen({
    super.key,
    this.initialAddress,
    this.initialLat,
    this.initialLng,
  });

  @override
  State<PatientAddressScreen> createState() => _PatientAddressScreenState();
}

class _PatientAddressScreenState extends State<PatientAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressCtrl = TextEditingController();
  final MapController _mapController = MapController();

  late LatLng _selectedLocation;
  bool _isGeocoding = false;
  bool _isSaving = false;
  bool _isLoadingInitial = true;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _loadInitialPatientData();
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  /// Cargar datos ya almacenados en Supabase si no fueron provistos explícitamente
  Future<void> _loadInitialPatientData() async {
    String addr = widget.initialAddress ?? '';
    double? lat = widget.initialLat;
    double? lng = widget.initialLng;

    if (addr.isEmpty || !isValidMapCoordinate(lat, lng)) {
      final userProfileMap = await SupabaseService.getCurrentUserProfile();
      if (userProfileMap != null) {
        if (addr.isEmpty && userProfileMap['address'] != null) {
          addr = userProfileMap['address'].toString();
        }
        lat ??= (userProfileMap['latitude'] as num?)?.toDouble();
        lng ??= (userProfileMap['longitude'] as num?)?.toDouble();
      }
    }

    if (!mounted) return;

    setState(() {
      _addressCtrl.text = addr;
      if (isValidMapCoordinate(lat, lng)) {
        _selectedLocation = LatLng(lat!, lng!);
      } else {
        _selectedLocation = kDefaultCaguaLocation;
      }
      _isLoadingInitial = false;
    });
  }

  /// Buscar coordenadas y abrir el mapa en ventana emergente cuadrada
  Future<void> _searchAddress() async {
    final query = _addressCtrl.text.trim();
    if (query.isEmpty) {
      setState(() => _statusMessage = 'Ingresa una dirección para geocodificar.');
      return;
    }

    setState(() {
      _isGeocoding = true;
      _statusMessage = null;
    });

    final coords = await SupabaseService.geocodeAddress(query);

    if (!mounted) return;

    if (coords != null) {
      setState(() {
        _selectedLocation = coords;
        _isGeocoding = false;
        _statusMessage = 'Ubicación localizada. Puedes verificar el PIN en el mapa.';
      });
      _openSquareMapDialog();
    } else {
      setState(() {
        _isGeocoding = false;
        _statusMessage = 'No se encontró la dirección. Se mantuvo la ubicación actual en Cagua/Aragua.';
      });
      _openSquareMapDialog();
    }
  }

  /// Desplegar mapa en una ventana emergente cuadrada (aprox 1/4 del tamaño de la pantalla total)
  void _openSquareMapDialog() {
    LatLng tempLoc = _selectedLocation;
    final media = MediaQuery.of(context).size;
    final side = (media.width * 0.65).clamp(280.0, 380.0);

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: side,
            height: side + 68,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  color: AppTheme.cDeepAccent,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Seleccionar Posición del PIN',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.close, color: Colors.white, size: 18),
                        onPressed: () => Navigator.pop(dialogCtx),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PatientMapPicker(
                    selectedLocation: tempLoc,
                    mapController: _mapController,
                    height: side,
                    onLocationChanged: (newLoc) {
                      tempLoc = newLoc;
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.grey.shade50,
                  child: SizedBox(
                    width: double.infinity,
                    height: 38,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cDeepAccent),
                      onPressed: () {
                        setState(() {
                          _selectedLocation = tempLoc;
                          _statusMessage = 'PIN actualizado en el formulario.';
                        });
                        Navigator.pop(dialogCtx);
                      },
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text('Confirmar Posición del PIN', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Guardar la latitud, longitud y dirección en Supabase
  Future<void> _saveLocation() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final user = SupabaseService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No se encontró sesión activa de usuario.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await SupabaseService.updateProfileData(
        userId: user.id,
        fullName: user.userMetadata?['full_name'] ?? 'Paciente',
        phone: user.userMetadata?['phone'] ?? '',
        address: _addressCtrl.text.trim(),
        latitude: _selectedLocation.latitude,
        longitude: _selectedLocation.longitude,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text('✅ Dirección y posición exacta guardadas en Supabase exitosamente.'),
        ),
      );

      Navigator.of(context).maybePop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Error al guardar en Supabase: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingInitial) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.cDeepAccent),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ubicación del Paciente'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dirección de Residencia',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.cDeepAccent),
              ),
              const SizedBox(height: 4),
              const Text(
                'Busca tu dirección o presiona el botón para abrir el mapa en una ventana emergente y ajustar tu PIN.',
                style: TextStyle(fontSize: 13, color: AppTheme.cMutedText),
              ),
              const SizedBox(height: 16),

              // Campo de Dirección
              TextFormField(
                controller: _addressCtrl,
                textInputAction: TextInputAction.search,
                onFieldSubmitted: (_) => _searchAddress(),
                decoration: AppTheme.fieldDecoration(
                  label: 'Dirección Completa',
                  hint: 'Ej: Av. Bolívar, Cagua, Aragua',
                  prefix: const Icon(Icons.location_on_outlined, color: AppTheme.cDeepAccent),
                  suffix: _isGeocoding
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.cDeepAccent),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.search_rounded, color: AppTheme.cDeepAccent),
                          onPressed: _searchAddress,
                          tooltip: 'Buscar Dirección',
                        ),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa una dirección válida' : null,
              ),
              const SizedBox(height: 10),

              // Mensaje de estado
              if (_statusMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 16, color: AppTheme.cDeepAccent),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _statusMessage!,
                          style: const TextStyle(fontSize: 12, color: AppTheme.cDeepAccent, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),

              // Botón de activación del Mapa Emergente Cuadrado
              InkWell(
                onTap: _openSquareMapDialog,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.cPastelBlue.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(color: AppTheme.cDeepAccent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.cDeepAccent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.pin_drop_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Abrir Mapa en Ventana Emergente',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.cDarkText),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Lat: ${_selectedLocation.latitude.toStringAsFixed(5)}, Lng: ${_selectedLocation.longitude.toStringAsFixed(5)}',
                              style: const TextStyle(fontSize: 11, color: AppTheme.cMutedText),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.open_in_new_rounded, color: AppTheme.cDeepAccent, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Campos de Coordenadas (Lat / Lng)
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Latitud', style: TextStyle(fontSize: 11, color: AppTheme.cMutedText)),
                          const SizedBox(height: 2),
                          Text(
                            _selectedLocation.latitude.toStringAsFixed(6),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Longitud', style: TextStyle(fontSize: 11, color: AppTheme.cMutedText)),
                          const SizedBox(height: 2),
                          Text(
                            _selectedLocation.longitude.toStringAsFixed(6),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Botón Guardar
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveLocation,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_rounded),
                  label: Text(_isSaving ? 'Guardando en Supabase...' : 'Confirmar y Guardar Ubicación'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
