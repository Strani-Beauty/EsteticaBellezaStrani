import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import '../../domain/entities/rol_entity.dart';
import '../cubits/admin_roles_cubit.dart';

/// Roles y Permisos — catálogo RBAC del sistema.
class AdminRolesScreen extends StatefulWidget {
  const AdminRolesScreen({super.key});

  @override
  State<AdminRolesScreen> createState() => _AdminRolesScreenState();
}

class _AdminRolesScreenState extends State<AdminRolesScreen> {
  bool _cargado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_cargado) {
      _cargado = true;
      context.read<AdminRolesCubit>().load();
    }
  }

  Future<void> _editarRol(RolEntity? rol) async {
    final nombreCtrl = TextEditingController(text: rol?.nombre ?? '');
    final codigoCtrl = TextEditingController(text: rol?.codigo ?? '');
    final descCtrl = TextEditingController(text: rol?.descripcion ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(rol == null ? 'Nuevo rol' : 'Editar rol'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            TextField(
              controller: codigoCtrl,
              decoration: const InputDecoration(labelText: 'Código'),
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
        const SnackBar(content: Text('El nombre del rol es obligatorio.')),
      );
      return;
    }
    final guardado = await context.read<AdminRolesCubit>().guardarRol(
          id: rol?.id,
          nombre: nombreCtrl.text.trim(),
          codigo: codigoCtrl.text.trim().isEmpty
              ? null
              : codigoCtrl.text.trim(),
          descripcion: descCtrl.text.trim().isEmpty
              ? null
              : descCtrl.text.trim(),
          activo: rol?.activo ?? true,
        );
    if (guardado && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rol guardado.')),
      );
    }
  }

  Future<void> _agregarPermiso(
      AdminRolesLoaded state, RolEntity rol) async {
    final disponibles = state.permisos
        .where((p) => !rol.permisos.any((rp) => rp.id == p.id))
        .toList();
    final permiso = await showModalBottomSheet<PermisoEntity>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
      ),
      builder: (ctx) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Agregar permiso',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (disponibles.isEmpty)
              const Text('Todos los permisos ya están asignados.',
                  style: TextStyle(color: AppTheme.cMutedText))
            else
              for (final p in disponibles)
                ListTile(
                  leading: const Icon(Icons.lock_open_outlined,
                      color: AppTheme.cDeepAccent),
                  title: Text(p.nombre,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${p.modulo ?? ''} · ${p.codigo}',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.cMutedText)),
                  onTap: () => Navigator.of(ctx).pop(p),
                ),
          ],
        ),
      ),
    );
    if (permiso == null || !mounted) return;
    await context.read<AdminRolesCubit>().asignarPermiso(rol.id, permiso.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Roles y Permisos'),
        backgroundColor: AppTheme.cDeepAccent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.cDeepAccent,
        foregroundColor: Colors.white,
        onPressed: () => _editarRol(null),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo rol'),
      ),
      body: BlocConsumer<AdminRolesCubit, AdminRolesState>(
        listener: (context, state) {
          if (state is AdminRolesError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        builder: (context, state) {
          if (state is AdminRolesLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.cDeepAccent),
            );
          }
          if (state is AdminRolesError) {
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
                          context.read<AdminRolesCubit>().load(),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (state is! AdminRolesLoaded) {
            return const SizedBox.shrink();
          }
          return RefreshIndicator(
            onRefresh: () async => context.read<AdminRolesCubit>().load(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.roles.length,
              itemBuilder: (context, i) => _RolCard(
                rol: state.roles[i],
                state: state,
                onEdit: () => _editarRol(state.roles[i]),
                onToggleActivo: (v) =>
                    context.read<AdminRolesCubit>().setActivo(state.roles[i].id, v),
                onAddPermiso: () => _agregarPermiso(state, state.roles[i]),
                onRemovePermiso: (permisoId) => context
                    .read<AdminRolesCubit>()
                    .quitarPermiso(state.roles[i].id, permisoId),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RolCard extends StatelessWidget {
  final RolEntity rol;
  final AdminRolesLoaded state;
  final VoidCallback onEdit;
  final ValueChanged<bool> onToggleActivo;
  final VoidCallback onAddPermiso;
  final ValueChanged<int> onRemovePermiso;

  const _RolCard({
    required this.rol,
    required this.state,
    required this.onEdit,
    required this.onToggleActivo,
    required this.onAddPermiso,
    required this.onRemovePermiso,
  });

  @override
  Widget build(BuildContext context) {
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
                  child: Text(rol.nombre,
                      style:
                          const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                ),
                Switch(
                  value: rol.activo,
                  onChanged: onToggleActivo,
                  activeTrackColor: AppTheme.cDeepAccent,
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: onEdit,
                  tooltip: 'Editar',
                ),
              ],
            ),
            if (rol.codigo != null || rol.descripcion != null)
              Text(
                [rol.codigo, rol.descripcion].whereType<String>().join(' · '),
                style:
                    const TextStyle(color: AppTheme.cMutedText, fontSize: 12),
              ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in rol.permisos)
                  Chip(
                    label: Text(p.nombre, style: const TextStyle(fontSize: 12)),
                    deleteIcon: const Icon(Icons.close_rounded, size: 16),
                    onDeleted: () => onRemovePermiso(p.id),
                    backgroundColor: AppTheme.cPastelPurple.withValues(alpha: 0.4),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Permiso', style: TextStyle(fontSize: 12)),
                  onPressed: onAddPermiso,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
