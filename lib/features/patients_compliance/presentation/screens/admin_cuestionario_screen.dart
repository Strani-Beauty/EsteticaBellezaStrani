import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import 'package:esteticaybellezastrani/app/core/di/injection.dart';
import 'package:esteticaybellezastrani/features/patients_compliance/domain/entities/cuestionario_entity.dart';
import 'package:esteticaybellezastrani/features/patients_compliance/presentation/cubits/admin_cuestionario_cubit.dart';

/// Gestión mínima del cuestionario de salud (requisitos 3-5 y 14):
/// ver versión activa e histórico, crear nueva versión, activar versión y
/// editar preguntas del catálogo.
class AdminCuestionarioScreen extends StatelessWidget {
  const AdminCuestionarioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AdminCuestionarioCubit>.value(
      value: sl<AdminCuestionarioCubit>(),
      child: const _AdminCuestionarioView(),
    );
  }
}

class _AdminCuestionarioView extends StatefulWidget {
  const _AdminCuestionarioView();

  @override
  State<_AdminCuestionarioView> createState() => _AdminCuestionarioViewState();
}

class _AdminCuestionarioViewState extends State<_AdminCuestionarioView> {
  @override
  void initState() {
    super.initState();
    sl<AdminCuestionarioCubit>().load();
  }

  void _mostrarFeedback(String? feedback) {
    if (feedback == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(feedback), duration: const Duration(seconds: 3)),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cuestionario de Salud'),
        centerTitle: true,
      ),
      body: BlocConsumer<AdminCuestionarioCubit, AdminCuestionarioState>(
        listener: (context, state) {
          if (state is AdminCuestionarioError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
          if (state is AdminCuestionarioLoaded) {
            _mostrarFeedback(state.feedback);
          }
        },
        builder: (context, state) {
          if (state is AdminCuestionarioLoading) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.cDeepAccent));
          }
          if (state is AdminCuestionarioError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: AppTheme.cError, size: 44),
                  const SizedBox(height: 12),
                  Text(state.message, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cDeepAccent),
                    onPressed: () => context.read<AdminCuestionarioCubit>().load(),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }
          if (state is! AdminCuestionarioLoaded) {
            return const SizedBox.shrink();
          }
          return _buildContenido(context, state);
        },
      ),
    );
  }

  Widget _buildContenido(BuildContext context, AdminCuestionarioLoaded state) {
    final cubit = context.read<AdminCuestionarioCubit>();
    final versionActiva = _buscarActiva(state.cuestionarios);
    final seleccionada = _buscarPorId(state.cuestionarios, state.versionSeleccionada);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _resumen(versionActiva),
        const SizedBox(height: 16),
        const Text('Versiones',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.cDarkText)),
        const SizedBox(height: 8),
        for (final c in state.cuestionarios)
          _VersionCard(
            cuestionario: c,
            seleccionado: c.id == state.versionSeleccionada,
            onSeleccionar: () => cubit.loadPreguntas(c.id),
          ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: seleccionada == null
                  ? null
                  : () => _confirmarCrearVersion(context, seleccionada),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Crear nueva versión'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cDeepAccent),
              onPressed: (seleccionada == null || seleccionada.activo)
                  ? null
                  : () => _confirmarActivarVersion(context, seleccionada),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Activar esta versión'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Preguntas ${seleccionada == null ? '' : '(v${seleccionada.version})'}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.cDarkText),
        ),
        const SizedBox(height: 4),
        const Text(
          'El texto de la pregunta se conserva en cada evaluación (snapshot).',
          style: TextStyle(fontSize: 12, color: AppTheme.cMutedText),
        ),
        const SizedBox(height: 12),
        if (state.preguntas.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('Selecciona una versión para ver sus preguntas.',
                style: TextStyle(color: AppTheme.cMutedText)),
          )
        else
          for (final p in state.preguntas)
            _PreguntaCard(
              pregunta: p,
              onEditar: () => _editarPregunta(context, cubit, p),
            ),
      ],
    );
  }

  Widget _resumen(CuestionarioEntity? activa) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cPastelPurple.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.cDeepAccent.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.assignment_rounded, color: AppTheme.cDeepAccent, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Cuestionario de Salud',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.cDarkText)),
                const SizedBox(height: 2),
                Text(
                  activa == null
                      ? 'Sin versión activa.'
                      : 'Versión activa: v${activa.version}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.cMutedText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmarCrearVersion(BuildContext context, CuestionarioEntity actual) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
        title: const Text('Crear nueva versión'),
        content: Text(
          'Se creará la versión v${actual.version + 1} del cuestionario '
          '"${actual.nombre}" copiando la relación de preguntas actual. '
          'La nueva versión nace inactiva; actívala cuando esté lista.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cDeepAccent),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AdminCuestionarioCubit>().crearNuevaVersion(actual.id);
            },
            child: const Text('Crear versión'),
          ),
        ],
      ),
    );
  }

  void _confirmarActivarVersion(BuildContext context, CuestionarioEntity objetivo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
        title: const Text('Activar versión'),
        content: Text(
          'La versión v${objetivo.version} quedará activa y las demás del '
          'mismo cuestionario se desactivarán. Las evaluaciones anteriores '
          'conservan su versión.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cBrandGreen),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AdminCuestionarioCubit>().activarVersion(objetivo.id);
            },
            child: const Text('Activar'),
          ),
        ],
      ),
    );
  }

  void _editarPregunta(BuildContext context, AdminCuestionarioCubit cubit, PreguntaEntity pregunta) {
    showDialog(
      context: context,
      builder: (_) => _EditarPreguntaDialog(
        pregunta: pregunta,
        onGuardar: (texto, obligatoria, opciones, riesgoJson, activo) {
          cubit.editarPregunta(
            preguntaId: pregunta.id,
            texto: texto,
            obligatoria: obligatoria,
            opciones: opciones,
            riesgo: riesgoJson,
            activo: activo,
          );
        },
      ),
    );
  }

  CuestionarioEntity? _buscarActiva(List<CuestionarioEntity> lista) {
    for (final c in lista) {
      if (c.activo) return c;
    }
    return null;
  }

  CuestionarioEntity? _buscarPorId(List<CuestionarioEntity> lista, int? id) {
    if (id == null) return null;
    for (final c in lista) {
      if (c.id == id) return c;
    }
    return null;
  }
}

class _VersionCard extends StatelessWidget {
  final CuestionarioEntity cuestionario;
  final bool seleccionado;
  final VoidCallback onSeleccionar;

  const _VersionCard({
    required this.cuestionario,
    required this.seleccionado,
    required this.onSeleccionar,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        side: BorderSide(
          color: seleccionado ? AppTheme.cDeepAccent : Colors.grey.shade200,
          width: seleccionado ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        onTap: onSeleccionar,
        leading: CircleAvatar(
          backgroundColor: AppTheme.cPastelBlue,
          child: Text('v${cuestionario.version}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cDarkText)),
        ),
        title: Text(cuestionario.nombre,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(
          'Creado: ${_fmt(cuestionario.createdAt)}',
          style: const TextStyle(fontSize: 11, color: AppTheme.cMutedText),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: (cuestionario.activo ? AppTheme.cBrandGreen : Colors.grey).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: Text(
            cuestionario.activo ? 'ACTIVA' : 'INACTIVA',
            style: TextStyle(
              color: cuestionario.activo ? AppTheme.cBrandGreen : AppTheme.cMutedText,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _PreguntaCard extends StatelessWidget {
  final PreguntaEntity pregunta;
  final VoidCallback onEditar;

  const _PreguntaCard({required this.pregunta, required this.onEditar});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    pregunta.texto,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.cDarkText),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Editar pregunta',
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  onPressed: onEditar,
                ),
              ],
            ),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _chip(pregunta.tipo.label),
                _chip(pregunta.obligatoria ? 'Obligatoria' : 'Opcional'),
                if (pregunta.riesgo != null && (pregunta.riesgo!.etiqueta.isNotEmpty))
                  _chip(
                    'Riesgo: ${pregunta.riesgo!.etiqueta}${pregunta.riesgo!.critico ? ' (crítico)' : ''}',
                    color: pregunta.riesgo!.critico ? AppTheme.cError : Colors.orange,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String texto, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (color ?? AppTheme.cDeepAccent).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        texto,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color ?? AppTheme.cDeepAccent),
      ),
    );
  }
}

class _EditarPreguntaDialog extends StatefulWidget {
  final PreguntaEntity pregunta;
  final void Function(String, bool, List<String>?, Map<String, dynamic>?, bool) onGuardar;

  const _EditarPreguntaDialog({required this.pregunta, required this.onGuardar});

  @override
  State<_EditarPreguntaDialog> createState() => _EditarPreguntaDialogState();
}

class _EditarPreguntaDialogState extends State<_EditarPreguntaDialog> {
  late final TextEditingController _textoCtrl;
  late final TextEditingController _opcionesCtrl;
  late final TextEditingController _riesgoCtrl;
  late bool _obligatoria;
  late bool _activo;

  @override
  void initState() {
    super.initState();
    _textoCtrl = TextEditingController(text: widget.pregunta.texto);
    _opcionesCtrl = TextEditingController(text: widget.pregunta.opciones.join('\n'));
    _riesgoCtrl = TextEditingController(text: _riesgoToText(widget.pregunta.riesgo));
    _obligatoria = widget.pregunta.obligatoria;
    _activo = widget.pregunta.activo;
  }

  @override
  void dispose() {
    _textoCtrl.dispose();
    _opcionesCtrl.dispose();
    _riesgoCtrl.dispose();
    super.dispose();
  }

  String _riesgoToText(RiesgoSentinel? r) {
    if (r == null) return '';
    return '{"detonante": "${r.detonante ?? ''}", "patron": "${r.patron ?? ''}", '
        '"etiqueta": "${r.etiqueta}", "critico": ${r.critico}}';
  }

  Map<String, dynamic>? _parseRiesgo(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    try {
      final decoded = jsonDecode(t);
      if (decoded is! Map) return null;
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
      title: const Text('Editar pregunta'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _textoCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Texto de la pregunta'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _opcionesCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Opciones (una por línea)',
                hintText: 'Sí\nNo',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _riesgoCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Regla de riesgo (JSON)',
                hintText: '{"detonante":"SI","etiqueta":"Alergia","critico":false}',
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Obligatoria'),
              value: _obligatoria,
              onChanged: (v) => setState(() => _obligatoria = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Activa'),
              value: _activo,
              onChanged: (v) => setState(() => _activo = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cDeepAccent),
          onPressed: () {
            final opciones = _opcionesCtrl.text
                .split('\n')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList();
            widget.onGuardar(
              _textoCtrl.text.trim(),
              _obligatoria,
              opciones.isEmpty ? null : opciones,
              _parseRiesgo(_riesgoCtrl.text),
              _activo,
            );
            Navigator.pop(context);
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}