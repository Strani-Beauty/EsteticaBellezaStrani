import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import 'package:esteticaybellezastrani/supabase_service.dart';

/// Modelo para un punto de inyección seleccionado en la silueta
class InjectionPoint {
  final String id;
  final String label;
  final Offset relativeOffset; // (x, y) entre 0.0 y 1.0
  final bool isCustom;

  const InjectionPoint({
    required this.id,
    required this.label,
    required this.relativeOffset,
    this.isCustom = false,
  });
}

/// Screen para el Cuestionario de Inyectables y Mapeo Interactivo de Puntos sobre la imagen física `Silueta.jpg`.
class FaceMapQuestionnaireScreen extends StatefulWidget {
  final String? tratamientoId;

  const FaceMapQuestionnaireScreen({
    super.key,
    this.tratamientoId,
  });

  @override
  State<FaceMapQuestionnaireScreen> createState() => _FaceMapQuestionnaireScreenState();
}

class _FaceMapQuestionnaireScreenState extends State<FaceMapQuestionnaireScreen> {
  final TextEditingController _notasController = TextEditingController();

  late final String _effectiveTratamientoId;
  bool _isSaving = false;
  bool _showRegulatoryInfo = false;

  // Puntos predefinidos válidos mapeados EXACTAMENTE sobre los rasgos de Silueta.jpg
  final List<InjectionPoint> _predefinedPoints = const [
    InjectionPoint(id: 'frente', label: 'Frente / Arrugas Frontales', relativeOffset: Offset(0.50, 0.22)),
    InjectionPoint(id: 'glabela_centro', label: 'Glabela / Entrecejo', relativeOffset: Offset(0.50, 0.33)), // Bajado a la zona entre cejas
    InjectionPoint(id: 'patas_gallo_izq', label: 'Patas de Gallo Izq', relativeOffset: Offset(0.26, 0.42)),
    InjectionPoint(id: 'patas_gallo_der', label: 'Patas de Gallo Der', relativeOffset: Offset(0.74, 0.42)),
    InjectionPoint(id: 'pomulo_izq', label: 'Pómulo Izquierdo', relativeOffset: Offset(0.30, 0.52)),
    InjectionPoint(id: 'pomulo_der', label: 'Pómulo Derecho', relativeOffset: Offset(0.70, 0.52)),
    InjectionPoint(id: 'surco_naso_izq', label: 'Surco Nasogeniano Izq', relativeOffset: Offset(0.42, 0.55)),
    InjectionPoint(id: 'surco_naso_der', label: 'Surco Nasogeniano Der', relativeOffset: Offset(0.58, 0.55)),
    InjectionPoint(id: 'labios', label: 'Labios & Perioral', relativeOffset: Offset(0.50, 0.63)),
    InjectionPoint(id: 'menton', label: 'Mentón & Barbilla', relativeOffset: Offset(0.50, 0.73)),
    InjectionPoint(id: 'cuello_izq', label: 'Cuello / Platisma Izq', relativeOffset: Offset(0.42, 0.82)), // Subido ligeramente
    InjectionPoint(id: 'cuello_der', label: 'Cuello / Platisma Der', relativeOffset: Offset(0.58, 0.82)), // Subido ligeramente
  ];

  // Puntos actualmente seleccionados
  final List<InjectionPoint> _selectedPoints = [];

  // Zonas NO VÁLIDAS / PROHIBIDAS (Ojos, Nariz, Arterias Temporales y Pecho)
  final List<Map<String, dynamic>> _forbiddenRegions = [
    {
      'id': 'ojo_izquierdo',
      'title': 'Cavidad Ocular / Globo Ocular Izquierdo',
      'reason': 'Prohibido por la FDA y la sociedad de dermatología: riesgo grave de necrosis vascular y ceguera.',
      'bounds': const Rect.fromLTRB(0.34, 0.38, 0.44, 0.46),
    },
    {
      'id': 'ojo_derecho',
      'title': 'Cavidad Ocular / Globo Ocular Derecho',
      'reason': 'Prohibido por la FDA y la sociedad de dermatología: riesgo grave de necrosis vascular y ceguera.',
      'bounds': const Rect.fromLTRB(0.56, 0.38, 0.66, 0.46),
    },
    {
      'id': 'nariz_dorso',
      'title': 'Dorso & Punta Nasal (Zona Vascular de Alto Riesgo)',
      'reason': 'Prohibido por la FDA y dermatología: alto riesgo de oclusión vascular y necrosis nasal.',
      'bounds': const Rect.fromLTRB(0.46, 0.48, 0.54, 0.54), // Directamente sobre la nariz entre los surcos nasogenianos
    },
    {
      'id': 'arteria_temporal_izq',
      'title': 'Zona Arterial Temporal de Alto Riesgo (Izq)',
      'reason': 'Prohibido para aplicación directa de inyectables sin guía ecográfica avanzada.',
      'bounds': const Rect.fromLTRB(0.21, 0.32, 0.27, 0.40),
    },
    {
      'id': 'arteria_temporal_der',
      'title': 'Zona Arterial Temporal de Alto Riesgo (Der)',
      'reason': 'Prohibido para aplicación directa de inyectables sin guía ecográfica avanzada.',
      'bounds': const Rect.fromLTRB(0.73, 0.32, 0.79, 0.40),
    },
    {
      'id': 'pecho_inferior',
      'title': 'Zona Corporal Inferior (Escote / Senos)',
      'reason': 'La FDA prohíbe explícitamente el uso de inyectables en grandes volúmenes para modelado corporal (como senos o glúteos).',
      'bounds': const Rect.fromLTRB(0.10, 0.94, 0.90, 1.00),
    },
  ];

  // Registro de intentos de clic en zonas prohibidas
  final List<String> _attemptedForbiddenZones = [];

  @override
  void initState() {
    super.initState();
    _effectiveTratamientoId = widget.tratamientoId ??
        'TRAT-INY-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
  }

  @override
  void dispose() {
    _notasController.dispose();
    super.dispose();
  }

  void _handleSilhouetteTap(TapDownDetails details, BoxConstraints constraints) {
    final dx = details.localPosition.dx / constraints.maxWidth;
    final dy = details.localPosition.dy / constraints.maxHeight;
    final tappedOffset = Offset(dx, dy);

    // 1. Verificar si el clic cayó dentro de una zona prohibida / no válida
    for (final region in _forbiddenRegions) {
      final Rect bounds = region['bounds'] as Rect;
      if (bounds.contains(tappedOffset)) {
        _showForbiddenZoneWarning(region);
        return;
      }
    }

    // 2. Verificar si el clic estuvo cerca de un punto predefinido (distancia < 0.07)
    for (final point in _predefinedPoints) {
      final dist = (point.relativeOffset - tappedOffset).distance;
      if (dist < 0.07) {
        _togglePoint(point);
        return;
      }
    }

    // 3. Si se hizo clic en una zona válida del rostro o cuello, agregar punto personalizado
    if (dy >= 0.12 && dy <= 0.92 && dx >= 0.20 && dx <= 0.80) {
      final customPoint = InjectionPoint(
        id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
        label: 'Punto Marcado (${(dx * 100).toStringAsFixed(0)}%, ${(dy * 100).toStringAsFixed(0)}%)',
        relativeOffset: tappedOffset,
        isCustom: true,
      );
      setState(() {
        _selectedPoints.add(customPoint);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Punto de inyección marcado en (${(dx * 100).toStringAsFixed(0)}%, ${(dy * 100).toStringAsFixed(0)}%)'),
          duration: const Duration(seconds: 1),
          backgroundColor: AppTheme.cDeepAccent,
        ),
      );
    }
  }

  void _togglePoint(InjectionPoint point) {
    setState(() {
      final existingIndex = _selectedPoints.indexWhere((p) => p.id == point.id);
      if (existingIndex >= 0) {
        _selectedPoints.removeAt(existingIndex);
      } else {
        _selectedPoints.add(point);
      }
    });
  }

  void _showForbiddenZoneWarning(Map<String, dynamic> region) {
    final title = region['title'] as String;
    final reason = region['reason'] as String;

    if (!_attemptedForbiddenZones.contains(title)) {
      _attemptedForbiddenZones.add(title);
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Zona No Válida / Prohibida (FDA)',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.redAccent,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  const Text('🚫 ', style: TextStyle(fontSize: 20)),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              reason,
              style: const TextStyle(fontSize: 13.5, height: 1.4, color: AppTheme.cDarkText),
            ),
            const SizedBox(height: 12),
            const Text(
              'Regulación Sanitaria FDA:\n'
              'Sólo están autorizados los puntos indicados de rostro y cuello. Queda prohibida la aplicación en estructuras oculares, vasculares críticas o grandes volúmenes corporales.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppTheme.cMutedText),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Entendido', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveFaceMap() async {
    final user = SupabaseService.currentUser;
    final profileId = user?.id ?? 'invitado_test';

    if (_selectedPoints.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona al menos un punto de inyección en la silueta.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final selectedLabels = _selectedPoints.map((p) => p.label).toList();

    try {
      final success = await SupabaseService.saveFaceMapRecord(
        profileId: profileId,
        tratamientoId: _effectiveTratamientoId,
        zonasSeleccionadas: selectedLabels,
        zonasProhibidasIntentadas: _attemptedForbiddenZones,
        notas: _notasController.text.trim(),
      );

      if (!mounted) return;
      setState(() => _isSaving = false);

      if (success) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            ),
            title: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
                SizedBox(width: 10),
                Text('Mapeo Registrado'),
              ],
            ),
            content: Text(
              'Se han guardado correctamente ${_selectedPoints.length} puntos de inyección en la tabla face_maps de Supabase para el Tratamiento ID: $_effectiveTratamientoId.',
              style: const TextStyle(fontSize: 14),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cDeepAccent),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/services');
                  }
                },
                child: const Text('Aceptar', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar mapeo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Cuestionario & Face Maps'),
        backgroundColor: AppTheme.cDeepAccent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_showRegulatoryInfo ? Icons.info : Icons.info_outline),
            tooltip: 'Regulación FDA & Estatal',
            onPressed: () {
              setState(() => _showRegulatoryInfo = !_showRegulatoryInfo);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 1. Imagen Superior: "Torso_inyectables" Completa ──
            _buildTopHeaderTorsoImage(),

            // ── Banner Regulatorio ──
            if (_showRegulatoryInfo) _buildRegulatoryBanner(),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badge Tratamiento
                  _buildTreatmentBadge(),
                  const SizedBox(height: 20),

                  // ── 2. SECCIÓN MAPA INTERACTIVO (Imagen Física Silueta.jpg) ──
                  _buildSectionTitle(
                    title: 'Mapa Mapeable de Inyectables (Rostro & Cuello)',
                    subtitle: 'Haz clic directamente sobre la silueta para marcar los puntos de inyección requeridos. Las zonas oculares prohibidas están sombreadas en rojo suave sobre ambos ojos.',
                    icon: Icons.touch_app_rounded,
                  ),
                  const SizedBox(height: 14),

                  // Silueta interactiva mapeable usando la imagen física Silueta.jpg
                  _buildInteractiveSilhouetteCanvas(),
                  const SizedBox(height: 16),

                  // Acceso rápido a puntos predefinidos
                  _buildQuickPointsBar(),
                  const SizedBox(height: 24),

                  // ── 3. RESUMEN Y NOTAS ──
                  _buildSectionTitle(
                    title: 'Resumen de Puntos Marcados',
                    subtitle: 'Lista de puntos de inyección válidos seleccionados:',
                    icon: Icons.checklist_rtl_rounded,
                  ),
                  const SizedBox(height: 12),
                  _buildPointsSummaryCard(),
                  const SizedBox(height: 16),
                  _buildNotesTextField(),
                  const SizedBox(height: 24),

                  // Botón Guardar en Supabase
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.cDeepAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        ),
                        elevation: 3,
                      ),
                      onPressed: _isSaving ? null : _saveFaceMap,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.cloud_upload_rounded, color: Colors.white),
                      label: Text(
                        _isSaving ? 'Guardando en Supabase...' : 'Guardar Mapeo en Supabase (face_maps)',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Encabezado superior usando la imagen completa "Torso_inyectables" (assets/images/Torso inyectables.jpg)
  Widget _buildTopHeaderTorsoImage() {
    return Container(
      width: double.infinity,
      color: Colors.blueGrey.shade900,
      child: Column(
        children: [
          Container(
            constraints: const BoxConstraints(maxHeight: 320),
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Image.asset(
              'assets/images/Torso inyectables.jpg',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 240,
                  color: Colors.teal.shade800,
                  child: const Center(
                    child: Icon(Icons.medical_services_outlined, size: 70, color: Colors.white54),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.85),
                  AppTheme.cDeepAccent,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.cPastelGold,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'TORSO INYECTABLES',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.cGoldAccent,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Cuestionario & Mapeo de Puntos',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegulatoryBanner() {
    return Container(
      color: Colors.blueGrey.shade900,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.gavel_rounded, color: AppTheme.cGoldAccent, size: 20),
              SizedBox(width: 8),
              Text(
                'Marco Normativo de Inyectables (FDA & Juntas Médicas)',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '• Marco Federal (FDA): Inyectables aprobados únicamente en sitios específicos de rostro y cuello (y dorso de manos). Prohibición estricta en grandes volúmenes corporales (senos, glúteos).\n'
            '• Marco Estatal: Práctica médica bajo evaluación previa y supervisión de Director Médico (MD/DO). Prohibido para esteticistas.',
            style: TextStyle(color: Colors.grey.shade300, fontSize: 12.5, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildTreatmentBadge() {
    final user = SupabaseService.currentUser;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: AppTheme.cDeepAccent,
            radius: 18,
            child: Icon(Icons.healing_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tratamiento ID: $_effectiveTratamientoId',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
                Text(
                  'Paciente: ${user?.email ?? 'Paciente Activo'}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppTheme.cDeepAccent, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.cDeepAccent,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
        ),
      ],
    );
  }

  /// Canvas interactivo que muestra ÚNICAMENTE la imagen física `Silueta.jpg` / `Silueta.png`
  Widget _buildInteractiveSilhouetteCanvas() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: AppTheme.cPastelPurple,
            child: const Row(
              children: [
                Icon(Icons.ads_click_rounded, color: AppTheme.cDeepAccent, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Haz clic sobre la silueta para agregar/quitar puntos de inyección. Zonas oculares rojas = Prohibidas.',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.cDeepAccent),
                  ),
                ),
              ],
            ),
          ),

          // Área de imagen silueta centrada a la mitad del ancho actual (1:1 proporcional)
          LayoutBuilder(
            builder: (context, constraints) {
              final double canvasWidth = (constraints.maxWidth * 0.5).clamp(280.0, 480.0);
              final double canvasHeight = canvasWidth; // Proporcional 1:1

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
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: GestureDetector(
                      onTapDown: (details) => _handleSilhouetteTap(
                        details,
                        BoxConstraints(maxWidth: canvasWidth, maxHeight: canvasHeight),
                      ),
                      child: SizedBox(
                        width: canvasWidth,
                        height: canvasHeight,
                        child: Stack(
                          children: [
                            // 1. Cargar ÚNICAMENTE el activo de imagen física `Silueta.jpg` / `Silueta.png`
                            Positioned.fill(
                              child: Container(
                                color: Colors.white,
                                child: Image.asset(
                                  'assets/images/Silueta.jpg',
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Image.asset(
                                      'assets/images/Silueta.png',
                                      fit: BoxFit.contain,
                                      errorBuilder: (ctx2, err2, st2) => const Center(
                                        child: Text(
                                          'Reiniciar servidor (flutter run) para cargar Silueta.jpg',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: Colors.grey, fontSize: 12),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),

                            // 2. Renderizar ZONAS NO VÁLIDAS / PROHIBIDAS (Sobre ambos ojos de Silueta.jpg)
                            ..._forbiddenRegions.map((region) {
                              final Rect bounds = region['bounds'] as Rect;
                              final left = bounds.left * canvasWidth;
                              final top = bounds.top * canvasHeight;
                              final width = bounds.width * canvasWidth;
                              final height = bounds.height * canvasHeight;

                              final bool isLowerBody = region['id'] == 'pecho_inferior';

                              return Positioned(
                                left: left,
                                top: top,
                                width: width,
                                height: height,
                                child: Tooltip(
                                  message: '${region['title']} (Zona Prohibida FDA)',
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.red.withValues(alpha: 0.35),
                                      shape: isLowerBody ? BoxShape.rectangle : BoxShape.circle,
                                      borderRadius: isLowerBody ? BorderRadius.circular(8) : null,
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

                            // 3. Renderizar PUNTOS PREDEFINIDOS no seleccionados (Marcadores circulares)
                            ..._predefinedPoints.map((point) {
                              final isSelected = _selectedPoints.any((p) => p.id == point.id);
                              if (isSelected) return const SizedBox.shrink();

                              final px = point.relativeOffset.dx * canvasWidth - 14;
                              final py = point.relativeOffset.dy * canvasHeight - 14;

                              return Positioned(
                                left: px,
                                top: py,
                                child: Tooltip(
                                  message: 'Clic para marcar: ${point.label}',
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: AppTheme.cDeepAccent.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: AppTheme.cDeepAccent.withValues(alpha: 0.5), width: 1.2),
                                    ),
                                    child: const Center(
                                      child: Icon(Icons.add, size: 16, color: AppTheme.cDeepAccent),
                                    ),
                                  ),
                                ),
                              );
                            }),

                            // 4. Renderizar PUNTOS SELECCIONADOS (Pines numerados destacados)
                            ..._selectedPoints.asMap().entries.map((entry) {
                              final index = entry.key + 1;
                              final point = entry.value;
                              final px = point.relativeOffset.dx * canvasWidth - 16;
                              final py = point.relativeOffset.dy * canvasHeight - 16;

                              return Positioned(
                                left: px,
                                top: py,
                                child: Tooltip(
                                  message: '${point.label} (Clic para desmarcar)',
                                  child: GestureDetector(
                                    onTap: () => _togglePoint(point),
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: AppTheme.cDeepAccent,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Colors.black26,
                                            blurRadius: 4,
                                            offset: Offset(0, 2),
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
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Barra de accesos rápidos para seleccionar/desmarcar puntos predefinidos
  Widget _buildQuickPointsBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Puntos de Inyección Válidos (Acceso Rápido):',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.cDarkText),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _predefinedPoints.map((point) {
            final isSelected = _selectedPoints.any((p) => p.id == point.id);
            return FilterChip(
              selected: isSelected,
              showCheckmark: true,
              selectedColor: AppTheme.cDeepAccent,
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : AppTheme.cDarkText,
              ),
              label: Text(point.label),
              onSelected: (_) => _togglePoint(point),
            );
          }).toList(),
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
              const Icon(Icons.pin_drop_rounded, color: AppTheme.cDeepAccent, size: 18),
              const SizedBox(width: 6),
              Text(
                'Puntos Marcados en Silueta (${_selectedPoints.length}):',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_selectedPoints.isEmpty)
            Text(
              'No se ha marcado ningún punto de inyección en la silueta. Haz clic sobre la imagen para añadir puntos.',
              style: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic, fontSize: 13),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _selectedPoints.asMap().entries.map((entry) {
                final idx = entry.key + 1;
                final point = entry.value;
                return Chip(
                  backgroundColor: AppTheme.cDeepAccent.withValues(alpha: 0.12),
                  side: const BorderSide(color: AppTheme.cDeepAccent, width: 0.8),
                  avatar: CircleAvatar(
                    backgroundColor: AppTheme.cDeepAccent,
                    child: Text('$idx', style: const TextStyle(fontSize: 10, color: Colors.white)),
                  ),
                  label: Text(
                    point.label,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.cDeepAccent),
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
      decoration: InputDecoration(
        labelText: 'Notas Clínicas / Observaciones (Opcional)',
        alignLabelWithHint: true,
        hintText: 'Ej: Toxina botulínica en glabela, 15 unidades; Ácido hialurónico en surcos nasogenianos...',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
}
