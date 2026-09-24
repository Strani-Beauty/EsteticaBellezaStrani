import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:signature/signature.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import '../../domain/entities/entrevista_medica_entity.dart';
import '../cubits/mi_entrevista_cubit.dart';
import '../widgets/jitsi_meet_view.dart';

/// Vista del paciente: su entrevista médica F2F por videollamada, firma del
/// consentimiento y unión a la sala.
class MiEntrevistaScreen extends StatefulWidget {
  const MiEntrevistaScreen({super.key});

  @override
  State<MiEntrevistaScreen> createState() => _MiEntrevistaScreenState();
}

class _MiEntrevistaScreenState extends State<MiEntrevistaScreen> {
  bool _cargado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_cargado) {
      _cargado = true;
      context.read<MiEntrevistaCubit>().load();
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppTheme.cError : null,
      ),
    );
  }

  Future<void> _firmarConsentimiento(EntrevistaMedicaEntity e) async {
    final bytes = await showDialog<Uint8List>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _FirmaConsentimientoDialog(),
    );
    if (bytes == null || !mounted) return;
    final error = await context
        .read<MiEntrevistaCubit>()
        .registrarConsentimiento(entrevistaId: e.id, firmaBytes: bytes);
    _snack(error ?? 'Consentimiento firmado.', error: error != null);
  }

  Future<void> _verFirma(String? path) async {
    if (path == null || path.isEmpty) return;
    final url = await context.read<MiEntrevistaCubit>().firmarUrl(path);
    if (url == null) {
      _snack('No se pudo generar el enlace.', error: true);
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      _snack('No se pudo abrir la firma.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi entrevista médica')),
      body: BlocConsumer<MiEntrevistaCubit, MiEntrevistaState>(
        listener: (context, state) {
          if (state is MiEntrevistaError) {
            _snack(state.message, error: true);
          }
        },
        builder: (context, state) {
          if (state is MiEntrevistaLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is MiEntrevistaError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(state.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.cError)),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => context.read<MiEntrevistaCubit>().load(),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }
          if (state is MiEntrevistaLoaded) {
            final e = state.entrevista;
            if (e == null) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Aún no tienes una entrevista médica agendada.\n'
                    'El equipo médico te notificará cuando la programe.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.cMutedText),
                  ),
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: () => context.read<MiEntrevistaCubit>().load(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _seccion('Detalles de la cita', [
                    _fila('Fecha y hora', _fmtFechaHora(e.fechaProgramada)),
                    _fila('Duración', '${e.duracionMin} minutos'),
                    _fila('Estado', e.estado.toDb().replaceAll('_', ' ')),
                  ]),
                  const SizedBox(height: 12),
                  _cardConsentimiento(e),
                  const SizedBox(height: 12),
                  _cardVideollamada(e),
                  if (e.emitida) ...[
                    const SizedBox(height: 12),
                    _cardDictamen(e),
                  ],
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _cardConsentimiento(EntrevistaMedicaEntity e) {
    final firmado = e.consentimientoTelemedicina;
    return _seccion('Consentimiento de telemedicina', [
      Text(
        firmado
            ? 'Tu consentimiento está firmado.'
            : 'Antes de la entrevista debes firmar el consentimiento para la '
                'atención por videollamada.',
        style: const TextStyle(fontSize: 13, color: AppTheme.cMutedText),
      ),
      const SizedBox(height: 12),
      if (firmado)
        OutlinedButton.icon(
          onPressed: () => _verFirma(e.firmaConsentimientoUrl),
          icon: const Icon(Icons.visibility_outlined, size: 18),
          label: const Text('Ver firma'),
        )
      else
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.cDeepAccent),
            onPressed: () => _firmarConsentimiento(e),
            icon: const Icon(Icons.draw_outlined),
            label: const Text('Firmar consentimiento'),
          ),
        ),
    ]);
  }

  Widget _cardVideollamada(EntrevistaMedicaEntity e) {
    if (e.cerrada) {
      return _seccion('Videollamada', [
        Text('La entrevista está ${e.estado.toDb().toLowerCase()}.',
            style: const TextStyle(fontSize: 13, color: AppTheme.cMutedText)),
      ]);
    }
    if (!e.consentimientoTelemedicina) {
      return _seccion('Videollamada', [
        const Text(
          'Firma el consentimiento para habilitar el acceso a la videollamada.',
          style: TextStyle(fontSize: 13, color: AppTheme.cMutedText),
        ),
      ]);
    }
    return _seccion('Videollamada', [
      SizedBox(
        height: 420,
        child: buildJitsiMeetView(salaUrl: 'https://meet.jit.si/${e.salaId}'),
      ),
      const SizedBox(height: 8),
      const Text(
        'Si el médico aún no ha iniciado la entrevista, espera en la sala.',
        style: TextStyle(fontSize: 11, color: AppTheme.cMutedText),
      ),
    ]);
  }

  Widget _cardDictamen(EntrevistaMedicaEntity e) {
    final apto = e.dictamen == DictamenEntrevista.apto;
    final color = apto ? AppTheme.cBrandGreen : AppTheme.cError;
    return _seccion('Resultado del examen médico', [
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
                    style:
                        TextStyle(fontWeight: FontWeight.w700, color: color)),
              ],
            ),
            if (e.dictamenObservaciones != null) ...[
              const SizedBox(height: 8),
              Text(e.dictamenObservaciones!,
                  style: const TextStyle(fontSize: 13)),
            ],
          ],
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

/// Diálogo de firma del consentimiento (retorna los PNG bytes o `null`).
class _FirmaConsentimientoDialog extends StatefulWidget {
  const _FirmaConsentimientoDialog();

  @override
  State<_FirmaConsentimientoDialog> createState() =>
      _FirmaConsentimientoDialogState();
}

class _FirmaConsentimientoDialogState
    extends State<_FirmaConsentimientoDialog> {
  final SignatureController _controller = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_controller.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primero firma el consentimiento.')),
      );
      return;
    }
    final bytes = await _controller.toPngBytes();
    if (bytes == null || !mounted) return;
    Navigator.of(context).pop(bytes);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      constraints: const BoxConstraints(maxWidth: 560),
      title: const Text('Consentimiento de telemedicina',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Autorizo la atención médica por videollamada y el tratamiento de '
            'mis datos de salud (ePHI) para el dictamen del examen médico.',
            style: TextStyle(fontSize: 12, color: AppTheme.cMutedText),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.cDeepAccent),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Signature(
              controller: _controller,
              height: 220,
              backgroundColor: Colors.white,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar',
              style: TextStyle(color: AppTheme.cMutedText)),
        ),
        TextButton(
          onPressed: _controller.isEmpty ? null : _controller.clear,
          child: const Text('Borrar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppTheme.cDeepAccent),
          onPressed: _guardar,
          child: const Text('Firmar y enviar'),
        ),
      ],
    );
  }
}

String _fmtFechaHora(DateTime dt) {
  final l = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(l.day)}/${two(l.month)}/${l.year} ${two(l.hour)}:${two(l.minute)}';
}
