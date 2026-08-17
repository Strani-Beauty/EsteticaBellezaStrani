import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/app_routes.dart';
import '../../../../app/config/app_theme.dart';
import '../../../auth_users/presentation/cubits/auth_cubit.dart';
import '../../domain/entities/documento_especialista_entity.dart';
import '../cubits/specialists_cubit.dart';
import '../widgets/documentos_requeridos.dart';

/// Pantalla obligatoria de documentos requeridos al registrarse como
/// especialista. Fuerza la subida de los documentos indispensables
/// antes de permitir continuar hacia el panel.
class SpecialistDocumentsScreen extends StatefulWidget {
  final String especialistaId;
  final bool isOnboarding;
  const SpecialistDocumentsScreen({
    super.key,
    required this.especialistaId,
    this.isOnboarding = true,
  });

  @override
  State<SpecialistDocumentsScreen> createState() =>
      _SpecialistDocumentsScreenState();
}

class _SpecialistDocumentsScreenState extends State<SpecialistDocumentsScreen> {
  static final _requeridos = requisitosDocumentos;

  bool _uploading = false;

  List<RequisitoDocumento> get _pendientes => _requeridos
      .where((r) => !_documentos.any((d) => d.activo && r.loCumple(d)))
      .toList();

  bool get _completo => _pendientes.isEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final usuarioId = context.read<AuthCubit>().currentProfile?.id;
      if (usuarioId != null && usuarioId.isNotEmpty) {
        context.read<SpecialistsCubit>().loadDashboard(usuarioId: usuarioId);
      }
    });
  }

  List<DocumentoEspecialistaEntity> get _documentos {
    final state = context.read<SpecialistsCubit>().state;
    if (state is SpecialistsLoaded) return state.documentos;
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Documentos requeridos'),
        automaticallyImplyLeading: false,
        leading: BackButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.specialistHome);
            }
          },
        ),
      ),
      body: BlocListener<SpecialistsCubit, SpecialistsState>(
        listener: (context, state) {
          if (state is SpecialistsError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: AppTheme.cError),
            );
          }
        },
        child: BlocBuilder<SpecialistsCubit, SpecialistsState>(
          builder: (context, state) {
            final pendientes = _pendientes;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.isOnboarding) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.verified_user_rounded, color: Colors.white, size: 32),
                          SizedBox(height: 8),
                          Text(
                            'Completa tu perfil profesional',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Para solicitar la verificación necesitas subir tus documentos.',
                            style: TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  const Text('Documentos obligatorios',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text(
                    'Adjunta cada documento requerido. Si algún documento ya fue subido, aparecerá como completado.',
                    style: TextStyle(color: AppTheme.cMutedText, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  ..._requeridos.map(
                    (requisito) => _DocumentoTile(
                      requisito: requisito,
                      subido: _documentos
                          .any((d) => d.activo && requisito.loCumple(d)),
                      cargando: _uploading,
                      onSelect: () => _seleccionarArchivo(requisito),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _completo && !_uploading ? _continuar : null,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: const Text('Continuar'),
                    ),
                  ),
                  if (pendientes.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Faltan ${pendientes.length} documento(s) obligatorio(s)',
                        style: const TextStyle(color: AppTheme.cMutedText, fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _seleccionarArchivo(RequisitoDocumento requisito) async {
    var tipo = requisito.tipo;
    if (requisito.alternativas.isNotEmpty) {
      final elegido = await showDialog<TipoDocumento>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('¿Qué documento adjuntarás?'),
          children: tiposDeRequisito(requisito)
              .map((t) => SimpleDialogOption(
                    onPressed: () => Navigator.pop(ctx, t),
                    child: Text(_labels[t] ?? t.toDb),
                  ))
              .toList(),
        ),
      );
      if (elegido == null || !mounted) return;
      tipo = elegido;
    }
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.any,
    );
    final picked = result?.files.single;
    if (picked == null || picked.bytes == null) return;
    if (!mounted) return;

    setState(() => _uploading = true);
    await context.read<SpecialistsCubit>().uploadDocument(
          especialistaId: widget.especialistaId,
          tipoDocumento: tipo,
          bytes: Uint8List.fromList(picked.bytes!),
          nombreArchivo: picked.name,
        );
    if (mounted) setState(() => _uploading = false);
  }

  void _continuar() {
    if (!_completo) return;
    final cubit = context.read<SpecialistsCubit>();
    // Al completar los documentos obligatorios se mueve la solicitud a
    // EN_REVISION: el especialista queda a la espera de validación del admin.
    cubit.solicitarVerificacion(especialistaId: widget.especialistaId);
    context.go(AppRoutes.specialistHome);
  }
}

class _DocumentoTile extends StatelessWidget {
  final RequisitoDocumento requisito;
  final bool subido;
  final bool cargando;
  final VoidCallback onSelect;

  const _DocumentoTile({
    required this.requisito,
    required this.subido,
    required this.cargando,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(
              subido ? Icons.verified_rounded : Icons.description_outlined,
              color: subido ? AppTheme.cBrandGreen : AppTheme.cDeepAccent,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(requisito.label,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    subido ? 'Completado' : 'Pendiente',
                    style: TextStyle(
                      fontSize: 12,
                      color: subido ? AppTheme.cBrandGreen : AppTheme.cMutedText,
                    ),
                  ),
                  if (!subido && requisito.alternativas.isNotEmpty)
                    Text(
                      requisito.descripcion,
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.cMutedText),
                    ),
                ],
              ),
            ),
            if (cargando)
              const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (!subido)
              // Dimensiones fijas: un botón como hijo no-flex de un Row recibe
              // ancho ilimitado (0..∞) y su mínimo interno (40) colapsa con
              // `BoxConstraints(w=Infinity)`. Con tamaño finito es inmune.
              SizedBox(
                width: 108,
                height: 40,
                child: OutlinedButton(
                  onPressed: onSelect,
                  child: const Text('Adjuntar'),
                ),
              )
            else
              const Icon(Icons.check_circle, color: AppTheme.cBrandGreen),
          ],
        ),
      ),
    );
  }
}

const Map<TipoDocumento, String> _labels = {
  TipoDocumento.identificacion: 'Identificación oficial (Cédula o pasaporte)',
  TipoDocumento.licencia: 'Licencia profesional',
  TipoDocumento.diploma: 'Diploma',
  TipoDocumento.certificacion: 'Certificación',
  TipoDocumento.otro: 'Otro',
};