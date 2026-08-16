import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';
import 'package:esteticaybellezastrani/app/config/app_routes.dart';
import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import 'package:esteticaybellezastrani/app/config/app_constants.dart';
import 'package:esteticaybellezastrani/app/config/map_config.dart';
import 'package:esteticaybellezastrani/app/core/di/injection.dart';
import 'package:esteticaybellezastrani/app/core/network/supabase_service.dart';
import 'package:esteticaybellezastrani/features/patients_compliance/presentation/widgets/patient_map_picker.dart';
import 'package:esteticaybellezastrani/features/patients_compliance/presentation/screens/patient_questionnaire_screen.dart';
import 'package:esteticaybellezastrani/features/payments_stripe/domain/repositories/i_payments_repository.dart';
import 'package:esteticaybellezastrani/features/payments_stripe/presentation/widgets/stripe_payment_sheet.dart';
import '../cubits/auth_cubit.dart';
import '../widgets/avatar_selector.dart';

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

  LatLng _selectedLocation = kDefaultLocation; // Houston, TX por defecto
  bool _searchingLocation = false;
  bool _isLoadingInitialData = true;
  String? _addressError;
  String? _avatarUrl;

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

  /// Cargar datos ya existentes en Supabase para edición de perfil
  Future<void> _loadExistingProfileData() async {
    final cubit = context.read<AuthCubit>();
    final profile = cubit.currentProfile;
    final userProfileMap = await SupabaseService.getCurrentUserProfile();

    if (!mounted) return;

    final phone = profile?.phone ?? userProfileMap?['phone']?.toString();
    final address = profile?.address ?? userProfileMap?['address']?.toString();
    final lat = profile?.latitude ?? (userProfileMap?['latitude'] as num?)?.toDouble();
    final lng = profile?.longitude ?? (userProfileMap?['longitude'] as num?)?.toDouble();
    final avatar = profile?.avatarUrl ?? userProfileMap?['avatar_url']?.toString();

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
      _avatarUrl = avatar;
      _isLoadingInitialData = false;
    });
  }

  /// Geocodificación centralizada con apertura automática de ventana emergente del mapa
  Future<void> _searchLocation([String? query]) async {
    final q = (query ?? _addressCtrl.text).trim();
    if (q.isEmpty) {
      setState(() => _addressError = 'Ingresa una dirección para buscar.');
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

/// Abrir ventana emergente cuadrada (1/4 del tamaño de la pantalla total) con el mapa
  void _openMapModalDialog() {
    LatLng tempLocation = _selectedLocation;
    final media = MediaQuery.of(context).size;
    const headerHeight = 46.0;
    const bottomHeight = 54.0;
    // Dimensiones adaptativas: ancho proporcional al dispositivo y alto que
    // siempre cabe en la pantalla (evita overflow en landscape/teclado).
    final modalWidth = (media.width * 0.9).clamp(280.0, 400.0);
    final mapHeight = (media.height - headerHeight - bottomHeight - 64).clamp(140.0, 380.0);

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
          clipBehavior: Clip.antiAlias,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: SizedBox(
            width: modalWidth,
            height: headerHeight + bottomHeight + mapHeight,
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
                            'Mapa (Houston, TX)',
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
                    height: mapHeight,
                    onLocationChanged: (newLoc) {
                      tempLocation = newLoc;
                    },
                  ),
                ),

                // Botón de confirmación inferior
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

  /// Cerrar sesión y volver a la pantalla de bienvenida.
  /// Al hacer signOut, AuthCubit pasa a AuthUnauthenticated y GoRouter
  /// lleva al usuario de vuelta al inicio.
  void _exitToWelcome() {
    context.read<AuthCubit>().signOut();
    context.go(AppRoutes.welcome);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final cubit = context.read<AuthCubit>();
    final profile = cubit.currentProfile;
    final user = SupabaseService.currentUser;
    final userId = profile?.id ?? user?.id;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No se encontró sesión activa de usuario.')),
      );
      return;
    }

    // ── 1. Guardar datos del paciente directamente en Supabase ──
    // NO usamos cubit.updateProfile aquí porque emite AuthLoading
    // y destruye el contexto mientras esperamos las consultas siguientes.
    final savedProfile = await SupabaseService.updateProfileData(
      userId: userId,
      fullName: profile?.fullName ?? user?.userMetadata?['full_name'] ?? 'Paciente',
      phone: _phoneCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      latitude: _selectedLocation.latitude,
      longitude: _selectedLocation.longitude,
      avatarUrl: _avatarUrl,
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

    // Mostrar confirmación de guardado exitoso
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Colors.green,
        content: Text('✅ Datos guardados en Supabase correctamente.'),
        duration: Duration(seconds: 2),
      ),
    );

    // ── 2. Verificar estado del flujo desde Supabase ──
    final status = await SupabaseService.checkPatientFlowStatus(profileId: userId);
    final bool paymentCompleted = status['paymentCompleted'] == true;
    final bool hasCompletedQuestionnaire = status['hasCompletedQuestionnaire'] == true;
    final String evaluationStatus = status['evaluationStatus']?.toString() ?? 'PENDIENTE';

    if (!mounted) return;

    // ── Si NO ha cancelado la cuota inicial de $30 ──
    if (!paymentCompleted) {
      _showStripeModal();
      return;
    }

    // ── Ya canceló la cuota → verificar cuestionario ──
    if (!hasCompletedQuestionnaire) {
      _openQuestionnaires(paid: true);
      return;
    }

    // ── Ya llenó cuestionario → revisar dictamen de evaluación médica ──
    if (evaluationStatus == 'VENCIDA') {
      _showExpiredEvaluationDialog(status['proveedorEvaluacion']?.toString() ?? 'Telemedicina / Medicina Interna');
    } else if (evaluationStatus == 'RECHAZADA') {
      _showNegativeEvaluationDialog();
    } else if (evaluationStatus == 'APROBADA') {
      _showPositiveEvaluationDialog();
    } else {
      // Estado pendiente: abrir cuestionario (que incluye evaluación médica internamente)
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
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        constraints: const BoxConstraints(maxWidth: 440),
        title: const Row(children: [
          Icon(Icons.history_toggle_off_rounded, color: Colors.orangeAccent, size: 28),
          SizedBox(width: 10),
          Expanded(child: Text('Evaluación Médica Expirada')),
        ]),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tu aprobación médica previa ($proveedor) ha cumplido su ciclo de 1 año (365 días) de validez.',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              const Text(
                'Según las políticas del sistema, para continuar reservando servicios debes realizar una nueva evaluación clínica y el abono inicial de \$30 USD.',
                style: TextStyle(fontSize: 13, color: AppTheme.cMutedText),
              ),
            ],
          ),
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
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        constraints: const BoxConstraints(maxWidth: 440),
        title: const Row(children: [
          Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 28),
          SizedBox(width: 10),
          Expanded(child: Text('Dictamen Médica No Apto', style: TextStyle(color: Colors.redAccent))),
        ]),
        content: const SingleChildScrollView(
          child: Text(
            'Tu evaluación médica previa con Qualify no resultó apta para este servicio en este momento.',
            style: TextStyle(fontSize: 14),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.go(AppRoutes.services);
            },
            child: const Text('Ir a Catálogo de Servicios'),
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
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        constraints: const BoxConstraints(maxWidth: 440),
        title: const Row(children: [
          Icon(Icons.verified_rounded, color: AppTheme.cSuccess, size: 28),
          SizedBox(width: 10),
          Expanded(child: Text('Dictamen Médico Aprobado')),
        ]),
        content: const SingleChildScrollView(
          child: Text(
            'Ya cuentas con una evaluación médica aprobada para este servicio. Redirigiendo a Cancelación Total del Servicio (Módulo a realizar a posteriori).',
            style: TextStyle(fontSize: 14),
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cDeepAccent),
            onPressed: () {
              Navigator.pop(ctx);
              context.go(AppRoutes.services);
            },
            child: const Text('Ir a Cancelación / Servicios'),
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
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          constraints: const BoxConstraints(maxWidth: 440),
          title: const Row(children: [
            Icon(Icons.credit_card_rounded, color: AppTheme.cStripe, size: 28),
            SizedBox(width: 10),
            Expanded(child: Text('Paso 2: Pago de Cuota Inicial')),
          ]),
          content: SingleChildScrollView(
            child: Column(
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
                      Flexible(
                        child: Text('Cuota Inicial:', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      SizedBox(width: 8),
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
          ),
          actions: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
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

                    final user = SupabaseService.currentUser;
                    final userId = cubitRef.currentProfile?.id ?? user?.id;
                    if (userId == null) {
                      setModal(() => processing = false);
                      return;
                    }

                    // Pago real con Stripe (o simulado si no hay clave configurada)
                    final monto = AppConstants.depositoInicial.toDouble();
                    final stripeRef = await procesarPagoStripe(
                      monto: monto,
                      concepto: 'CUOTA_INICIAL',
                    );
                    if (stripeRef == null) {
                      // Pago cancelado o falló: permitir reintentar
                      setModal(() => processing = false);
                      return;
                    }

                    // Marcar payment_completed y activar paciente
                    await sl<IPaymentsRepository>().registerInitialPayment(
                      profileId: userId,
                      amount: monto,
                      paymentReference: stripeRef,
                    );
                    // Guardar dirección principal
                    await SupabaseService.savePatientAddress(
                      profileId: userId,
                      address: _addressCtrl.text.trim(),
                      latitude: _selectedLocation.latitude,
                      longitude: _selectedLocation.longitude,
                    );

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
          ],
        ),
      ),
    ).whenComplete(() => _stripeModalOpen = false);
  }

  /// Paso 3: Cuestionarios Médicos por Servicio
  void _openQuestionnaires({required bool paid, String? stripeRef}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => PatientQuestionnaireScreen(
          serviceName: 'Estética y Belleza General',
          stripePaymentRef: stripeRef,
          onCompleted: () async {
            // El cuestionario ya ejecutó Qualify internamente.
            // Refrescamos el perfil y volvemos a llevar al paciente al catálogo.
            Navigator.pop(ctx);
            await context.read<AuthCubit>().refreshProfile();
            if (!mounted) return;
            context.go(AppRoutes.services);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<AuthCubit>();
    final isLoading = cubit.state is AuthLoading;

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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Atrás',
          onPressed: () => _exitToWelcome(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            tooltip: 'Cerrar sesión',
            onPressed: () => _exitToWelcome(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              // Avatar
              AvatarSelector(
                avatarUrl: _avatarUrl,
                onChanged: (value) => setState(() => _avatarUrl = value),
              ),
              const SizedBox(height: 18),

              // Teléfono
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: AppTheme.fieldDecoration(
                  label: 'Teléfono de Contacto',
                  hint: '+58 412 1234567',
                  prefix: const Icon(Icons.phone_outlined, color: AppTheme.cDeepAccent),
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Ingresa tu número telefónico' : null,
              ),
              const SizedBox(height: 14),

              // Dirección
              TextFormField(
                controller: _addressCtrl,
                textInputAction: TextInputAction.search,
                onFieldSubmitted: _searchLocation,
                decoration: AppTheme.fieldDecoration(
                  label: 'Dirección de Habitación',
                  hint: 'Ej: Main St, Houston, TX',
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
                          tooltip: 'Buscar Dirección y Abrir Mapa',
                        ),
                  error: _addressError,
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Ingresa tu dirección' : null,
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
                              'Ubicación en Mapa (Ventana Emergente)',
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

              // Botón de Envío
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
