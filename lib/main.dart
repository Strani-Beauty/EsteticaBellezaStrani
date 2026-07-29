import 'package:flutter/material.dart';

void main() {
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

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedRole = 'employee';
  bool _obscurePassword = true;
  bool _isLoading = false;

  // Sistema de Colores Pastel - Estética y Belleza Strani
  static const _cPastelPink = Color(0xFFF7D6E0);
  static const _cPastelBlue = Color(0xFFBEE1E6);
  static const _cPastelPurple = Color(0xFFE2ECE9);
  static const _cDeepAccent = Color(0xFF6B4F71);
  static const _cDarkText = Color(0xFF2B2D42);
  static const _cMutedText = Color(0xFF6C757D);

  final List<Map<String, String>> _rolesList = const [
    {'code': 'admin', 'name': 'Administrador del Sistema'},
    {'code': 'office', 'name': 'Personal Administrativo'},
    {'code': 'leader', 'name': 'Líder de Estudio / Cuadrilla'},
    {'code': 'employee', 'name': 'Empleado / Estilista'},
    {'code': 'mechanic', 'name': 'Mantenimiento / Técnico'},
    {'code': 'warehouse', 'name': 'Bodega / Inventario'},
    {'code': 'finance', 'name': 'Finanzas / Contabilidad'},
  ];

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleSignIn() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Bienvenido/a a Estética y Belleza Strani (${_rolesList.firstWhere((r) => r['code'] == _selectedRole)['name']})',
            ),
            backgroundColor: _cDeepAccent,
          ),
        );
      }
    }
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
                      await Future.delayed(const Duration(milliseconds: 800));
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
  // DESKTOP LAYOUT (50% Imagen Modelo Izquierda / 50% Formulario Izquierda de la toma de datos)
  // -------------------------------------------------------
  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Mitad Izquierda (50%): Imagen de la Modelo con gradiente pastel en estudio de belleza
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
                          _cPastelPink.withValues(alpha: 0.25),
                          _cPastelBlue.withValues(alpha: 0.35),
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

        // Mitad Derecha (50%): Formulario para toma de datos (usuarios, roles, password)
        Expanded(
          flex: 1,
          child: Container(
            color: Colors.white,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 56,
                  vertical: 40,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: _buildFormSection(),
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
            height: 260,
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
                  child: Container(color: Colors.black.withValues(alpha: 0.2)),
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
            child: _buildFormSection(),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------
  // FORMULARIO DE TOMA DE DATOS (Usuario, Rol, Contraseña)
  // -------------------------------------------------------
  Widget _buildFormSection() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo & Título
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _cPastelPink,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.spa_rounded,
                  color: _cDeepAccent,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Iniciar Sesión',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: _cDarkText,
                      ),
                    ),
                    Text(
                      'Estética y Belleza Strani',
                      style: TextStyle(fontSize: 13, color: _cMutedText),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // CAMPO 1: Validación / Toma de Usuario (Email)
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
              prefixIcon: const Icon(Icons.person_outline, color: _cDeepAccent),
              filled: true,
              fillColor: _cPastelPurple.withValues(alpha: 0.4),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
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
              if (v == null || v.trim().isEmpty)
                return 'Ingresa tu usuario o correo';
              if (!v.contains('@')) return 'Correo no válido';
              return null;
            },
          ),
          const SizedBox(height: 18),

          // CAMPO 2: Validación / Toma de Rol
          const Text(
            'Rol de Acceso',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _cDarkText,
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _selectedRole,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.badge_outlined, color: _cDeepAccent),
              filled: true,
              fillColor: _cPastelPurple.withValues(alpha: 0.4),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
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
            items: _rolesList.map((role) {
              return DropdownMenuItem<String>(
                value: role['code'],
                child: Text(
                  role['name']!,
                  style: const TextStyle(fontSize: 14, color: _cDarkText),
                ),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedRole = val);
            },
          ),
          const SizedBox(height: 18),

          // CAMPO 3: Validación / Toma de Contraseña (Password)
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
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
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
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Ingresa tu contraseña' : null,
          ),
          const SizedBox(height: 28),

          // BOTÓN: Iniciar Sesión
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleSignIn,
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
                  : const Text(
                      'Ingresar al Sistema',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 24),
          Center(
            child: Text(
              'Estética y Belleza Strani © 2026 - Todos los derechos reservados',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ),
        ],
      ),
    );
  }
}
