import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:esteticaybellezastrani/app/config/app_routes.dart';
import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import 'package:esteticaybellezastrani/features/admin_users/domain/entities/paciente_admin_entity.dart';
import 'package:esteticaybellezastrani/features/admin_users/presentation/cubits/admin_pacientes_cubit.dart';

/// Panel admin: expediente de salud (ePHI/HIPAA). Lista los pacientes con un
/// buscador; al tocar uno se abre el detalle con las evaluaciones y el PDF.
class AdminExpedienteSaludScreen extends StatefulWidget {
  const AdminExpedienteSaludScreen({super.key});

  @override
  State<AdminExpedienteSaludScreen> createState() =>
      _AdminExpedienteSaludScreenState();
}

class _AdminExpedienteSaludScreenState extends State<AdminExpedienteSaludScreen> {
  bool _loaded = false;
  final TextEditingController _buscarCtrl = TextEditingController();
  String _filtro = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      context.read<AdminPacientesCubit>().loadPacientes();
    }
  }

  @override
  void dispose() {
    _buscarCtrl.dispose();
    super.dispose();
  }

  List<PacienteAdminEntity> _filtrar(List<PacienteAdminEntity> pacientes) {
    final q = _filtro.trim().toLowerCase();
    if (q.isEmpty) return pacientes;
    return [
      for (final p in pacientes)
        if ((p.fullName?.toLowerCase().contains(q) ?? false) ||
            (p.email?.toLowerCase().contains(q) ?? false))
          p,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expedientes de Salud'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _buscarCtrl,
              onChanged: (value) => setState(() => _filtro = value),
              decoration: AppTheme.fieldDecoration(
                label: 'Buscar paciente',
                hint: 'Nombre o correo del paciente',
                prefix: const Icon(Icons.search_rounded,
                    color: AppTheme.cDeepAccent),
              ),
            ),
          ),
          Expanded(
            child: BlocConsumer<AdminPacientesCubit, AdminPacientesState>(
              listener: (context, state) {
                if (state is AdminPacientesError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.message),
                      backgroundColor: AppTheme.cError,
                    ),
                  );
                }
              },
              builder: (context, state) {
                if (state is AdminPacientesLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state is AdminPacientesError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(state.message,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppTheme.cError)),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () => context
                              .read<AdminPacientesCubit>()
                              .loadPacientes(),
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  );
                }
                if (state is AdminPacientesLoaded) {
                  final pacientes = _filtrar(state.pacientes);
                  if (pacientes.isEmpty) {
                    return Center(
                      child: Text(
                        state.pacientes.isEmpty
                            ? 'No hay pacientes registrados.'
                            : 'Sin resultados para la búsqueda.',
                        style: const TextStyle(color: AppTheme.cMutedText),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: pacientes.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final p = pacientes[index];
                      return Card(
                        elevation: 0,
                        color: AppTheme.cSurface,
                        margin: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSm),
                          side: const BorderSide(color: Colors.black12),
                        ),
                        child: ListTile(
                          onTap: () => context.push(
                            AppRoutes.adminExpedienteSaludPaciente,
                            extra: p,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.cPastelBlue,
                            child: const Icon(Icons.folder_shared_rounded,
                                color: AppTheme.cDeepAccent),
                          ),
                          title: Text(
                            p.fullName == null || p.fullName!.isEmpty
                                ? (p.email ?? 'Paciente')
                                : p.fullName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.cDarkText),
                          ),
                          subtitle: Text(
                            p.email ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.cMutedText),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded,
                              color: AppTheme.cDeepAccent),
                        ),
                      );
                    },
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }
}