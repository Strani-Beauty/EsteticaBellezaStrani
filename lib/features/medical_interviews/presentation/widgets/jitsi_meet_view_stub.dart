import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:esteticaybellezastrani/app/config/app_theme.dart';

/// Fuera de web no hay `HtmlElementView`/iframe: se ofrece abrir la sala de
/// Jitsi en la app o navegador externo con `url_launcher`.
Widget buildJitsiMeetView(String salaUrl) => _JitsiFallback(salaUrl: salaUrl);

class _JitsiFallback extends StatelessWidget {
  final String salaUrl;
  const _JitsiFallback({required this.salaUrl});

  Future<void> _abrir(BuildContext context) async {
    final uri = Uri.tryParse(salaUrl);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir la videollamada.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        children: [
          const Icon(Icons.videocam_rounded,
              size: 40, color: AppTheme.cDeepAccent),
          const SizedBox(height: 8),
          const Text(
            'La videollamada embebida está disponible en la versión web.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppTheme.cMutedText),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: AppTheme.cDeepAccent),
            onPressed: () => _abrir(context),
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('Abrir videollamada'),
          ),
        ],
      ),
    );
  }
}
