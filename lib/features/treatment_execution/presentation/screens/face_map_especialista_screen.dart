import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/config/app_theme.dart';
import '../../../patients_compliance/presentation/screens/face_map_questionnaire_screen.dart';
import '../../domain/entities/face_map_especialista_entity.dart';
import '../cubits/treatment_execution_cubit.dart';

/// Face map del especialista durante la ejecución del tratamiento.
/// Reutiliza el canvas del paciente (HeadView / InjectionPoint / ForbiddenRegion)
/// para marcar los puntos de aplicación y las notas clínicas, y los guarda
/// vinculados al tratamiento (upsert en face_maps / face_map_puntos).
class FaceMapEspecialistaScreen extends StatefulWidget {
  final String tratamientoId;

  const FaceMapEspecialistaScreen({super.key, required this.tratamientoId});

  @override
  State<FaceMapEspecialistaScreen> createState() =>
      _FaceMapEspecialistaScreenState();
}

class _FaceMapEspecialistaScreenState extends State<FaceMapEspecialistaScreen> {
  final TextEditingController _notasController = TextEditingController();
  final List<InjectionPoint> _predefinedPoints = _defaultInjectionPoints();
  final List<ForbiddenRegion> _forbiddenRegions = _defaultForbiddenRegions();
  final List<InjectionPoint> _selectedPoints = [];
  final List<String> _attemptedForbiddenZones = [];
  late final PageController _pageController;
  HeadView _currentView = HeadView.frente;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: HeadView.frente.index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context
          .read<TreatmentExecutionCubit>()
          .loadFaceMap(tratamientoId: widget.tratamientoId);
    });
  }

  @override
  void dispose() {
    _notasController.dispose();
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

  void _togglePoint(InjectionPoint point) {
    setState(() {
      final exists = _selectedPoints.any((p) => p.id == point.id);
      if (exists) {
        _selectedPoints.removeWhere((p) => p.id == point.id);
      } else {
        _selectedPoints.add(point);
      }
    });
  }

  void _handleSilhouetteTap(
    TapDownDetails details,
    HeadView view,
    BoxConstraints constraints,
  ) {
    final dx = details.localPosition.dx / constraints.maxWidth;
    final dy = details.localPosition.dy / constraints.maxHeight;
    final tappedOffset = Offset(dx, dy);

    for (final region in _forbiddenRegions) {
      final bounds = region.boundsFor(view);
      if (bounds != null && bounds.contains(tappedOffset)) {
        _showForbiddenZoneWarning(region);
        return;
      }
    }

    for (final point in _predefinedPoints) {
      final off = point.offsetFor(view);
      if (off != null && (off - tappedOffset).distance < 0.07) {
        _togglePoint(point);
        return;
      }
    }

    if (dy >= 0.12 && dy <= 0.92 && dx >= 0.20 && dx <= 0.80) {
      final custom = InjectionPoint(
        id: 'custom_${DateTime.now().millisecondsSinceEpoch}_${view.name}',
        label:
            'Punto Marcado (${(dx * 100).toStringAsFixed(0)}%, ${(dy * 100).toStringAsFixed(0)}%)',
        offsets: {view: tappedOffset},
        isCustom: true,
      );
      setState(() => _selectedPoints.add(custom));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Punto de inyección marcado en ${custom.label}.'),
          backgroundColor: AppTheme.cDeepAccent,
        ),
      );
    }
  }

  void _showForbiddenZoneWarning(ForbiddenRegion region) {
    if (!_attemptedForbiddenZones.contains(region.title)) {
      _attemptedForbiddenZones.add(region.title);
    }
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Zona No Válida / Prohibida (FDA)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    region.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    region.reason,
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'La aplicación de inyectables en esta zona está prohibida por '
              'regulación sanitaria (FDA). No es apta para procedimientos.',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  void _aplicarPuntosCargados(FaceMapEspecialistaEntity? faceMap) {
    if (faceMap == null || _loaded) return;
    _loaded = true;
    final puntos = reconstruirPuntosFaceMap(faceMap.puntos);
    if (puntos.isNotEmpty) _selectedPoints.addAll(puntos);
    if (faceMap.observaciones != null && faceMap.observaciones!.isNotEmpty) {
      _notasController.text = faceMap.observaciones!;
    }
  }

  Future<void> _guardar() async {
    if (_selectedPoints.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Marca al menos un punto en el rostro para guardar.'),
        ),
      );
      return;
    }
    final puntos = <Map<String, dynamic>>[
      for (final p in _selectedPoints)
        for (final entry in p.offsets.entries)
          {
            'zona_anatomica': p.label,
            'punto_id': p.id,
            'vista': entry.key.name,
            'coordenada_x': double.parse(
              entry.value.dx.toStringAsFixed(3),
            ),
            'coordenada_y': double.parse(
              entry.value.dy.toStringAsFixed(3),
            ),
          },
    ];
    final cubit = context.read<TreatmentExecutionCubit>();
    final state = cubit.state;
    final pacienteId = state is TreatmentExecutionLoaded
        ? (state.cita?.tratamiento?.pacienteId ??
            (state.faceMap?.pacienteId ?? ''))
        : (state is TreatmentExecutionLoaded
            ? state.faceMap?.pacienteId ?? ''
            : '');
    if (pacienteId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo determinar el paciente. Recarga el detalle de la cita.',
          ),
        ),
      );
      return;
    }
    await cubit.guardarFaceMap(
      tratamientoId: widget.tratamientoId,
      pacienteId: pacienteId,
      puntos: puntos,
      observaciones: _notasController.text.trim().isEmpty
          ? null
          : _notasController.text.trim(),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Face map del tratamiento guardado.'),
          backgroundColor: AppTheme.cDeepAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: AppTheme.cDeepAccent,
        foregroundColor: Colors.white,
        title: const Text('Face Map · Puntos de Aplicación'),
      ),
      body: BlocConsumer<TreatmentExecutionCubit, TreatmentExecutionState>(
        listener: (context, state) {
          if (state is TreatmentExecutionLoaded) {
            _aplicarPuntosCargados(state.faceMap);
          }
        },
        builder: (context, state) {
          final cargando = state is TreatmentExecutionLoading ||
              (state is TreatmentExecutionLoaded && state.trabajando);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSectionTitle(
                  title: 'Mapa Mapeable de Inyectables (Rostro & Cuello)',
                  subtitle:
                      'Desliza la cabeza para rotar (frente y perfiles) y '
                      'toca para marcar los puntos de aplicación. Las zonas '
                      'oculares prohibidas se sombrean en rojo.',
                  icon: Icons.touch_app_rounded,
                ),
                const SizedBox(height: 12),
                _buildInteractiveSilhouetteCanvas(),
                const SizedBox(height: 12),
                _buildQuickPointsBar(),
                const SizedBox(height: 16),
                _buildSectionTitle(
                  title: 'Resumen de Puntos Marcados',
                  icon: Icons.checklist_rtl_rounded,
                ),
                const SizedBox(height: 8),
                _buildPointsSummaryCard(),
                const SizedBox(height: 16),
                _buildNotesTextField(),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: cargando ? null : _guardar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.cDeepAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  icon: cargando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(cargando ? 'Guardando...' : 'Guardar Face Map'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle({
    required String title,
    String? subtitle,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppTheme.cDeepAccent, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _buildInteractiveSilhouetteCanvas() {
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
              final viewConstraints = BoxConstraints(
                maxWidth: canvasWidth,
                maxHeight: canvasHeight,
              );
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
                          return _buildHeadViewPage(
                            view,
                            canvasWidth,
                            canvasHeight,
                            viewConstraints,
                          );
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: _currentView == HeadView.izq
              ? null
              : () => _goToView(HeadView.values[_currentView.index - 1]),
        ),
        ...HeadView.values.map(
          (view) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
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
              onSelected: (_) => _goToView(view),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: _currentView == HeadView.der
              ? null
              : () => _goToView(HeadView.values[_currentView.index + 1]),
        ),
      ],
    );
  }

  Widget _buildHeadViewPage(
    HeadView view,
    double canvasWidth,
    double canvasHeight,
    BoxConstraints constraints,
  ) {
    return GestureDetector(
      onTapDown: (details) =>
          _handleSilhouetteTap(details, view, constraints),
      child: SizedBox(
        width: canvasWidth,
        height: canvasHeight,
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
            ..._forbiddenRegions.map((region) {
              final bounds = region.boundsFor(view);
              if (bounds == null) return const SizedBox.shrink();
              final isLowerBody = region.id == 'pecho_inferior';
              return Positioned(
                left: bounds.left * canvasWidth,
                top: bounds.top * canvasHeight,
                width: bounds.width * canvasWidth,
                height: bounds.height * canvasHeight,
                child: Tooltip(
                  message: '${region.title} (región Prohibida FDA)',
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.35),
                      shape: isLowerBody ? BoxShape.rectangle : BoxShape.circle,
                      borderRadius: isLowerBody
                          ? BorderRadius.circular(8)
                          : null,
                      border: Border.all(color: Colors.red.shade600, width: 1.5),
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
            ..._predefinedPoints.map((point) {
              final off = point.offsetFor(view);
              if (off == null) return const SizedBox.shrink();
              if (_selectedPoints.any((p) => p.id == point.id)) {
                return const SizedBox.shrink();
              }
              return Positioned(
                left: off.dx * canvasWidth - 14,
                top: off.dy * canvasHeight - 14,
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
                      child: Icon(Icons.add, size: 16, color: AppTheme.cDeepAccent),
                    ),
                  ),
                ),
              );
            }),
            ..._selectedPoints
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
                top: off.dy * canvasHeight - 16,
                child: Tooltip(
                  message: '${point.label} (Clic para desmarcar)',
                  child: GestureDetector(
                    onTap: () => _togglePoint(point),
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
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickPointsBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Puntos de Inyección Válidos (Acceso Rápido):',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _predefinedPoints
              .map(
                (point) => FilterChip(
                  selected: _selectedPoints.any((p) => p.id == point.id),
                  showCheckmark: true,
                  selectedColor: AppTheme.cDeepAccent,
                  checkmarkColor: Colors.white,
                  labelStyle: const TextStyle(fontSize: 12),
                  label: Text(point.label),
                  onSelected: (_) => _togglePoint(point),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildPointsSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.pin_drop_rounded,
                size: 18,
                color: AppTheme.cDeepAccent,
              ),
              const SizedBox(width: 8),
              Text(
                'Puntos Marcados (${_selectedPoints.length}):',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_selectedPoints.isEmpty)
            Text(
              'No se ha marcado ningún punto todavía. Toca el rostro o usa '
              'el acceso rápido para marcar la zona de aplicación.',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _selectedPoints.asMap().entries.map((entry) {
                final index = entry.key + 1;
                final point = entry.value;
                return Chip(
                  backgroundColor: AppTheme.cDeepAccent.withValues(alpha: 0.12),
                  side: BorderSide(
                    color: AppTheme.cDeepAccent.withValues(alpha: 0.8),
                  ),
                  avatar: CircleAvatar(
                    backgroundColor: AppTheme.cDeepAccent,
                    child: Text(
                      '$index',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                  label: Text(
                    point.label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.cDeepAccent,
                    ),
                  ),
                  onDeleted: () => _togglePoint(point),
                  deleteIconColor: AppTheme.cDeepAccent,
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildNotesTextField() {
    return TextField(
      controller: _notasController,
      maxLines: 3,
      decoration: const InputDecoration(
        labelText: 'Notas Clínicas / Observaciones (Opcional)',
        hintText: 'Ej: Toxina botulínica en glabela, 15 unidades; ácido '
            'hialurónico en surco nasogeniano, 0.5 ml.',
        border: OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
}

List<InjectionPoint> _defaultInjectionPoints() {
  return [
    InjectionPoint(
      id: 'frente',
      label: 'Frente / Arrugas Frontales',
      offsets: {
        HeadView.izq: Offset(0.356, 0.235),
        HeadView.frente: Offset(0.500, 0.220),
        HeadView.der: Offset(0.621, 0.228),
      },
    ),
    InjectionPoint(
      id: 'glabela_centro',
      label: 'Glabela / Entrecejo',
      offsets: {
        HeadView.izq: Offset(0.339, 0.311),
        HeadView.frente: Offset(0.500, 0.330),
        HeadView.der: Offset(0.617, 0.311),
      },
    ),
    InjectionPoint(
      id: 'patas_gallo_izq',
      label: 'Patas de Gallo Izq',
      offsets: {
        HeadView.izq: Offset(0.413, 0.435),
        HeadView.frente: Offset(0.330, 0.420),
      },
    ),
    InjectionPoint(
      id: 'patas_gallo_der',
      label: 'Patas de Gallo Der',
      offsets: {
        HeadView.frente: Offset(0.670, 0.420),
        HeadView.der: Offset(0.572, 0.435),
      },
    ),
    InjectionPoint(
      id: 'pomulo_izq',
      label: 'Pómulo Izquierdo',
      offsets: {
        HeadView.izq: Offset(0.385, 0.522),
        HeadView.frente: Offset(0.370, 0.510),
      },
    ),
    InjectionPoint(
      id: 'pomulo_der',
      label: 'Pómulo Derecho',
      offsets: {
        HeadView.frente: Offset(0.630, 0.510),
        HeadView.der: Offset(0.617, 0.518),
      },
    ),
    InjectionPoint(
      id: 'surco_naso_izq',
      label: 'Surco Nasogeniano Izq',
      offsets: {
        HeadView.izq: Offset(0.301, 0.574),
        HeadView.frente: Offset(0.430, 0.560),
      },
    ),
    InjectionPoint(
      id: 'surco_naso_der',
      label: 'Surco Nasogeniano Der',
      offsets: {
        HeadView.frente: Offset(0.570, 0.560),
        HeadView.der: Offset(0.692, 0.562),
      },
    ),
    InjectionPoint(
      id: 'labios',
      label: 'Labios & Perioral',
      offsets: {
        HeadView.izq: Offset(0.317, 0.650),
        HeadView.frente: Offset(0.500, 0.630),
        HeadView.der: Offset(0.664, 0.644),
      },
    ),
    InjectionPoint(
      id: 'menton',
      label: 'Mentón & Barbilla',
      offsets: {
        HeadView.izq: Offset(0.413, 0.694),
        HeadView.frente: Offset(0.500, 0.730),
        HeadView.der: Offset(0.560, 0.675),
      },
    ),
    InjectionPoint(
      id: 'cuello_izq',
      label: 'Cuello / Platisma Izq',
      offsets: {
        HeadView.izq: Offset(0.531, 0.842),
        HeadView.frente: Offset(0.420, 0.820),
      },
    ),
    InjectionPoint(
      id: 'cuello_der',
      label: 'Cuello / Platisma Der',
      offsets: {
        HeadView.frente: Offset(0.580, 0.820),
        HeadView.der: Offset(0.450, 0.838),
      },
    ),
  ];
}

List<ForbiddenRegion> _defaultForbiddenRegions() {
  return [
    const ForbiddenRegion(
      id: 'ojo_izquierdo',
      title: 'Cavidad Ocular / Globo Ocular Izquierdo',
      reason: 'Prohibido por la FDA y la sociedad de dermatología: riesgo '
          'grave de necrosis vascular y ceguera.',
      bounds: {
        HeadView.izq: Rect.fromLTWH(0.300, 0.380, 0.380, 0.460),
        HeadView.frente: Rect.fromLTWH(0.370, 0.380, 0.450, 0.460),
        HeadView.der: Rect.fromLTWH(0.620, 0.380, 0.700, 0.460),
      },
    ),
    const ForbiddenRegion(
      id: 'ojo_derecho',
      title: 'Cavidad Ocular / Globo Ocular Derecho',
      reason: 'Prohibido por la FDA y la sociedad de dermatología: riesgo '
          'grave de necrosis vascular y ceguera.',
      bounds: {
        HeadView.frente: Rect.fromLTWH(0.550, 0.380, 0.630, 0.460),
      },
    ),
    const ForbiddenRegion(
      id: 'nariz_dorso',
      title: 'Dorso & Punta Nasal (Zona Vascular de Alto Riesgo)',
      reason: 'Prohibido por la FDA y dermatología: alto riesgo de oclusión '
          'vascular y necrosis nasal.',
      bounds: {
        HeadView.izq: Rect.fromLTWH(0.178, 0.497, 0.228, 0.557),
        HeadView.frente: Rect.fromLTWH(0.470, 0.470, 0.530, 0.530),
        HeadView.der: Rect.fromLTWH(0.747, 0.497, 0.797, 0.557),
      },
    ),
    const ForbiddenRegion(
      id: 'arteria_temporal_izq',
      title: 'Zona Arterial Temporal de Alto Riesgo (Izq)',
      reason: 'Prohibido para aplicación directa de inyectables sin guía '
          'ecográfica avanzada.',
      bounds: {
        HeadView.izq: Rect.fromLTWH(0.482, 0.305, 0.542, 0.385),
        HeadView.frente: Rect.fromLTWH(0.260, 0.320, 0.320, 0.400),
      },
    ),
    const ForbiddenRegion(
      id: 'arteria_temporal_der',
      title: 'Zona Arterial Temporal de Alto Riesgo (Der)',
      reason: 'Prohibido para aplicación directa de inyectables sin guía '
          'ecográfica avanzada.',
      bounds: {
        HeadView.frente: Rect.fromLTWH(0.680, 0.320, 0.740, 0.400),
        HeadView.der: Rect.fromLTWH(0.467, 0.330, 0.527, 0.410),
      },
    ),
    const ForbiddenRegion(
      id: 'pecho_inferior',
      title: 'Zona Corporal Inferior (Escote / Senos)',
      reason: 'La FDA prohíbe explícitamente el uso de inyectables en grandes '
          'volúmenes para modelado corporal (como senos o glúteos).',
      bounds: {
        HeadView.izq: Rect.fromLTWH(0.100, 0.940, 0.900, 1.000),
        HeadView.frente: Rect.fromLTWH(0.100, 0.940, 0.900, 1.000),
        HeadView.der: Rect.fromLTWH(0.100, 0.940, 0.900, 1.000),
      },
    ),
  ];
}