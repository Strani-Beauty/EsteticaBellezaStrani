import 'package:flutter/material.dart';

import 'package:esteticaybellezastrani/app/config/app_theme.dart';

/// Muestra la advertencia modal de confidencialidad ePHI/HIPAA antes de acceder
/// al expediente de salud de un paciente.
///
/// Retorna `true` si el administrador pulsa **Continuar** y `false` si pulsa
/// **Declinar** (o cierra el diálogo).
Future<bool> confirmarAccesoExpediente(BuildContext context) async {
  final continuar = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        constraints: const BoxConstraints(maxWidth: 480),
        icon: const Icon(
          Icons.gpp_maybe_rounded,
          size: 36,
          color: AppTheme.cGoldAccent,
        ),
        title: const Text(
          'Aviso de confidencialidad (ePHI/HIPAA)',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.cDarkText,
          ),
        ),
        content: const Text(
          'La información que vas a consultar es Información Electrónica '
          'Protegida de Salud (ePHI) regulada por la norma HIPAA.\n\n'
          'El acceso queda registrado en la auditoría del sistema. Está '
          'prohibida su divulgación, copia o uso sin autorización del paciente '
          'y con fines ajenos a la gestión de su atención. El uso indebido '
          'puede acarrear responsabilidad legal.',
          textAlign: TextAlign.start,
          style: TextStyle(
            fontSize: 13,
            height: 1.5,
            color: AppTheme.cMutedText,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(
              'Declinar',
              style: TextStyle(color: AppTheme.cError),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.cDeepAccent,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Continuar'),
          ),
        ],
      );
    },
  );
  return continuar == true;
}