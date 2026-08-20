import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import 'package:esteticaybellezastrani/app/core/network/supabase_service.dart';

/// Vista de la cabeza (ángulo) sobre la que se mapean los puntos de inyección.
enum HeadView { izq, frente, der }

extension HeadViewX on HeadView {
  String get asset => switch (this) {
        HeadView.izq => 'assets/images/Izq.png',
        HeadView.frente => 'assets/images/Fte.png',
        HeadView.der => 'assets/images/Der.png',
      };

  String get label => switch (this) {
        HeadView.izq => 'Perfil Izq',
        HeadView.frente => 'Frente',
        HeadView.der => 'Perfil Der',
      };
}

/// Modelo para un punto de inyección con offset normalizado por vista (0..1).
class InjectionPoint {
  final String id;
  final String label;
  final Map<HeadView, Offset> offsets; // offsets por vista (x, y) entre 0.0 y 1.0
  final bool isCustom;

  InjectionPoint({
    required this.id,
    required this.label,
    required this.offsets,
    this.isCustom = false,
  });

  Offset? offsetFor(HeadView view) => offsets[view];
}

/// Zona no válida / prohibida con su área (rect) por vista.
class ForbiddenRegion {
  final String id;
  final String title;
  final String reason;
  final Map<HeadView, Rect> bounds;

  const ForbiddenRegion({
    required this.id,
    required this.title,
    required this.reason,
    required this.bounds,
  });

  Rect? boundsFor(HeadView view) => bounds[view];
}

/// Puntos predefinidos válidos mapeados sobre los rasgos de cada vista
/// (Fte.png frontal, Izq.png / Der.png perfiles).
List<InjectionPoint> _defaultInjectionPoints() {
  return [
    InjectionPoint(id: 'frente', label: 'Frente / Arrugas Frontales', offsets: {
      HeadView.izq: const Offset(0.356, 0.235),
      HeadView.frente: const Offset(0.500, 0.220),
      HeadView.der: const Offset(0.621, 0.228),
    }),
    InjectionPoint(id: 'glabela_centro', label: 'Glabela / Entrecejo', offsets: {
      HeadView.izq: const Offset(0.339, 0.311),
      HeadView.frente: const Offset(0.500, 0.330),
      HeadView.der: const Offset(0.617, 0.311),
    }),
    InjectionPoint(id: 'patas_gallo_izq', label: 'Patas de Gallo Izq', offsets: {
      HeadView.izq: const Offset(0.413, 0.435),
      HeadView.frente: const Offset(0.330, 0.420),
    }),
    InjectionPoint(id: 'patas_gallo_der', label: 'Patas de Gallo Der', offsets: {
      HeadView.frente: const Offset(0.670, 0.420),
      HeadView.der: const Offset(0.572, 0.435),
    }),
    InjectionPoint(id: 'pomulo_izq', label: 'Pómulo Izquierdo', offsets: {
      HeadView.izq: const Offset(0.385, 0.522),
      HeadView.frente: const Offset(0.370, 0.510),
    }),
    InjectionPoint(id: 'pomulo_der', label: 'Pómulo Derecho', offsets: {
      HeadView.frente: const Offset(0.630, 0.510),
      HeadView.der: const Offset(0.617, 0.518),
    }),
    InjectionPoint(id: 'surco_naso_izq', label: 'Surco Nasogeniano Izq', offsets: {
      HeadView.izq: const Offset(0.301, 0.574),
      HeadView.frente: const Offset(0.430, 0.560),
    }),
    InjectionPoint(id: 'surco_naso_der', label: 'Surco Nasogeniano Der', offsets: {
      HeadView.frente: const Offset(0.570, 0.560),
      HeadView.der: const Offset(0.692, 0.562),
    }),
    InjectionPoint(id: 'labios', label: 'Labios & Perioral', offsets: {
      HeadView.izq: const Offset(0.317, 0.650),
      HeadView.frente: const Offset(0.500, 0.630),
      HeadView.der: const Offset(0.664, 0.644),
    }),
    InjectionPoint(id: 'menton', label: 'Mentón & Barbilla', offsets: {
      HeadView.izq: const Offset(0.413, 0.694),
      HeadView.frente: const Offset(0.500, 0.730),
      HeadView.der: const Offset(0.560, 0.675),
    }),
    InjectionPoint(id: 'cuello_izq', label: 'Cuello / Platisma Izq', offsets: {
      HeadView.izq: const Offset(0.531, 0.842),
      HeadView.frente: const Offset(0.420, 0.820),
    }),
    InjectionPoint(id: 'cuello_der', label: 'Cuello / Platisma Der', offsets: {
      HeadView.frente: const Offset(0.580, 0.820),
      HeadView.der: const Offset(0.450, 0.838),
    }),
  ];
}

/// Zonas NO VÁLIDAS / PROHIBIDAS (Ojos, Nariz, Arterias Temporales y Pecho)
/// con su área por cada vista.
List<ForbiddenRegion> _defaultForbiddenRegions() {
  const eyeReason =
      'Prohibido por la FDA y la sociedad de dermatología: riesgo grave de necrosis vascular y ceguera.';
  const temporalReason =
      'Prohibido para aplicación directa de inyectables sin guía ecográfica avanzada.';
  const narizReason =
      'Prohibido por la FDA y dermatología: alto riesgo de oclusión vascular y necrosis nasal.';
  const pechoReason =
      'La FDA prohíbe explícitamente el uso de inyectables en grandes volúmenes para modelado corporal (como senos o glúteos).';

  return [
    ForbiddenRegion(
      id: 'ojo_izquierdo',
      title: 'Cavidad Ocular / Globo Ocular Izquierdo',
      reason: eyeReason,
      bounds: {
        HeadView.izq: const Rect.fromLTRB(0.300, 0.380, 0.380, 0.460),
        HeadView.frente: const Rect.fromLTRB(0.370, 0.380, 0.450, 0.460),
        HeadView.der: const Rect.fromLTRB(0.620, 0.380, 0.700, 0.460),
      },
    ),
    ForbiddenRegion(
      id: 'ojo_derecho',
      title: 'Cavidad Ocular / Globo Ocular Derecho',
      reason: eyeReason,
      bounds: {
        HeadView.frente: const Rect.fromLTRB(0.550, 0.380, 0.630, 0.460),
      },
    ),
    ForbiddenRegion(
      id: 'nariz_dorso',
      title: 'Dorso & Punta Nasal (Zona Vascular de Alto Riesgo)',
      reason: narizReason,
      bounds: {
        HeadView.izq: const Rect.fromLTRB(0.178, 0.497, 0.228, 0.557),
        HeadView.frente: const Rect.fromLTRB(0.470, 0.470, 0.530, 0.530),
        HeadView.der: const Rect.fromLTRB(0.747, 0.497, 0.797, 0.557),
      },
    ),
    ForbiddenRegion(
      id: 'arteria_temporal_izq',
      title: 'Zona Arterial Temporal de Alto Riesgo (Izq)',
      reason: temporalReason,
      bounds: {
        HeadView.izq: const Rect.fromLTRB(0.482, 0.305, 0.542, 0.385),
        HeadView.frente: const Rect.fromLTRB(0.260, 0.320, 0.320, 0.400),
      },
    ),
    ForbiddenRegion(
      id: 'arteria_temporal_der',
      title: 'Zona Arterial Temporal de Alto Riesgo (Der)',
      reason: temporalReason,
      bounds: {
        HeadView.frente: const Rect.fromLTRB(0.680, 0.320, 0.740, 0.400),
        HeadView.der: const Rect.fromLTRB(0.467, 0.330, 0.527, 0.410),
      },
    ),
    ForbiddenRegion(
      id: 'pecho_inferior',
      title: 'Zona Corporal Inferior (Escote / Senos)',
      reason: pechoReason,
      bounds: {
        HeadView.izq: const Rect.fromLTRB(0.100, 0.940, 0.900, 1.000),
        HeadView.frente: const Rect.fromLTRB(0.100, 0.940, 0.900, 1.000),
        HeadView.der: const Rect.fromLTRB(0.100, 0.940, 0.900, 1.000),
      },
    ),
  ];
}

/// Argumentos de navegación hacia el face map (extra de la ruta).
class FaceMapParams {
  final String? tratamientoId;
  final String? servicioId;
  final bool soloLectura;
  final List<InjectionPoint>? puntosIniciales;

  const FaceMapParams({
    this.tratamientoId,
    this.servicioId,
    this.soloLectura = false,
    this.puntosIniciales,
  });
}

/// Screen para el Cuestionario de Inyectables y Mapeo Interactivo de Puntos
/// sobre una cabeza realista rotable (Frente + Perfiles Izq/Der).
class FaceMapQuestionnaireScreen extends StatefulWidget {
  final String? tratamientoId;
  final String? servicioId;

  /// Si `true`, la pantalla solo muestra los puntos ya registrados del paciente
  /// (sin permitir marcar/desmarcar). El botón principal pasa a "Continuar al
  /// Pago" y hace `Navigator.pop(context, 'continuar')`.
  final bool soloLectura;

  /// Puntos a precargar (modo edición con tratamiento previo cerrado, o modo
  /// lectura para re-mostrar el mapa ya guardado).
  final List<InjectionPoint>? puntosIniciales;

  const FaceMapQuestionnaireScreen({
    super.key,
    this.tratamientoId,
    this.servicioId,
    this.soloLectura = false,
    this.puntosIniciales,
  });

  @override
  State<FaceMapQuestionnaireScreen> createState() =>
      _FaceMapQuestionnaireScreenState();
}

class _FaceMapQuestionnaireScreenState
    extends State<FaceMapQuestionnaireScreen> {
  final TextEditingController _notasController = TextEditingController();

  late final String _effectiveTratamientoId;
  bool _isSaving = false;
  bool _showRegulatoryInfo = false;

  // Puntos predefinidos válidos (offsets por vista). Mutables durante tuning.
  final List<InjectionPoint> _predefinedPoints = _defaultInjectionPoints();

  // Zonas NO VÁLIDAS / PROHIBIDAS por vista.
  final List<ForbiddenRegion> _forbiddenRegions = _defaultForbiddenRegions();

  // Puntos actualmente seleccionados
  final List<InjectionPoint> _selectedPoints = [];

  // Registro de intentos de clic en zonas prohibidas
  final List<String> _attemptedForbiddenZones = [];

  // ── Vista rotatoria ─────────────────────────────────────────
  late final PageController _pageController;
  HeadView _currentView = HeadView.frente;

  bool get _soloLectura => widget.soloLectura;

  @override
  void initState() {
    super.initState();
    _effectiveTratamientoId = widget.tratamientoId ??
        'TRAT-INY-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    _pageController = PageController(initialPage: HeadView.frente.index);
    if (widget.puntosIniciales != null && widget.puntosIniciales!.isNotEmpty) {
      _selectedPoints.addAll(widget.puntosIniciales!);
    }
  }

  @override
  void dispose() {
    _notasController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _goToView(HeadView view) {
    final index = HeadView.values.indexOf(view);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
    setState(() => _currentView = view);
  }

  void _handleSilhouetteTap(
    TapDownDetails details,
    HeadView view,
    BoxConstraints constraints,
  ) {
    if (_soloLectura) return;

    final dx = details.localPosition.dx / constraints.maxWidth;
    final dy = details.localPosition.dy / constraints.maxHeight;
    final tappedOffset = Offset(dx, dy);

    // 1. Verificar si el clic cayó dentro de una zona prohibida / no válida
    for (final region in _forbiddenRegions) {
      final bounds = region.boundsFor(view);
      if (bounds != null && bounds.contains(tappedOffset)) {
        _showForbiddenZoneWarning(region);
        return;
      }
    }

    // 2. Verificar si el clic estuvo cerca de un punto predefinido (distancia < 0.07)
    for (final point in _predefinedPoints) {
      final off = point.offsetFor(view);
      if (off == null) continue;
      if ((off - tappedOffset).distance < 0.07) {
        _togglePoint(point);
        return;
      }
    }

    // 3. Si se hizo clic en una zona válida del rostro o cuello, agregar punto personalizado
    if (dy >= 0.12 && dy <= 0.92 && dx >= 0.20 && dx <= 0.80) {
      final customPoint = InjectionPoint(
        id: 'custom_${DateTime.now().millisecondsSinceEpoch}_${view.name}',
        label:
            'Punto Marcado (${(dx * 100).toStringAsFixed(0)}%, ${(dy * 100).toStringAsFixed(0)}%)',
        offsets: {view: tappedOffset},
        isCustom: true,
      );
      setState(() {
        _selectedPoints.add(customPoint);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Punto de inyección marcado en (${(dx * 100).toStringAsFixed(0)}%, ${(dy * 100).toStringAsFixed(0)}%)'),
          duration: const Duration(seconds: 1),
          backgroundColor: AppTheme.cDeepAccent,
        ),
      );
    }
  }

  void _togglePoint(InjectionPoint point) {
    if (_soloLectura) return;
    setState(() {
      final existingIndex = _selectedPoints.indexWhere((p) => p.id == point.id);
      if (existingIndex >= 0) {
        _selectedPoints.removeAt(existingIndex);
      } else {
        _selectedPoints.add(point);
      }
    });
  }

  void _showForbiddenZoneWarning(ForbiddenRegion region) {
    if (!_attemptedForbiddenZones.contains(region.title)) {
      _attemptedForbiddenZones.add(region.title);
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
                      region.title,
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
              region.reason,
              style: const TextStyle(
                  fontSize: 13.5, height: 1.4, color: AppTheme.cDarkText),
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
          content: Text('Por favor selecciona al menos un punto de inyección en la cabeza.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    // Una fila por (punto × vista) con coordenadas normalizadas (0..1).
    final puntos = <Map<String, dynamic>>[
      for (final p in _selectedPoints)
        for (final entry in p.offsets.entries)
          {
            'zona_anatomica': p.label,
            'punto_id': p.id,
            'vista': entry.key.name,
            'coordenada_x': double.parse(entry.value.dx.toStringAsFixed(3)),
            'coordenada_y': double.parse(entry.value.dy.toStringAsFixed(3)),
          },
    ];

    try {
      final success = await SupabaseService.saveFaceMapRecord(
        profileId: profileId,
        tratamientoId: widget.tratamientoId,
        servicioId: widget.servicioId,
        puntos: puntos,
        notas: _notasController.text.trim(),
      );

      if (!mounted) return;
      setState(() => _isSaving = false);

      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'No se pudo guardar el mapeo: no se encontró el registro del paciente.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

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
            'Se han guardado correctamente ${_selectedPoints.length} puntos de inyección para el paciente.',
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cDeepAccent),
              onPressed: () {
                Navigator.of(ctx).pop();
                if (context.canPop()) {
                  context.pop('continuar');
                } else {
                  context.go('/services');
                }
              },
              child: const Text('Aceptar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
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
            _buildTopHeaderTorsoImage(),
            if (_showRegulatoryInfo) _buildRegulatoryBanner(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTreatmentBadge(),
                  if (_soloLectura) ...[
                    const SizedBox(height: 12),
                    _buildReadOnlyBanner(),
                  ],
                  const SizedBox(height: 20),
                  _buildSectionTitle(
                    title: 'Mapa Mapeable de Inyectables (Rostro & Cuello)',
                    subtitle: 'Desliza la cabeza para rotar (frente y perfiles) y haz clic para marcar los puntos de inyección. Las zonas oculares prohibidas se sombrean en rojo.',
                    icon: Icons.touch_app_rounded,
                  ),
                  const SizedBox(height: 14),
                  _buildInteractiveSilhouetteCanvas(),
                  const SizedBox(height: 16),
                  if (!_soloLectura) ...[
                    _buildQuickPointsBar(),
                    const SizedBox(height: 24),
                  ],
                  _buildSectionTitle(
                    title: 'Resumen de Puntos Marcados',
                    subtitle: 'Lista de puntos de inyección válidos seleccionados:',
                    icon: Icons.checklist_rtl_rounded,
                  ),
                  const SizedBox(height: 12),
                  _buildPointsSummaryCard(),
                  if (!_soloLectura) ...[
                    const SizedBox(height: 16),
                    _buildNotesTextField(),
                  ],
                  const SizedBox(height: 24),
                  if (_soloLectura)
                    _buildContinueButton()
                  else
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

  /// Encabezado superior usando la imagen completa "Torso_inyectables".
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
                    child: Icon(Icons.medical_services_outlined,
                        size: 70, color: Colors.white54),
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
        children: const [
          Row(
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
          SizedBox(height: 8),
          Text(
            '• Marco Federal (FDA): Inyectables aprobados únicamente en sitios específicos de rostro y cuello (y dorso de manos). Prohibición estricta en grandes volúmenes corporales (senos, glúteos).\n'
            '• Marco Estatal: Práctica médica bajo evaluación previa y supervisión de Director Médico (MD/DO). Prohibido para esteticistas.',
            style: TextStyle(color: Colors.grey, fontSize: 12.5, height: 1.4),
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

  /// Aviso en modo lectura: muestra que son los puntos ya registrados.
  Widget _buildReadOnlyBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.cPastelPurple.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.cDeepAccent.withValues(alpha: 0.25)),
      ),
      child: const Row(
        children: [
          Icon(Icons.visibility_rounded, color: AppTheme.cDeepAccent, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Estos son los puntos de inyección ya registrados para tu tratamiento en curso. No se pueden modificar en esta vista.',
              style: TextStyle(fontSize: 12.5, color: AppTheme.cDarkText, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  /// Botón de modo lectura: continúa al pago del servicio.
  Widget _buildContinueButton() {
    return SizedBox(
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
        onPressed: () => Navigator.of(context).pop('continuar'),
        icon: const Icon(Icons.payment_rounded, color: Colors.white),
        label: const Text(
          'Continuar al Pago',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
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

  /// Canvas interactivo: cabeza rotatoria en 3 vistas (Izq → Frente → Der).
  Widget _buildInteractiveSilhouetteCanvas() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _buildCanvasHeader(),
          LayoutBuilder(
            builder: (context, constraints) {
              final double canvasWidth =
                  (constraints.maxWidth * 0.5).clamp(280.0, 480.0);
              final double canvasHeight = canvasWidth; // 1:1
              final viewConstraints = BoxConstraints(
                maxWidth: canvasWidth,
                maxHeight: canvasHeight,
              );

              return Column(
                children: [
                  Center(
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
                        child: SizedBox(
                          width: canvasWidth,
                          height: canvasHeight,
                          child: PageView.builder(
                            controller: _pageController,
                            onPageChanged: (i) => setState(
                                () => _currentView = HeadView.values[i]),
                            itemCount: HeadView.values.length,
                            itemBuilder: (context, i) {
                              final view = HeadView.values[i];
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
                  ),
                  _buildViewNavigation(),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCanvasHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: AppTheme.cPastelPurple,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.ads_click_rounded, color: AppTheme.cDeepAccent, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Desliza para rotar la cabeza (frente · perfiles). Puntos rojos = Zonas Prohibidas.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.cDeepAccent),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildViewNavigation() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: _currentView != HeadView.izq
                ? () => _goToView(HeadView.values[_currentView.index - 1])
                : null,
            icon: const Icon(Icons.chevron_left_rounded, color: AppTheme.cDeepAccent),
          ),
          ...HeadView.values.map((v) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(v.label,
                      style: const TextStyle(fontSize: 11)),
                  selected: v == _currentView,
                  selectedColor: AppTheme.cDeepAccent,
                  labelStyle: TextStyle(
                    fontSize: 11,
                    color: v == _currentView ? Colors.white : AppTheme.cDarkText,
                    fontWeight: v == _currentView ? FontWeight.bold : FontWeight.normal,
                  ),
                  showCheckmark: false,
                  onSelected: (_) => _goToView(v),
                ),
              )),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: _currentView != HeadView.der
                ? () => _goToView(HeadView.values[_currentView.index + 1])
                : null,
            icon: const Icon(Icons.chevron_right_rounded, color: AppTheme.cDeepAccent),
          ),
        ],
      ),
    );
  }

  /// Página individual de una vista: imagen + zonas prohibidas + marcadores.
  Widget _buildHeadViewPage(
    HeadView view,
    double canvasWidth,
    double canvasHeight,
    BoxConstraints constraints,
  ) {
    return GestureDetector(
      onTapDown: (details) => _handleSilhouetteTap(details, view, constraints),
      child: SizedBox(
        width: canvasWidth,
        height: canvasHeight,
        child: Stack(
          children: [
            // 1. Imagen de la vista
            Positioned.fill(
              child: Container(
                color: Colors.white,
                child: Image.asset(
                  view.asset,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Icon(Icons.person_rounded, size: 90, color: Colors.grey),
                  ),
                ),
              ),
            ),
            // 2. Zonas NO VÁLIDAS / PROHIBIDAS de esta vista
            ..._forbiddenRegions.map((region) {
              final bounds = region.boundsFor(view);
              if (bounds == null) return const SizedBox.shrink();
              final bool isLowerBody = region.id == 'pecho_inferior';
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
                        borderRadius: isLowerBody ? BorderRadius.circular(8) : null,
                        border: Border.all(color: Colors.red.shade600, width: 1.5),
                        boxShadow: [
                          BoxShadow(color: Colors.red.withValues(alpha: 0.2), blurRadius: 6),
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
            // 3. Puntos predefinidos no seleccionados (marcadores + )
            ..._predefinedPoints.map((point) {
              final off = point.offsetFor(view);
              if (off == null) return const SizedBox.shrink();
              final isSelected = _selectedPoints.any((p) => p.id == point.id);
              if (isSelected) return const SizedBox.shrink();
              final px = off.dx * canvasWidth - 14;
              final py = off.dy * canvasHeight - 14;
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
                        border: Border.all(
                          color: AppTheme.cDeepAccent.withValues(alpha: 0.5),
                          width: 1.2,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.add,
                          size: 16,
                          color: AppTheme.cDeepAccent,
                        ),
                      ),
                    ),
                  ),
              );
            }),
            // 4. Puntos seleccionados (pines numerados) visibles en esta vista
            ..._selectedPoints
                .where((p) => p.offsetFor(view) != null)
                .toList()
                .asMap()
                .entries
                .map((entry) {
              final index = entry.key + 1;
              final point = entry.value;
              final off = point.offsetFor(view)!;
              final px = off.dx * canvasWidth - 16;
              final py = off.dy * canvasHeight - 16;
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
    );
  }

  /// Barra de accesos rápidos para seleccionar/desmarcar puntos predefinidos.
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
                'Puntos Marcados (${_selectedPoints.length}):',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_selectedPoints.isEmpty)
            Text(
              'No se ha marcado ningún punto. Haz clic sobre la cabeza para añadir puntos.',
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
                  onDeleted: _soloLectura ? null : () => _togglePoint(point),
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

/// Convierte las filas de `face_map_puntos` (con `punto_id`, `vista` y
/// coordenadas normalizadas) de vuelta a [InjectionPoint] para re-mostrar o
/// precargar el mapa ya guardado del paciente.
///
/// Si la fila no trae `punto_id`/`vista` (datos viejos), hace un fallback por
/// `zona_anatomica` (label) contra los puntos predefinidos.
List<InjectionPoint> reconstruirPuntosFaceMap(List<dynamic> filas) {
  final predefinidos = _defaultInjectionPoints();
  final predefinidosPorLabel = {for (final p in predefinidos) p.label: p};
  final predefinidosIds = predefinidos.map((p) => p.id).toSet();

  // Agrupar por id (formato nuevo) o por label (fallback para filas viejas).
  final grupos = <String, List<Map<String, dynamic>>>{};
  final ids = <String>[];
  for (final item in filas) {
    if (item is! Map) continue;
    final fila = Map<String, dynamic>.from(item);
    var key = (fila['punto_id'] as String?)?.trim();
    if (key == null || key.isEmpty) {
      final label = (fila['zona_anatomica'] as String?)?.trim() ?? '';
      key = predefinidosPorLabel[label]?.id ?? 'custom_$label';
    }
    if (!grupos.containsKey(key)) ids.add(key);
    grupos.putIfAbsent(key, () => []).add(fila);
  }

  final result = <InjectionPoint>[];
  for (final id in ids) {
    final rows = grupos[id]!;
    final first = rows.first;
    final label = (first['zona_anatomica'] as String?)?.trim() ?? 'Punto marcado';

    // Punto predefinido: se conservan sus offsets conocidos por vista.
    InjectionPoint? predef;
    for (final p in predefinidos) {
      if (p.id == id) {
        predef = p;
        break;
      }
    }
    if (predef != null) {
      result.add(predef);
      continue;
    }

    // Punto custom: reconstruir offsets por vista desde las coordenadas.
    final offsets = <HeadView, Offset>{};
    for (final fila in rows) {
      HeadView? vista;
      for (final v in HeadView.values) {
        if (v.name == fila['vista']) {
          vista = v;
          break;
        }
      }
      if (vista == null) continue;
      final x = (fila['coordenada_x'] as num?)?.toDouble();
      final y = (fila['coordenada_y'] as num?)?.toDouble();
      if (x == null || y == null) continue;
      offsets[vista] = Offset(x, y);
    }
    if (offsets.isEmpty) continue;
    result.add(
      InjectionPoint(
        id: id,
        label: label,
        offsets: offsets,
        isCustom: !predefinidosIds.contains(id),
      ),
    );
  }
  return result;
}