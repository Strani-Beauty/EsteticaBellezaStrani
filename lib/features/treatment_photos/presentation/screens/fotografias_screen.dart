import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import 'package:esteticaybellezastrani/features/treatment_photos/domain/entities/fotografia_tratamiento_entity.dart';
import 'package:esteticaybellezastrani/features/treatment_photos/presentation/cubits/treatment_photos_cubit.dart';

/// Galería de fotografías de un tratamiento (PRE / POST / OTRO).
/// Permite ver las fotos registradas y añadir una nueva por URL.
class FotografiasScreen extends StatefulWidget {
  final String tratamientoId;

  const FotografiasScreen({super.key, required this.tratamientoId});

  @override
  State<FotografiasScreen> createState() => _FotografiasScreenState();
}

class _FotografiasScreenState extends State<FotografiasScreen> {
  final _urlCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  TipoFotografia _tipo = TipoFotografia.pre;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TreatmentPhotosCubit>().loadFotografias(widget.tratamientoId);
    });
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _addByUrl() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa la URL de la fotografía.')),
      );
      return;
    }
    await context.read<TreatmentPhotosCubit>().registrarPorUrl(
          tratamientoId: widget.tratamientoId,
          tipoFotografia: _tipo,
          archivoUrl: url,
          descripcion: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
        );
    _urlCtrl.clear();
    _descCtrl.clear();
  }

  void _confirmDelete(FotografiaTratamientoEntity foto) {
    final cubit = context.read<TreatmentPhotosCubit>();
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        title: const Text('Eliminar fotografía'),
        content: const Text('¿Eliminar esta fotografía del registro del tratamiento?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cDeepAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    ).then((ok) {
      if (ok == true) {
        cubit.eliminarFotografia(foto.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Fotografías del Tratamiento'),
        backgroundColor: AppTheme.cDeepAccent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: BlocBuilder<TreatmentPhotosCubit, TreatmentPhotosState>(
        builder: (context, state) {
          if (state is TreatmentPhotosLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.cDeepAccent),
            );
          }
          if (state is TreatmentPhotosError && state is! TreatmentPhotosLoaded) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 44),
                    const SizedBox(height: 12),
                    Text(
                      state.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.cMutedText),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => context
                          .read<TreatmentPhotosCubit>()
                          .loadFotografias(widget.tratamientoId),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }

          final fotos = state is TreatmentPhotosLoaded ? state.fotografias : const <FotografiaTratamientoEntity>[];
          final uploading = state is TreatmentPhotosLoaded && state.uploading;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildHeader(),
              const SizedBox(height: 14),
              _buildAddForm(),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Icon(Icons.photo_library_outlined, color: AppTheme.cDeepAccent, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Registradas (${fotos.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.cDeepAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (fotos.isEmpty && !uploading)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.add_photo_alternate_outlined, color: AppTheme.cMutedText, size: 40),
                      SizedBox(height: 8),
                      Text(
                        'Aún no hay fotografías para este tratamiento.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.cMutedText),
                      ),
                    ],
                  ),
                )
              else
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.86,
                  children: [
                    ...fotos.map((f) => _buildPhotoCard(f)),
                    if (uploading)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(color: AppTheme.cDeepAccent),
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cPastelPurple,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: AppTheme.cDeepAccent,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.photo_camera_outlined, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Evidencia Fotográfica',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.cDarkText),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tratamiento ID: ${widget.tratamientoId}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.cMutedText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddForm() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Añadir fotografía por URL',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.cDarkText),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<TipoFotografia>(
            initialValue: _tipo,
            decoration: AppTheme.fieldDecoration(label: 'Tipo'),
            items: const [
              DropdownMenuItem(value: TipoFotografia.pre, child: Text('PRE (antes)')),
              DropdownMenuItem(value: TipoFotografia.post, child: Text('POST (después)')),
              DropdownMenuItem(value: TipoFotografia.otro, child: Text('OTRO')),
            ],
            onChanged: (v) => setState(() => _tipo = v ?? TipoFotografia.pre),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _urlCtrl,
            decoration: AppTheme.fieldDecoration(
              label: 'URL del archivo en Storage',
              hint: 'https://...',
              prefix: const Icon(Icons.link, color: AppTheme.cDeepAccent),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _descCtrl,
            maxLines: 2,
            decoration: AppTheme.fieldDecoration(
              label: 'Descripción (opcional)',
              hint: 'Ej: Sesión 1, vista frontal',
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cDeepAccent),
              onPressed: _addByUrl,
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
              label: const Text('Registrar Fotografía'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoCard(FotografiaTratamientoEntity foto) {
    final tipoLabel = switch (foto.tipoFotografia) {
      TipoFotografia.pre => 'PRE',
      TipoFotografia.post => 'POST',
      TipoFotografia.otro => 'OTRO',
    };

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: Colors.grey.shade300),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _previewPhoto(foto),
              child: CachedNetworkImage(
                imageUrl: foto.archivoUrl,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(
                  color: Colors.grey.shade200,
                  child: const Center(
                    child: CircularProgressIndicator(color: AppTheme.cDeepAccent, strokeWidth: 2),
                  ),
                ),
                errorWidget: (_, _, _) => Container(
                  color: Colors.grey.shade200,
                  child: const Center(
                    child: Icon(Icons.broken_image_outlined, color: AppTheme.cMutedText, size: 34),
                  ),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            color: AppTheme.cPastelPurple,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.cDeepAccent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    tipoLabel,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                const Spacer(),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                  onPressed: () => _confirmDelete(foto),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _previewPhoto(FotografiaTratamientoEntity foto) {
    final size = MediaQuery.of(context).size;
    final dialogMaxHeight = size.height * 0.85;
    final imgMaxHeight = (size.height * 0.6).clamp(120.0, 480.0);
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: dialogMaxHeight),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: imgMaxHeight),
                    child: CachedNetworkImage(
                      imageUrl: foto.archivoUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => const Center(
                        child: CircularProgressIndicator(color: AppTheme.cDeepAccent),
                      ),
                      errorWidget: (_, _, _) => const Center(
                        child: Icon(Icons.broken_image_outlined, color: AppTheme.cMutedText, size: 48),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: AppTheme.cPastelPurple,
                  child: Text(
                    '${foto.descripcion?.isNotEmpty == true ? foto.descripcion! : 'Fotografía de tratamiento'} — ${foto.fechaCaptura.toLocal().toString().substring(0, 16)}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.cDarkText),
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