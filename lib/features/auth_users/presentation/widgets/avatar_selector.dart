import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/config/app_constants.dart';
import '../../../../app/config/app_theme.dart';
import 'avatar_preset.dart';
import 'avatar_view.dart';

/// Selector de avatar para el perfil del paciente (AU-H-08).
///
/// Ofrece dos modos:
///  * Avatares predefinidos: avatares DiceBear creativos; se guardan como clave
///    `avatar_N` en `avatar_url`.
///  * Subir foto propia: se sube al bucket privado `avatars` y se guarda el
///    **path de storage** en `avatar_url` (se lee con URL firmada).
class AvatarSelector extends StatefulWidget {
  final String? avatarUrl;
  final ValueChanged<String?> onChanged;

  const AvatarSelector({
    super.key,
    required this.avatarUrl,
    required this.onChanged,
  });

  @override
  State<AvatarSelector> createState() => _AvatarSelectorState();
}

class _AvatarSelectorState extends State<AvatarSelector> {
  bool _uploading = false;

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
        Center(child: _Preview(avatarUrl: widget.avatarUrl)),
        const SizedBox(height: 12),
        // Subir foto propia
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _uploading ? null : () => _pickAndUpload(context),
            icon: _uploading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_a_photo_rounded, size: 18),
            label: Text(
              _uploading
                  ? 'Subiendo foto...'
                  : 'Subir foto desde mi dispositivo',
            ),
          ),
        ),
        const SizedBox(height: 14),
        // Fila única de predefinidos (tiles compactos con etiqueta)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final preset in avatarPresets)
              Expanded(
                child: _PresetTile(
                  preset: preset,
                  selected: widget.avatarUrl == preset.key,
                  onTap: () => widget.onChanged(preset.key),
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

    setState(() => _uploading = true);
    try {
      final path = await _upload(bytes, picked.name);
      widget.onChanged(path);
      messenger.showSnackBar(
        const SnackBar(content: Text('Foto de perfil subida correctamente.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error al subir la foto: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<String> _upload(Uint8List bytes, String fileName) async {
    final client = Supabase.instance.client;
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : 'png';
    final path =
        '${client.auth.currentUser?.id ?? 'anon'}/${DateTime.now().millisecondsSinceEpoch}.$ext';

    await client.storage
        .from(AppConstants.bucketAvatars)
        .uploadBinary(path, bytes);
    return path;
  }
}

/// Vista previa del avatar actual.
class _Preview extends StatelessWidget {
  final String? avatarUrl;
  const _Preview({required this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    return AvatarView(
      avatarUrl: avatarUrl,
      isPatient: true,
      seed: Supabase.instance.client.auth.currentUser?.id,
      diameter: 96,
      showBorder: true,
    );
  }
}

/// Tile de un avatar predefinido (avatar DiceBear circular pequeño + etiqueta).
class _PresetTile extends StatelessWidget {
  final AvatarPreset preset;
  final bool selected;
  final VoidCallback onTap;

  const _PresetTile({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final svg = dicebearSvgFor(preset.key)!;
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
              color: preset.color,
              border: Border.all(
                color: selected ? AppTheme.cDeepAccent : Colors.transparent,
                width: 2,
              ),
            ),
            child: ClipOval(
              child: SizedBox(
                width: 38,
                height: 38,
                child: SvgPicture.string(svg, fit: BoxFit.cover),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            preset.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 8,
              height: 1.1,
              color: selected ? AppTheme.cDeepAccent : AppTheme.cMutedText,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}