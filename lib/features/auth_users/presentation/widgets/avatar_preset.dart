import 'package:dicebear_core/dicebear_core.dart' as dicebear;
import 'package:dicebear_styles/adventurer.dart';
import 'package:dicebear_styles/avataaars.dart';
import 'package:dicebear_styles/big_ears.dart';
import 'package:dicebear_styles/fun_emoji.dart';
import 'package:dicebear_styles/lorelei.dart';
import 'package:dicebear_styles/micah.dart';
import 'package:dicebear_styles/miniavs.dart';
import 'package:dicebear_styles/open_peeps.dart';
import 'package:flutter/material.dart';

/// Avatar predefinido del selector: la clave se persiste en `avatar_url` y el
/// estilo/seed de DiceBear determinan el SVG que se renderiza.
///
/// Cada preset usa un estilo DiceBear distinto y un seed fijo, de modo que la
/// misma clave siempre produce el mismo avatar (offline y determinístico).
class AvatarPreset {
  final String key;
  final String label;
  final String style;
  final String seed;
  final Color color;

  const AvatarPreset({
    required this.key,
    required this.label,
    required this.style,
    required this.seed,
    required this.color,
  });
}

/// Avatares predefinidos (clave `avatar_N`, persistida en `profiles.avatar_url`).
const List<AvatarPreset> avatarPresets = [
  AvatarPreset(
    key: 'avatar_1',
    label: 'Hombre joven',
    style: 'adventurer',
    seed: 'strani-adventurer-1',
    color: Color(0xFFF7D6E0),
  ),
  AvatarPreset(
    key: 'avatar_2',
    label: 'Hombre adulto',
    style: 'avataaars',
    seed: 'strani-avataaars-2',
    color: Color(0xFFBEE1E6),
  ),
  AvatarPreset(
    key: 'avatar_3',
    label: 'Mujer joven',
    style: 'lorelei',
    seed: 'strani-lorelei-3',
    color: Color(0xFFE2ECE9),
  ),
  AvatarPreset(
    key: 'avatar_4',
    label: 'Mujer adulta',
    style: 'micah',
    seed: 'strani-micah-4',
    color: Color(0xFFFFF3CD),
  ),
  AvatarPreset(
    key: 'avatar_5',
    label: 'Tercera edad hombre',
    style: 'fun_emoji',
    seed: 'strani-fun-emoji-5',
    color: Color(0xFFF7D6E0),
  ),
  AvatarPreset(
    key: 'avatar_6',
    label: 'Tercera edad mujer',
    style: 'open_peeps',
    seed: 'strani-open-peeps-6',
    color: Color(0xFFBEE1E6),
  ),
  AvatarPreset(
    key: 'avatar_7',
    label: 'Adulto mayor hombre',
    style: 'big_ears',
    seed: 'strani-big-ears-7',
    color: Color(0xFFE2ECE9),
  ),
  AvatarPreset(
    key: 'avatar_8',
    label: 'Adulto mayor mujer',
    style: 'miniavs',
    seed: 'strani-miniavs-8',
    color: Color(0xFFFFF3CD),
  ),
];

/// Estilos DiceBear ya parseados (la validación del estilo es costosa; se cachea).
final Map<String, dicebear.Style> _styles = {};

dicebear.Style _styleFor(String name) {
  return _styles.putIfAbsent(name, () {
    switch (name) {
      case 'adventurer':
        return dicebear.Style.parse(adventurer);
      case 'avataaars':
        return dicebear.Style.parse(avataaars);
      case 'lorelei':
        return dicebear.Style.parse(lorelei);
      case 'micah':
        return dicebear.Style.parse(micah);
      case 'fun_emoji':
        return dicebear.Style.parse(funEmoji);
      case 'open_peeps':
        return dicebear.Style.parse(openPeeps);
      case 'big_ears':
        return dicebear.Style.parse(bigEars);
      case 'miniavs':
        return dicebear.Style.parse(miniavs);
      default:
        return dicebear.Style.parse(adventurer);
    }
  });
}

/// Preset cuyo key coincide, o null si no es un preset.
AvatarPreset? presetFor(String? key) {
  if (key == null) return null;
  for (final p in avatarPresets) {
    if (p.key == key) return p;
  }
  return null;
}

/// Indica si `key` es una clave de avatar predefinido.
bool isPresetKey(String? key) => presetFor(key) != null;

/// Genera el SVG determinístico de un estilo + seed.
String dicebearSvg(String style, String seed) {
  final avatar = dicebear.Avatar(_styleFor(style), {'seed': seed});
  return avatar.svg;
}

/// SVG del preset cuyo key coincide, o null si no es preset.
String? dicebearSvgFor(String? key) {
  final preset = presetFor(key);
  if (preset == null) return null;
  return dicebearSvg(preset.style, preset.seed);
}

/// Color de fondo del preset (o null si no es preset).
Color? presetColorFor(String? key) => presetFor(key)?.color;