import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import '../../domain/entities/documento_especialista_entity.dart';
import '../cubits/specialists_cubit.dart';
import 'documentos_requeridos.dart';

/// Sección de documentos del especialista: subida de archivos para revisión
/// y vista de cada documento vía URL firmada (bucket privado).
class DocumentosSection extends StatelessWidget {
  final String especialistaId;
  final List<DocumentoEspecialistaEntity> documentos;

  /// true cuando el especialista ya está verificado: solo consulta, no sube.
  final bool verificado;

  const DocumentosSection({
    super.key,
    required this.especialistaId,
    required this.documentos,
    this.verificado = false,
  });

  @override
  Widget build(BuildContext context) {
    final tiposSubibles = tiposSubiblesDocumentos(documentos);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Documentos',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                if (!verificado && tiposSubibles.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => _showSubirDialog(context, tiposSubibles),
                    icon: const Icon(Icons.upload_file_rounded, size: 18),
                    label: const Text('Subir'),
                  ),
              ],
            ),
            if (documentos.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No has subido documentos todavía.',
                    style: TextStyle(color: AppTheme.cMutedText)),
              )
            else
              ...documentos.map((doc) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: _DocumentoFila(
                      documento: doc,
                      onVer: () => _abrirDocumento(context, doc),
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Future<void> _showSubirDialog(
    BuildContext context,
    Set<TipoDocumento> tiposSubibles,
  ) async {
    if (tiposSubibles.isEmpty) return;
    final tipos = tiposSubibles.toList()
      ..sort((a, b) => (b.index).compareTo(a.index));
    final tipo = await showDialog<TipoDocumento>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Tipo de documento'),
        children: tipos
            .map((t) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, t),
                  child: Text(_labels[t] ?? t.toDb),
                ))
            .toList(),
      ),
    );
    if (tipo == null || !context.mounted) return;

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.any,
    );
    final picked = result?.files.single;
    if (picked == null || picked.bytes == null || !context.mounted) return;

    context.read<SpecialistsCubit>().uploadDocument(
          especialistaId: especialistaId,
          tipoDocumento: tipo,
          bytes: Uint8List.fromList(picked.bytes!),
          nombreArchivo: picked.name,
        );
  }

  Future<void> _abrirDocumento(
      BuildContext context, DocumentoEspecialistaEntity documento) async {
    final path = documento.urlArchivo;
    if (path == null || path.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Este documento no tiene archivo adjunto.')),
      );
      return;
    }
    final url = await context
        .read<SpecialistsCubit>()
        .generarUrlFirmadaDocumento(path);
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

class _DocumentoFila extends StatelessWidget {
  final DocumentoEspecialistaEntity documento;
  final VoidCallback onVer;

  const _DocumentoFila({required this.documento, required this.onVer});

  @override
  Widget build(BuildContext context) {
    final aprobado = documento.isAprobado;
    final rechazado =
        documento.estadoRevision == EstadoRevisionDocumento.rechazado;
    final color = aprobado
        ? AppTheme.cBrandGreen
        : rechazado
            ? Colors.redAccent
            : AppTheme.cMutedText;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(
        aprobado
            ? Icons.verified_rounded
            : rechazado
                ? Icons.cancel_outlined
                : Icons.description_outlined,
        color: color,
      ),
      title: Text(_labels[documento.tipoDocumento] ?? documento.tipoDocumento.toDb),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            documento.estadoRevision.toDb,
            style: TextStyle(fontSize: 12, color: color),
          ),
          if (rechazado && documento.observacionRevision != null)
            Text(
              'Motivo: ${documento.observacionRevision}',
              style: const TextStyle(fontSize: 12, color: Colors.redAccent),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('v${documento.versionDocumento}'),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Ver documento',
            icon: const Icon(Icons.visibility_outlined, size: 20),
            onPressed: onVer,
          ),
        ],
      ),
    );
  }
}

const Map<TipoDocumento, String> _labels = {
  TipoDocumento.identificacion: 'Identificación oficial',
  TipoDocumento.licencia: 'Licencia profesional',
  TipoDocumento.diploma: 'Diploma',
  TipoDocumento.certificacion: 'Certificación',
  TipoDocumento.otro: 'Otro',
};