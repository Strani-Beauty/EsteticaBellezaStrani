import 'package:flutter/material.dart';

import 'package:esteticaybellezastrani/app/config/app_theme.dart';

/// Resultado del diálogo de dictamen médico (examen médico total).
class DictamenDialogResult {
  final bool aprobado;
  final String observaciones;
  final String? hallazgos;

  const DictamenDialogResult({
    required this.aprobado,
    required this.observaciones,
    this.hallazgos,
  });
}

/// Muestra el diálogo para emitir el dictamen del examen médico total
/// (evaluación aplicada + entrevista F2F). Retorna `null` si se cancela.
Future<DictamenDialogResult?> mostrarDictamenDialog(
  BuildContext context, {
  String? hallazgosIniciales,
}) {
  return showDialog<DictamenDialogResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DictamenDialog(hallazgosIniciales: hallazgosIniciales),
  );
}

class _DictamenDialog extends StatefulWidget {
  final String? hallazgosIniciales;
  const _DictamenDialog({this.hallazgosIniciales});

  @override
  State<_DictamenDialog> createState() => _DictamenDialogState();
}

class _DictamenDialogState extends State<_DictamenDialog> {
  bool _aprobado = true;
  late final TextEditingController _obsCtrl = TextEditingController();
  late final TextEditingController _hallCtrl =
      TextEditingController(text: widget.hallazgosIniciales ?? '');
  String? _error;

  @override
  void dispose() {
    _obsCtrl.dispose();
    _hallCtrl.dispose();
    super.dispose();
  }

  void _confirmar() {
    if (_obsCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Las observaciones del dictamen son obligatorias.');
      return;
    }
    Navigator.of(context).pop(
      DictamenDialogResult(
        aprobado: _aprobado,
        observaciones: _obsCtrl.text.trim(),
        hallazgos: _hallCtrl.text.trim().isEmpty ? null : _hallCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      constraints: const BoxConstraints(maxWidth: 540),
      title: const Text(
        'Dictamen del examen médico',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Emite el resultado del examen médico total (evaluación aplicada '
              'más la entrevista presencial por videollamada).',
              style: TextStyle(fontSize: 12, color: AppTheme.cMutedText),
            ),
            const SizedBox(height: 14),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: true,
                  label: Text('Apto'),
                  icon: Icon(Icons.check_circle_outline_rounded),
                ),
                ButtonSegment(
                  value: false,
                  label: Text('No apto'),
                  icon: Icon(Icons.cancel_outlined),
                ),
              ],
              selected: {_aprobado},
              onSelectionChanged: (s) => setState(() => _aprobado = s.first),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _obsCtrl,
              maxLines: 3,
              decoration: AppTheme.fieldDecoration(
                label: 'Observaciones (obligatorio)',
                hint: 'Conclusión clínica del dictamen',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _hallCtrl,
              maxLines: 3,
              decoration: AppTheme.fieldDecoration(
                label: 'Hallazgos',
                hint: 'Hallazgos de la entrevista (opcional)',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.cError)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar',
              style: TextStyle(color: AppTheme.cMutedText)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor:
                _aprobado ? AppTheme.cBrandGreen : AppTheme.cError,
          ),
          onPressed: _confirmar,
          child: Text(_aprobado ? 'Emitir APTO' : 'Emitir NO APTO'),
        ),
      ],
    );
  }
}
