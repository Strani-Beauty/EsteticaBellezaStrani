import 'package:flutter/material.dart';

import '../../../../app/config/app_theme.dart';
import '../../../patients_compliance/presentation/screens/face_map_questionnaire_screen.dart';
import 'face_map_geometry.dart';

/// Canvas interactivo del Face Map: rotación de vistas (izq/frente/der),
/// zonas prohibidas (FDA), pines de puntos seleccionados y marcado de puntos
/// nuevos y custom. Desacoplado de la pantalla para permitir tests de
/// precisión multi-tamaño (Act. 14).
class FaceMapCanvas extends StatefulWidget {
  final List<InjectionPoint> puntos;
  final List<ForbiddenRegion> zonasProhibidas;
  final List<InjectionPoint> seleccionados;

  /// Se invoca al tocar un punto (predefinido o pin ya seleccionado).
  final void Function(InjectionPoint punto) onTogglePunto;

  /// Se invoca al marcar un punto custom en zona válida.
  final void Function(InjectionPoint punto) onCustomPunto;

  /// Se invoca al tocar una zona prohibida (FDA).
  final void Function(ForbiddenRegion region) onZonaProhibida;

  /// Badge opcional a mostrar bajo cada pin seleccionado (p. ej. cantidad).
  final Widget? Function(InjectionPoint punto)? buildBadge;

  const FaceMapCanvas({
    super.key,
    required this.puntos,
    required this.zonasProhibidas,
    required this.seleccionados,
    required this.onTogglePunto,
    required this.onCustomPunto,
    required this.onZonaProhibida,
    this.buildBadge,
  });

  @override
  State<FaceMapCanvas> createState() => _FaceMapCanvasState();
}

class _FaceMapCanvasState extends State<FaceMapCanvas> {
  late final PageController _pageController;
  HeadView _currentView = HeadView.frente;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: HeadView.frente.index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToView(HeadView view) {
    _pageController.animateToPage(
      HeadView.values.indexOf(view),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
    setState(() => _currentView = view);
  }

  void _handleTap(TapDownDetails details, HeadView view, Size size) {
    final p = normalizarTap(details.localPosition, size);
    final region = zonaProhibidaEn(p, view, widget.zonasProhibidas);
    if (region != null) {
      widget.onZonaProhibida(region);
      return;
    }
    final punto = puntoCercano(p, view, widget.puntos);
    if (punto != null) {
      widget.onTogglePunto(punto);
      return;
    }
    if (enRegionCustom(p)) {
      widget.onCustomPunto(InjectionPoint(
        id: 'custom_${DateTime.now().millisecondsSinceEpoch}_${view.name}',
        label: 'Punto Marcado (${(p.dx * 100).toStringAsFixed(0)}%, '
            '${(p.dy * 100).toStringAsFixed(0)}%)',
        offsets: {view: p},
        isCustom: true,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: AppTheme.cPastelPurple,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: const Row(
              children: [
                Icon(Icons.ads_click_rounded, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Desliza para rotar la cabeza (frente · perfiles). '
                    'Puntos rojos = Zonas Prohibidas.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final canvasWidth = (constraints.maxWidth * 0.5)
                  .clamp(280.0, 480.0)
                  .toDouble();
              final canvasHeight = canvasWidth;
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(color: Colors.grey.shade300),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: SizedBox(
                      width: canvasWidth,
                      height: canvasHeight,
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: (i) =>
                            setState(() => _currentView = HeadView.values[i]),
                        itemCount: HeadView.values.length,
                        itemBuilder: (context, index) {
                          final view = HeadView.values[index];
                          return _buildHeadViewPage(view, canvasWidth);
                        },
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          _buildViewNavigation(),
        ],
      ),
    );
  }

  Widget _buildViewNavigation() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.chevron_left),
            onPressed: _currentView == HeadView.izq
                ? null
                : () => _goToView(HeadView.values[_currentView.index - 1]),
          ),
          Expanded(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              runSpacing: 4,
              children: HeadView.values.map(
                (view) => ChoiceChip(
                  label: Text(
                    view.label,
                    style: const TextStyle(fontSize: 11),
                  ),
                  selected: view == _currentView,
                  selectedColor: AppTheme.cDeepAccent,
                  labelStyle: TextStyle(
                    color: view == _currentView ? Colors.white : null,
                  ),
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => _goToView(view),
                ),
              ).toList(),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.chevron_right),
            onPressed: _currentView == HeadView.der
                ? null
                : () => _goToView(HeadView.values[_currentView.index + 1]),
          ),
        ],
      ),
    );
  }

  Widget _buildHeadViewPage(HeadView view, double canvasWidth) {
    final size = Size(canvasWidth, canvasWidth);
    return GestureDetector(
      onTapDown: (details) => _handleTap(details, view, size),
      child: SizedBox(
        width: canvasWidth,
        height: canvasWidth,
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                color: Colors.white,
                child: Image.asset(
                  view.asset,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Icon(Icons.person, size: 90, color: Colors.grey),
                  ),
                ),
              ),
            ),
            ...widget.zonasProhibidas.map((region) {
              final bounds = region.boundsFor(view);
              if (bounds == null) return const SizedBox.shrink();
              final isLowerBody = region.id == 'pecho_inferior';
              return Positioned(
                left: bounds.left * canvasWidth,
                top: bounds.top * canvasWidth,
                width: bounds.width * canvasWidth,
                height: bounds.height * canvasWidth,
                child: Tooltip(
                  message: '${region.title} (región Prohibida FDA)',
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.35),
                      shape:
                          isLowerBody ? BoxShape.rectangle : BoxShape.circle,
                      borderRadius:
                          isLowerBody ? BorderRadius.circular(8) : null,
                      border:
                          Border.all(color: Colors.red.shade600, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.2),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.block_rounded,
                        color: Colors.red.shade800,
                        size: isLowerBody ? 16 : 14,
                      ),
                    ),
                  ),
                ),
              );
            }),
            ...widget.puntos.map((point) {
              final off = point.offsetFor(view);
              if (off == null) return const SizedBox.shrink();
              if (widget.seleccionados.any((p) => p.id == point.id)) {
                return const SizedBox.shrink();
              }
              return Positioned(
                left: off.dx * canvasWidth - 14,
                top: off.dy * canvasWidth - 14,
                child: Tooltip(
                  message: 'Clic para marcar: ${point.label}',
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.cDeepAccent.withValues(alpha: 0.15),
                      border: Border.all(
                        color: AppTheme.cDeepAccent.withValues(alpha: 0.5),
                        width: 1.2,
                      ),
                    ),
                    child: const Center(
                      child:
                          Icon(Icons.add, size: 16, color: AppTheme.cDeepAccent),
                    ),
                  ),
                ),
              );
            }),
            ...widget.seleccionados
                .where((p) => p.offsetFor(view) != null)
                .toList()
                .asMap()
                .entries
                .map((entry) {
              final index = entry.key + 1;
              final point = entry.value;
              final off = point.offsetFor(view)!;
              return Positioned(
                left: off.dx * canvasWidth - 16,
                top: off.dy * canvasWidth - 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Tooltip(
                      message: '${point.label} (Clic para editar producto)',
                      child: GestureDetector(
                        onTap: () => widget.onTogglePunto(point),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.cDeepAccent,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              '$index',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (widget.buildBadge?.call(point) case final badge?)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: badge,
                      ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}