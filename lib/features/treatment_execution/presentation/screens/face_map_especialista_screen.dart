import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/config/app_constants.dart';
import '../../../../app/config/app_theme.dart';
import '../../../patients_compliance/presentation/screens/face_map_questionnaire_screen.dart';
import '../../domain/entities/face_map_especialista_entity.dart';
import '../../domain/entities/producto_aplicado_entity.dart';
import '../cubits/treatment_execution_cubit.dart';
import '../widgets/face_map_canvas.dart';

/// Face map del especialista durante la ejecución del tratamiento.
/// Parte del Face Map pre-cargado del paciente (si existe) y permite asignar a
/// cada punto el producto aplicado, la cantidad (con la unidad del
/// producto/servicio) y una nota por punto. Guarda vinculado al tratamiento
/// (upsert en face_maps / face_map_puntos).
class FaceMapEspecialistaScreen extends StatefulWidget {
  final String tratamientoId;

  const FaceMapEspecialistaScreen({super.key, required this.tratamientoId});

  @override
  State<FaceMapEspecialistaScreen> createState() =>
      _FaceMapEspecialistaScreenState();
}

/// Datos de producto aplicado asociados a un punto del face map.
class _DatoPunto {
  String? productoId;
  String? productoNombre;
  double? cantidad;
  String? unidadMedida;
  String? observaciones;

  bool get tieneProducto => productoId != null && productoId!.isNotEmpty;
}

/// Resultado del panel de producto por punto.
class _ResultadoPunto {
  final bool quitar;
  final _DatoPunto? dato;

  const _ResultadoPunto({this.quitar = false, this.dato});
}

class _FaceMapEspecialistaScreenState extends State<FaceMapEspecialistaScreen> {
  final TextEditingController _notasController = TextEditingController();
  final List<InjectionPoint> _predefinedPoints = _defaultInjectionPoints();
  final List<ForbiddenRegion> _forbiddenRegions = _defaultForbiddenRegions();
  final List<InjectionPoint> _selectedPoints = [];
  final Map<String, _DatoPunto> _datosPorPunto = {};
  final List<String> _attemptedForbiddenZones = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context
          .read<TreatmentExecutionCubit>()
          .loadFaceMap(tratamientoId: widget.tratamientoId);
    });
  }

  @override
  void dispose() {
    _notasController.dispose();
    super.dispose();
  }

  void _togglePoint(InjectionPoint point) {
    setState(() {
      final exists = _selectedPoints.any((p) => p.id == point.id);
      if (exists) {
        _selectedPoints.removeWhere((p) => p.id == point.id);
        _datosPorPunto.remove(point.id);
      } else {
        _selectedPoints.add(point);
      }
    });
  }

  void _onCanvasTogglePunto(InjectionPoint point) {
    if (_selectedPoints.any((p) => p.id == point.id)) {
      _abrirPanelProducto(point);
    } else {
      setState(() => _selectedPoints.add(point));
    }
  }

  void _onCustomPunto(InjectionPoint point) {
    setState(() => _selectedPoints.add(point));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Punto de inyección marcado en ${point.label}.'),
        backgroundColor: AppTheme.cDeepAccent,
      ),
    );
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
    if (puntos.isNotEmpty) {
      _selectedPoints.addAll(puntos);
      _parsearDatosPuntos(faceMap.puntos);
    }
    if (faceMap.observaciones != null && faceMap.observaciones!.isNotEmpty) {
      _notasController.text = faceMap.observaciones!;
    }
  }

  void _parsearDatosPuntos(List<Map<String, dynamic>> filas) {
    for (final fila in filas) {
      final id = fila['punto_id'] as String?;
      if (id == null || id.isEmpty) continue;
      final dato = _datosPorPunto.putIfAbsent(id, _DatoPunto.new);
      if (!dato.tieneProducto) {
        final prodId = fila['producto_id'];
        if (prodId is String && prodId.isNotEmpty) {
          dato.productoId = prodId;
          final emb = fila['productos_aplicados'];
          dato.productoNombre = emb is Map<String, dynamic>
              ? emb['producto_nombre'] as String?
              : null;
        }
      }
      final cantidad = fila['cantidad'];
      if (dato.cantidad == null && cantidad is num) {
        dato.cantidad = cantidad.toDouble();
      }
      final unidad = fila['unidad_medida'];
      if (unidad is String &&
          unidad.trim().isNotEmpty &&
          (dato.unidadMedida == null || dato.unidadMedida!.isEmpty)) {
        dato.unidadMedida = unidad;
      }
      final obs = fila['observaciones'];
      if (obs is String &&
          obs.trim().isNotEmpty &&
          (dato.observaciones == null || dato.observaciones!.isEmpty)) {
        dato.observaciones = obs;
      }
    }
  }

  String? _unidadSugerida(String? tipoPrecio) {
    switch (tipoPrecio) {
      case AppConstants.precioPorUnidad:
        return 'unidades';
      case AppConstants.precioPorJeringa:
        return 'jeringas';
      case AppConstants.precioPorSesion:
        return 'sesiones';
      case AppConstants.precioPorPlan:
        return 'plan';
      default:
        return null;
    }
  }

  Future<void> _abrirPanelProducto(InjectionPoint point) async {
    final state = context.read<TreatmentExecutionCubit>().state;
    final productos = state is TreatmentExecutionLoaded
        ? state.productos
        : const <ProductoAplicadoEntity>[];
    final tipoPrecio =
        state is TreatmentExecutionLoaded ? state.cita?.tipoPrecio : null;
    final resultado = await showModalBottomSheet<_ResultadoPunto>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _PanelProductoPunto(
        punto: point,
        productos: productos,
        tratamientoId: widget.tratamientoId,
        unidadSugerida: _unidadSugerida(tipoPrecio),
        datoInicial: _datosPorPunto[point.id] ?? _DatoPunto(),
        cubit: context.read<TreatmentExecutionCubit>(),
      ),
    );
    if (resultado == null || !mounted) return;
    setState(() {
      if (resultado.quitar) {
        _selectedPoints.removeWhere((p) => p.id == point.id);
        _datosPorPunto.remove(point.id);
      } else if (resultado.dato != null) {
        _datosPorPunto[point.id] = resultado.dato!;
      }
    });
  }

  Widget? _badgePunto(InjectionPoint point) {
    final dato = _datosPorPunto[point.id];
    if (dato == null || !dato.tieneProducto) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: Colors.orange.shade100,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.orange.shade300),
        ),
        child: const Text(
          'sin producto',
          style: TextStyle(fontSize: 8, color: Colors.black87),
        ),
      );
    }
    final partes = <String>[
      if ((dato.cantidad ?? 0) > 0) _fmtCantidad(dato.cantidad!),
      if (dato.unidadMedida != null && dato.unidadMedida!.trim().isNotEmpty)
        dato.unidadMedida!.trim(),
    ];
    if (partes.isEmpty) return null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: AppTheme.cDeepAccent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        partes.join(' '),
        style: const TextStyle(fontSize: 8, color: Colors.white),
      ),
    );
  }

  String _fmtCantidad(double v) {
    final s = v.toStringAsFixed(2);
    return s.replaceFirst(RegExp(r'\.?0+$'), '');
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
            'producto_id': ?_datosPorPunto[p.id]?.productoId,
            'cantidad': ?_datosPorPunto[p.id]?.cantidad,
            'unidad_medida': ?_datosPorPunto[p.id]?.unidadMedida,
            'observaciones': ?_datosPorPunto[p.id]?.observaciones,
          },
    ];
    final cubit = context.read<TreatmentExecutionCubit>();
    final state = cubit.state;
    final pacienteId = state is TreatmentExecutionLoaded
        ? (state.cita?.tratamiento?.pacienteId ?? state.faceMap?.pacienteId)
        : null;
    if (pacienteId == null || pacienteId.isEmpty) {
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
                  subtitle: 'Desliza la cabeza para rotar (frente y perfiles) '
                      'y toca para marcar los puntos de aplicación. Toca un '
                      'punto marcado para asignar producto y cantidad. Las '
                      'zonas oculares prohibidas se sombrean en rojo.',
                  icon: Icons.touch_app_rounded,
                ),
                const SizedBox(height: 12),
                FaceMapCanvas(
                  puntos: _predefinedPoints,
                  zonasProhibidas: _forbiddenRegions,
                  seleccionados: _selectedPoints,
                  onTogglePunto: _onCanvasTogglePunto,
                  onCustomPunto: _onCustomPunto,
                  onZonaProhibida: _showForbiddenZoneWarning,
                  buildBadge: _badgePunto,
                ),
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
                final dato = _datosPorPunto[point.id];
                final detalle = dato != null && dato.tieneProducto
                    ? ' · ${_fmtCantidad(dato.cantidad ?? 0)} '
                        '${dato.unidadMedida ?? ''}'.trim()
                    : '';
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
                    '${point.label}$detalle',
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
          const SizedBox(height: 8),
          const Text(
            'Toca un punto sobre el rostro para asignar el producto aplicado, '
            'la cantidad y una nota.',
            style: TextStyle(fontSize: 11, color: Colors.grey),
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

/// Panel de asignación de producto, cantidad y nota a un punto del face map.
/// Permite elegir un insumo ya registrado del tratamiento o crear uno nuevo
/// (que se inserta en `productos_aplicados`) y asignarlo al punto.
class _PanelProductoPunto extends StatefulWidget {
  final InjectionPoint punto;
  final List<ProductoAplicadoEntity> productos;
  final String tratamientoId;
  final String? unidadSugerida;
  final _DatoPunto datoInicial;
  final TreatmentExecutionCubit cubit;

  const _PanelProductoPunto({
    required this.punto,
    required this.productos,
    required this.tratamientoId,
    required this.unidadSugerida,
    required this.datoInicial,
    required this.cubit,
  });

  @override
  State<_PanelProductoPunto> createState() => _PanelProductoPuntoState();
}

class _PanelProductoPuntoState extends State<_PanelProductoPunto> {
  bool _creando = false;
  bool _guardando = false;
  String? _productoId;
  String? _productoNombre;

  late final TextEditingController _cantidadController;
  late final TextEditingController _unidadController;
  late final TextEditingController _notaController;
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _cantidadTotalController = TextEditingController();
  final TextEditingController _unidadCrearController = TextEditingController();
  final TextEditingController _loteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _productoId = widget.datoInicial.productoId;
    _productoNombre = widget.datoInicial.productoNombre;
    _cantidadController = TextEditingController(
      text: (widget.datoInicial.cantidad ?? 1.0).toStringAsFixed(2),
    );
    _unidadController = TextEditingController(
      text: widget.datoInicial.unidadMedida ?? '',
    );
    _notaController = TextEditingController(
      text: widget.datoInicial.observaciones ?? '',
    );
    _cantidadTotalController.text = '1.0';
    _unidadCrearController.text = widget.unidadSugerida ?? 'unidades';
  }

  @override
  void dispose() {
    _cantidadController.dispose();
    _unidadController.dispose();
    _notaController.dispose();
    _nombreController.dispose();
    _cantidadTotalController.dispose();
    _unidadCrearController.dispose();
    _loteController.dispose();
    super.dispose();
  }

  double _parseCantidad(TextEditingController controller) {
    final v = double.tryParse(controller.text.trim().replaceAll(',', '.'));
    return (v ?? 0) > 0 ? v! : 1.0;
  }

  Future<void> _guardar() async {
    if (_creando) {
      final nombre = _nombreController.text.trim();
      if (nombre.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Indica el nombre del insumo.')),
        );
        return;
      }
      setState(() => _guardando = true);
      final cantidadTotal = _parseCantidad(_cantidadTotalController);
      final unidadCrear = _unidadCrearController.text.trim();
      final lote = _loteController.text.trim();
      await widget.cubit.agregarProducto(
        tratamientoId: widget.tratamientoId,
        productoNombre: nombre,
        cantidadTotal: cantidadTotal,
        unidadMedida: unidadCrear.isEmpty ? null : unidadCrear,
        lote: lote.isEmpty ? null : lote,
      );
      final st = widget.cubit.state;
      if (st is TreatmentExecutionLoaded) {
        final coincidentes =
            st.productos.where((p) => p.productoNombre == nombre);
        if (coincidentes.isNotEmpty) {
          _productoId = coincidentes.last.id;
          _productoNombre = coincidentes.last.productoNombre;
          if (_unidadController.text.trim().isEmpty) {
            _unidadController.text =
                coincidentes.last.unidadMedida ?? unidadCrear;
          }
        }
      }
    }
      if (!mounted) return;
      if (_productoId == null || _productoId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Asigna un producto aplicado al punto.'),
        ),
      );
      return;
    }
    final unidadPunto = _unidadController.text.trim();
    final nota = _notaController.text.trim();
    final dato = _DatoPunto()
      ..productoId = _productoId
      ..productoNombre = _productoNombre
      ..cantidad = _parseCantidad(_cantidadController)
      ..unidadMedida = unidadPunto.isEmpty ? null : unidadPunto
      ..observaciones = nota.isEmpty ? null : nota;
    if (mounted) Navigator.of(context).pop(_ResultadoPunto(dato: dato));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.science_outlined,
                      color: AppTheme.cDeepAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Producto aplicado · ${widget.punto.label}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Elegir insumo'),
                      selected: !_creando,
                      selectedColor: AppTheme.cDeepAccent,
                      labelStyle: TextStyle(
                        color: !_creando ? Colors.white : null,
                        fontSize: 12,
                      ),
                      onSelected: (_) => setState(() => _creando = false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Crear insumo'),
                      selected: _creando,
                      selectedColor: AppTheme.cDeepAccent,
                      labelStyle: TextStyle(
                        color: _creando ? Colors.white : null,
                        fontSize: 12,
                      ),
                      onSelected: (_) => setState(() => _creando = true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (!_creando)
                DropdownButtonFormField<String>(
                  initialValue: _productoId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Insumo aplicado',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: widget.productos
                      .map(
                        (p) => DropdownMenuItem<String>(
                          value: p.id,
                          child: Text(
                            '${p.productoNombre}'
                            '${p.unidadMedida != null ? ' (${p.unidadMedida})' : ''}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    final coincidentes =
                        widget.productos.where((prod) => prod.id == v).toList();
                    final p = coincidentes.isNotEmpty ? coincidentes.first : null;
                    setState(() {
                      _productoId = v;
                      _productoNombre = p?.productoNombre;
                      if (p?.unidadMedida != null &&
                          _unidadController.text.trim().isEmpty) {
                        _unidadController.text = p!.unidadMedida!;
                      }
                    });
                  },
                )
              else ...[
                TextField(
                  controller: _nombreController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del insumo *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _cantidadTotalController,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Cantidad total',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _unidadCrearController,
                        decoration: const InputDecoration(
                          labelText: 'Unidad',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _loteController,
                  decoration: const InputDecoration(
                    labelText: 'Lote (opcional)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                if (_productoId != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Insumo asignado: $_productoNombre',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.cDeepAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _cantidadController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Cantidad aplicada',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _unidadController,
                      decoration: const InputDecoration(
                        labelText: 'Unidad',
                        hintText: 'ml · unidades · jeringas',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _notaController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Nota del punto (opcional)',
                  hintText: 'Ej: inyección profunda, 0.5 ml aplicado.',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _guardando
                        ? null
                        : () => Navigator.of(context)
                            .pop(const _ResultadoPunto(quitar: true)),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Quitar punto'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _guardando ? null : _guardar,
                    icon: _guardando
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check),
                    label: Text(_guardando ? 'Guardando...' : 'Aplicar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.cDeepAccent,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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