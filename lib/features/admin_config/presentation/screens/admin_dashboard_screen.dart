import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import 'package:esteticaybellezastrani/features/auth_users/presentation/cubits/auth_cubit.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/entities/especialista_entity.dart';
import 'package:esteticaybellezastrani/features/specialists/presentation/cubits/specialists_cubit.dart';

/// Panel de administración — gestión de verificación de licencias.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
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
    final profile = context.watch<AuthCubit>().currentProfile;
    return Scaffold(
      appBar: AppBar(
        title: Text('Panel Admin — ${profile?.fullName ?? 'Administrador'}'),
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
              onAprobar: (especialista) => _cambiarEstado(
                especialista,
                EstadoVerificacion.aprobado,
              ),
              onRechazar: (especialista) => _cambiarEstado(
                especialista,
                EstadoVerificacion.rechazado,
              ),
              onBloquear: (especialista) => _cambiarEstado(
                especialista,
                EstadoVerificacion.bloqueado,
              ),
            );
          },
        ),
      ),
    );
  }

  void _cambiarEstado(
    EspecialistaEntity especialista,
    EstadoVerificacion estado,
  ) {
    final adminId = context.read<AuthCubit>().currentProfile?.id;
    if (adminId == null) return;
    context.read<SpecialistsCubit>().updateVerificacion(
          especialistaId: especialista.id,
          estado: estado,
          aprobadoPor: adminId,
        );
  }
}

class _VerificacionDeLicencias extends StatelessWidget {
  final List<EspecialistaEntity> especialistas;
  final void Function(EspecialistaEntity) onAprobar;
  final void Function(EspecialistaEntity) onRechazar;
  final void Function(EspecialistaEntity) onBloquear;

  const _VerificacionDeLicencias({
    required this.especialistas,
    required this.onAprobar,
    required this.onRechazar,
    required this.onBloquear,
  });

  @override
  Widget build(BuildContext context) {
    final pendientes =
        especialistas.where((e) => !e.isApproved).toList(growable: false);

    return RefreshIndicator(
      onRefresh: () async {
        await context.read<SpecialistsCubit>().loadAllEspecialistas();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Verificación de Licencias',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
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
                onAprobar: () => onAprobar(especialista),
                onRechazar: () => onRechazar(especialista),
                onBloquear: () => onBloquear(especialista),
              ),
        ],
      ),
    );
  }
}

class _EspecialistaCard extends StatelessWidget {
  final EspecialistaEntity especialista;
  final VoidCallback onAprobar;
  final VoidCallback onRechazar;
  final VoidCallback onBloquear;

  const _EspecialistaCard({
    required this.especialista,
    required this.onAprobar,
    required this.onRechazar,
    required this.onBloquear,
  });

  @override
  Widget build(BuildContext context) {
    final aprobado = especialista.isApproved;
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
              Text(
                especialista.emailUsuario!,
                style: const TextStyle(color: AppTheme.cMutedText, fontSize: 13),
              ),
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
                style: const TextStyle(color: AppTheme.cMutedText, fontSize: 12),
              ),
            const SizedBox(height: 12),
            if (aprobado)
              const Row(
                children: [
                  Icon(Icons.check_circle, color: AppTheme.cBrandGreen, size: 18),
                  SizedBox(width: 6),
                  Text('Licencia verificada'),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onAprobar,
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
