import 'package:flutter/material.dart';
import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import 'package:esteticaybellezastrani/app/core/di/injection.dart';
import 'package:esteticaybellezastrani/app/core/network/supabase_service.dart';
import 'package:esteticaybellezastrani/features/payments_stripe/domain/repositories/i_payments_repository.dart';
import 'package:esteticaybellezastrani/features/patients_compliance/domain/entities/cuestionario_entity.dart';
import 'package:esteticaybellezastrani/features/patients_compliance/domain/entities/evaluacion_salud_entity.dart';
import 'package:esteticaybellezastrani/features/patients_compliance/presentation/cubits/patient_health_cubit.dart';

/// Screen de Cuestionario Clínico Pre-Tratamiento.
/// Carga las preguntas reales del cuestionario activo (BD) y las renderiza
/// según `tipo_respuesta`. Al aprobarse, registra la validación de
/// telemedicina con fechas reales (validez 1 año).
class PatientQuestionnaireScreen extends StatefulWidget {
  final String? serviceName;
  final VoidCallback? onCompleted;
  /// Referencia del pago de Stripe (se usa al crear la solicitud al aprobarse Qualify)
  final String? stripePaymentRef;

  const PatientQuestionnaireScreen({
    super.key,
    this.serviceName,
    this.onCompleted,
    this.stripePaymentRef,
  });

  @override
  State<PatientQuestionnaireScreen> createState() => _PatientQuestionnaireScreenState();
}

class _PatientQuestionnaireScreenState extends State<PatientQuestionnaireScreen> {
  final _formKey = GlobalKey<FormState>();

  bool _cargando = true;
  String? _error;
  int? _cuestionarioId;
  int _versionCuestionario = 1;
  List<PreguntaEntity> _preguntas = const [];
  final Map<int, String?> _respuestas = {};
  final Map<int, TextEditingController> _textControllers = {};
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    for (final ctrl in _textControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    final cubit = sl<PatientHealthCubit>();
    await cubit.loadCuestionario();

    if (!mounted) return;
    final state = cubit.state;
    if (state is PatientHealthLoaded && state.cuestionario != null) {
      setState(() {
        _cuestionarioId = state.cuestionario!.id;
        _versionCuestionario = state.cuestionario!.version;
        _preguntas = state.preguntas;
        _cargando = false;
      });
      for (final p in _preguntas) {
        if (p.tipo == TipoRespuestaPregunta.texto ||
            p.tipo == TipoRespuestaPregunta.numero ||
            p.tipo == TipoRespuestaPregunta.decimal) {
          _textControllers[p.id] = TextEditingController();
        }
      }
    } else {
      setState(() {
        _cargando = false;
        _error = state is PatientHealthError
            ? state.message
            : 'No se pudo cargar el cuestionario.';
      });
    }
  }

  int get _answeredCount {
    int count = 0;
    for (final p in _preguntas) {
      if (p.tipo == TipoRespuestaPregunta.archivo ||
          p.tipo == TipoRespuestaPregunta.imagen) {
        continue;
      }
      final v = _textControllers[p.id]?.text.trim() ?? _respuestas[p.id] ?? '';
      if (v.isNotEmpty) count++;
    }
    return count;
  }

  String _fmtFecha(DateTime? d) => d == null
      ? '—'
      : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _submitQuestionnaire() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.orange,
          content: Text('Por favor responde todas las preguntas obligatorias antes de continuar.'),
        ),
      );
      return;
    }

    if (_cuestionarioId == null) return;

    // Compilar respuestas finales (textos desde controllers).
    final respuestas = <int, String>{};
    for (final entry in _respuestas.entries) {
      final v = entry.value;
      if (v != null && v.trim().isNotEmpty) respuestas[entry.key] = v;
    }
    for (final p in _preguntas) {
      final ctrl = _textControllers[p.id];
      if (ctrl != null && ctrl.text.trim().isNotEmpty) {
        respuestas[p.id] = ctrl.text.trim();
      }
    }

    setState(() => _isSubmitting = true);

    final cubit = sl<PatientHealthCubit>();
    final resultado = await cubit.enviarRespuestas(_cuestionarioId!, respuestas);

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (resultado == null) return;

    if (resultado.resultado == ResultadoEvaluacion.apto) {
      _showEvaluationModalitySelector();
    } else {
      _showDictamenConRiesgos(resultado);
    }
  }

  // ── Modalidad de evaluación (Qualify simulado) ────────────────────────────

  void _showEvaluationModalitySelector() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        title: const Row(
          children: [
            Icon(Icons.medical_services_rounded, color: AppTheme.cDeepAccent, size: 26),
            SizedBox(width: 10),
            Text('Modalidad de Evaluación'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Selecciona el canal médico para dictaminar tu aptitud clínica:',
              style: TextStyle(fontSize: 13, color: AppTheme.cMutedText),
            ),
            SizedBox(height: 12),
            Text(
              '📌 Nota: La aprobación clínica por cualquiera de las dos modalidades otorga una validez oficial de 1 año (365 días) para acceder a todos nuestros servicios.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppTheme.cDeepAccent),
            ),
          ],
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _triggerEvaluationProcess(proveedor: 'Medicina Interna');
            },
            icon: const Icon(Icons.local_hospital_rounded, size: 18),
            label: const Text('Medicina Interna'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cDeepAccent),
            onPressed: () {
              Navigator.pop(ctx);
              _triggerEvaluationProcess(proveedor: 'Telemedicina');
            },
            icon: const Icon(Icons.videocam_rounded, size: 18),
            label: const Text('Telemedicina'),
          ),
        ],
      ),
    );
  }

  void _triggerEvaluationProcess({required String proveedor}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            Future.delayed(const Duration(seconds: 3), () async {
              if (!mounted) return;

              final cubit = sl<PatientHealthCubit>();
              final validacion = await cubit.registrarValidacion(
                aprobado: true,
                proveedor: proveedor,
              );

              final user = SupabaseService.currentUser;
              if (user != null && validacion != null) {
                try {
                  await sl<IPaymentsRepository>().createSolicitudAndPayment(
                    profileId: user.id,
                    stripePaymentRef: widget.stripePaymentRef ??
                        'STRIPE_SIM_${DateTime.now().millisecondsSinceEpoch}',
                  );
                } catch (_) {}
              }

              if (dialogCtx.mounted) Navigator.pop(dialogCtx);
              if (!mounted) return;

              if (validacion != null) {
                _showQualifySuccessModal(proveedor: proveedor, validacion: validacion);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: Colors.redAccent,
                    content: Text('No se pudo registrar la validación. Intenta de nuevo.'),
                  ),
                );
              }
            });

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 14),
                  const CircularProgressIndicator(color: AppTheme.cDeepAccent),
                  const SizedBox(height: 20),
                  Text(
                    'Evaluación Médica ($proveedor)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Procesando cuestionario y expediente clínico con el departamento de $proveedor...',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: AppTheme.cMutedText),
                  ),
                  const SizedBox(height: 10),
                  const Chip(
                    backgroundColor: AppTheme.cPastelGold,
                    label: Text('VALIDEZ 1 AÑO (365 DÍAS)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showQualifySuccessModal({
    required String proveedor,
    required ValidacionTelemedicinaEntity validacion,
  }) {
    final fecha = validacion.fechaValidacion;
    final venc = validacion.fechaVencimiento;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        title: const Row(
          children: [
            Icon(Icons.verified_user_rounded, color: AppTheme.cSuccess, size: 28),
            SizedBox(width: 10),
            Text('Dictamen Aprobado'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¡Evaluación Exitosa por $proveedor!',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              'Tu expediente médico ha sido revisado y calificado como APTO. Ahora tienes acceso a reservar cualquier servicio del catálogo.',
              style: const TextStyle(fontSize: 13, color: AppTheme.cDarkText),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: AppTheme.cPastelPurple,
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.shield_outlined, size: 18, color: AppTheme.cDeepAccent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Aprobación médica oficial válida por 1 año (365 días).',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Aprobada: ${_fmtFecha(fecha)}  ·  Vence: ${_fmtFecha(venc)}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cDeepAccent),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cDeepAccent),
            onPressed: () {
              Navigator.pop(ctx);
              if (widget.onCompleted != null) {
                widget.onCompleted!();
              } else {
                Navigator.of(context).maybePop(true);
              }
            },
            child: const Text('Continuar al Catálogo'),
          ),
        ],
      ),
    );
  }

  // ── Dictamen con riesgos (REQUIERE_REVISION / NO_APTO) ────────────────────

  void _showDictamenConRiesgos(ResultadoEvaluacionRegistrada resultado) {
    final bloqueado = resultado.resultado == ResultadoEvaluacion.noApto;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        title: Row(
          children: [
            Icon(
              bloqueado ? Icons.gpp_bad_rounded : Icons.report_problem_rounded,
              color: bloqueado ? AppTheme.cError : Colors.orange,
              size: 28,
            ),
            const SizedBox(width: 10),
            Text(bloqueado ? 'Dictamen NO APTO' : 'Revisión requerida'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              bloqueado
                  ? 'Nuestro equipo médico debe revisar tu caso antes de que puedas continuar.'
                  : 'Tu cuestionario requiere revisión por nuestro equipo médico.',
              style: const TextStyle(fontSize: 13, color: AppTheme.cDarkText),
            ),
            if (resultado.riesgos.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Aspectos a revisar:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              for (final r in resultado.riesgos)
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
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cDeepAccent),
            onPressed: () {
              Navigator.pop(ctx);
              if (widget.onCompleted != null) {
                widget.onCompleted!();
              } else {
                Navigator.of(context).maybePop(false);
              }
            },
            child: Text(bloqueado ? 'Entendido' : 'Entendido'),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Cuestionario: ${widget.serviceName ?? 'Salud'}'),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.cDeepAccent));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppTheme.cError, size: 42),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.cMutedText),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _cargar,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final progress = _preguntas.isEmpty ? 0.0 : _answeredCount / _preguntas.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.cPastelPink,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.assignment_turned_in_rounded, color: AppTheme.cDeepAccent, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Evaluación Médica Previa',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.cDeepAccent),
                      ),
                      Text(
                        'Completa las preguntas clínicas requeridas para tu aptitud.',
                        style: TextStyle(fontSize: 12, color: AppTheme.cMutedText),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Cuestionario de Salud',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.cMutedText),
                ),
                Chip(
                  backgroundColor: AppTheme.cPastelBlue,
                  label: Text('Versión $_versionCuestionario',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Progreso del Cuestionario',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                    ),
                    Text(
                      '$_answeredCount / ${_preguntas.length}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.cDeepAccent),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade200,
                    color: AppTheme.cDeepAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            ..._preguntas.asMap().entries.map((entry) {
              final idx = entry.key + 1;
              final p = entry.value;
              return _buildQuestionCard(idx, p);
            }),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitQuestionnaire,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(_isSubmitting
                    ? 'Procesando...'
                    : 'Enviar y Evaluar con Qualify'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(int index, PreguntaEntity pregunta) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: AppTheme.cPastelBlue,
                  child: Text(
                    '$index',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cDarkText),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    pregunta.texto,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.cDarkText),
                  ),
                ),
                if (pregunta.obligatoria)
                  const Text(' *', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),

            _buildRespuesta(pregunta),
          ],
        ),
      ),
    );
  }

  Widget _buildRespuesta(PreguntaEntity pregunta) {
    switch (pregunta.tipo) {
      case TipoRespuestaPregunta.siNo:
        return _siNoField(pregunta);
      case TipoRespuestaPregunta.texto:
      case TipoRespuestaPregunta.numero:
      case TipoRespuestaPregunta.decimal:
        return _textField(pregunta);
      case TipoRespuestaPregunta.fecha:
        return _fechaField(pregunta);
      case TipoRespuestaPregunta.lista:
        return _listaField(pregunta, multiple: false);
      case TipoRespuestaPregunta.multiple:
        return _listaField(pregunta, multiple: true);
      case TipoRespuestaPregunta.archivo:
      case TipoRespuestaPregunta.imagen:
        return const Text(
          'Adjuntar archivo/imagen estará disponible próximamente.',
          style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppTheme.cMutedText),
        );
    }
  }

  String? _validarObligatoria(String? v, PreguntaEntity p) {
    if (p.obligatoria && (v == null || v.trim().isEmpty)) {
      return 'Responde esta pregunta';
    }
    return null;
  }

  Widget _siNoField(PreguntaEntity pregunta) {
    return FormField<String>(
      initialValue: _respuestas[pregunta.id],
      validator: (v) => _validarObligatoria(v, pregunta),
      builder: (field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Sí')),
                    selected: _respuestas[pregunta.id] == 'Sí',
                    selectedColor: AppTheme.cPastelPink,
                    onSelected: (selected) {
                      setState(() {
                        _respuestas[pregunta.id] = selected ? 'Sí' : null;
                      });
                      field.didChange(_respuestas[pregunta.id]);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('No')),
                    selected: _respuestas[pregunta.id] == 'No',
                    selectedColor: AppTheme.cPastelBlue,
                    onSelected: (selected) {
                      setState(() {
                        _respuestas[pregunta.id] = selected ? 'No' : null;
                      });
                      field.didChange(_respuestas[pregunta.id]);
                    },
                  ),
                ),
              ],
            ),
            if (field.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  field.errorText ?? '',
                  style: TextStyle(fontSize: 12, color: Colors.red.shade600),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _textField(PreguntaEntity pregunta) {
    final esNumerico =
        pregunta.tipo == TipoRespuestaPregunta.numero || pregunta.tipo == TipoRespuestaPregunta.decimal;
    return TextFormField(
      controller: _textControllers[pregunta.id],
      keyboardType: esNumerico ? TextInputType.number : TextInputType.multiline,
      maxLines: pregunta.tipo == TipoRespuestaPregunta.texto ? 2 : 1,
      onChanged: (_) => setState(() {}),
      validator: (v) {
        final obligatoria = _validarObligatoria(v, pregunta);
        if (obligatoria != null) return obligatoria;
        if (esNumerico && (v?.trim().isNotEmpty ?? false)) {
          final ok = pregunta.tipo == TipoRespuestaPregunta.numero
              ? int.tryParse(v!.trim()) != null
              : double.tryParse(v!.trim()) != null;
          if (!ok) return 'Ingresa un valor numérico válido';
        }
        return null;
      },
      decoration: AppTheme.fieldDecoration(
        label: pregunta.tipo == TipoRespuestaPregunta.texto
            ? 'Detalles (opcional)'
            : pregunta.tipo == TipoRespuestaPregunta.numero
                ? 'Número'
                : 'Valor numérico',
        hint: esNumerico ? '0' : 'Escribe tu respuesta aquí...',
      ),
    );
  }

  Widget _fechaField(PreguntaEntity pregunta) {
    return FormField<String>(
      initialValue: _respuestas[pregunta.id],
      validator: (v) => _validarObligatoria(v, pregunta),
      builder: (field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() {
                    _respuestas[pregunta.id] = picked.toIso8601String().split('T').first;
                  });
                  field.didChange(_respuestas[pregunta.id]);
                }
              },
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              child: InputDecorator(
                decoration: AppTheme.fieldDecoration(
                  label: pregunta.obligatoria ? 'Fecha' : 'Fecha (opcional)',
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _respuestas[pregunta.id] ?? 'Selecciona una fecha',
                      style: TextStyle(
                        fontSize: 14,
                        color: _respuestas[pregunta.id] == null
                            ? AppTheme.cMutedText
                            : AppTheme.cDarkText,
                      ),
                    ),
                    const Icon(Icons.calendar_today_rounded, size: 18, color: AppTheme.cMutedText),
                  ],
                ),
              ),
            ),
            if (field.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  field.errorText ?? '',
                  style: TextStyle(fontSize: 12, color: Colors.red.shade600),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _listaField(PreguntaEntity pregunta, {required bool multiple}) {
    return FormField<String>(
      initialValue: _respuestas[pregunta.id],
      validator: (v) => _validarObligatoria(v, pregunta),
      builder: (field) {
        final seleccionados = (_respuestas[pregunta.id] ?? '')
            .split(', ')
            .where((s) => s.isNotEmpty)
            .toSet();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: pregunta.opciones.map((op) {
                final isSelected = seleccionados.contains(op);
                return ChoiceChip(
                  label: Text(op),
                  selected: isSelected,
                  selectedColor: multiple ? AppTheme.cPastelPurple : AppTheme.cPastelPink,
                  onSelected: (sel) {
                    setState(() {
                      if (multiple) {
                        if (sel) {
                          seleccionados.add(op);
                        } else {
                          seleccionados.remove(op);
                        }
                        _respuestas[pregunta.id] =
                            seleccionados.isEmpty ? null : seleccionados.join(', ');
                      } else {
                        _respuestas[pregunta.id] = sel ? op : null;
                      }
                    });
                    field.didChange(_respuestas[pregunta.id]);
                  },
                );
              }).toList(),
            ),
            if (field.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  field.errorText ?? '',
                  style: TextStyle(fontSize: 12, color: Colors.red.shade600),
                ),
              ),
          ],
        );
      },
    );
  }
}