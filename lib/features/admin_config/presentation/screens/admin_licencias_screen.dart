import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import 'package:esteticaybellezastrani/features/auth_users/presentation/cubits/auth_cubit.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/entities/contrato_entity.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/entities/documento_especialista_entity.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/entities/especialista_entity.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/entities/medico_regente_entity.dart';
import 'package:esteticaybellezastrani/features/specialists/presentation/cubits/specialists_cubit.dart';
import 'package:esteticaybellezastrani/features/specialists/presentation/widgets/expediente_compliance.dart';

/// Verificación de licencias — vista propia del panel admin.
class AdminLicenciasScreen extends StatefulWidget {
  const AdminLicenciasScreen({super.key});

  @override
  State<AdminLicenciasScreen> createState() => _AdminLicenciasScreenState();
}

class _AdminLicenciasScreenState extends State<AdminLicenciasScreen> {
  bool _cargado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_cargado) {
      _cargado = true;
      context.read<SpecialistsCubit>().loadAllEspecialistas();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Verificación de Licencias'),
        backgroundColor: AppTheme.cDeepAccent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => context.read<AuthCubit>().signOut(),
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
          ),
        ],
      ),
      body: BlocListener<SpecialistsCubit, SpecialistsState>(
        listener: (context, state) {
          if (state is SpecialistsError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        child: BlocBuilder<SpecialistsCubit, SpecialistsState>(
          builder: (context, state) {
            if (state is SpecialistsLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is SpecialistsError) {
              return _ErrorView(
                message: state.message,
                onRetry: () =>
                    context.read<SpecialistsCubit>().loadAllEspecialistas(),
              );
            }
            if (state is! SpecialistsLoaded) {
              return const SizedBox.shrink();
            }
            return _VerificacionDeLicencias(
              especialistas: state.especialistas,
              medicosRegentes: state.medicosRegentes,
              documentosPorEspecialista: state.documentosPorEspecialista,
              contratosPorEspecialista: state.contratosPorEspecialista,
              especialidadesCountPorEspecialista:
                  state.especialidadesCountPorEspecialista,
              onAprobar: (especialista) => _cambiarEstado(
                especialista,
                EstadoVerificacion.aprobado,
              ),
              onRechazar: (especialista) => _pedirMotivo(
                especialista,
                EstadoVerificacion.rechazado,
              ),
              onBloquear: (especialista) => _pedirMotivo(
                especialista,
                EstadoVerificacion.bloqueado,
              ),
              onAprobarMedicoRegente: (medicoId) =>
                  context.read<SpecialistsCubit>().aprobarMedicoRegente(medicoId),
              onRevisarDocumento: _revisarDocumento,
            );
          },
        ),
      ),
    );
  }

  Future<void> _pedirMotivo(
    EspecialistaEntity especialista,
    EstadoVerificacion estado,
  ) async {
    final esRechazo = estado == EstadoVerificacion.rechazado;
    final motivo = await showDialog<String>(
      context: context,
      builder: (_) => _MotivoDialog(
        titulo: esRechazo ? 'Rechazar especialista' : 'Bloquear especialista',
        confirmar: esRechazo ? 'Rechazar' : 'Bloquear',
        hint: esRechazo
            ? 'Motivo del rechazo (visible para el especialista)'
            : 'Motivo del bloqueo (visible para el especialista)',
      ),
    );
    if (motivo == null || !mounted) return;
    _cambiarEstado(
      especialista,
      estado,
      observacion: motivo.trim().isEmpty ? null : motivo.trim(),
    );
  }

  void _cambiarEstado(
    EspecialistaEntity especialista,
    EstadoVerificacion estado, {
    String? observacion,
  }) {
    final adminId = context.read<AuthCubit>().currentProfile?.id;
    if (adminId == null) return;
    context.read<SpecialistsCubit>().updateVerificacion(
          especialistaId: especialista.id,
          estado: estado,
          aprobadoPor: adminId,
          observacion: observacion,
        );
  }

  Future<void> _revisarDocumento(
    DocumentoEspecialistaEntity documento,
    EstadoRevisionDocumento estado,
  ) async {
    final adminId = context.read<AuthCubit>().currentProfile?.id;
    if (adminId == null) return;

    String? observacion;
    if (estado == EstadoRevisionDocumento.rechazado) {
      observacion = await showDialog<String>(
        context: context,
        builder: (_) => _MotivoDialog(
          titulo: 'Rechazar documento',
          confirmar: 'Rechazar',
          hint: 'Motivo del rechazo (visible para el especialista)',
        ),
      );
      if (observacion == null || !mounted) return;
    }
    final motivoTrim = observacion?.trim();
    context.read<SpecialistsCubit>().revisarDocumento(
          documentoId: documento.id,
          estado: estado,
          observacion: (motivoTrim == null || motivoTrim.isEmpty)
              ? null
              : motivoTrim,
          revisadoPor: adminId,
        );
  }
}

class _VerificacionDeLicencias extends StatelessWidget {
  final List<EspecialistaEntity> especialistas;
  final List<MedicoRegenteEntity> medicosRegentes;
  final Map<String, List<DocumentoEspecialistaEntity>> documentosPorEspecialista;
  final Map<String, ContratoEntity?> contratosPorEspecialista;
  final Map<String, int> especialidadesCountPorEspecialista;
  final void Function(EspecialistaEntity) onAprobar;
  final void Function(EspecialistaEntity) onRechazar;
  final void Function(EspecialistaEntity) onBloquear;
  final void Function(String) onAprobarMedicoRegente;
  final void Function(DocumentoEspecialistaEntity, EstadoRevisionDocumento)
      onRevisarDocumento;

  const _VerificacionDeLicencias({
    required this.especialistas,
    required this.medicosRegentes,
    required this.documentosPorEspecialista,
    required this.contratosPorEspecialista,
    required this.especialidadesCountPorEspecialista,
    required this.onAprobar,
    required this.onRechazar,
    required this.onBloquear,
    required this.onAprobarMedicoRegente,
    required this.onRevisarDocumento,
  });

  @override
  Widget build(BuildContext context) {
    final pendientes = especialistas.where((e) => !e.isApproved).toList(growable: false);
    final medicosPendientes = medicosRegentes.where((m) => !m.activo).toList(growable: false);

    return RefreshIndicator(
      onRefresh: () async {
        await context.read<SpecialistsCubit>().loadAllEspecialistas();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${pendientes.length} pendiente(s) · ${especialistas.length} en total',
            style: const TextStyle(color: AppTheme.cMutedText),
          ),
          const SizedBox(height: 12),
          if (especialistas.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Aún no hay especialistas registrados.',
                  textAlign: TextAlign.center),
            )
          else
            for (final especialista in especialistas)
              _EspecialistaCard(
                especialista: especialista,
                medicosRegentes: medicosRegentes,
                documentos:
                    documentosPorEspecialista[especialista.id] ?? const [],
                contrato: contratosPorEspecialista[especialista.id],
                numeroEspecialidades:
                    especialidadesCountPorEspecialista[especialista.id] ?? 0,
                onAprobar: () => onAprobar(especialista),
                onRechazar: () => onRechazar(especialista),
                onBloquear: () => onBloquear(especialista),
                onRevisarDocumento: onRevisarDocumento,
              ),
          const SizedBox(height: 24),
          const Text('Médicos Regentes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            '${medicosPendientes.length} pendiente(s) de validación · '
            '${medicosRegentes.length} en total',
            style: const TextStyle(color: AppTheme.cMutedText),
          ),
          const SizedBox(height: 12),
          if (medicosRegentes.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Aún no hay médicos regentes registrados.',
                  textAlign: TextAlign.center),
            )
          else
            for (final medico in medicosRegentes)
              _MedicoRegenteCard(
                medico: medico,
                onAprobar: () => onAprobarMedicoRegente(medico.id),
              ),
        ],
      ),
    );
  }
}

class _MedicoRegenteCard extends StatelessWidget {
  final MedicoRegenteEntity medico;
  final VoidCallback onAprobar;

  const _MedicoRegenteCard({required this.medico, required this.onAprobar});

  @override
  Widget build(BuildContext context) {
    final validado = medico.activo;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(medico.nombre,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (validado ? AppTheme.cBrandGreen : Colors.orange)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Text(
                    validado ? 'ACTIVO' : 'PENDIENTE',
                    style: TextStyle(
                      color: validado ? AppTheme.cBrandGreen : Colors.orange,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            if (medico.numeroLicencia != null)
              Text('Licencia: ${medico.numeroLicencia}'),
            if (medico.telefono != null || medico.correo != null)
              Text(
                [medico.telefono, medico.correo]
                    .whereType<String>()
                    .join(' · '),
                style: const TextStyle(color: AppTheme.cMutedText, fontSize: 13),
              ),
            if (!validado) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onAprobar,
                icon: const Icon(Icons.verified_rounded),
                label: const Text('Aprobar médico regente'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.cBrandGreen,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EspecialistaCard extends StatelessWidget {
  final EspecialistaEntity especialista;
  final List<MedicoRegenteEntity> medicosRegentes;
  final List<DocumentoEspecialistaEntity> documentos;
  final ContratoEntity? contrato;
  final int numeroEspecialidades;
  final VoidCallback onAprobar;
  final VoidCallback onRechazar;
  final VoidCallback onBloquear;
  final void Function(DocumentoEspecialistaEntity, EstadoRevisionDocumento)
      onRevisarDocumento;

  const _EspecialistaCard({
    required this.especialista,
    required this.medicosRegentes,
    required this.documentos,
    required this.contrato,
    required this.numeroEspecialidades,
    required this.onAprobar,
    required this.onRechazar,
    required this.onBloquear,
    required this.onRevisarDocumento,
  });

  @override
  Widget build(BuildContext context) {
    final aprobado = especialista.isApproved;
    final expediente = ExpedienteEspecialista(
      documentos: documentos,
      medicoRegenteId: especialista.medicoRegenteId,
      medicosRegentes: medicosRegentes,
      numeroEspecialidades: numeroEspecialidades,
      contrato: contrato,
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    especialista.nombreUsuario ??
                        especialista.emailUsuario ??
                        'Especialista ${especialista.usuarioId}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                _Badge(especialista.estadoVerificacion),
              ],
            ),
            if (especialista.emailUsuario != null)
              Text(especialista.emailUsuario!,
                  style:
                      const TextStyle(color: AppTheme.cMutedText, fontSize: 13)),
            const SizedBox(height: 6),
            Text(
              especialista.numeroLicencia?.isEmpty == true ||
                      especialista.numeroLicencia == null
                  ? 'Licencia: no registrada'
                  : 'Licencia: ${especialista.numeroLicencia}',
            ),
            if (especialista.fechaSolicitudVerificacion != null)
              Text(
                'Solicitud: ${_formatFecha(especialista.fechaSolicitudVerificacion!)}',
                style:
                    const TextStyle(color: AppTheme.cMutedText, fontSize: 12),
              ),
            if (!aprobado && especialista.observacion != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Text(
                  'Motivo: ${especialista.observacion}',
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ),
            ],
            const SizedBox(height: 12),
            _DocumentosBloque(
              documentos: documentos,
              onRevisar: onRevisarDocumento,
            ),
            const SizedBox(height: 12),
            _ExpedienteChecklist(expediente: expediente),
            const SizedBox(height: 12),
            if (aprobado)
              const Row(
                children: [
                  Icon(Icons.check_circle, color: AppTheme.cBrandGreen, size: 18),
                  SizedBox(width: 6),
                  Text('Licencia verificada'),
                ],
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: expediente.cumple ? onAprobar : null,
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Aprobar'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.cBrandGreen,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onRechazar,
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Rechazar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                      ),
                    ),
                  ),
                ],
              ),
              if (!expediente.cumple) ...[
                const SizedBox(height: 8),
                Text(
                  'Aprobación disponible cuando el expediente esté completo '
                  '(falta: ${expediente.pendientes.join(', ')}).',
                  style: const TextStyle(
                      color: AppTheme.cMutedText, fontSize: 12),
                ),
              ],
            ],
            if (!aprobado) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onBloquear,
                icon: const Icon(Icons.block_rounded),
                label: const Text('Bloquear especialista'),
                style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatFecha(DateTime fecha) {
    final local = fecha.toLocal();
    return '${local.day}/${local.month}/${local.year}';
  }
}

class _ExpedienteChecklist extends StatelessWidget {
  final ExpedienteEspecialista expediente;
  const _ExpedienteChecklist({required this.expediente});

  @override
  Widget build(BuildContext context) {
    final items = [
      (expediente.documentosAprobados, 'Documentos obligatorios aprobados'),
      (expediente.medicoRegenteActivo, 'Médico regente activo'),
      (expediente.tieneEspecialidades, 'Al menos una especialidad'),
      (expediente.contratoFirmado, 'Contrato firmado'),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Expediente',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          for (final (cumplido, label) in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(
                    cumplido ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 16,
                    color:
                        cumplido ? AppTheme.cBrandGreen : AppTheme.cMutedText,
                  ),
                  const SizedBox(width: 6),
                  Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DocumentosBloque extends StatelessWidget {
  final List<DocumentoEspecialistaEntity> documentos;
  final void Function(DocumentoEspecialistaEntity, EstadoRevisionDocumento)
      onRevisar;

  const _DocumentosBloque({required this.documentos, required this.onRevisar});

  @override
  Widget build(BuildContext context) {
    if (documentos.isEmpty) {
      return const Text(
        'Sin documentos subidos',
        style: TextStyle(color: AppTheme.cMutedText, fontSize: 13),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Documentos',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        for (final doc in documentos)
          _DocumentoFila(documento: doc, onRevisar: onRevisar),
      ],
    );
  }
}

class _DocumentoFila extends StatelessWidget {
  final DocumentoEspecialistaEntity documento;
  final void Function(DocumentoEspecialistaEntity, EstadoRevisionDocumento)
      onRevisar;

  const _DocumentoFila({required this.documento, required this.onRevisar});

  @override
  Widget build(BuildContext context) {
    final aprobado = documento.isAprobado;
    final rechazado = documento.estadoRevision == EstadoRevisionDocumento.rechazado;
    final color = aprobado
        ? AppTheme.cBrandGreen
        : rechazado
            ? Colors.redAccent
            : AppTheme.cDeepAccent;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                aprobado
                    ? Icons.verified_rounded
                    : rechazado
                        ? Icons.cancel_outlined
                        : Icons.description_outlined,
                color: color,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${documento.tipoDocumento.toDb} · v${documento.versionDocumento}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Text(
                  documento.estadoRevision.toDb,
                  style: TextStyle(color: color, fontSize: 10),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Ver documento',
                icon: const Icon(Icons.visibility_outlined, size: 20),
                onPressed: () => _abrirDocumento(context, documento),
              ),
            ],
          ),
          if (rechazado && documento.observacionRevision != null)
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Text(
                'Motivo: ${documento.observacionRevision}',
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),
          if (!aprobado && !rechazado) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () =>
                      onRevisar(documento, EstadoRevisionDocumento.aprobado),
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Aprobar'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.cBrandGreen,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                TextButton.icon(
                  onPressed: () =>
                      onRevisar(documento, EstadoRevisionDocumento.rechazado),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Rechazar'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _abrirDocumento(
      BuildContext context, DocumentoEspecialistaEntity documento) async {
    final path = documento.urlArchivo;
    if (path == null || path.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este documento no tiene archivo adjunto.')),
      );
      return;
    }
    final url =
        await context.read<SpecialistsCubit>().generarUrlFirmadaDocumento(path);
    if (url == null || !context.mounted) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el documento.')),
        );
      }
    }
  }
}

class _MotivoDialog extends StatefulWidget {
  final String titulo;
  final String confirmar;
  final String hint;
  const _MotivoDialog({
    required this.titulo,
    required this.confirmar,
    required this.hint,
  });

  @override
  State<_MotivoDialog> createState() => _MotivoDialogState();
}

class _MotivoDialogState extends State<_MotivoDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titulo),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        maxLines: 3,
        maxLength: 500,
        decoration: InputDecoration(
          hintText: widget.hint,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _ctrl.text),
          child: Text(widget.confirmar),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final EstadoVerificacion estado;
  const _Badge(this.estado);

  @override
  Widget build(BuildContext context) {
    final Color color = switch (estado) {
      EstadoVerificacion.aprobado => AppTheme.cBrandGreen,
      EstadoVerificacion.rechazado ||
      EstadoVerificacion.bloqueado =>
        Colors.redAccent,
      EstadoVerificacion.enRevision => Colors.orange,
      EstadoVerificacion.pendiente => AppTheme.cDeepAccent,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Text(estado.toDb, style: TextStyle(color: color, fontSize: 11)),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
