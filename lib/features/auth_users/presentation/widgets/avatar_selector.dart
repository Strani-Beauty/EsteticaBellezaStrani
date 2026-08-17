import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/config/app_constants.dart';
import '../../../../app/config/app_theme.dart';

/// Selector de avatar para el perfil del paciente (AU-H-08).
///
/// Ofrece dos modos:
///  * Avatares predefinidos: se guardan como clave `avatar_N` en `avatar_url`.
///  * Subir foto propia: se sube al bucket `avatars` y se guarda la URL pública.
class AvatarSelector extends StatelessWidget {
  final String? avatarUrl;
  final ValueChanged<String?> onChanged;

  const AvatarSelector({
    super.key,
    required this.avatarUrl,
    required this.onChanged,
  });

  /// Avatares predefinidos (íconos pastel de la paleta Strani).
  /// Cada preset identifica un perfil por edad y género (clave `avatar_N`).
  static const List<Map<String, dynamic>> presets = [
    {'key': 'avatar_1', 'label': 'Hombre joven', 'icon': Icons.face_3_rounded, 'color': Color(0xFFF7D6E0)},
    {'key': 'avatar_2', 'label': 'Hombre adulto', 'icon': Icons.face_5_rounded, 'color': Color(0xFFBEE1E6)},
    {'key': 'avatar_3', 'label': 'Mujer joven', 'icon': Icons.face_2_rounded, 'color': Color(0xFFE2ECE9)},
    {'key': 'avatar_4', 'label': 'Mujer adulta', 'icon': Icons.face_6_rounded, 'color': Color(0xFFFFF3CD)},
    {'key': 'avatar_5', 'label': 'Tercera edad hombre', 'icon': Icons.face_4_rounded, 'color': Color(0xFFF7D6E0)},
    {'key': 'avatar_6', 'label': 'Tercera edad mujer', 'icon': Icons.face_rounded, 'color': Color(0xFFBEE1E6)},
    {'key': 'avatar_7', 'label': 'Adulto mayor hombre', 'icon': Icons.emoji_emotions_rounded, 'color': Color(0xFFE2ECE9)},
    {'key': 'avatar_8', 'label': 'Adulto mayor mujer', 'icon': Icons.sentiment_satisfied_alt, 'color': Color(0xFFFFF3CD)},
  ];

  /// Indica si `avatarUrl` es una clave de avatar predefinido.
  static bool isPreset(String? avatarUrl) {
    if (avatarUrl == null) return false;
    return presets.any((p) => p['key'] == avatarUrl);
  }

  /// Resuelve el ícono de un avatar predefinido (o null si no es preset).
  static IconData? presetIcon(String? avatarUrl) {
    if (avatarUrl == null) return null;
    for (final p in presets) {
      if (p['key'] == avatarUrl) return p['icon'] as IconData;
    }
    return null;
  }

  /// Resuelve el color de fondo de un avatar predefinido.
  static Color? presetColor(String? avatarUrl) {
    if (avatarUrl == null) return null;
    for (final p in presets) {
      if (p['key'] == avatarUrl) return p['color'] as Color;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Foto de perfil',
          style: TextStyle(color: AppTheme.cMutedText, fontSize: 13),
        ),
        const SizedBox(height: 8),
        // Vista previa
        Center(child: _Preview(avatarUrl: avatarUrl)),
        const SizedBox(height: 12),
        // Subir foto propia
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _pickAndUpload(context),
            icon: const Icon(Icons.add_a_photo_rounded, size: 18),
            label: const Text('Subir foto desde mi dispositivo'),
          ),
        ),
        const SizedBox(height: 14),
        // Fila única de predefinidos (tiles compactos con etiqueta)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final preset in presets)
              Expanded(
                child: _PresetTile(
                  preset: preset,
                  selected: avatarUrl == preset['key'],
                  onTap: () => onChanged(preset['key'] as String),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickAndUpload(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.image,
    );
    final picked = result?.files.single;
    if (picked == null) return;

    final bytes = picked.bytes;
    if (bytes == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo leer la imagen seleccionada.')),
      );
      return;
    }

    try {
      final url = await _upload(bytes, picked.name);
      onChanged(url);
      messenger.showSnackBar(
        const SnackBar(content: Text('Foto de perfil subida correctamente.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error al subir la foto: $e')),
      );
    }
  }

  Future<String> _upload(Uint8List bytes, String fileName) async {
    final client = Supabase.instance.client;
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : 'png';
    final path =
        '${client.auth.currentUser?.id ?? 'anon'}/${DateTime.now().millisecondsSinceEpoch}.$ext';

    final uploaded = await client.storage
        .from(AppConstants.bucketAvatars)
        .uploadBinary(path, bytes);
    return client.storage
        .from(AppConstants.bucketAvatars)
        .getPublicUrl(uploaded);
  }
}

/// Vista previa del avatar actual.
class _Preview extends StatelessWidget {
  final String? avatarUrl;
  const _Preview({required this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    final presetIcon = AvatarSelector.presetIcon(avatarUrl);
    final presetColor = AvatarSelector.presetColor(avatarUrl);

    Widget child;
    if (presetIcon != null) {
      child = Icon(presetIcon, size: 52, color: AppTheme.cDeepAccent);
    } else if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      child = ClipOval(
        child: Image.network(
          avatarUrl!,
          width: 88,
          height: 88,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const Icon(
            Icons.person_rounded,
            size: 52,
            color: AppTheme.cDeepAccent,
          ),
        ),
      );
    } else {
      child = const Icon(Icons.person_rounded, size: 52, color: AppTheme.cDeepAccent);
    }

    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: presetColor ?? AppTheme.cPastelPurple,
        border: Border.all(color: AppTheme.cDeepAccent.withValues(alpha: 0.3)),
      ),
      child: Center(child: child),
    );
  }
}

/// Tile de un avatar predefinido (avatar circular pequeño + etiqueta).
class _PresetTile extends StatelessWidget {
  final Map<String, dynamic> preset;
  final bool selected;
  final VoidCallback onTap;

  const _PresetTile({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = preset['color'] as Color;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              border: Border.all(
                color: selected
                    ? AppTheme.cDeepAccent
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: Center(
              child: Icon(
                preset['icon'] as IconData,
                size: 20,
                color: AppTheme.cDeepAccent,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            preset['label'] as String,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 8,
              height: 1.1,
              color: selected
                  ? AppTheme.cDeepAccent
                  : AppTheme.cMutedText,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}