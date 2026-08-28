import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/app_routes.dart';
import '../../../../app/config/app_theme.dart';
import '../../../../app/core/di/injection.dart';
import '../../../auth_users/presentation/cubits/auth_cubit.dart';
import '../../../notifications/presentation/cubits/notifications_cubit.dart';
import '../../../notifications/presentation/widgets/notificaciones_bell.dart';
import '../../domain/entities/documento_especialista_entity.dart';
import '../../domain/entities/especialista_entity.dart';
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
        sl<NotificationsCubit>().load(usuarioId);
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
        actions: const [NotificacionesBell()],
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
                    (requisito) => _buildTile(requisito),
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

  /// Estado del requisito según los documentos ya subidos:
  /// completado (APROBADO) → no se puede re-subir; rechazado → re-subir ese
  /// mismo tipo; en revisión → esperando al admin; pendiente → adjuntar.
  Widget _buildTile(RequisitoDocumento requisito) {
    final docs = _documentos.where(requisito.loCumple).toList();
    final aprobado = docs
        .where((d) => d.estadoRevision == EstadoRevisionDocumento.aprobado)
        .toList();
    final rechazado = docs
        .where((d) => d.estadoRevision == EstadoRevisionDocumento.rechazado)
        .toList();
    final enRevision = docs.any((d) =>
        d.activo && d.estadoRevision == EstadoRevisionDocumento.pendiente);

    // Precedencia: un documento ACTIVO en revisión (re-subida) manda sobre el
    // rechazo anterior; sin activo, se muestra el rechazo de la última versión.
    _EstadoRequisito estado;
    if (aprobado.isNotEmpty) {
      estado = _EstadoRequisito.completado;
    } else if (enRevision) {
      estado = _EstadoRequisito.enRevision;
    } else if (rechazado.isNotEmpty) {
      estado = _EstadoRequisito.rechazado;
    } else {
      estado = _EstadoRequisito.pendiente;
    }

    return _DocumentoTile(
      requisito: requisito,
      estado: estado,
      motivo:
          rechazado.isNotEmpty ? rechazado.last.observacionRevision : null,
      cargando: _uploading,
      onSelect: () => _seleccionarArchivo(
        requisito,
        tipo: rechazado.isNotEmpty ? rechazado.last.tipoDocumento : null,
      ),
    );
  }

  Future<void> _seleccionarArchivo(
    RequisitoDocumento requisito, {
    TipoDocumento? tipo,
  }) async {
    // Re-subida de un rechazado: `tipo` viene forzado. Primera carga: si el
    // requisito tiene alternativas (formación) se pregunta cuál; si no, se usa
    // el tipo principal directamente.
    var tipoElegido = tipo;
    if (tipoElegido == null && requisito.alternativas.isNotEmpty) {
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
      tipoElegido = elegido;
    }
    tipoElegido ??= requisito.tipo;
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
          tipoDocumento: tipoElegido,
          bytes: Uint8List.fromList(picked.bytes!),
          nombreArchivo: picked.name,
        );
    if (mounted) setState(() => _uploading = false);
  }

  void _continuar() {
    if (!_completo) return;
    final cubit = context.read<SpecialistsCubit>();
    final state = cubit.state;
    // Si el especialista ya está APROBADO no debe degradarse a EN_REVISION
    // (trigger `proteger_verificacion_especialista` lo bloquea): solo se
    // solicita verificación para PENDIENTE/RECHAZADO.
    final yaAprobado = state is SpecialistsLoaded &&
        state.especialista?.estadoVerificacion == EstadoVerificacion.aprobado;
    if (!yaAprobado) {
      // Al completar los documentos obligatorios se mueve la solicitud a
      // EN_REVISION: el especialista queda a la espera de validación del admin.
      cubit.solicitarVerificacion(especialistaId: widget.especialistaId);
    }
    context.go(AppRoutes.specialistHome);
  }
}

enum _EstadoRequisito { completado, enRevision, rechazado, pendiente }

class _DocumentoTile extends StatelessWidget {
  final RequisitoDocumento requisito;
  final _EstadoRequisito estado;
  final String? motivo;
  final bool cargando;
  final VoidCallback onSelect;

  const _DocumentoTile({
    required this.requisito,
    required this.estado,
    this.motivo,
    required this.cargando,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final subido = estado != _EstadoRequisito.pendiente;
    final rechazado = estado == _EstadoRequisito.rechazado;
    final Color color = switch (estado) {
      _EstadoRequisito.completado => AppTheme.cBrandGreen,
      _EstadoRequisito.rechazado => Colors.redAccent,
      _EstadoRequisito.enRevision => Colors.orange,
      _EstadoRequisito.pendiente => AppTheme.cMutedText,
    };
    final String estadoTexto = switch (estado) {
      _EstadoRequisito.completado => 'Aprobado',
      _EstadoRequisito.enRevision => 'En revisión',
      _EstadoRequisito.rechazado => 'Rechazado',
      _EstadoRequisito.pendiente => 'Pendiente',
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(
              switch (estado) {
                _EstadoRequisito.completado => Icons.verified_rounded,
                _EstadoRequisito.rechazado => Icons.cancel_outlined,
                _EstadoRequisito.enRevision => Icons.hourglass_top_rounded,
                _EstadoRequisito.pendiente => Icons.description_outlined,
              },
              color: color,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(requisito.label,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    estadoTexto,
                    style: TextStyle(fontSize: 12, color: color),
                  ),
                  if (rechazado && motivo != null && motivo!.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Motivo: $motivo',
                        style: const TextStyle(
                            fontSize: 12,
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w500),
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
            else if (estado == _EstadoRequisito.completado)
              const Icon(Icons.check_circle, color: AppTheme.cBrandGreen)
            else if (estado == _EstadoRequisito.enRevision)
              const Icon(Icons.schedule_rounded, color: Colors.orange)
            else
              // Un botón como hijo no-flex de un Row recibe ancho ilimitado
              // (0..∞), por lo que se acota con `maxWidth` y deja que crezca
              // según el texto ('Reintentar' no cabe en un ancho fijo de 108).
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: SizedBox(
                  height: 40,
                  child: OutlinedButton(
                    onPressed: onSelect,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: Text(rechazado ? 'Reintentar' : 'Adjuntar'),
                  ),
                ),
              ),
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