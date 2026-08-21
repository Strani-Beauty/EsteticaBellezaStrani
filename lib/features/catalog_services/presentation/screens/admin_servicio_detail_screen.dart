import 'package:flutter/material.dart';

import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import 'package:esteticaybellezastrani/app/core/di/injection.dart';
import 'package:esteticaybellezastrani/features/catalog_services/domain/entities/categoria_servicio_entity.dart';
import 'package:esteticaybellezastrani/features/catalog_services/domain/entities/servicio_cuestionario_entity.dart';
import 'package:esteticaybellezastrani/features/catalog_services/domain/entities/servicio_entity.dart';
import 'package:esteticaybellezastrani/features/catalog_services/domain/usecases/get_requisitos_servicio.dart';
import 'package:esteticaybellezastrani/features/catalog_services/presentation/cubits/admin_catalog_cubit.dart';
import 'package:esteticaybellezastrani/features/patients_compliance/domain/entities/cuestionario_entity.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/entities/especialidad_entity.dart';

/// Formulario de alta/edición de un servicio: datos básicos, flags,
/// especialidades vinculadas y cuestionarios (con obligatoriedad).
class AdminServicioDetailScreen extends StatefulWidget {
  final ServicioEntity? servicio;
  const AdminServicioDetailScreen({super.key, this.servicio});

  @override
  State<AdminServicioDetailScreen> createState() =>
      _AdminServicioDetailScreenState();
}

class _AdminServicioDetailScreenState extends State<AdminServicioDetailScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nombreCtrl;
  late final TextEditingController _descripcionCtrl;
  late final TextEditingController _precioCtrl;
  late final TextEditingController _duracionCtrl;

  int? _categoriaId;
  TipoPrecio _tipoPrecio = TipoPrecio.precioFijo;
  bool _activo = true;
  bool _requiereTelemedicina = false;
  bool _requiereFaceMap = false;
  bool _requiereFotos = false;
  bool _requiereConsentimiento = false;

  final Set<int> _especialidadIds = {};
  final Map<int, bool> _cuestionariosSel = {}; // cuestionarioId -> obligatorio

  bool _cargandoRequisitos = false;
  bool _guardando = false;

  List<CategoriaServicioEntity> get _categorias {
    final state = sl<AdminCatalogCubit>().state;
    if (state is AdminCatalogLoaded) return state.categorias;
    return const [];
  }

  List<EspecialidadEntity> get _especialidades {
    final state = sl<AdminCatalogCubit>().state;
    if (state is AdminCatalogLoaded) return state.especialidades;
    return const [];
  }

  List<CuestionarioEntity> get _cuestionarios {
    final state = sl<AdminCatalogCubit>().state;
    if (state is AdminCatalogLoaded) return state.cuestionarios;
    return const [];
  }

  @override
  void initState() {
    super.initState();
    final s = widget.servicio;
    _nombreCtrl = TextEditingController(text: s?.nombre ?? '');
    _descripcionCtrl = TextEditingController(text: s?.descripcion ?? '');
    _precioCtrl = TextEditingController(
      text: s == null ? '' : s.precioBase.toString(),
    );
    _duracionCtrl = TextEditingController(
      text: s?.duracionEstimada?.toString() ?? '',
    );
    _categoriaId = s?.categoriaId;
    if (s != null) {
      _tipoPrecio = s.tipoPrecio;
      _activo = s.activo;
      _requiereTelemedicina = s.requiereTelemedicina;
      _requiereFaceMap = s.requiereFaceMap;
      _requiereFotos = s.requiereFotos;
      _requiereConsentimiento = s.requiereConsentimiento;
      _cargarRequisitos(s.id);
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    _precioCtrl.dispose();
    _duracionCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarRequisitos(String servicioId) async {
    setState(() => _cargandoRequisitos = true);
    final res = await sl<GetRequisitosServicio>()(
      GetRequisitosServicioParams(servicioId),
    );
    if (!mounted) return;
    res.fold(
      (f) {
        setState(() => _cargandoRequisitos = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudieron cargar los requisitos: ${f.message}')),
        );
      },
      (requisitos) {
        setState(() {
          _especialidadIds.addAll(requisitos.especialidadIds);
          for (final c in requisitos.cuestionarios) {
            _cuestionariosSel[c.cuestionarioId] = c.obligatorio;
          }
          _cargandoRequisitos = false;
        });
      },
    );
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    final valido = _formKey.currentState?.validate() ?? false;
    final durTrim = _duracionCtrl.text.trim();
    final durEsNumero = int.tryParse(durTrim) != null;
    if (!valido || durTrim.isEmpty || !durEsNumero) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(durTrim.isEmpty
                ? 'La duración estimada es requerida'
                : 'La duración estimada debe ser un número entero'),
          ),
        );
      }
      return;
    }

    final cubit = sl<AdminCatalogCubit>();
    setState(() => _guardando = true);

    final creado = await cubit.guardarServicio(
      id: widget.servicio?.id ?? '',
      categoriaId: _categoriaId,
      nombre: _nombreCtrl.text.trim(),
      descripcion: _descripcionCtrl.text.trim().isEmpty
          ? null
          : _descripcionCtrl.text.trim(),
      precioBase: double.parse(_precioCtrl.text.trim()),
      tipoPrecio: _tipoPrecio,
      duracionEstimada: _duracionCtrl.text.trim().isEmpty
          ? null
          : int.tryParse(_duracionCtrl.text.trim()),
      requiereTelemedicina: _requiereTelemedicina,
      requiereFaceMap: _requiereFaceMap,
      requiereFotos: _requiereFotos,
      requiereConsentimiento: _requiereConsentimiento,
      activo: _activo,
    );
    if (creado == null) {
      if (mounted) {
        setState(() => _guardando = false);
        _mostrarErrorGuardado();
      }
      return;
    }

    final servicioId = creado.id;
    final okEspecialidades = await cubit.guardarEspecialidadesServicio(
      servicioId,
      _especialidadIds.toList(),
    );

    final items = <ServicioCuestionarioEntity>[];
    var orden = 0;
    _cuestionariosSel.forEach((cuestionarioId, obligatorio) {
      items.add(ServicioCuestionarioEntity(
        cuestionarioId: cuestionarioId,
        obligatorio: obligatorio,
        orden: orden++,
      ));
    });
    final okCuestionarios =
        await cubit.guardarCuestionariosServicio(servicioId, items);

    if (!mounted) return;
    setState(() => _guardando = false);

    if (!okEspecialidades || !okCuestionarios) {
      _mostrarErrorGuardado();
      return;
    }

    Navigator.of(context).pop(creado);
  }

  /// Muestra el error del guardado guardado en el estado del cubit (si existe)
  /// o un mensaje genérico, sin cerrar la pantalla.
  void _mostrarErrorGuardado() {
    final state = sl<AdminCatalogCubit>().state;
    final mensaje = state is AdminCatalogLoaded && state.error != null
        ? state.error!
        : 'No se pudo guardar el servicio. Intenta de nuevo.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.cSurface,
      appBar: AppBar(
        title: Text(
          widget.servicio == null ? 'Nuevo servicio' : 'Editar servicio',
        ),
        centerTitle: true,
      ),
      body: _cargandoRequisitos
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.cDeepAccent),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _seccionDatosBasicos(),
                  const SizedBox(height: 20),
                  _seccionFlags(),
                  const SizedBox(height: 20),
                  _seccionEspecialidades(),
                  const SizedBox(height: 20),
                  _seccionCuestionarios(),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.cDeepAccent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _guardando ? null : _guardar,
                    icon: _guardando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_rounded),
                    label: Text(
                      _guardando ? 'Guardando...' : 'Guardar servicio',
                    ),                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _seccionDatosBasicos() {
    return Card(
      elevation: 0,
      color: AppTheme.cWhite,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        side: const BorderSide(color: Colors.black12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Datos básicos',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.cDarkText,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nombreCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre *',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              initialValue: _categoriaId,
              decoration: const InputDecoration(
                labelText: 'Categoría',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Sin categoría'),
                ),
                for (final c in _categorias)
                  DropdownMenuItem<int?>(
                    value: c.id,
                    child: Text(c.nombre),
                  ),
              ],
              onChanged: (v) => setState(() => _categoriaId = v),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descripcionCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _precioCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Precio base (\$) *',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Requerido';
                if (double.tryParse(v.trim()) == null) {
                  return 'Debe ser un número';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<TipoPrecio>(
              initialValue: _tipoPrecio,
              decoration: const InputDecoration(
                labelText: 'Tipo de precio',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final t in TipoPrecio.values)
                  DropdownMenuItem<TipoPrecio>(
                    value: t,
                    child: Text(_labelTipoPrecio(t)),
                  ),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _tipoPrecio = v);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _duracionCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Duración estimada (minutos) *',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Requerido';
                if (int.tryParse(v.trim()) == null) {
                  return 'Debe ser un número entero';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Servicio activo'),
              value: _activo,
              onChanged: (v) => setState(() => _activo = v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _seccionFlags() {
    Widget tile(String titulo, String subtitulo, bool value,
        ValueChanged<bool> onChanged) {
      return SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(titulo),
        subtitle: Text(subtitulo),
        value: value,
        activeTrackColor: AppTheme.cBrandGreen,
        onChanged: onChanged,
      );
    }

    return Card(
      elevation: 0,
      color: AppTheme.cWhite,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        side: const BorderSide(color: Colors.black12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Requisitos del servicio',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.cDarkText,
              ),
            ),
            const SizedBox(height: 4),
            tile('Requiere telemedicina (RN-020)',
                'Se valida la evaluación de salud antes de la solicitud', 
                _requiereTelemedicina,
                (v) => setState(() => _requiereTelemedicina = v)),
            tile('Requiere face map',
                'Solicita el cuestionario facial de puntos',
                _requiereFaceMap,
                (v) => setState(() => _requiereFaceMap = v)),
            tile('Requiere fotos',
                'Informa sobre la necesidad de fotografías',
                _requiereFotos,
                (v) => setState(() => _requiereFotos = v)),
            tile('Requiere consentimiento',
                'Informa sobre la firma de consentimiento',
                _requiereConsentimiento,
                (v) => setState(() => _requiereConsentimiento = v)),
          ],
        ),
      ),
    );
  }

  Widget _seccionEspecialidades() {
    return Card(
      elevation: 0,
      color: AppTheme.cWhite,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        side: const BorderSide(color: Colors.black12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Especialidades que pueden atender este servicio',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.cDarkText,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Dejar vacío = visible para todos los especialistas',
              style: TextStyle(color: AppTheme.cMutedText, fontSize: 12),
            ),
            const SizedBox(height: 12),
            if (_especialidades.isEmpty)
              const Text('No hay especialidades registradas.')
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in _especialidades)
                    FilterChip(
                      label: Text(e.nombre),
                      selected: _especialidadIds.contains(e.id),
                      onSelected: (sel) => setState(() {
                        if (sel) {
                          _especialidadIds.add(e.id);
                        } else {
                          _especialidadIds.remove(e.id);
                        }
                      }),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _seccionCuestionarios() {
    return Card(
      elevation: 0,
      color: AppTheme.cWhite,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        side: const BorderSide(color: Colors.black12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cuestionarios de salud vinculados',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.cDarkText,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Si son obligatorios, el paciente debe aprobarlos antes de la solicitud',
              style: TextStyle(color: AppTheme.cMutedText, fontSize: 12),
            ),
            const SizedBox(height: 12),
            if (_cuestionarios.isEmpty)
              const Text('No hay cuestionarios registrados.')
            else
              for (final c in _cuestionarios) ...[
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(c.nombre),
                  subtitle: Text('v${c.version}'),
                  value: _cuestionariosSel.containsKey(c.id),
                  onChanged: (sel) => setState(() {
                    if (sel == true) {
                      _cuestionariosSel[c.id] = false;
                    } else {
                      _cuestionariosSel.remove(c.id);
                    }
                  }),
                ),
                if (_cuestionariosSel.containsKey(c.id))
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Obligatorio'),
                    value: _cuestionariosSel[c.id] ?? false,
                    activeTrackColor: AppTheme.cBrandGreen,
                    onChanged: (v) => setState(() => _cuestionariosSel[c.id] = v),
                  ),
              ],
          ],
        ),
      ),
    );
  }

  String _labelTipoPrecio(TipoPrecio tipo) {
    switch (tipo) {
      case TipoPrecio.precioFijo:
        return 'Precio fijo';
      case TipoPrecio.porUnidad:
        return 'Por unidad';
      case TipoPrecio.porJeringa:
        return 'Por jeringa';
      case TipoPrecio.porSesion:
        return 'Por sesión';
      case TipoPrecio.porPlan:
        return 'Por plan';
    }
  }
}