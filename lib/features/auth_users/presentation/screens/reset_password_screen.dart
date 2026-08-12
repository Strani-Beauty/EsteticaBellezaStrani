import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import 'package:esteticaybellezastrani/app/config/app_routes.dart';
import '../cubits/auth_cubit.dart';

/// Pantalla de recuperación de contraseña — consumida desde el deep link de
/// recovery de Supabase (`event passwordRecovery`). Guarda la nueva contraseña
/// con `updatePassword` y limpia la sesión temporal de recovery.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva contraseña'),
        leading: IconButton(
          onPressed: () => context.go(AppRoutes.login),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: BlocListener<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: AppTheme.cError),
            );
          } else if (state is AuthPasswordChanged) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Contraseña actualizada. Inicia sesión de nuevo.')),
            );
            context.go(AppRoutes.login);
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Restablece tu contraseña. Usa al menos 6 caracteres.',
                  style: TextStyle(color: AppTheme.cMutedText),
                ),
                const SizedBox(height: 20),
                _passwordField('Nueva contraseña', _newCtrl, () => setState(
                    () => _obscureNew = !_obscureNew), _obscureNew,
                    validator: (v) {
                  if (v == null || v.isEmpty) return 'Ingresa la nueva contraseña';
                  if (v.length < 6) return 'Mínimo 6 caracteres';
                  return null;
                }),
                const SizedBox(height: 14),
                _passwordField('Confirmar contraseña', _confirmCtrl, () =>
                    setState(
                        () => _obscureConfirm = !_obscureConfirm), _obscureConfirm,
                    validator: (v) {
                  if (v == null || v.isEmpty) return 'Confirma la contraseña';
                  if (v != _newCtrl.text) return 'Las contraseñas no coinciden';
                  return null;
                }),
                const SizedBox(height: 24),
                SizedBox(
                  height: 50,
                  child: BlocBuilder<AuthCubit, AuthState>(
                    builder: (context, state) {
                      final loading = state is AuthLoading;
                      return ElevatedButton(
                        onPressed: loading ? null : _submit,
                        child: loading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5, color: Colors.white),
                              )
                            : const Text('Guardar contraseña'),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _passwordField(
    String label,
    TextEditingController ctrl,
    VoidCallback onToggle,
    bool obscure, {
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      obscureText: obscure,
      decoration: AppTheme.fieldDecoration(
        label: label,
        prefix: const Icon(Icons.lock_outline, color: AppTheme.cDeepAccent),
        suffix: IconButton(
          onPressed: onToggle,
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: AppTheme.cMutedText,
          ),
        ),
      ),
      validator: validator,
    );
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    context.read<AuthCubit>().completePasswordReset(_newCtrl.text);
  }
}