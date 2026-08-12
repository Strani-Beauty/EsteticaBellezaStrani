import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:signature/signature.dart';
import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import '../cubits/specialists_cubit.dart';

/// Pantalla para que el especialista firme su contrato de prestación de
/// servicios (firma manuscrita). La imagen se sube al bucket `contratos` y se
/// registra en `contratos` con `metodo_firma=TOUCH`.
class ContractSignatureScreen extends StatefulWidget {
  final String especialistaId;
  const ContractSignatureScreen({super.key, required this.especialistaId});

  @override
  State<ContractSignatureScreen> createState() =>
      _ContractSignatureScreenState();
}

class _ContractSignatureScreenState extends State<ContractSignatureScreen> {
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
        const SnackBar(content: Text('Primero firma el contrato')),
      );
      return;
    }
    final bytes = await _controller.toPngBytes();
    if (bytes == null) return;
    if (!mounted) return;
    setState(() => _guardando = true);
    context.read<SpecialistsCubit>().firmarContratoConFirma(
          especialistaId: widget.especialistaId,
          bytesFirma: bytes,
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SpecialistsCubit, SpecialistsState>(
      listener: (context, state) {
        if (state is SpecialistsLoaded &&
            state.contrato?.firmado == true) {
          Navigator.of(context).pop(true);
        } else if (state is SpecialistsError) {
          setState(() => _guardando = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Firma del contrato'),
          actions: [
            TextButton(
              onPressed: _controller.isEmpty ? null : _controller.clear,
              child: const Text('Borrar'),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Al firmar aceptas los términos y condiciones de prestación '
                  'de servicios de Estética y Belleza Strani.',
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
                const SizedBox(height: 20),
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
                    label: const Text('Firmar contrato'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
