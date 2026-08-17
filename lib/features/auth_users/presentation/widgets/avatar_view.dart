import 'package:cached_network_image/cached_network_image.dart';
import 'package:dicebear_core/dicebear_core.dart';
import 'package:dicebear_styles/adventurer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import 'package:esteticaybellezastrani/app/core/di/injection.dart';
import '../../domain/usecases/generar_url_firmada_avatar.dart';
import 'avatar_selector.dart';

/// Vista circular compartida del avatar.
///
/// Resuelve, en orden:
///   * preset (`avatar_N`) → ícono pastel de la paleta Strani;
///   * path de storage / URL pública legacy → URL firmada (`createSignedUrl`)
///     → `CachedNetworkImage`;
///   * null + paciente → DiceBear determinístico (seed = user id);
///   * null + admin/especialista → ícono de rol.
class AvatarView extends StatelessWidget {
  final String? avatarUrl;
  final bool isPatient;
  final bool isAdmin;
  final bool isSpecialist;
  final String? seed;
  final double diameter;
  final bool showBorder;

  const AvatarView({
    super.key,
    required this.avatarUrl,
    this.isPatient = false,
    this.isAdmin = false,
    this.isSpecialist = false,
    this.seed,
    required this.diameter,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final presetIcon = AvatarSelector.presetIcon(avatarUrl);
    final presetColor = AvatarSelector.presetColor(avatarUrl);
    final bg = presetColor ?? AppTheme.cPastelPurple;

    Widget child;
    if (presetIcon != null) {
      child = Center(
        child: Icon(presetIcon, size: diameter * 0.55, color: AppTheme.cDeepAccent),
      );
    } else if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      child = _SignedAvatar(value: avatarUrl!, diameter: diameter);
    } else if (isPatient && seed != null && seed!.isNotEmpty) {
      child = _DiceBearAvatar(seed: seed!, diameter: diameter);
    } else {
      child = Center(
        child: Icon(
          isAdmin
              ? Icons.admin_panel_settings_rounded
              : isSpecialist
                  ? Icons.medical_services_rounded
                  : Icons.person_rounded,
          size: diameter * 0.55,
          color: AppTheme.cDeepAccent,
        ),
      );
    }

    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bg,
        border: showBorder
            ? Border.all(color: AppTheme.cDeepAccent.withValues(alpha: 0.3))
            : null,
      ),
      child: ClipOval(child: child),
    );
  }
}

/// Avatar con foto: resuelve la URL firmada del path privado y la muestra.
class _SignedAvatar extends StatefulWidget {
  final String value;
  final double diameter;

  const _SignedAvatar({required this.value, required this.diameter});

  @override
  State<_SignedAvatar> createState() => _SignedAvatarState();
}

class _SignedAvatarState extends State<_SignedAvatar> {
  String? _signedUrl;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    final value = widget.value;
    String? path;
    if (value.startsWith('http')) {
      // URL pública legacy → extraer el path de storage (`.../avatars/<path>`).
      const marker = '/avatars/';
      final idx = value.indexOf(marker);
      path = idx >= 0 ? value.substring(idx + marker.length) : null;
    } else {
      path = value;
    }

    if (path == null) {
      if (mounted) setState(() => _failed = true);
      return;
    }

    try {
      final result = await sl<GenerarUrlFirmadaAvatar>()(
        GenerarUrlFirmadaAvatarParams(path),
      );
      result.fold(
        (failure) {
          if (mounted) setState(() => _failed = true);
        },
        (url) {
          if (mounted) setState(() => _signedUrl = url);
        },
      );
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedUrl = _signedUrl;
    if (signedUrl != null) {
      return SizedBox(
        width: widget.diameter,
        height: widget.diameter,
        child: CachedNetworkImage(
          imageUrl: signedUrl,
          fit: BoxFit.cover,
          placeholder: (_, _) => Center(
            child: SizedBox(
              width: widget.diameter * 0.35,
              height: widget.diameter * 0.35,
              child: const CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ),
          errorWidget: (_, _, _) => Center(
            child: Icon(
              Icons.person_rounded,
              size: widget.diameter * 0.55,
              color: AppTheme.cDeepAccent,
            ),
          ),
        ),
      );
    }
    if (_failed) {
      return Center(
        child: Icon(
          Icons.person_rounded,
          size: widget.diameter * 0.55,
          color: AppTheme.cDeepAccent,
        ),
      );
    }
    return Center(
      child: SizedBox(
        width: widget.diameter * 0.4,
        height: widget.diameter * 0.4,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: AppTheme.cDeepAccent,
        ),
      ),
    );
  }
}

/// Avatar determinístico generado localmente con DiceBear (estilo adventurer).
class _DiceBearAvatar extends StatelessWidget {
  final String seed;
  final double diameter;

  const _DiceBearAvatar({required this.seed, required this.diameter});

  @override
  Widget build(BuildContext context) {
    final style = Style.parse(adventurer);
    final avatar = Avatar(style, {'seed': seed});
    return SizedBox(
      width: diameter,
      height: diameter,
      child: SvgPicture.string(avatar.svg, fit: BoxFit.cover),
    );
  }
}