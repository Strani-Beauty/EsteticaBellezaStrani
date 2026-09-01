import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import 'package:esteticaybellezastrani/features/admin_users/domain/entities/paciente_admin_entity.dart';
import 'package:esteticaybellezastrani/features/admin_users/presentation/cubits/admin_pacientes_cubit.dart';
import 'package:esteticaybellezastrani/features/auth_users/presentation/cubits/auth_cubit.dart';

/// Panel admin: consulta y gestión (activar/desactivar) de pacientes.
class AdminPacientesScreen extends StatefulWidget {
  const AdminPacientesScreen({super.key});

  @override
  State<AdminPacientesScreen> createState() => _AdminPacientesScreenState();
}

class _AdminPacientesScreenState extends State<AdminPacientesScreen> {
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      context.read<AdminPacientesCubit>().loadPacientes();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Pacientes'),
      ),
      body: BlocConsumer<AdminPacientesCubit, AdminPacientesState>(
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
                    onPressed: () =>
                        context.read<AdminPacientesCubit>().loadPacientes(),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }
          if (state is AdminPacientesLoaded) {
            final pacientes = state.pacientes;
            if (pacientes.isEmpty) {
              return const Center(child: Text('No hay pacientes registrados.'));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: pacientes.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) =>
                  _PacienteTile(pacientes[index]),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _PacienteTile extends StatelessWidget {
  final PacienteAdminEntity paciente;
  const _PacienteTile(this.paciente);

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<AuthCubit>().currentProfile?.id;
    final esAuto = currentUserId == paciente.usuarioId;
    final canToggle = !esAuto;

    return Card(
      elevation: 0,
      color: AppTheme.cSurface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        side: const BorderSide(color: Colors.black12),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.cPastelBlue,
          child: const Icon(Icons.person_outline_rounded,
              color: AppTheme.cDeepAccent),
        ),
        title: Text(
          paciente.fullName == null || paciente.fullName!.isEmpty
              ? (paciente.email ?? 'Paciente')
              : '${paciente.fullName} (${paciente.email ?? ''})',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              fontWeight: FontWeight.w600, color: AppTheme.cDarkText),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            'Paciente${esAuto ? ' · tú' : ''}',
            style: const TextStyle(
                fontSize: 12, color: AppTheme.cMutedText),
          ),
        ),
        trailing: canToggle
            ? Switch(
                value: paciente.profileActivo,
                onChanged: (value) => context
                    .read<AdminPacientesCubit>()
                    .setActivo(paciente.usuarioId, value),
              )
            : null,
      ),
    );
  }
}