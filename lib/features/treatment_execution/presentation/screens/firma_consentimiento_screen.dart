import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:signature/signature.dart';
import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import '../cubits/treatment_execution_cubit.dart';

/// Pantalla para que el paciente firme el consentimiento del tratamiento.
class FirmaConsentimientoScreen extends StatefulWidget {
  final String tratamientoId;
  final String pacienteId;
  final String tipoConsentimiento;
  const FirmaConsentimientoScreen({
    super.key,
    required this.tratamientoId,
    required this.pacienteId,
    required this.tipoConsentimiento,
  });

  @override
  State<FirmaConsentimientoScreen> createState() =>
      _FirmaConsentimientoScreenState();
}

class _FirmaConsentimientoScreenState extends State<FirmaConsentimientoScreen> {
  final SignatureController _controller = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );
  bool _guardando = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_controller.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primero firma el consentimiento')),
      );
      return;
    }
    final bytes = await _controller.toPngBytes();
    if (bytes == null) return;
    if (!mounted) return;
    setState(() => _guardando = true);
    context.read<TreatmentExecutionCubit>().firmarConsulta(
          tratamientoId: widget.tratamientoId,
          pacienteId: widget.pacienteId,
          tipoConsentimiento: widget.tipoConsentimiento,
          bytesFirma: bytes,
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<TreatmentExecutionCubit, TreatmentExecutionState>(
      listener: (context, state) {
        if (state is TreatmentExecutionLoaded && state.consentimiento != null) {
          Navigator.of(context).pop(true);
        } else if (state is TreatmentExecutionError) {
          setState(() => _guardando = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Firma del consentimiento'),
          actions: [
            TextButton(
              onPressed: _controller.isEmpty ? null : _controller.clear,
              child: const Text('Borrar'),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text(
                'El paciente declara estar informado sobre el tratamiento '
                'a realizar y autoriza su ejecución.',
                style: TextStyle(color: AppTheme.cMutedText),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.cDeepAccent),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Signature(
                  controller: _controller,
                  height: 240,
                  backgroundColor: Colors.white,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _guardando ? null : _guardar,
                  icon: _guardando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.draw_rounded),
                  label: const Text('Guardar firma'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}