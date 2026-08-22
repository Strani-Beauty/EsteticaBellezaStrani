import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import '../../domain/entities/config_sistema_entity.dart';
import '../cubits/admin_configuracion_cubit.dart';

/// Configuración del sistema — listar y editar claves (`configuracion_sistema`).
class AdminConfiguracionScreen extends StatefulWidget {
  const AdminConfiguracionScreen({super.key});

  @override
  State<AdminConfiguracionScreen> createState() =>
      _AdminConfiguracionScreenState();
}

class _AdminConfiguracionScreenState extends State<AdminConfiguracionScreen> {
  bool _cargado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_cargado) {
      _cargado = true;
      context.read<AdminConfiguracionCubit>().load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Configuración del Sistema'),
        backgroundColor: AppTheme.cDeepAccent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: BlocConsumer<AdminConfiguracionCubit, AdminConfiguracionState>(
        listener: (context, state) {
          if (state is AdminConfiguracionSaved) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
            context.read<AdminConfiguracionCubit>().clearSaved();
          } else if (state is AdminConfiguracionError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        builder: (context, state) {
          if (state is AdminConfiguracionLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.cDeepAccent),
            );
          }
          if (state is AdminConfiguracionError) {
            return _ErrorView(
              message: state.message,
              onRetry: () => context.read<AdminConfiguracionCubit>().load(),
            );
          }
          if (state is! AdminConfiguracionLoaded) {
            return const SizedBox.shrink();
          }
          return RefreshIndicator(
            onRefresh: () async {
              context.read<AdminConfiguracionCubit>().load();
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.items.length,
              itemBuilder: (context, i) => _ConfigTile(
                item: state.items[i],
                onEdit: () => _editar(state.items[i]),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _editar(ConfigSistemaEntity item) async {
    final ctrl = TextEditingController(text: item.valor);
    final nuevo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item.clave),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.descripcion != null) ...[
              Text(item.descripcion!,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.cMutedText)),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.text,
              decoration: InputDecoration(
                labelText: 'Valor (${item.tipoDato})',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (nuevo == null || !mounted) return;
    await context
        .read<AdminConfiguracionCubit>()
        .update(item.clave, nuevo.trim());
  }
}

class _ConfigTile extends StatelessWidget {
  final ConfigSistemaEntity item;
  final VoidCallback onEdit;

  const _ConfigTile({required this.item, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const Icon(Icons.tune_rounded, color: AppTheme.cDeepAccent),
        title: Text(item.clave,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(
          '${item.valor} · ${item.tipoDato}${item.descripcion != null ? ' — ${item.descripcion}' : ''}',
          style: const TextStyle(fontSize: 12, color: AppTheme.cMutedText),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit_outlined, size: 20),
          onPressed: onEdit,
          tooltip: 'Editar',
        ),
      ),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 44),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.cMutedText)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.cDeepAccent),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
