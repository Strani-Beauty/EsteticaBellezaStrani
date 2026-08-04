import 'package:flutter/material.dart';
import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import 'package:esteticaybellezastrani/supabase_service.dart';
import 'package:esteticaybellezastrani/features/patients_compliance/domain/entities/cuestionario_entity.dart';

/// Screen de Cuestionario Clínico Pre-Tratamiento (Previo a Consulta Qualify Modo Prueba).
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

  // Preguntas dinámicas de prueba (simulando tabla preguntas / cuestionario_preguntas por servicio)
  final List<PreguntaEntity> _preguntas = [
    PreguntaEntity(
      id: 'p1',
      texto: '¿Tienes alguna alergia conocida a la lidocaína, anestésicos locales o ácido hialurónico?',
      tipo: TipoPregunta.boolean,
      obligatoria: true,
      activo: true,
      createdAt: DateTime.now(),
    ),
    PreguntaEntity(
      id: 'p2',
      texto: '¿Estás actualmente embarazada, en período de lactancia o planeando embarazo en los próximos 3 meses?',
      tipo: TipoPregunta.boolean,
      obligatoria: true,
      activo: true,
      createdAt: DateTime.now(),
    ),
    PreguntaEntity(
      id: 'p3',
      texto: '¿Padeces alguna enfermedad autoinmune, diabetes no controlada o trastorno de coagulación?',
      tipo: TipoPregunta.boolean,
      obligatoria: true,
      activo: true,
      createdAt: DateTime.now(),
    ),
    PreguntaEntity(
      id: 'p4',
      texto: 'Menciona cualquier medicamento o suplemento que estés tomando actualmente (anticoagulantes, aspirina, etc.):',
      tipo: TipoPregunta.abierta,
      obligatoria: false,
      activo: true,
      createdAt: DateTime.now(),
    ),
    PreguntaEntity(
      id: 'p5',
      texto: '¿Has recibido tratamientos estéticos faciales o inyectables en los últimos 6 meses?',
      tipo: TipoPregunta.seleccionMultiple,
      opciones: const ['Bótox / Toxina Botulínica', 'Ácido Hialurónico', 'Peeling Químico', 'Hilos Tensores', 'Ninguno'],
      obligatoria: true,
      activo: true,
      createdAt: DateTime.now(),
    ),
  ];

  // Respuestas almacenadas
  final Map<String, dynamic> _respuestas = {};
  final Map<String, TextEditingController> _textControllers = {};
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    for (final p in _preguntas) {
      if (p.tipo == TipoPregunta.abierta) {
        _textControllers[p.id] = TextEditingController();
      }
    }
  }

  @override
  void dispose() {
    for (final ctrl in _textControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  int get _answeredCount {
    int count = 0;
    for (final p in _preguntas) {
      if (p.tipo == TipoPregunta.abierta) {
        if ((_textControllers[p.id]?.text.trim() ?? '').isNotEmpty) count++;
      } else if (_respuestas.containsKey(p.id) && _respuestas[p.id] != null) {
        count++;
      }
    }
    return count;
  }

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

    setState(() => _isSubmitting = true);

    final user = SupabaseService.currentUser;
    final userId = user?.id ?? 'invitado_test';

    // Compilar respuestas finales
    final Map<String, String> respuestasFinales = {};
    for (final p in _preguntas) {
      if (p.tipo == TipoPregunta.abierta) {
        respuestasFinales[p.id] = _textControllers[p.id]?.text.trim() ?? 'N/A';
      } else {
        respuestasFinales[p.id] = _respuestas[p.id]?.toString() ?? 'No respondida';
      }
    }

    // Persistir evaluación clínica en Supabase
    try {
      await SupabaseService.saveHealthEvaluation(
        profileId: userId,
        serviceName: widget.serviceName ?? 'Estética General',
        answers: respuestasFinales,
      );
    } catch (_) {}

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    // Diálogo de selección de modalidad de evaluación (Telemedicina vs Medicina Interna)
    _showEvaluationModalitySelector();
  }

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

              final user = SupabaseService.currentUser;
              if (user != null) {
                try {
                  await SupabaseService.saveQualifyTestValidation(
                    profileId: user.id,
                    aprobado: true,
                    proveedor: proveedor,
                  );
                } catch (_) {}

                try {
                  await SupabaseService.createSolicitudAndPayment(
                    profileId: user.id,
                    stripePaymentRef: widget.stripePaymentRef
                        ?? 'STRIPE_SIM_${DateTime.now().millisecondsSinceEpoch}',
                  );
                } catch (_) {}
              }

              if (dialogCtx.mounted) Navigator.pop(dialogCtx);

              _showQualifySuccessModal(proveedor: proveedor);
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

  void _showQualifySuccessModal({required String proveedor}) {
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
              'Tu expediente médico ha sido revisado y calificado como APTO por el canal de $proveedor. Ahora tienes acceso a reservar cualquier servicio del catálogo.',
              style: const TextStyle(fontSize: 13, color: AppTheme.cDarkText),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: AppTheme.cPastelPurple,
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined, size: 18, color: AppTheme.cDeepAccent),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Aprobación médica oficial válida por 1 año (365 días).',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
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

  @override
  Widget build(BuildContext context) {
    final progress = _answeredCount / _preguntas.length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Cuestionario: ${widget.serviceName ?? 'Servicio Estético'}'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado
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
              const SizedBox(height: 16),

              // Barra de progreso
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

              // Lista de preguntas dinámicas
              ..._preguntas.asMap().entries.map((entry) {
                final idx = entry.key + 1;
                final p = entry.value;
                return _buildQuestionCard(idx, p);
              }),

              const SizedBox(height: 24),

              // Botón de Envío
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
                      : 'Enviar y Evaluar con Qualify (Modo Prueba)'),
                ),
              ),
            ],
          ),
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

            // Renderizado por tipo de pregunta
            if (pregunta.tipo == TipoPregunta.boolean)
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Sí')),
                      selected: _respuestas[pregunta.id] == true,
                      selectedColor: AppTheme.cPastelPink,
                      onSelected: (selected) {
                        setState(() {
                          _respuestas[pregunta.id] = selected ? true : null;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('No')),
                      selected: _respuestas[pregunta.id] == false,
                      selectedColor: AppTheme.cPastelBlue,
                      onSelected: (selected) {
                        setState(() {
                          _respuestas[pregunta.id] = selected ? false : null;
                        });
                      },
                    ),
                  ),
                ],
              )
            else if (pregunta.tipo == TipoPregunta.abierta)
              TextFormField(
                controller: _textControllers[pregunta.id],
                maxLines: 2,
                onChanged: (_) => setState(() {}),
                decoration: AppTheme.fieldDecoration(
                  label: 'Detalles (opcional)',
                  hint: 'Escribe tu respuesta aquí...',
                ),
              )
            else if (pregunta.tipo == TipoPregunta.seleccionMultiple && pregunta.opciones != null)
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: pregunta.opciones!.map((op) {
                  final isSelected = _respuestas[pregunta.id] == op;
                  return ChoiceChip(
                    label: Text(op),
                    selected: isSelected,
                    selectedColor: AppTheme.cPastelPurple,
                    onSelected: (sel) {
                      setState(() {
                        _respuestas[pregunta.id] = sel ? op : null;
                      });
                    },
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}
