import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import 'package:esteticaybellezastrani/app/config/app_routes.dart';
import '../cubits/auth_cubit.dart';

/// Pantalla del perfil del usuario autenticado.
/// Permite consultar la información básica y actualizar nombre/teléfono.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _editing = false;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      _loadProfile();
    }
  }

  void _loadProfile() {
    final profile = context.read<AuthCubit>().currentProfile;
    if (profile != null) {
      _nameCtrl.text = profile.fullName ?? '';
      _phoneCtrl.text = profile.phone ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        actions: [
          IconButton(
            onPressed: () => context.go(AppRoutes.changePassword),
            tooltip: 'Cambiar contraseña',
            icon: const Icon(Icons.lock_reset_rounded),
          ),
          IconButton(
            onPressed: () {
              if (_editing) {
                setState(() => _editing = false);
              } else {
                context.read<AuthCubit>().signOut();
              }
            },
            tooltip: _editing ? 'Cancelar edición' : 'Cerrar sesión',
            icon: Icon(
              _editing ? Icons.close_rounded : Icons.logout_rounded,
              color: _editing ? AppTheme.cMutedText : Colors.redAccent,
            ),
          ),
        ],
      ),
      body: BlocListener<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is AuthUnauthenticated) {
            context.go(AppRoutes.login);
          } else if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: AppTheme.cError),
            );
          } else if (state is AuthAuthenticated) {
            _loadProfile();
            if (_editing) {
              setState(() => _editing = false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Perfil actualizado.')),
              );
            }
          }
        },
        child: BlocBuilder<AuthCubit, AuthState>(
          builder: (context, state) {
            final profile =
                state is AuthAuthenticated ? state.profile : null;
            if (profile == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 44,
                      backgroundColor: AppTheme.cPastelPurple,
                      child: Icon(
                        profile.isAdmin
                            ? Icons.admin_panel_settings_rounded
                            : profile.isSpecialist
                                ? Icons.medical_services_rounded
                                : Icons.person_rounded,
                        size: 48,
                        color: AppTheme.cDeepAccent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      profile.rolNombre,
                      style: TextStyle(
                        color: AppTheme.cDeepAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (!profile.activo)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Center(
                        child: Text(
                          'Cuenta pendiente de activación',
                          style: TextStyle(color: Colors.orange),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  _infoTile(Icons.email_outlined, 'Correo electrónico',
                      profile.email),
                  _infoTile(Icons.badge_outlined, 'Nombre completo',
                      _editing
                          ? null
                          : (profile.fullName?.isEmpty == true
                              ? 'Sin registrar'
                              : profile.fullName), nameField: _editing),
                  _infoTile(Icons.phone_outlined, 'Teléfono',
                      _editing
                          ? null
                          : (profile.phone?.isEmpty == true
                              ? 'Sin registrar'
                              : profile.phone), phoneField: _editing),
                  if (!_editing) ...[
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => setState(() => _editing = true),
                      icon: const Icon(Icons.edit_rounded),
                      label: const Text('Editar mi información'),
                    ),
                  ] else ...[
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: state is AuthLoading ? null : _guardar,
                        child: state is AuthLoading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5, color: Colors.white),
                              )
                            : const Text('Guardar cambios'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        _loadProfile();
                        setState(() => _editing = false);
                      },
                      child: const Text('Cancelar'),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _infoTile(
    IconData icon,
    String label,
    String? value, {
    bool nameField = false,
    bool phoneField = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.cDeepAccent, size: 20),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: AppTheme.cMutedText)),
            ],
          ),
          const SizedBox(height: 6),
          if (nameField)
            TextFormField(
              controller: _nameCtrl,
              decoration: AppTheme.fieldDecoration(label: 'Nombre completo'),
            )
          else if (phoneField)
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: AppTheme.fieldDecoration(label: 'Teléfono'),
            )
          else
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Text(
                value ?? '-',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _guardar() async {
    final profile = context.read<AuthCubit>().currentProfile;
    if (profile == null) return;
    await context.read<AuthCubit>().updateProfile(
          userId: profile.id,
          fullName: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        );
  }
}