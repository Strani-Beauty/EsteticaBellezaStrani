import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import 'package:esteticaybellezastrani/app/config/app_constants.dart';
import 'package:esteticaybellezastrani/app/config/app_routes.dart';
import '../cubits/auth_cubit.dart';
import '../widgets/role_selector_card.dart';
import '../widgets/auth_form_section.dart';

/// Pantalla de autenticación — Login + Registro por rol.
/// Migrado del _LoginScreenState original, preservando la UI pastel.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum _UserType { client, specialist, admin }
enum _AuthMode { roleSelection, signIn, signUp }

class _LoginScreenState extends State<LoginScreen> {
  _AuthMode _mode = _AuthMode.roleSelection;
  _UserType _selectedType = _UserType.client;

  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  String get _rolNombre {
    switch (_selectedType) {
      case _UserType.client:     return AppConstants.rolPaciente;
      case _UserType.specialist: return AppConstants.rolEspecialista;
      case _UserType.admin:      return AppConstants.rolAdministrador;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          // GoRouter redirect se encarga del enrutamiento por rol
          context.go(_redirectForRole(state.profile.rolNombre));
        } else if (state is AuthError) {
          _showError(state.message);
        } else if (state is AuthEmailConfirmationSent) {
          _showEmailConfirmation(state.email);
        }
      },
      child: Scaffold(
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 850;
            return isDesktop ? _buildDesktop() : _buildMobile();
          },
        ),
      ),
    );
  }

  // ── Desktop Layout ──────────────────────────────────────────
  Widget _buildDesktop() {
    return Row(
      children: [
        // Panel izquierdo — Branding
        Expanded(child: _buildBrandPanel()),
        // Panel derecho — Formulario
        Expanded(
          child: Container(
            color: Colors.white,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: _buildContent(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobile() {
    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(height: 220, child: _buildBrandPanel()),
          Padding(
            padding: const EdgeInsets.all(20),
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandPanel() {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.brandGradient),
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/login_model.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: AppTheme.cPastelPink,
                child: const Center(
                  child: Icon(Icons.face_retouching_natural,
                      size: 96, color: AppTheme.cDeepAccent),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.cPastelPink.withValues(alpha: 0.25),
                    AppTheme.cPastelBlue.withValues(alpha: 0.35),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 40, left: 40, right: 40,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppConstants.appName,
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 6),
                  Text(
                    'Plataforma integral de gestión y servicios de belleza.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      child: switch (_mode) {
        _AuthMode.roleSelection => _buildRoleSelection(),
        _AuthMode.signIn        => _buildAuthForm(isSignIn: true),
        _AuthMode.signUp        => _buildAuthForm(isSignIn: false),
      },
    );
  }

  // ── Vista 1: Selección de Rol ───────────────────────────────
  Widget _buildRoleSelection() {
    return Column(
      key: const ValueKey('roleSelection'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.cPastelPink, AppTheme.cPastelPurple],
                ),
                shape: BoxShape.circle,
                boxShadow: AppTheme.cardShadow,
              ),
              child: const Icon(Icons.spa_rounded, size: 24, color: AppTheme.cDeepAccent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bienvenido/a a Strani',
                      style: Theme.of(context).textTheme.titleMedium),
                  Text('Selecciona tu perfil de ingreso:',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        RoleSelectorCard(
          icon: Icons.person_rounded,
          title: 'Cliente / Paciente',
          description: 'Reserva servicios y sigue tu historial',
          badgeColor: AppTheme.cPastelPink,
          iconColor: AppTheme.cDeepAccent,
          onSignIn: () => _goToAuth(_UserType.client, signIn: true),
          onSignUp: () => _goToAuth(_UserType.client, signIn: false),
        ),
        const SizedBox(height: 12),
        RoleSelectorCard(
          icon: Icons.medical_services_rounded,
          title: 'Especialista',
          description: 'Gestiona citas y expedientes clínicos',
          badgeColor: AppTheme.cPastelBlue,
          iconColor: AppTheme.cBrandGreen,
          onSignIn: () => _goToAuth(_UserType.specialist, signIn: true),
          onSignUp: () => _goToAuth(_UserType.specialist, signIn: false),
        ),
        const SizedBox(height: 12),
        RoleSelectorCard(
          icon: Icons.admin_panel_settings_rounded,
          title: 'Administrador',
          description: 'Reportes, configuración y control general',
          badgeColor: AppTheme.cPastelGold,
          iconColor: AppTheme.cGoldAccent,
          onSignIn: () => _goToAuth(_UserType.admin, signIn: true),
          onSignUp: () => _goToAuth(_UserType.admin, signIn: false),
        ),
        const SizedBox(height: 20),
        Center(
          child: Text(
            '${AppConstants.appName} © 2026',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      ],
    );
  }

  // ── Vista 2: Formulario Auth ────────────────────────────────
  Widget _buildAuthForm({required bool isSignIn}) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        final isLoading = state is AuthLoading;
        return Form(
          key: _formKey,
          child: Column(
            key: ValueKey(isSignIn ? 'signIn' : 'signUp'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton.icon(
                onPressed: () => setState(() => _mode = _AuthMode.roleSelection),
                icon: const Icon(Icons.arrow_back_rounded,
                    color: AppTheme.cDeepAccent, size: 20),
                label: const Text('Volver a selección'),
              ),
              const SizedBox(height: 12),
              AuthFormSection(
                isSignIn: isSignIn,
                rolNombre: _rolNombre,
                selectedType: _selectedType,
              ),
              const SizedBox(height: 16),
              if (!isSignIn) ...[
                _field('Nombre Completo', _nameCtrl, Icons.badge_outlined,
                    validator: (v) => v!.trim().isEmpty ? 'Ingresa tu nombre' : null),
                const SizedBox(height: 14),
                _field('Teléfono (opcional)', _phoneCtrl, Icons.phone_outlined,
                    keyboardType: TextInputType.phone),
                const SizedBox(height: 14),
              ],
              _field('Correo Electrónico', _emailCtrl, Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Ingresa tu correo';
                    if (!v.contains('@')) return 'Correo no válido';
                    return null;
                  }),
              const SizedBox(height: 14),
              _passwordField(isSignIn),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: isLoading ? null : () => _submit(isSignIn),
                  child: isLoading
                      ? const SizedBox(
                          height: 22, width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : Text(isSignIn
                          ? 'Ingresar como $_rolNombre'
                          : 'Registrar cuenta de $_rolNombre'),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () => setState(() =>
                      _mode = isSignIn ? _AuthMode.signUp : _AuthMode.signIn),
                  child: Text(isSignIn
                      ? '¿No tienes cuenta? Regístrate'
                      : '¿Ya tienes cuenta? Inicia sesión'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl,
    IconData icon, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration: AppTheme.fieldDecoration(
        label: label,
        prefix: Icon(icon, color: AppTheme.cDeepAccent),
      ),
      validator: validator,
    );
  }

  Widget _passwordField(bool isSignIn) {
    return TextFormField(
      controller: _passwordCtrl,
      obscureText: _obscurePassword,
      decoration: AppTheme.fieldDecoration(
        label: 'Contraseña',
        prefix: const Icon(Icons.lock_outline, color: AppTheme.cDeepAccent),
        suffix: IconButton(
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: AppTheme.cMutedText,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Ingresa tu contraseña';
        if (!isSignIn && v.length < 6) return 'Mínimo 6 caracteres';
        return null;
      },
    );
  }

  // ── Acciones ────────────────────────────────────────────────
  void _goToAuth(_UserType type, {required bool signIn}) {
    setState(() {
      _selectedType = type;
      _mode = signIn ? _AuthMode.signIn : _AuthMode.signUp;
    });
  }

  void _submit(bool isSignIn) {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final cubit = context.read<AuthCubit>();

    if (isSignIn) {
      cubit.signIn(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
    } else {
      cubit.signUp(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        fullName: _nameCtrl.text.trim().isEmpty
            ? _emailCtrl.text.split('@').first
            : _nameCtrl.text.trim(),
        rolNombre: _rolNombre,
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      );
    }
  }

  String _redirectForRole(String role) {
    switch (role) {
      case AppConstants.rolAdministrador: return AppRoutes.adminDashboard;
      case AppConstants.rolEspecialista:  return AppRoutes.specialistHome;
      default:                            return AppRoutes.services;
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.cError,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showEmailConfirmation(String email) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
        title: const Row(children: [
          Icon(Icons.mark_email_read_outlined, color: AppTheme.cDeepAccent),
          SizedBox(width: 10),
          Text('Confirma tu correo'),
        ]),
        content: Text('Revisa tu bandeja de $email para confirmar la cuenta.'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _mode = _AuthMode.signIn);
            },
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }
}
