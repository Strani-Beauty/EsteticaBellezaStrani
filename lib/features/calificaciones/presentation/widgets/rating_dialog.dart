import 'package:flutter/material.dart';

import '../../../../app/config/app_theme.dart';

/// Resultado del diálogo de calificación.
class RatingResult {
  final int puntuacion;
  final String? comentario;

  const RatingResult({required this.puntuacion, this.comentario});
}

/// Diálogo reutilizable de calificación con estrellas (1-5) y comentario.
/// Devuelve un [RatingResult] al confirmar o `null` si se cancela.
Future<RatingResult?> showRatingDialog(
  BuildContext context, {
  required String titulo,
  required String subtitulo,
}) {
  return showDialog<RatingResult>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _RatingDialog(titulo: titulo, subtitulo: subtitulo),
  );
}

class _RatingDialog extends StatefulWidget {
  final String titulo;
  final String subtitulo;

  const _RatingDialog({required this.titulo, required this.subtitulo});

  @override
  State<_RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<_RatingDialog> {
  int _puntuacion = 0;
  final TextEditingController _comentario = TextEditingController();
  bool _enviando = false;

  @override
  void dispose() {
    _comentario.dispose();
    super.dispose();
  }

  void _enviar() {
    if (_puntuacion == 0) return;
    setState(() => _enviando = true);
    Navigator.of(context).pop(
      RatingResult(puntuacion: _puntuacion, comentario: _comentario.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.titulo,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.subtitulo,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.cMutedText, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final estrella = i + 1;
              return IconButton(
                onPressed: _enviando
                    ? null
                    : () => setState(() => _puntuacion = estrella),
                icon: Icon(
                  estrella <= _puntuacion
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  color: estrella <= _puntuacion
                      ? Colors.amber.shade600
                      : AppTheme.cMutedText,
                  size: 36,
                ),
                padding: EdgeInsets.zero,
              );
            }),
          ),
          const SizedBox(height: 4),
          Text(
            _puntuacion == 0 ? 'Toca una estrella para calificar' : '$_puntuacion de 5',
            style: TextStyle(
              color: _puntuacion == 0 ? AppTheme.cMutedText : AppTheme.cDeepAccent,
              fontSize: 13,
              fontWeight: _puntuacion == 0 ? FontWeight.normal : FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _comentario,
            enabled: !_enviando,
            maxLines: 3,
            maxLength: 500,
            decoration: const InputDecoration(
              hintText: 'Cuéntanos tu experiencia (opcional)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _enviando ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _puntuacion == 0 || _enviando ? null : _enviar,
          style: FilledButton.styleFrom(backgroundColor: AppTheme.cDeepAccent),
          child: const Text('Enviar calificación'),
        ),
      ],
    );
  }
}