import 'package:flutter/material.dart';
import 'package:esteticaybellezastrani/app/config/app_theme.dart';

/// Diálogo para registrar un nuevo médico regente.
/// Devuelve el mapa con los datos capturados o null si se cancela.
class RegistrarMedicoRegenteDialog extends StatefulWidget {
  const RegistrarMedicoRegenteDialog({super.key});

  @override
  State<RegistrarMedicoRegenteDialog> createState() =>
      _RegistrarMedicoRegenteDialogState();
}

class _RegistrarMedicoRegenteDialogState
    extends State<RegistrarMedicoRegenteDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _licenciaCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _correoCtrl = TextEditingController();

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _licenciaCtrl.dispose();
    _telefonoCtrl.dispose();
    _correoCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(context, {
      'nombre': _nombreCtrl.text.trim(),
      'numeroLicencia': _licenciaCtrl.text.trim().isEmpty
          ? null
          : _licenciaCtrl.text.trim(),
      'telefono': _telefonoCtrl.text.trim().isEmpty
          ? null
          : _telefonoCtrl.text.trim(),
      'correo': _correoCtrl.text.trim().isEmpty ? null : _correoCtrl.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      title: const Row(children: [
        Icon(Icons.local_hospital_rounded, color: AppTheme.cDeepAccent, size: 26),
        SizedBox(width: 10),
        Expanded(child: Text('Registrar Médico Regente')),
      ]),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nombreCtrl,
                decoration: AppTheme.fieldDecoration(
                  label: 'Nombre completo *',
                  prefix: const Icon(Icons.person_outline, color: AppTheme.cDeepAccent),
                ),
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Ingresa el nombre' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _licenciaCtrl,
                decoration: AppTheme.fieldDecoration(
                  label: 'Número de licencia',
                  prefix: const Icon(Icons.badge_outlined, color: AppTheme.cDeepAccent),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _telefonoCtrl,
                keyboardType: TextInputType.phone,
                decoration: AppTheme.fieldDecoration(
                  label: 'Teléfono',
                  prefix: const Icon(Icons.phone_outlined, color: AppTheme.cDeepAccent),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _correoCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: AppTheme.fieldDecoration(
                  label: 'Correo',
                  prefix: const Icon(Icons.mail_outline, color: AppTheme.cDeepAccent),
                ),
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'El médico regente quedará PENDIENTE de validación por un administrador antes de poder asociarlo.',
                  style: TextStyle(color: AppTheme.cMutedText, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.save_rounded),
          label: const Text('Registrar'),
        ),
      ],
    );
  }
}
