import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import '../../domain/entities/documento_especialista_entity.dart';
import '../cubits/specialists_cubit.dart';

/// Sección de documentos del especialista con registro para revisión.
class DocumentosSection extends StatelessWidget {
  final String especialistaId;
  final List<DocumentoEspecialistaEntity> documentos;

  const DocumentosSection({
    super.key,
    required this.especialistaId,
    required this.documentos,
  });

  @override
  Widget build(BuildContext context) {
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
                TextButton.icon(
                  onPressed: () => _showRegisterDialog(context),
                  icon: const Icon(Icons.upload_file_rounded, size: 18),
                  label: const Text('Subir'),
                ),
              ],
            ),
            if (documentos.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No has registrado documentos todavía.',
                    style: TextStyle(color: AppTheme.cMutedText)),
              )
            else
              ...documentos.map((doc) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Icon(
                      doc.isAprobado
                          ? Icons.verified_rounded
                          : Icons.description_outlined,
                      color: doc.isAprobado
                          ? AppTheme.cBrandGreen
                          : AppTheme.cMutedText,
                    ),
                    title: Text(doc.tipoDocumento.toDb),
                    subtitle: Text(
                      doc.estadoRevision.toDb,
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Text('v${doc.versionDocumento}'),
                  )),
          ],
        ),
      ),
    );
  }

  Future<void> _showRegisterDialog(BuildContext context) async {
    final tipo = await showDialog<TipoDocumento>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Tipo de documento'),
        children: TipoDocumento.values
            .map((t) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, t),
                  child: Text(t.toDb),
                ))
            .toList(),
      ),
    );
    if (tipo == null || !context.mounted) return;

    context.read<SpecialistsCubit>().registerDocument(
          especialistaId: especialistaId,
          tipoDocumento: tipo,
        );
  }
}