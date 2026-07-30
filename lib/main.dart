import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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

enum AuthMode { dashboard, signIn, signUp }
enum UserAccessType { client, specialist, admin }

class _LoginScreenState extends State<LoginScreen> {
  // Estado del flujo de UI en el panel derecho
  AuthMode _currentAuthMode = AuthMode.dashboard;
  UserAccessType _selectedType = UserAccessType.client;

  // Controladores de formulario
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();

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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '¡Bienvenido/a! Sesión iniciada como $_currentRoleName ($email).',
              ),
              backgroundColor: _cBrandGreen,
            ),
          );
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
          _showEmailConfirmationDialog(email);
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
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => sending = true);
                      try {
                        await SupabaseService.resetPassword(emailCtrl.text.trim());
                      } catch (_) {}
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Enlace enviado. Revisa tu bandeja de entrada.',
                            ),
                            backgroundColor: Colors.teal,
                          ),
                        );
                      }
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
  // DESKTOP LAYOUT (50% Izquierda Imagen Modelo + Logo Strani / 50% Derecha Dashboard & Auth)
  // -------------------------------------------------------
  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Mitad Izquierda (50%): Imagen de la Modelo con gradiente pastel + Logo de Strani
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
                // Tarjeta flotante de branding "Estética y Belleza Strani"
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

        // Mitad Derecha (50%): Dashboard de Selección / Formulario SignIn / Formulario SignUp / SignOut
        Expanded(
          flex: 1,
          child: Container(
            color: Colors.white,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 36,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
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
            padding: const EdgeInsets.all(24),
            child: _buildRightPanelContent(),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------
  // CONTENIDO PANEL DERECHO (DASHBOARD O FORMULARIO AUTH)
  // -------------------------------------------------------
  Widget _buildRightPanelContent() {
    // 1. Si el usuario ya está autenticado, mostrar estado y botón de SignOut
    if (_loggedUser != null) {
      return _buildSignOutView();
    }

    // 2. Si se presionó Iniciar Sesión o Registrase, mostrar el formulario correspondiente
    if (_currentAuthMode == AuthMode.signIn || _currentAuthMode == AuthMode.signUp) {
      return _buildAuthFormView();
    }

    // 3. De lo contrario, mostrar el Dashboard de Selección
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
      padding: const EdgeInsets.all(20),
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
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _cDarkText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 13,
                        color: _cMutedText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onSignIn,
                  icon: const Icon(Icons.login_rounded, size: 18),
                  label: const Text('Iniciar Sesión'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _cDeepAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
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
                  icon: const Icon(Icons.person_add_outlined, size: 18),
                  label: const Text('Registrarse'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _cDeepAccent,
                    side: const BorderSide(color: _cDeepAccent),
                    padding: const EdgeInsets.symmetric(vertical: 12),
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
  // VISTA 2: FORMULARIO SIGN IN / SIGN UP (CON ROL PACIENTE O ESPECIALISTA)
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
  // VISTA 3: USUARIO AUTENTICADO / SIGN OUT
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
