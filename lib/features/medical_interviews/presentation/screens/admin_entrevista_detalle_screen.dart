import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:esteticaybellezastrani/app/config/app_routes.dart';
import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import 'package:esteticaybellezastrani/features/admin_users/domain/entities/paciente_admin_entity.dart';
import 'package:esteticaybellezastrani/features/patients_compliance/presentation/widgets/advertencia_expediente_dialog.dart';
import '../../domain/entities/entrevista_medica_entity.dart';
import '../cubits/entrevistas_cubit.dart';
import '../widgets/dictamen_dialog.dart';
import '../widgets/jitsi_meet_view.dart';

/// Detalle admin de una entrevista médica F2F: datos, evaluación aplicada,
/// videollamada embebida, notas/hallazgos, grabación y dictamen del examen
/// médico total.
class AdminEntrevistaDetalleScreen extends StatefulWidget {
  final EntrevistaMedicaEntity entrevista;
  const AdminEntrevistaDetalleScreen({super.key, required this.entrevista});

  @override
  State<AdminEntrevistaDetalleScreen> createState() =>
      _AdminEntrevistaDetalleScreenState();
}

class _AdminEntrevistaDetalleScreenState
    extends State<AdminEntrevistaDetalleScreen> {
  late final TextEditingController _notasCtrl =
      TextEditingController(text: widget.entrevista.notasClinicas ?? '');
  late final TextEditingController _hallazgosCtrl =
      TextEditingController(text: widget.entrevista.hallazgos ?? '');
  bool _guardandoNotas = false;
  bool _subiendoGrabacion = false;

  @override
  void dispose() {
    _notasCtrl.dispose();
    _hallazgosCtrl.dispose();
    super.dispose();
  }

  EntrevistaMedicaEntity _actual() =>
      context.read<EntrevistasCubit>().porId(widget.entrevista.id) ??
      widget.entrevista;

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppTheme.cError : null,
      ),
    );
  }

  Future<void> _iniciar(EntrevistaMedicaEntity e) async {
    final error = await context.read<EntrevistasCubit>().iniciar(e.id);
    if (error != null) {
      _snack(error, error: true);
    } else {
      _snack('Entrevista iniciada.');
    }
  }

  Future<void> _guardarNotas(EntrevistaMedicaEntity e) async {
    setState(() => _guardandoNotas = true);
    final error = await context.read<EntrevistasCubit>().guardarNotas(
          entrevistaId: e.id,
          notasClinicas: _notasCtrl.text.trim(),
          hallazgos: _hallazgosCtrl.text.trim().isEmpty
              ? null
              : _hallazgosCtrl.text.trim(),
        );
    if (!mounted) return;
    setState(() => _guardandoNotas = false);
    _snack(error ?? 'Notas guardadas.', error: error != null);
  }

  Future<void> _adjuntarGrabacion(EntrevistaMedicaEntity e) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.video,
    );
    final picked = result?.files.single;
    if (picked == null || picked.bytes == null || !mounted) return;
    setState(() => _subiendoGrabacion = true);
    final error = await context.read<EntrevistasCubit>().adjuntarGrabacion(
          entrevistaId: e.id,
          bytes: Uint8List.fromList(picked.bytes!),
          extension: picked.extension ?? 'webm',
        );
    if (!mounted) return;
    setState(() => _subiendoGrabacion = false);
    _snack(error ?? 'Grabación adjuntada.', error: error != null);
  }

  Future<void> _emitirDictamen(EntrevistaMedicaEntity e) async {
    final res = await mostrarDictamenDialog(
      context,
      hallazgosIniciales: e.hallazgos,
    );
    if (res == null || !mounted) return;
    final error = await context.read<EntrevistasCubit>().emitirDictamen(
          entrevistaId: e.id,
          aprobado: res.aprobado,
          observaciones: res.observaciones,
          hallazgos: res.hallazgos,
        );
    _snack(error ?? 'Dictamen emitido. El examen médico quedó actualizado.',
        error: error != null);
  }

  Future<void> _verAdjunto(String? path) async {
    if (path == null || path.isEmpty) {
      _snack('No hay archivo adjunto.');
      return;
    }
    final url = await context.read<EntrevistasCubit>().firmarUrl(path);
    if (url == null) {
      _snack('No se pudo generar el enlace.', error: true);
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      _snack('No se pudo abrir el archivo.', error: true);
    }
  }

  Future<void> _abrirExpediente(EntrevistaMedicaEntity e) async {
    final usuarioId = e.pacienteUsuarioId;
    if (usuarioId == null) {
      _snack('No se pudo identificar al paciente.', error: true);
      return;
    }
    if (!await confirmarAccesoExpediente(context)) return;
    if (!mounted) return;
    context.push(
      AppRoutes.adminExpedienteSaludPaciente,
      extra: PacienteAdminEntity(
        id: e.pacienteId,
        usuarioId: usuarioId,
        activo: true,
        fullName: e.pacienteNombre,
        email: e.pacienteEmail,
        profileActivo: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Entrevista médica')),
      body: BlocListener<EntrevistasCubit, EntrevistasState>(
        listener: (context, state) {
          if (state is EntrevistasError) {
            _snack(state.message, error: true);
          }
        },
        child: BlocBuilder<EntrevistasCubit, EntrevistasState>(
          builder: (context, _) {
            final e = _actual();
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _seccion('Datos de la entrevista', [
                  _fila('Paciente', e.pacienteNombre ?? 'Paciente'),
                  if (e.pacienteEmail != null) _fila('Correo', e.pacienteEmail!),
                  _fila('Fecha y hora', _fmtFechaHora(e.fechaProgramada)),
                  _fila('Duración', '${e.duracionMin} minutos'),
                  _fila('Estado', e.estado.toDb().replaceAll('_', ' ')),
                  _fila('Sala', e.salaId),
                ]),
                const SizedBox(height: 12),
                _seccion('Evaluación médica aplicada', [
                  const Text(
                    'El dictamen corresponde al examen médico total '
                    '(evaluación aplicada + entrevista). Revisa el expediente '
                    'de salud antes de dictaminar.',
                    style: TextStyle(fontSize: 12, color: AppTheme.cMutedText),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _abrirExpediente(e),
                    icon: const Icon(Icons.folder_shared_rounded, size: 18),
                    label: const Text('Ver expediente de salud'),
                  ),
                ]),
                const SizedBox(height: 12),
                _cardVideollamada(e),
                const SizedBox(height: 12),
                _cardNotas(e),
                const SizedBox(height: 12),
                _cardGrabacion(e),
                const SizedBox(height: 12),
                _cardDictamen(e),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _cardVideollamada(EntrevistaMedicaEntity e) {
    final cerrada = e.cerrada;
    final salaUrl = 'https://meet.jit.si/${e.salaId}';
    return _seccion('Videollamada (Jitsi)', [
      if (cerrada)
        Text('La entrevista está ${e.estado.toDb().toLowerCase()}.',
            style: const TextStyle(fontSize: 13, color: AppTheme.cMutedText))
      else ...[
        if (e.estado == EstadoEntrevista.programada)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.cDeepAccent),
              onPressed: () => _iniciar(e),
              icon: const Icon(Icons.play_circle_outline_rounded),
              label: const Text('Iniciar entrevista'),
            ),
          ),
        const SizedBox(height: 12),
        SizedBox(
          height: 420,
          child: buildJitsiMeetView(salaUrl: salaUrl),
        ),
        const SizedBox(height: 8),
        const Text(
          'Aviso: se usa Jitsi público. No es apto para ePHI real (sin BAA); '
          'la grabación se adjunta manualmente y se guarda en el bucket privado.',
          style: TextStyle(fontSize: 11, color: AppTheme.cGoldAccent),
        ),
      ],
    ]);
  }

  Widget _cardNotas(EntrevistaMedicaEntity e) {
    final editable = !e.cerrada;
    return _seccion('Notas clínicas y hallazgos', [
      TextField(
        controller: _notasCtrl,
        enabled: editable,
        maxLines: 4,
        decoration: AppTheme.fieldDecoration(
          label: 'Notas clínicas',
          hint: 'Anamnesis, observaciones de la entrevista',
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _hallazgosCtrl,
        enabled: editable,
        maxLines: 3,
        decoration: AppTheme.fieldDecoration(
          label: 'Hallazgos',
          hint: 'Hallazgos relevantes de la entrevista',
        ),
      ),
      if (editable) ...[
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: _guardandoNotas ? null : () => _guardarNotas(e),
            icon: _guardandoNotas
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined, size: 18),
            label: const Text('Guardar notas'),
          ),
        ),
      ],
    ]);
  }

  Widget _cardGrabacion(EntrevistaMedicaEntity e) {
    final tiene = e.grabacionUrl != null && e.grabacionUrl!.isNotEmpty;
    return _seccion('Grabación', [
      Text(
        tiene
            ? 'Grabación adjunta.'
            : 'Adjunta la grabación de la entrevista (video subido al bucket privado).',
        style: const TextStyle(fontSize: 13, color: AppTheme.cMutedText),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: (e.cerrada || _subiendoGrabacion)
                  ? null
                  : () => _adjuntarGrabacion(e),
              icon: _subiendoGrabacion
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.video_file_outlined, size: 18),
              label: Text(tiene ? 'Reemplazar' : 'Adjuntar grabación'),
            ),
          ),
          if (tiene) ...[
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Ver grabación',
              onPressed: () => _verAdjunto(e.grabacionUrl),
              icon: const Icon(Icons.visibility_outlined),
            ),
          ],
        ],
      ),
    ]);
  }

  Widget _cardDictamen(EntrevistaMedicaEntity e) {
    if (e.emitida) {
      final apto = e.dictamen == DictamenEntrevista.apto;
      final color = apto ? AppTheme.cBrandGreen : AppTheme.cError;
      return _seccion('Dictamen emitido', [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(apto ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      color: color, size: 20),
                  const SizedBox(width: 8),
                  Text(e.dictamen!.toDb(),
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: color)),
                ],
              ),
              if (e.dictamenObservaciones != null) ...[
                const SizedBox(height: 8),
                Text(e.dictamenObservaciones!,
                    style: const TextStyle(fontSize: 13)),
              ],
              if (e.finalizadaAt != null) ...[
                const SizedBox(height: 6),
                Text('Emitido el ${_fmtFechaHora(e.finalizadaAt!)}',
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.cMutedText)),
              ],
            ],
          ),
        ),
      ]);
    }
    return _seccion('Dictamen del examen médico', [
      const Text(
        'Al emitir el dictamen se cierra la entrevista y se actualiza el '
        'estado médico del paciente (habilita reservas si es APTO).',
        style: TextStyle(fontSize: 12, color: AppTheme.cMutedText),
      ),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppTheme.cDeepAccent),
          onPressed: (e.estado == EstadoEntrevista.enCurso)
              ? () => _emitirDictamen(e)
              : null,
          icon: const Icon(Icons.gavel_rounded),
          label: Text(e.estado == EstadoEntrevista.enCurso
              ? 'Emitir dictamen'
              : 'Inicia la entrevista para dictaminar'),
        ),
      ),
    ]);
  }

  Widget _seccion(String titulo, List<Widget> contenido) {
    return Card(
      elevation: 0,
      color: AppTheme.cSurface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        side: const BorderSide(color: Colors.black12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.cDeepAccent)),
            const SizedBox(height: 12),
            ...contenido,
          ],
        ),
      ),
    );
  }

  Widget _fila(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.cMutedText)),
          ),
          Expanded(
            child: Text(valor,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.cDarkText)),
          ),
        ],
      ),
    );
  }
}

String _fmtFechaHora(DateTime dt) {
  final l = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(l.day)}/${two(l.month)}/${l.year} ${two(l.hour)}:${two(l.minute)}';
}
