import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/entities/medico_regente_entity.dart';
import '../cubits/admin_medicos_regentes_cubit.dart';

/// Médicos Regentes — registro y validación (Datos Maestros).
class AdminMedicosRegentesScreen extends StatefulWidget {
  const AdminMedicosRegentesScreen({super.key});

  @override
  State<AdminMedicosRegentesScreen> createState() =>
      _AdminMedicosRegentesScreenState();
}

class _AdminMedicosRegentesScreenState extends State<AdminMedicosRegentesScreen> {
  bool _cargado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_cargado) {
      _cargado = true;
      context.read<AdminMedicosRegentesCubit>().load();
    }
  }

  Future<void> _crear() async {
    final nombreCtrl = TextEditingController();
    final licenciaCtrl = TextEditingController();
    final telefonoCtrl = TextEditingController();
    final correoCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo médico regente'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            TextField(
              controller: licenciaCtrl,
              decoration: const InputDecoration(labelText: 'Número de licencia'),
            ),
            TextField(
              controller: telefonoCtrl,
              decoration: const InputDecoration(labelText: 'Teléfono'),
            ),
            TextField(
              controller: correoCtrl,
              decoration: const InputDecoration(labelText: 'Correo'),
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
            child: const Text('Registrar'),
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
    final creado = await context.read<AdminMedicosRegentesCubit>().crear(
          nombre: nombreCtrl.text.trim(),
          numeroLicencia:
              licenciaCtrl.text.trim().isEmpty ? null : licenciaCtrl.text.trim(),
          telefono:
              telefonoCtrl.text.trim().isEmpty ? null : telefonoCtrl.text.trim(),
          correo: correoCtrl.text.trim().isEmpty ? null : correoCtrl.text.trim(),
        );
    if (creado && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Médico regente registrado (PENDIENTE).')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Médicos Regentes'),
        backgroundColor: AppTheme.cDeepAccent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.cDeepAccent,
        foregroundColor: Colors.white,
        onPressed: _crear,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Registrar'),
      ),
      body: BlocConsumer<AdminMedicosRegentesCubit, AdminMedicosRegentesState>(
        listener: (context, state) {
          if (state is AdminMedicosRegentesError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        builder: (context, state) {
          if (state is AdminMedicosRegentesLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.cDeepAccent),
            );
          }
          if (state is AdminMedicosRegentesError) {
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
                          context.read<AdminMedicosRegentesCubit>().load(),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (state is! AdminMedicosRegentesLoaded) {
            return const SizedBox.shrink();
          }
          return RefreshIndicator(
            onRefresh: () async =>
                context.read<AdminMedicosRegentesCubit>().load(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.items.length,
              itemBuilder: (context, i) => _MedicoTile(
                medico: state.items[i],
                onAprobar: () => context
                    .read<AdminMedicosRegentesCubit>()
                    .aprobar(state.items[i].id),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MedicoTile extends StatelessWidget {
  final MedicoRegenteEntity medico;
  final VoidCallback onAprobar;

  const _MedicoTile({required this.medico, required this.onAprobar});

  @override
  Widget build(BuildContext context) {
    final validado = medico.activo;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const Icon(Icons.medical_information_outlined,
            color: AppTheme.cDeepAccent),
        title: Text(medico.nombre,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          [
            if (medico.numeroLicencia != null) 'Lic: ${medico.numeroLicencia}',
            medico.telefono,
            medico.correo,
          ].whereType<String>().join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: AppTheme.cMutedText),
        ),
        trailing: validado
            ? const Chip(
                label: Text('ACTIVO'),
                backgroundColor: AppTheme.cBrandGreen,
                labelStyle: TextStyle(color: Colors.white, fontSize: 11),
              )
            : FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.cBrandGreen,
                ),
                onPressed: onAprobar,
                child: const Text('Aprobar'),
              ),
      ),
    );
  }
}
