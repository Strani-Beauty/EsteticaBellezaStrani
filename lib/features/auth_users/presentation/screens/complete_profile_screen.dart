import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';
import 'package:esteticaybellezastrani/app/config/app_routes.dart';
import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import 'package:esteticaybellezastrani/app/config/app_constants.dart';
import 'package:esteticaybellezastrani/app/config/map_config.dart';
import 'package:esteticaybellezastrani/app/core/network/supabase_service.dart';
import 'package:esteticaybellezastrani/features/patients_compliance/presentation/widgets/patient_map_picker.dart';
import 'package:esteticaybellezastrani/features/patients_compliance/presentation/screens/patient_questionnaire_screen.dart';
import '../cubits/auth_cubit.dart';

/// Pantalla para completar o editar el perfil del paciente.
/// Carga datos previos de Supabase y ofrece mapa en ventana emergente cuadrada (~1/4 pantalla).
class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final MapController _mapController = MapController();

  LatLng _selectedLocation = kDefaultCaguaLocation; // Cagua, Aragua por defecto
  bool _searchingLocation = false;
  bool _isLoadingInitialData = true;
  String? _addressError;

  @override
  void initState() {
    super.initState();
    _loadExistingProfileData();
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  /// Cargar datos ya existentes en Supabase para ediciÃ³n de perfil
  Future<void> _loadExistingProfileData() async {
    final cubit = context.read<AuthCubit>();
    final profile = cubit.currentProfile;
    final userProfileMap = await SupabaseService.getCurrentUserProfile();

    if (!mounted) return;

    final phone = profile?.phone ?? userProfileMap?['phone']?.toString();
    final address = profile?.address ?? userProfileMap?['address']?.toString();
    final lat = profile?.latitude ?? (userProfileMap?['latitude'] as num?)?.toDouble();
    final lng = profile?.longitude ?? (userProfileMap?['longitude'] as num?)?.toDouble();

    setState(() {
      if (phone != null && phone.isNotEmpty) {
        _phoneCtrl.text = phone;
      }
      if (address != null && address.isNotEmpty) {
        _addressCtrl.text = address;
      }
      if (isValidMapCoordinate(lat, lng)) {
        _selectedLocation = LatLng(lat!, lng!);
      }
      _isLoadingInitialData = false;
    });
  }

  /// GeocodificaciÃ³n centralizada con apertura automÃ¡tica de ventana emergente del mapa
  Future<void> _searchLocation([String? query]) async {
    final q = (query ?? _addressCtrl.text).trim();
    if (q.isEmpty) {
      setState(() => _addressError = 'Ingresa una direcciÃ³n para buscar.');
      return;
    }
    setState(() {
      _searchingLocation = true;
      _addressError = null;
    });

    final coords = await SupabaseService.geocodeAddress(q);

    if (!mounted) return;

    if (coords != null) {
      setState(() {
        _selectedLocation = coords;
        _searchingLocation = false;
      });
      _openMapModalDialog(); // Abrir mapa emergente cuadrado al geocodificar
    } else {
      setState(() {
        _searchingLocation = false;
        _addressError = 'No se encontraron coordenadas exactas. Puedes ajustar el PIN en el mapa manualmente.';
      });
      _openMapModalDialog();
    }
  }

  /// Abrir ventana emergente cuadrada (1/4 del tamaÃ±o de la pantalla total) con el mapa
  void _openMapModalDialog() {
    LatLng tempLocation = _selectedLocation;
    final media = MediaQuery.of(context).size;
    // Dimensiones cuadradas aproximadas a la cuarta parte de la ventana total
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
            height: side + 70, // TamaÃ±o cuadrado + barra de acciones
            child: Column(
              children: [
                // Header modal
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  color: AppTheme.cDeepAccent,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.map_rounded, color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Mapa (Cagua / Aragua)',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
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

                // Mapa cuadrado interactivo
                Expanded(
                  child: PatientMapPicker(
                    selectedLocation: tempLocation,
                    mapController: _mapController,
                    height: side,
                    onLocationChanged: (newLoc) {
                      tempLocation = newLoc;
                    },
                  ),
                ),

                // BotÃ³n de confirmaciÃ³n inferior
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
                          _selectedLocation = tempLocation;
                        });
                        Navigator.pop(dialogCtx);
                      },
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Confirmar PosiciÃ³n del PIN', style: TextStyle(fontSize: 12)),
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

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final cubit = context.read<AuthCubit>();
    final profile = cubit.currentProfile;
    final user = SupabaseService.currentUser;
    final userId = profile?.id ?? user?.id;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No se encontrÃ³ sesiÃ³n activa de usuario.')),
      );
      return;
    }

    // â”€â”€ 1. Guardar datos del paciente directamente en Supabase â”€â”€
    // NO usamos cubit.updateProfile aquÃ­ porque emite AuthLoading
    // y destruye el contexto mientras esperamos las consultas siguientes.
    final savedProfile = await SupabaseService.updateProfileData(
      userId: userId,
      fullName: profile?.fullName ?? user?.userMetadata?['full_name'] ?? 'Paciente',
      phone: _phoneCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      latitude: _selectedLocation.latitude,
      longitude: _selectedLocation.longitude,
    );

    if (!mounted) return;

    if (savedProfile.containsKey('error')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Error al guardar: ${savedProfile['error']}'),
        ),
      );
      return;
    }

    // Mostrar confirmaciÃ³n de guardado exitoso
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Colors.green,
        content: Text('âœ… Datos guardados en Supabase correctamente.'),
        duration: Duration(seconds: 2),
      ),
    );

    // â”€â”€ 2. Verificar estado del flujo desde Supabase â”€â”€
    final status = await SupabaseService.checkPatientFlowStatus(profileId: userId);
    final bool paymentCompleted = status['paymentCompleted'] == true;
    final bool hasCompletedQuestionnaire = status['hasCompletedQuestionnaire'] == true;
    final String evaluationStatus = status['evaluationStatus']?.toString() ?? 'PENDIENTE';

    if (!mounted) return;

    // â”€â”€ Si NO ha cancelado la cuota inicial de $30 â”€â”€
    if (!paymentCompleted) {
      _showStripeModal();
      return;
    }

    // â”€â”€ Ya cancelÃ³ la cuota â†’ verificar cuestionario â”€â”€
    if (!hasCompletedQuestionnaire) {
      _openQuestionnaires(paid: true);
      return;
    }

    // â”€â”€ Ya llenÃ³ cuestionario â†’ revisar dictamen de evaluaciÃ³n mÃ©dica â”€â”€
    if (evaluationStatus == 'VENCIDA') {
      _showExpiredEvaluationDialog(status['proveedorEvaluacion']?.toString() ?? 'Telemedicina / Medicina Interna');
    } else if (evaluationStatus == 'RECHAZADA') {
      _showNegativeEvaluationDialog();
    } else if (evaluationStatus == 'APROBADA') {
      _showPositiveEvaluationDialog();
    } else {
      // Estado pendiente: abrir cuestionario (que incluye evaluaciÃ³n mÃ©dica internamente)
      _openQuestionnaires(paid: true);
    }
  }

  void _showExpiredEvaluationDialog(String proveedor) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        title: const Row(children: [
          Icon(Icons.history_toggle_off_rounded, color: Colors.orangeAccent, size: 28),
          SizedBox(width: 10),
          Text('EvaluaciÃ³n MÃ©dica Expirada'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tu aprobaciÃ³n mÃ©dica previa ($proveedor) ha cumplido su ciclo de 1 aÃ±o (365 dÃ­as) de validez.',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            const Text(
              'SegÃºn las polÃ­ticas del sistema, para continuar reservando servicios debes realizar una nueva evaluaciÃ³n clÃ­nica y el abono inicial de \$30 USD.',
              style: TextStyle(fontSize: 13, color: AppTheme.cMutedText),
            ),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cDeepAccent),
            onPressed: () {
              Navigator.pop(ctx);
              _showStripeModal();
            },
            icon: const Icon(Icons.payment_rounded, size: 18),
            label: const Text('Pagar \$30 USD y Renovar Evaluation'),
          ),
        ],
      ),
    );
  }

  void _showNegativeEvaluationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        title: const Row(children: [
          Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 28),
          SizedBox(width: 10),
          Text('Dictamen MÃ©dica No Apto', style: TextStyle(color: Colors.redAccent)),
        ]),
        content: const Text(
          'Tu evaluaciÃ³n mÃ©dica previa con Qualify no resultÃ³ apta para este servicio en este momento.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.go(AppRoutes.services);
            },
            child: const Text('Ir a CatÃ¡logo de Servicios'),
          ),
        ],
      ),
    );
  }

  void _showPositiveEvaluationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        title: const Row(children: [
          Icon(Icons.verified_rounded, color: AppTheme.cSuccess, size: 28),
          SizedBox(width: 10),
          Text('Dictamen MÃ©dico Aprobado'),
        ]),
        content: const Text(
          'Ya cuentas con una evaluaciÃ³n mÃ©dica aprobada para este servicio. Redirigiendo a CancelaciÃ³n Total del Servicio (MÃ³dulo a realizar a posteriori).',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cDeepAccent),
            onPressed: () {
              Navigator.pop(ctx);
              context.go(AppRoutes.services);
            },
            child: const Text('Ir a CancelaciÃ³n / Servicios'),
          ),
        ],
      ),
    );
  }

  /// Paso 2: Modal de Pago Stripe (simulado)
  /// Guard a nivel de instancia para evitar doble apertura por doble tap
  bool _stripeModalOpen = false;

  void _showStripeModal() {
    if (_stripeModalOpen) return;          // evita doble llamada
    _stripeModalOpen = true;

    bool processing = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setModal) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          ),
          title: const Row(children: [
            Icon(Icons.credit_card_rounded, color: AppTheme.cStripe, size: 28),
            SizedBox(width: 10),
            Text('Paso 2: Pago de Cuota Inicial'),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.cPastelPurple,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('Cuota Inicial:', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text('\$${AppConstants.depositoInicial} USD',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                            color: AppTheme.cDeepAccent)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text('Procesado de forma segura con Stripe.',
                  style: TextStyle(fontSize: 12, color: AppTheme.cMutedText)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: processing ? null : () {
                _stripeModalOpen = false;
                Navigator.pop(dialogCtx);
                _openQuestionnaires(paid: false, stripeRef: null);
              },
              child: const Text('Posponer', style: TextStyle(color: Colors.redAccent)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cStripe),
              onPressed: processing ? null : () async {
                if (processing) return;    // guard extra contra doble tap
                final cubitRef = context.read<AuthCubit>();
                setModal(() => processing = true);

                // Simular procesamiento Stripe 2 seg (reemplazar por SDK real)
                await Future.delayed(const Duration(seconds: 2));

                final user = SupabaseService.currentUser;
                final userId = cubitRef.currentProfile?.id ?? user?.id;
                String? stripeRef;

                if (userId != null) {
                  stripeRef = 'STRIPE_INIT_${DateTime.now().millisecondsSinceEpoch}';
                  // Marcar payment_completed y activar paciente
                  await SupabaseService.registerInitialPayment(
                    profileId: userId,
                    amount: AppConstants.depositoInicial.toDouble(),
                    paymentReference: stripeRef,
                  );
                  // Guardar direcciÃ³n principal
                  await SupabaseService.savePatientAddress(
                    profileId: userId,
                    address: _addressCtrl.text.trim(),
                    latitude: _selectedLocation.latitude,
                    longitude: _selectedLocation.longitude,
                  );
                }

                _stripeModalOpen = false;
                if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                if (mounted) _openQuestionnaires(paid: true, stripeRef: stripeRef);
              },
              child: processing
                  ? const SizedBox(height: 18, width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Pagar con Stripe'),
            ),
          ],
        ),
      ),
    ).whenComplete(() => _stripeModalOpen = false);
  }

  /// Paso 3: Cuestionarios MÃ©dicos por Servicio
  void _openQuestionnaires({required bool paid, String? stripeRef}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => PatientQuestionnaireScreen(
          serviceName: 'EstÃ©tica y Belleza General',
          stripePaymentRef: stripeRef,
          onCompleted: () {
            // El cuestionario ya ejecutÃ³ Qualify internamente.
            // Solo cerramos la pantalla y volvemos al perfil.
            Navigator.pop(ctx);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<AuthCubit>();
    final isLoading = cubit.state is AuthLoading;
    final profile = cubit.currentProfile;

    if (_isLoadingInitialData) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.cDeepAccent),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil del Paciente'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badge Paciente
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(children: [
                  const Icon(Icons.person_pin_rounded, size: 18, color: AppTheme.cDeepAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ID del Paciente: ${profile?.id ?? SupabaseService.currentUser?.id ?? '...'}',
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 16),

              // TelÃ©fono
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: AppTheme.fieldDecoration(
                  label: 'TelÃ©fono de Contacto',
                  hint: '+58 412 1234567',
                  prefix: const Icon(Icons.phone_outlined, color: AppTheme.cDeepAccent),
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Ingresa tu nÃºmero telefÃ³nico' : null,
              ),
              const SizedBox(height: 14),

              // DirecciÃ³n
              TextFormField(
                controller: _addressCtrl,
                textInputAction: TextInputAction.search,
                onFieldSubmitted: _searchLocation,
                decoration: AppTheme.fieldDecoration(
                  label: 'DirecciÃ³n de HabitaciÃ³n',
                  hint: 'Ej: Calle Comercio, Res. Strani, Cagua',
                  prefix: const Icon(Icons.location_on_outlined, color: AppTheme.cDeepAccent),
                  suffix: _searchingLocation
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2,
                                  color: AppTheme.cDeepAccent)))
                      : IconButton(
                          icon: const Icon(Icons.search_rounded, color: AppTheme.cDeepAccent),
                          onPressed: () => _searchLocation(),
                          tooltip: 'Buscar DirecciÃ³n y Abrir Mapa',
                        ),
                  error: _addressError,
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Ingresa tu direcciÃ³n' : null,
              ),
              const SizedBox(height: 14),

              // Tarjeta interactiva para disparar la Ventana Emergente del Mapa Cuadrado (~1/4 pantalla)
              InkWell(
                onTap: _openMapModalDialog,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.cPastelPurple.withValues(alpha: 0.4),
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
                        child: const Icon(Icons.map_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'UbicaciÃ³n en Mapa (Ventana Emergente)',
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
              const SizedBox(height: 14),

              // Coordenadas seleccionadas
              Row(children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Latitud', style: TextStyle(fontSize: 10, color: AppTheme.cMutedText)),
                        Text(_selectedLocation.latitude.toStringAsFixed(6),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Longitud', style: TextStyle(fontSize: 10, color: AppTheme.cMutedText)),
                        Text(_selectedLocation.longitude.toStringAsFixed(6),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 24),

              // BotÃ³n de EnvÃ­o
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: isLoading ? null : _submit,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Guardar e Ir a Pago Stripe (\$30)'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
