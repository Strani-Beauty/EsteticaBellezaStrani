import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:esteticaybellezastrani/app/config/app_routes.dart';
import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import 'package:esteticaybellezastrani/features/patients_compliance/domain/entities/evaluacion_salud_entity.dart';

/// Vista de "Evaluación Médica aplicada" (solo UI, fase 1).
///
/// Se muestra tras guardar el cuestionario (`guardar_respuestas_evaluacion`).
/// NO emite dictamen: el dictamen lo realiza un médico en entrevista F2F
/// desde administración. Requiere checkbox de consentimiento ePHI antes de
/// continuar al catálogo.
class EvaluacionMedicaAplicadaScreen extends StatefulWidget {
  final ResultadoEvaluacionRegistrada resultado;
  final String? serviceName;
  final VoidCallback? onCompleted;

  const EvaluacionMedicaAplicadaScreen({
    super.key,
    required this.resultado,
    this.serviceName,
    this.onCompleted,
  });

  @override
  State<EvaluacionMedicaAplicadaScreen> createState() =>
      _EvaluacionMedicaAplicadaScreenState();
}

class _EvaluacionMedicaAplicadaScreenState
    extends State<EvaluacionMedicaAplicadaScreen> {
  bool _consentimiento = false;

  String get _folioCorto {
    final id = widget.resultado.evaluacionId;
    if (id.isEmpty) return '—';
    return id.length <= 8 ? id : id.substring(0, 8).toUpperCase();
  }

  String _fmtFecha(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _resultadoLabel(ResultadoEvaluacion r) {
    switch (r) {
      case ResultadoEvaluacion.apto:
        return 'Cuestionario aplicado (sin dictamen)';
      case ResultadoEvaluacion.requiereRevision:
        return 'Requiere revisión médica';
      case ResultadoEvaluacion.noApto:
        return 'Requiere revisión médica prioritaria';
    }
  }

  void _continuar() {
    if (!_consentimiento) return;
    if (widget.onCompleted != null) {
      widget.onCompleted!();
    } else {
      Navigator.of(context).maybePop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final res = widget.resultado;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Evaluación Médica Interna'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.cPastelBlue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.assignment_turned_in_rounded,
                    color: AppTheme.cDeepAccent,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Evaluación aplicada',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.cDeepAccent,
                        ),
                      ),
                      Text(
                        'Tu cuestionario fue registrado. El dictamen médico se realiza en entrevista F2F por videollamada.',
                        style: TextStyle(fontSize: 12, color: AppTheme.cMutedText),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _resultadoLabel(res.resultado),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Chip(
                        backgroundColor: AppTheme.cPastelPurple,
                        label: Text('Folio $_folioCorto',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                      Chip(
                        backgroundColor: AppTheme.cPastelBlue,
                        label: Text('v${res.versionCuestionario} · ${_fmtFecha(res.fechaEvaluacion)}',
                            style: const TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                  if (res.riesgos.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'Aspectos detectados (informativo, no es un diagnóstico):',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    for (final r in res.riesgos)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Icon(
                              r.critico ? Icons.error_outline : Icons.info_outline,
                              size: 16,
                              color: r.critico ? AppTheme.cError : Colors.orange,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                r.etiqueta,
                                style: const TextStyle(fontSize: 12, color: AppTheme.cMutedText),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.cPastelGold.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.cGoldAccent.withValues(alpha: 0.4)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Qué sigue',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '1. Un médico revisará tu cuestionario.\n'
                    '2. Te agendaremos una entrevista F2F por videollamada.\n'
                    '3. El dictamen (apto / no apto) lo emite el médico desde administración.',
                    style: TextStyle(fontSize: 12, height: 1.5, color: AppTheme.cDarkText),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.gpp_maybe_rounded, size: 18, color: AppTheme.cGoldAccent),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Avisos FDA / HIPAA (ePHI)',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Esta información es Información Electrónica Protegida de Salud (ePHI). '
                    'Se usa solo para tu evaluación clínica interna, con acceso restringido '
                    'y auditado. No constituye un diagnóstico ni una autorización de tratamiento '
                    '(FDA: solo personal médico calificado emite el dictamen).',
                    style: TextStyle(fontSize: 11, height: 1.5, color: AppTheme.cMutedText),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: _consentimiento,
              onChanged: (v) => setState(() => _consentimiento = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'He leído los avisos y autorizo el tratamiento de mis datos de salud (ePHI) para la evaluación médica interna.',
                style: TextStyle(fontSize: 12, color: AppTheme.cDarkText),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _consentimiento ? _continuar : null,
                icon: const Icon(Icons.storefront_rounded),
                label: const Text('Continuar al catálogo'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.push(AppRoutes.miEntrevista),
                icon: const Icon(Icons.video_call_rounded, size: 18),
                label: const Text('Ver mi entrevista médica'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
