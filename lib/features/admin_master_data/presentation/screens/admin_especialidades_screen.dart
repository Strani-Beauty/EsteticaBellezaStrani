import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import '../../domain/entities/especialidad_admin_entity.dart';
import '../cubits/admin_especialidades_cubit.dart';

/// Catálogo de especialidades (CRUD admin).
class AdminEspecialidadesScreen extends StatefulWidget {
  const AdminEspecialidadesScreen({super.key});

  @override
  State<AdminEspecialidadesScreen> createState() =>
      _AdminEspecialidadesScreenState();
}

class _AdminEspecialidadesScreenState extends State<AdminEspecialidadesScreen> {
  bool _cargado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_cargado) {
      _cargado = true;
      context.read<AdminEspecialidadesCubit>().load();
    }
  }

  Future<void> _editar(EspecialidadAdminEntity? item) async {
    final nombreCtrl = TextEditingController(text: item?.nombre ?? '');
    final descCtrl = TextEditingController(text: item?.descripcion ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item == null ? 'Nueva especialidad' : 'Editar especialidad'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: 'Descripción'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (nombreCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El nombre es obligatorio.')),
      );
      return;
    }
    final guardado = await context.read<AdminEspecialidadesCubit>().guardar(
          id: item?.id,
          nombre: nombreCtrl.text.trim(),
          descripcion:
              descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
          activo: item?.activo ?? true,
        );
    if (guardado && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Especialidad guardada.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Especialidades'),
        backgroundColor: AppTheme.cDeepAccent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.cDeepAccent,
        foregroundColor: Colors.white,
        onPressed: () => _editar(null),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nueva'),
      ),
      body: BlocConsumer<AdminEspecialidadesCubit, AdminEspecialidadesState>(
        listener: (context, state) {
          if (state is AdminEspecialidadesError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        builder: (context, state) {
          if (state is AdminEspecialidadesLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.cDeepAccent),
            );
          }
          if (state is AdminEspecialidadesError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.redAccent, size: 44),
                    const SizedBox(height: 12),
                    Text(state.message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.cMutedText)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.cDeepAccent),
                      onPressed: () =>
                          context.read<AdminEspecialidadesCubit>().load(),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (state is! AdminEspecialidadesLoaded) {
            return const SizedBox.shrink();
          }
          return RefreshIndicator(
            onRefresh: () async =>
                context.read<AdminEspecialidadesCubit>().load(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.items.length,
              itemBuilder: (context, i) {
                final item = state.items[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: const Icon(Icons.category_outlined,
                        color: AppTheme.cDeepAccent),
                    title: Text(item.nombre,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      item.descripcion ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.cMutedText),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: item.activo,
                          activeTrackColor: AppTheme.cDeepAccent,
                          onChanged: (v) => context
                              .read<AdminEspecialidadesCubit>()
                              .setActivo(item.id, v),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          onPressed: () => _editar(item),
                          tooltip: 'Editar',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
