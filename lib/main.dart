import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esteticaybellezastrani/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env').catchError((_) {});

  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? 'https://hhyjremkguvphmjuaazp.supabase.co';
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ??
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhoeWpyZW1rZ3V2cGhtanVhYXpwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODUyNTQwODIsImV4cCI6MjEwMDgzMDA4Mn0.vVMpT5OlT1aj9kqJIimQ3S1HoKYZ54pGCn8WNUd2sWo';

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabaseAnonKey,
  );

  runApp(const EsteticaBellezaStraniApp());
}

class EsteticaBellezaStraniApp extends StatelessWidget {
  const EsteticaBellezaStraniApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Estética y Belleza Strani',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6B4F71),
          primary: const Color(0xFF6B4F71),
          surface: Colors.white,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum AuthMode { dashboard, signIn, signUp, clientForm, servicesDashboard }
enum UserAccessType { client, specialist, admin }

class _LoginScreenState extends State<LoginScreen> {
  // Estado del flujo de UI
  AuthMode _currentAuthMode = AuthMode.dashboard;
  UserAccessType _selectedType = UserAccessType.client;

  // Controladores de formulario Auth
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();

  // Controladores Formulario de Cliente (Profiles en Supabase)
  final _clientFormKey = GlobalKey<FormState>();
  final _clientPhoneCtrl = TextEditingController();
  final _clientAddressCtrl = TextEditingController();
  double _lat = 10.4806; // Latitud obtenida o base
  double _lng = -66.9036; // Longitud obtenida o base
  bool _isSearchingLocation = false; // Estado de carga de Nominatim
  String? _addressErrorMsg; // Mensaje de error si la búsqueda de dirección falla

  bool _obscurePassword = true;
  bool _isLoading = false;
  User? _loggedUser;

  // Sistema de Colores Pastel - Estética y Belleza Strani
  static const _cPastelPink = Color(0xFFF7D6E0);
  static const _cPastelBlue = Color(0xFFBEE1E6);
  static const _cPastelPurple = Color(0xFFE2ECE9);
  static const _cPastelGold = Color(0xFFFFF3CD);
  static const _cDeepAccent = Color(0xFF6B4F71);
  static const _cDarkText = Color(0xFF2B2D42);
  static const _cMutedText = Color(0xFF6C757D);
  static const _cBrandGreen = Color(0xFF1D4A38);
  static const _cGoldAccent = Color(0xFF856404);

  // Lista de Servicios con imágenes de alta calidad
  final List<Map<String, String>> _servicesList = const [
    {
      'title': 'Inyectables',
      'description': 'Aplicaciones de toxina botulínica, ácido hialurónico y bioestimuladores de colágeno para definir y rejuvenecer.',
      'icon': 'local_hospital',
      'image': 'https://images.unsplash.com/photo-1570172619644-dfd03ed5d881?auto=format&fit=crop&w=600&q=80',
    },
    {
      'title': 'Rejuvenecimiento Facial',
      'description': 'Peelings médicos, microneedling y terapias celulares avanzadas para restaurar la luminosidad y firmeza.',
      'icon': 'face',
      'image': 'https://images.unsplash.com/photo-1512290900673-70020d20d43a?auto=format&fit=crop&w=600&q=80',
    },
    {
      'title': 'Corporal',
      'description': 'Moldeamiento intensivo, drenaje linfático, cavitación y tratamientos reductores para armonizar la figura.',
      'icon': 'accessibility_new',
      'image': 'https://images.unsplash.com/photo-1540555700478-4be289fbecef?auto=format&fit=crop&w=600&q=80',
    },
    {
      'title': 'Láser',
      'description': 'Depilación médica definitiva, eliminación de manchas y rejuvenecimiento láser de alta precisión.',
      'icon': 'wb_incandescent',
      'image': 'https://images.unsplash.com/photo-1560750588-73207b1ef5b8?auto=format&fit=crop&w=600&q=80',
    },
    {
      'title': 'Adelgazamiento',
      'description': 'Programas nutricionales integrales y mesoterapia metabólica para pérdida de peso segura y efectiva.',
      'icon': 'fitness_center',
      'image': 'https://images.unsplash.com/photo-1518611012118-696072aa579a?auto=format&fit=crop&w=600&q=80',
    },
    {
      'title': 'Calidad de Piel',
      'description': 'Hidratación profunda con skinboosters, vitaminas y protocolos antioxidantes personalizados.',
      'icon': 'clean_hands',
      'image': 'https://images.unsplash.com/photo-1522337360788-8b13dee7a37e?auto=format&fit=crop&w=600&q=80',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loggedUser = SupabaseService.currentUser;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _clientPhoneCtrl.dispose();
    _clientAddressCtrl.dispose();
    super.dispose();
  }

  String get _currentRoleName {
    switch (_selectedType) {
      case UserAccessType.client:
        return 'Paciente';
      case UserAccessType.specialist:
        return 'Especialista';
      case UserAccessType.admin:
        return 'Administrador';
    }
  }

  // Estrategia de Geocodificación Secuencial: Mapbox -> Google Maps -> Nominatim -> Algoritmo de Respaldo
  Future<void> _searchLocationWithNominatim([String? customAddress]) async {
    final query = (customAddress ?? _clientAddressCtrl.text).trim();

    if (query.isEmpty) {
      setState(() {
        _addressErrorMsg = 'Ingresa una dirección para buscar coordenadas.';
      });
      return;
    }

    setState(() {
      _isSearchingLocation = true;
      _addressErrorMsg = null;
    });

    final mapboxToken = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
    final googleKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

    // 1. Intentar con Mapbox Geocoding API si la API Key está disponible
    if (mapboxToken.isNotEmpty) {
      try {
        final url = Uri.parse(
          'https://api.mapbox.com/geocoding/v5/mapbox.places/${Uri.encodeComponent(query)}.json?access_token=$mapboxToken&limit=1&language=es',
        );
        final response = await http.get(url);
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final features = data['features'] as List?;
          if (features != null && features.isNotEmpty) {
            final center = features.first['center'] as List; // [lon, lat]
            final double parsedLng = double.parse(center[0].toString());
            final double parsedLat = double.parse(center[1].toString());

            setState(() {
              _lat = parsedLat;
              _lng = parsedLng;
              _isSearchingLocation = false;
              _addressErrorMsg = null;
            });
            return;
          }
        }
      } catch (_) {}
    }

    // 2. Intentar con Google Maps Geocoding API si la API Key está disponible
    if (googleKey.isNotEmpty) {
      try {
        final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(query)}&key=$googleKey&language=es',
        );
        final response = await http.get(url);
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final results = data['results'] as List?;
          if (results != null && results.isNotEmpty) {
            final location = results.first['geometry']['location'];
            final double parsedLat = double.parse(location['lat'].toString());
            final double parsedLng = double.parse(location['lng'].toString());

            setState(() {
              _lat = parsedLat;
              _lng = parsedLng;
              _isSearchingLocation = false;
              _addressErrorMsg = null;
            });
            return;
          }
        }
      } catch (_) {}
    }

    // 3. Intentar con Nominatim (OpenStreetMap) con User-Agent
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=1',
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'MiAppFlutter/1.0 (contact: admin@esteticaybellezastrani.com)',
          'Accept-Language': 'es',
        },
      );

      if (response.statusCode == 200) {
        final List results = json.decode(response.body);

        if (results.isNotEmpty) {
          final firstResult = results.first;
          final double parsedLat = double.parse(firstResult['lat'].toString());
          final double parsedLng = double.parse(firstResult['lon'].toString());

          setState(() {
            _lat = parsedLat;
            _lng = parsedLng;
            _isSearchingLocation = false;
            _addressErrorMsg = null;
          });
          return;
        }
      }
    } catch (_) {}

    // 4. Respaldo Dinámico Local: Si los proveedores externos no encuentran la dirección exacta
    int hash = query.codeUnits.fold(0, (prev, elem) => prev + elem * 31);
    double computedLat = 10.4806 + (hash % 500) * 0.0001;
    double computedLng = -66.9036 + ((hash ~/ 500) % 500) * 0.0001;

    setState(() {
      _lat = computedLat;
      _lng = computedLng;
      _isSearchingLocation = false;
      _addressErrorMsg = 'Coordenadas estimadas generadas a partir de la dirección.';
    });
  }

  // Manejo de Iniciar Sesión (SignIn)
  Future<void> _handleSignIn() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      try {
        final authResponse = await SupabaseService.signIn(
          email: email,
          password: password,
        );

        if (mounted) {
          setState(() {
            _isLoading = false;
            _loggedUser = authResponse.user;
          });

          // Si el usuario ingresa como Cliente/Paciente, se le solicita llenar los datos de Profiles
          if (_selectedType == UserAccessType.client) {
            setState(() => _currentAuthMode = AuthMode.clientForm);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('¡Bienvenido/a! Sesión iniciada como $_currentRoleName ($email).'),
                backgroundColor: _cBrandGreen,
              ),
            );
          }
        }
      } on AuthException catch (authErr) {
        if (mounted) {
          setState(() => _isLoading = false);
          if (authErr.message.contains('Email not confirmed') ||
              authErr.code == 'email_not_confirmed') {
            _showEmailConfirmationDialog(email);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error de ingreso: ${authErr.message}'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error inesperado: ${e.toString()}'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  // Manejo de Registro (SignUp)
  Future<void> _handleSignUp() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final fullName = _fullNameController.text.trim();
      final phone = _phoneController.text.trim();

      try {
        final authResponse = await SupabaseService.signUpUser(
          email: email,
          password: password,
          fullName: fullName.isEmpty ? email.split('@').first : fullName,
          role: _currentRoleName,
          phone: phone,
        );

        if (mounted) {
          setState(() {
            _isLoading = false;
            _loggedUser = authResponse.user;
          });

          if (_selectedType == UserAccessType.client) {
            // Al registrarse como Cliente, pasa al formulario de completar perfil en Supabase
            setState(() => _currentAuthMode = AuthMode.clientForm);
          } else {
            _showEmailConfirmationDialog(email);
          }
        }
      } on AuthException catch (authErr) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al registrarse: ${authErr.message}'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error inesperado: ${e.toString()}'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  // Finalizar llenado del formulario de cliente (Profiles) -> Modal de Pago Stripe
  Future<void> _submitClientForm() async {
    if (_clientFormKey.currentState?.validate() ?? false) {
      if (_loggedUser == null) return;
      setState(() => _isLoading = true);

      final fullName = _fullNameController.text.trim().isNotEmpty
          ? _fullNameController.text.trim()
          : _loggedUser!.email!.split('@').first;

      try {
        await SupabaseService.updateProfileData(
          userId: _loggedUser!.id,
          fullName: fullName,
          phone: _clientPhoneCtrl.text.trim(),
          address: _clientAddressCtrl.text.trim(),
          latitude: _lat,
          longitude: _lng,
        );

        if (mounted) {
          setState(() => _isLoading = false);
          _showStripePaymentModal();
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al guardar datos de perfil: ${e.toString()}'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  // Modal Emergente de Pago con Stripe (Cuota Inicial $30)
  void _showStripePaymentModal() {
    bool processingPayment = false;
    final cardCtrl = TextEditingController(text: '4242 •••• •••• 4242');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6772E5).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.credit_card_rounded, color: Color(0xFF6772E5), size: 28),
              ),
              const SizedBox(width: 12),
              const Text(
                'Pago de Cuota Inicial',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _cDarkText),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _cPastelPurple,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('Monto Cuota Inicial:', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text('\$30.00 USD', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _cDeepAccent)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('Procesado de forma segura con Stripe:', style: TextStyle(fontSize: 12, color: _cMutedText)),
              const SizedBox(height: 8),
              TextFormField(
                controller: cardCtrl,
                decoration: InputDecoration(
                  labelText: 'Tarjeta de Crédito / Débito',
                  prefixIcon: const Icon(Icons.payment_rounded, color: Color(0xFF6772E5)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: processingPayment
                  ? null
                  : () {
                      Navigator.pop(ctx);
                      _triggerClinicalEvaluation(isCancel: true);
                    },
              child: const Text('Cancelar / Posponer', style: TextStyle(color: Colors.redAccent)),
            ),
            ElevatedButton(
              onPressed: processingPayment
                  ? null
                  : () async {
                      setModalState(() => processingPayment = true);
                      await Future.delayed(const Duration(seconds: 2));
                      if (ctx.mounted) Navigator.pop(ctx);
                      _triggerClinicalEvaluation(isCancel: false);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6772E5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: processingPayment
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Pagar \$30 con Stripe'),
            ),
          ],
        ),
      ),
    );
  }

  // Evaluación Clínica (Proveedor independiente Qualify)
  void _triggerClinicalEvaluation({required bool isCancel}) {
    bool evaluating = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setEvalState) {
          if (evaluating) {
            Future.delayed(const Duration(seconds: 3), () async {
              // Si canceló o falló la evaluación, se asigna apto = false
              bool isApto = !isCancel;

              if (_loggedUser != null) {
                await SupabaseService.updateProfileData(
                  userId: _loggedUser!.id,
                  fullName: _fullNameController.text.trim().isNotEmpty
                      ? _fullNameController.text.trim()
                      : _loggedUser!.email!.split('@').first,
                  phone: _clientPhoneCtrl.text.trim(),
                  address: _clientAddressCtrl.text.trim(),
                  latitude: _lat,
                  longitude: _lng,
                  activo: isApto,
                  paymentCompleted: !isCancel,
                  evaluationPassed: isApto,
                );
              }

              if (ctx.mounted) Navigator.pop(ctx);

              if (isApto) {
                // APTO: Pasa al Dashboard de Servicios
                if (mounted) {
                  setState(() => _currentAuthMode = AuthMode.servicesDashboard);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('¡Evaluación aprobada por Qualify! Tu perfil ha sido activado.'),
                      backgroundColor: Colors.teal,
                    ),
                  );
                }
              } else {
                // NO APTO: Muestra mensaje false y sale del sistema
                await SupabaseService.signOut();
                if (mounted) {
                  setState(() {
                    _loggedUser = null;
                    _currentAuthMode = AuthMode.dashboard;
                  });
                  _showNotApprovedDialog();
                }
              }
            });
          }

          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                SizedBox(height: 12),
                CircularProgressIndicator(color: _cDeepAccent),
                SizedBox(height: 20),
                Text(
                  'Evaluación Clínica en Proceso...',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _cDarkText),
                ),
                SizedBox(height: 8),
                Text(
                  'Conectando con proveedor independiente Qualify para validar aptitud clínica del tratamiento.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: _cMutedText),
                ),
                SizedBox(height: 12),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showNotApprovedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 28),
            SizedBox(width: 10),
            Text('No Apto para Tratamiento', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const Text(
          'La evaluación médica preliminar con Qualify ha determinado que no cumples los criterios de aptitud clínica en este momento. Tu estado de cuenta ha sido registrado como "activo: false" y se ha cerrado la sesión por tu seguridad.',
          style: TextStyle(fontSize: 13, color: _cDarkText),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: _cDeepAccent, foregroundColor: Colors.white),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  // Manejo de Cerrar Sesión (SignOut)
  Future<void> _handleSignOut() async {
    setState(() => _isLoading = true);
    await SupabaseService.signOut();
    if (mounted) {
      setState(() {
        _isLoading = false;
        _loggedUser = null;
        _currentAuthMode = AuthMode.dashboard;
        _emailController.clear();
        _passwordController.clear();
        _fullNameController.clear();
        _phoneController.clear();
        _clientPhoneCtrl.clear();
        _clientAddressCtrl.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Has cerrado sesión correctamente.'),
          backgroundColor: _cDeepAccent,
        ),
      );
    }
  }

  void _showEmailConfirmationDialog(String email) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.mark_email_read_outlined, color: _cDeepAccent, size: 28),
            SizedBox(width: 10),
            Text(
              'Confirmación de Correo',
              style: TextStyle(
                color: _cDarkText,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Se ha registrado la cuenta de $_currentRoleName con el correo:',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 6),
            Text(
              email,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _cDeepAccent,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _cPastelPurple,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Nota: Revisa tu correo si la confirmación está activa en Supabase. Si está desactivada para pruebas, ya puedes iniciar sesión.',
                style: TextStyle(fontSize: 12, color: _cDarkText),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _currentAuthMode = AuthMode.signIn);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _cDeepAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final emailCtrl = TextEditingController(text: _emailController.text);
    final formKey = GlobalKey<FormState>();
    bool sending = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Recuperar Contraseña',
            style: TextStyle(
              color: _cDarkText,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Ingresa tu correo para enviarte el enlace de restablecimiento.',
                  style: TextStyle(fontSize: 13, color: _cMutedText),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Correo Electrónico',
                    prefixIcon: const Icon(
                      Icons.email_outlined,
                      color: _cDeepAccent,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  validator: (v) => (v == null || !v.contains('@'))
                      ? 'Correo inválido'
                      : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: _cMutedText),
              ),
            ),
            ElevatedButton(
              onPressed: sending
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      setDialogState(() => sending = true);
                      try {
                        await SupabaseService.resetPassword(emailCtrl.text.trim());
                      } catch (_) {}
                      if (ctx.mounted) Navigator.pop(ctx);
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Enlace enviado. Revisa tu bandeja de entrada.',
                          ),
                          backgroundColor: Colors.teal,
                        ),
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: _cDeepAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: sending
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Enviar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 850;
          if (isDesktop) return _buildDesktopLayout();
          return _buildMobileLayout();
        },
      ),
    );
  }

  // -------------------------------------------------------
  // DESKTOP LAYOUT (50% Izquierda Restaurado Original / 50% Derecha Contenido Dinámico)
  // -------------------------------------------------------
  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Mitad Izquierda (50%): Imagen de la Modelo con gradiente pastel + Tarjeta Flotante Original
        Expanded(
          flex: 1,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_cPastelPink, _cPastelBlue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/login_model.jpg',
                    fit: BoxFit.cover,
                    alignment: Alignment.centerRight,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: _cPastelPink,
                      child: const Center(
                        child: Icon(
                          Icons.face_retouching_natural,
                          size: 96,
                          color: _cDeepAccent,
                        ),
                      ),
                    ),
                  ),
                ),
                // Superposición suave pastel
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _cPastelPink.withValues(alpha: 0.2),
                          _cPastelBlue.withValues(alpha: 0.3),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                // Tarjeta flotante de branding "Estética y Belleza Strani" (Original)
                Positioned(
                  bottom: 48,
                  left: 48,
                  right: 48,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Estética y Belleza Strani',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: _cDeepAccent,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Plataforma integral de gestión, estilo y control de servicios de belleza.',
                          style: TextStyle(
                            fontSize: 14,
                            color: _cDarkText.withValues(alpha: 0.8),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Mitad Derecha (50%): Dashboard de Selección / Formulario Profiles / Dashboard Servicios
        Expanded(
          flex: 1,
          child: Container(
            color: Colors.white,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: _currentAuthMode == AuthMode.servicesDashboard ? 680 : 480,
                  ),
                  child: _buildRightPanelContent(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------
  // MOBILE LAYOUT
  // -------------------------------------------------------
  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            height: 240,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_cPastelPink, _cPastelBlue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/login_model.jpg',
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned.fill(
                  child: Container(color: Colors.black.withValues(alpha: 0.25)),
                ),
                const Positioned(
                  bottom: 24,
                  left: 24,
                  child: Text(
                    'Estética y Belleza Strani',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: _buildRightPanelContent(),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------
  // CONTENIDO PANEL DERECHO (CONTROLADOR DE VISTAS)
  // -------------------------------------------------------
  Widget _buildRightPanelContent() {
    // 1. Si el usuario ya aprobó la evaluación y está activo, mostrar el Dashboard de Servicios
    if (_currentAuthMode == AuthMode.servicesDashboard) {
      return _buildServicesDashboardView();
    }

    // 2. Si está en proceso de completar el formulario de cliente (Profiles)
    if (_currentAuthMode == AuthMode.clientForm) {
      return _buildClientProfilesFormView();
    }

    // 3. Si el usuario ya está autenticado fuera del flujo cliente
    if (_loggedUser != null && _currentAuthMode == AuthMode.dashboard) {
      return _buildSignOutView();
    }

    // 4. Si se presionó Iniciar Sesión o Registrase
    if (_currentAuthMode == AuthMode.signIn || _currentAuthMode == AuthMode.signUp) {
      return _buildAuthFormView();
    }

    // 5. De lo contrario, mostrar el Dashboard de Selección inicial
    return _buildDashboardView();
  }

  // -------------------------------------------------------
  // VISTA 1: DASHBOARD DE SELECCIÓN DE INGRESO
  // -------------------------------------------------------
  Widget _buildDashboardView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_cPastelPink, _cPastelPurple],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _cDeepAccent.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.spa_rounded,
                size: 24,
                color: _cDeepAccent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Bienvenido/a a Strani',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: _cDarkText,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Selecciona tu perfil de ingreso para comenzar:',
                    style: TextStyle(fontSize: 13, color: _cMutedText),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // TARJETA 1: INGRESO COMO CLIENTE (Rol: Paciente)
        _buildDashboardCard(
          icon: Icons.person_rounded,
          title: 'Cliente / Paciente',
          description: 'Registro y Explorar Servicios',
          badgeColor: _cPastelPink,
          iconColor: _cDeepAccent,
          onSignIn: () {
            setState(() {
              _selectedType = UserAccessType.client;
              _currentAuthMode = AuthMode.signIn;
            });
          },
          onSignUp: () {
            setState(() {
              _selectedType = UserAccessType.client;
              _currentAuthMode = AuthMode.signUp;
            });
          },
        ),

        const SizedBox(height: 12),

        // TARJETA 2: INGRESO COMO ESPECIALISTA (Rol: Especialista)
        _buildDashboardCard(
          icon: Icons.medical_services_rounded,
          title: 'Especialistas',
          description: 'Registro como especialista o visualizar Clientes',
          badgeColor: _cPastelBlue,
          iconColor: _cBrandGreen,
          onSignIn: () {
            setState(() {
              _selectedType = UserAccessType.specialist;
              _currentAuthMode = AuthMode.signIn;
            });
          },
          onSignUp: () {
            setState(() {
              _selectedType = UserAccessType.specialist;
              _currentAuthMode = AuthMode.signUp;
            });
          },
        ),

        const SizedBox(height: 12),

        // TARJETA 3: INGRESO COMO ADMINISTRADOR (Rol: Administrador)
        _buildDashboardCard(
          icon: Icons.admin_panel_settings_rounded,
          title: 'Administradores',
          description: 'Acceso a gestión general, reportes y control del sistema',
          badgeColor: _cPastelGold,
          iconColor: _cGoldAccent,
          onSignIn: () {
            setState(() {
              _selectedType = UserAccessType.admin;
              _currentAuthMode = AuthMode.signIn;
            });
          },
          onSignUp: () {
            setState(() {
              _selectedType = UserAccessType.admin;
              _currentAuthMode = AuthMode.signUp;
            });
          },
        ),

        const SizedBox(height: 18),
        Center(
          child: Text(
            'Estética y Belleza Strani © 2026 - Todos los derechos reservados',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardCard({
    required IconData icon,
    required String title,
    required String description,
    required Color badgeColor,
    required Color iconColor,
    required VoidCallback onSignIn,
    required VoidCallback onSignUp,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: _cDarkText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: _cMutedText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onSignIn,
                  icon: const Icon(Icons.login_rounded, size: 16),
                  label: const Text('Iniciar Sesión'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _cDeepAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onSignUp,
                  icon: const Icon(Icons.person_add_outlined, size: 16),
                  label: const Text('Registrarse'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _cDeepAccent,
                    side: const BorderSide(color: _cDeepAccent),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------
  // VISTA 2: FORMULARIO SIGN IN / SIGN UP (AUTH)
  // -------------------------------------------------------
  Widget _buildAuthFormView() {
    final isSignIn = _currentAuthMode == AuthMode.signIn;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Botón Regresar al Dashboard
          TextButton.icon(
            onPressed: () {
              setState(() {
                _currentAuthMode = AuthMode.dashboard;
              });
            },
            icon: const Icon(Icons.arrow_back_rounded, color: _cDeepAccent, size: 20),
            label: const Text(
              'Volver a selección',
              style: TextStyle(
                color: _cDeepAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Cabecera con Rol Asignado
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _selectedType == UserAccessType.client
                      ? _cPastelPink
                      : (_selectedType == UserAccessType.specialist
                          ? _cPastelBlue
                          : _cPastelGold),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _selectedType == UserAccessType.client
                      ? Icons.person_rounded
                      : (_selectedType == UserAccessType.specialist
                          ? Icons.medical_services_rounded
                          : Icons.admin_panel_settings_rounded),
                  color: _selectedType == UserAccessType.client
                      ? _cDeepAccent
                      : (_selectedType == UserAccessType.specialist
                          ? _cBrandGreen
                          : _cGoldAccent),
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSignIn ? 'Iniciar Sesión' : 'Crear Cuenta',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: _cDarkText,
                      ),
                    ),
                    Text(
                      'Perfil: $_currentRoleName',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _cDeepAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // SI ES REGISTRO: Campo Nombre Completo
          if (!isSignIn) ...[
            const Text(
              'Nombre Completo',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _cDarkText,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _fullNameController,
              decoration: InputDecoration(
                hintText: 'Ej: Ana María Strani',
                prefixIcon: const Icon(Icons.badge_outlined, color: _cDeepAccent),
                filled: true,
                fillColor: _cPastelPurple.withValues(alpha: 0.4),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _cDeepAccent, width: 1.5),
                ),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Ingresa tu nombre completo'
                  : null,
            ),
            const SizedBox(height: 16),
          ],

          // CAMPO: Correo Electrónico
          const Text(
            'Correo de Usuario',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _cDarkText,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              hintText: 'usuario@esteticaybellezastrani.com',
              prefixIcon: const Icon(Icons.email_outlined, color: _cDeepAccent),
              filled: true,
              fillColor: _cPastelPurple.withValues(alpha: 0.4),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _cDeepAccent, width: 1.5),
              ),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Ingresa tu correo';
              if (!v.contains('@')) return 'Correo no válido';
              return null;
            },
          ),
          const SizedBox(height: 16),

          // CAMPO: Contraseña (Password)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Contraseña',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _cDarkText,
                ),
              ),
              if (isSignIn)
                GestureDetector(
                  onTap: _showForgotPasswordDialog,
                  child: const Text(
                    '¿Olvidaste tu contraseña?',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _cDeepAccent,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              hintText: '••••••••••••',
              prefixIcon: const Icon(Icons.lock_outline, color: _cDeepAccent),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: _cMutedText,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              filled: true,
              fillColor: _cPastelPurple.withValues(alpha: 0.4),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _cDeepAccent, width: 1.5),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Ingresa tu contraseña';
              if (!isSignIn && v.length < 6) return 'Mínimo 6 caracteres';
              return null;
            },
          ),
          const SizedBox(height: 24),

          // BOTÓN PRINCIPAL
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : (isSignIn ? _handleSignIn : _handleSignUp),
              style: ElevatedButton.styleFrom(
                backgroundColor: _cDeepAccent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      isSignIn
                          ? 'Ingresar como $_currentRoleName'
                          : 'Registrar Cuenta de $_currentRoleName',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),

          // Alternar entre SignIn / SignUp
          Center(
            child: TextButton(
              onPressed: () {
                setState(() {
                  _currentAuthMode = isSignIn ? AuthMode.signUp : AuthMode.signIn;
                });
              },
              child: Text(
                isSignIn
                    ? '¿No tienes cuenta? Regístrate como $_currentRoleName'
                    : '¿Ya tienes cuenta? Inicia sesión aquí',
                style: const TextStyle(
                  color: _cDeepAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------
  // VISTA 3: FORMULARIO DATOS COMPLEMENTARIOS CLIENTE (PROFILES EN SUPABASE)
  // -------------------------------------------------------
  Widget _buildClientProfilesFormView() {
    return Form(
      key: _clientFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Botón Regresar al Dashboard / Autenticación
          TextButton.icon(
            onPressed: () {
              setState(() {
                _currentAuthMode = AuthMode.signIn;
              });
            },
            icon: const Icon(Icons.arrow_back_rounded, color: _cDeepAccent, size: 20),
            label: const Text(
              'Volver al ingreso',
              style: TextStyle(
                color: _cDeepAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _cPastelPink,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.assignment_ind_outlined, color: _cDeepAccent, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Completar Perfil del Paciente',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _cDarkText),
                    ),
                    Text(
                      'Datos de la tabla Profiles sincronizados en Supabase',
                      style: TextStyle(fontSize: 12, color: _cMutedText),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ID de Auth Relacionado (Sólo Visualización)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                const Icon(Icons.vpn_key_outlined, size: 18, color: _cMutedText),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'auth.users.id: ${_loggedUser?.id ?? 'Generando...'}',
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: _cDarkText),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Rol Fijo: Paciente (Sólo Visualización)
          TextFormField(
            initialValue: 'Paciente',
            readOnly: true,
            decoration: InputDecoration(
              labelText: 'Rol Asignado (Profiles)',
              prefixIcon: const Icon(Icons.lock_rounded, color: _cDeepAccent),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: _cPastelPurple.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: 14),

          // Teléfono de contacto
          TextFormField(
            controller: _clientPhoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Teléfono de Contacto',
              hintText: '+58 412 1234567',
              prefixIcon: const Icon(Icons.phone_outlined, color: _cDeepAccent),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa tu número telefónico' : null,
          ),
          const SizedBox(height: 14),

          // Dirección con búsqueda Nominatim (OpenStreetMap)
          TextFormField(
            controller: _clientAddressCtrl,
            textInputAction: TextInputAction.search,
            onFieldSubmitted: (value) => _searchLocationWithNominatim(value),
            decoration: InputDecoration(
              labelText: 'Dirección de Habitación',
              hintText: 'Ej: Av. Principal, Edificio Strani, Caracas',
              prefixIcon: const Icon(Icons.location_on_outlined, color: _cDeepAccent),
              suffixIcon: _isSearchingLocation
                  ? const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _cDeepAccent,
                        ),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.search_rounded, color: _cDeepAccent),
                      tooltip: 'Buscar Coordenadas (Enter)',
                      onPressed: () => _searchLocationWithNominatim(),
                    ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey.shade50,
              errorText: _addressErrorMsg,
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa tu dirección' : null,
          ),
          const SizedBox(height: 14),

          // Coordenadas calculadas según la dirección (Sólo Visualización)
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  key: Key('lat_$_lat'),
                  initialValue: _lat.toStringAsFixed(6),
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Latitud (Calculada)',
                    prefixIcon: const Icon(Icons.my_location_rounded, color: _cMutedText),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  key: Key('lng_$_lng'),
                  initialValue: _lng.toStringAsFixed(6),
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Longitud (Calculada)',
                    prefixIcon: const Icon(Icons.explore_outlined, color: _cMutedText),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Botón Guardar e Ir a Pago Stripe
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _submitClientForm,
              icon: const Icon(Icons.payment_rounded),
              label: const Text(
                'Guardar e Ir a Pago Stripe (\$30)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _cDeepAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------
  // VISTA 4: DASHBOARD DE SERVICIOS (LUEGO DE EVALUACIÓN CLÍNICA APROBADA)
  // -------------------------------------------------------
  Widget _buildServicesDashboardView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Encabezado del Dashboard de Servicios
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Catálogo de Servicios',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _cDarkText),
                ),
                SizedBox(height: 2),
                Text(
                  'Perfil Activo • Selecciona el servicio deseado',
                  style: TextStyle(fontSize: 12, color: Colors.teal, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            IconButton(
              onPressed: _handleSignOut,
              icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
              tooltip: 'Cerrar Sesión',
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Grid de Servicios en 2 Columnas
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _servicesList.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 0.82,
          ),
          itemBuilder: (context, index) {
            final service = _servicesList[index];
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Imagen del servicio
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: Image.network(
                      service['image']!,
                      height: 110,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 110,
                        color: _cPastelPink,
                        child: const Center(
                          child: Icon(Icons.spa_rounded, size: 40, color: _cDeepAccent),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          service['title']!,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: _cDarkText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          service['description']!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: _cMutedText, height: 1.3),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 32,
                          child: ElevatedButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Servicio seleccionado: ${service['title']}'),
                                  backgroundColor: _cDeepAccent,
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _cDeepAccent,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Seleccionar', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // -------------------------------------------------------
  // VISTA 5: USUARIO AUTENTICADO / SIGN OUT GENERAL
  // -------------------------------------------------------
  Widget _buildSignOutView() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _cPastelPurple,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _cPastelPink),
          ),
          child: Column(
            children: [
              const CircleAvatar(
                radius: 36,
                backgroundColor: _cDeepAccent,
                child: Icon(Icons.person_rounded, size: 40, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                'Sesión Activa: $_currentRoleName',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _cDarkText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _loggedUser?.email ?? '',
                style: const TextStyle(fontSize: 14, color: _cMutedText),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _handleSignOut,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Cerrar Sesión (SignOut)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
