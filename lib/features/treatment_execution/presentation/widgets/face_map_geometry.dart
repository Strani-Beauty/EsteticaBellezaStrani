import 'dart:ui';

import '../../../patients_compliance/presentation/screens/face_map_questionnaire_screen.dart';

/// Normaliza una posición local de tap (en píxeles) a coordenadas relativas
/// 0..1 del canvas. Así la selección es independiente del tamaño de pantalla
/// (Act. 2) y testeable en distintos tamaños (Act. 14).
Offset normalizarTap(Offset local, Size size) {
  if (size.width <= 0 || size.height <= 0) return Offset.zero;
  return Offset(
    (local.dx / size.width).clamp(0.0, 1.0),
    (local.dy / size.height).clamp(0.0, 1.0),
  );
}

/// Devuelve la primera zona prohibida (FDA) que contiene la coordenada
/// normalizada en la vista dada, o `null` si ninguna la contiene.
ForbiddenRegion? zonaProhibidaEn(
  Offset tapped,
  HeadView view,
  List<ForbiddenRegion> zonas,
) {
  for (final region in zonas) {
    final bounds = region.boundsFor(view);
    if (bounds != null && bounds.contains(tapped)) return region;
  }
  return null;
}

/// Devuelve el punto predefinido cuyo offset en la vista está a menos de
/// [radio] (normalizado) de la coordenada tocada, o `null` si no hay ninguno.
InjectionPoint? puntoCercano(
  Offset tapped,
  HeadView view,
  List<InjectionPoint> puntos, {
  double radio = 0.07,
}) {
  for (final point in puntos) {
    final off = point.offsetFor(view);
    if (off != null && (off - tapped).distance < radio) return point;
  }
  return null;
}

/// Indica si la coordenada normalizada cae dentro de la región del rostro
/// válida para puntos custom (fuera de ella no se permite marcar).
bool enRegionCustom(Offset tapped) =>
    tapped.dy >= 0.12 &&
    tapped.dy <= 0.92 &&
    tapped.dx >= 0.20 &&
    tapped.dx <= 0.80;