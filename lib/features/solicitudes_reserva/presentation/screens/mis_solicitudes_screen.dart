import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import 'package:esteticaybellezastrani/app/core/di/injection.dart';
import 'package:esteticaybellezastrani/features/auth_users/presentation/cubits/auth_cubit.dart';
import 'package:esteticaybellezastrani/features/calificaciones/domain/usecases/registrar_evaluacion.dart';
import 'package:esteticaybellezastrani/features/calificaciones/presentation/widgets/rating_dialog.dart';
import '../../domain/entities/seguimiento_solicitud_entity.dart';
import '../cubits/mis_solicitudes_cubit.dart';

/// Seguimiento del paciente: lista sus solicitudes con estado, servicios,
/// obligación de pago y cita asignada (si existe).
class MisSolicitudesScreen extends StatefulWidget {
  const MisSolicitudesScreen({super.key});

  @override
  State<MisSolicitudesScreen> createState() => _MisSolicitudesScreenState();
}

class _MisSolicitudesScreenState extends State<MisSolicitudesScreen> {
  bool _cargado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_cargado) {
      _cargado = true;
      final profileId = context.read<AuthCubit>().currentProfile?.id;
      if (profileId != null && profileId.isNotEmpty) {
        context.read<MisSolicitudesCubit>().load(profileId);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Mis Solicitudes'),
        backgroundColor: AppTheme.cDeepAccent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: BlocBuilder<MisSolicitudesCubit, MisSolicitudesState>(
        builder: (context, state) {
          if (state is MisSolicitudesLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.cDeepAccent),
            );
          }
          if (state is MisSolicitudesError) {
            return _ErrorView(
              message: state.message,
              onRetry: () {
                final profileId =
                    context.read<AuthCubit>().currentProfile?.id;
                if (profileId != null) {
                  context.read<MisSolicitudesCubit>().load(profileId);
                }
              },
            );
          }
          if (state is! MisSolicitudesLoaded) {
            return const SizedBox.shrink();
          }
          if (state.solicitudes.isEmpty) {
            return const _EmptyView();
          }
          return RefreshIndicator(
            onRefresh: () async {
              final profileId =
                  context.read<AuthCubit>().currentProfile?.id;
              if (profileId != null) {
                context.read<MisSolicitudesCubit>().load(profileId);
              }
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.solicitudes.length,
              itemBuilder: (context, i) =>
                  _SolicitudCard(solicitud: state.solicitudes[i]),
            ),
          );
        },
      ),
    );
  }
}

class _SolicitudCard extends StatelessWidget {
  final SeguimientoSolicitudEntity solicitud;

  const _SolicitudCard({required this.solicitud});

  @override
  Widget build(BuildContext context) {
    final estado = _estadoInfo(solicitud.estado);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _fecha(solicitud.fechaSolicitud),
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.cMutedText),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: estado.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  ),
                  child: Text(
                    estado.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: estado.color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (solicitud.servicios.isEmpty)
              const Text('Sin servicios',
                  style: TextStyle(fontSize: 13, color: AppTheme.cMutedText))
            else
              ...solicitud.servicios.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.spa_rounded,
                            size: 16, color: AppTheme.cDeepAccent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            s.nombre,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          s.cantidad > 1 ? 'x${s.cantidad}' : '',
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.cMutedText),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '\$${s.subtotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  )),
            const SizedBox(height: 12),
            if (solicitud.fechaProgramada != null)
              _InfoRow(
                icon: Icons.schedule_rounded,
                label: 'Preferencia',
                value: _fecha(solicitud.fechaProgramada!),
              ),
            if (solicitud.ciudad != null)
              _InfoRow(
                icon: Icons.location_city_outlined,
                label: 'Zona',
                value: solicitud.ciudad!,
              ),
            _InfoRow(
              icon: Icons.payments_outlined,
              label: 'Total',
              value: '\$${solicitud.montoTotal.toStringAsFixed(2)} USD',
            ),
            _InfoRow(
              icon: Icons.bookmark_added_outlined,
              label: 'Depósito',
              value: '\$${solicitud.deposito.toStringAsFixed(2)} USD',
            ),
            if (solicitud.saldoPendiente > 0)
              _InfoRow(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Saldo pendiente',
                value: '\$${solicitud.saldoPendiente.toStringAsFixed(2)} USD',
              ),
            if (solicitud.citaEstado != null) ...[
              const Divider(height: 20),
              _InfoRow(
                icon: Icons.event_available_rounded,
                label: 'Cita',
                value: _citaLabel(solicitud.citaEstado!),
              ),
              if (solicitud.citaFechaAceptacion != null)
                _InfoRow(
                  icon: Icons.schedule_rounded,
                  label: 'Aceptada',
                  value: _fecha(solicitud.citaFechaAceptacion!),
                ),
              if (solicitud.citaEstado == 'FINALIZADA' &&
                  !solicitud.yaEvaluado &&
                  solicitud.citaId != null)
                _CalificarEspecialistaButton(solicitud: solicitud),
            ],
          ],
        ),
      ),
    );
  }
}

class _CalificarEspecialistaButton extends StatelessWidget {
  final SeguimientoSolicitudEntity solicitud;

  const _CalificarEspecialistaButton({required this.solicitud});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: FilledButton.tonalIcon(
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.cPastelBlue,
          foregroundColor: AppTheme.cDeepAccent,
          minimumSize: const Size.fromHeight(40),
        ),
        onPressed: () => _calificar(context),
        icon: const Icon(Icons.star_rounded, size: 20),
        label: const Text('Calificar especialista',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  Future<void> _calificar(BuildContext context) async {
    final resultado = await showRatingDialog(
      context,
      titulo: 'Califica a tu especialista',
      subtitulo: '¿Cómo fue el servicio? Tu opinión ayuda a la comunidad.',
    );
    if (resultado == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final usecase = sl<RegistrarEvaluacion>();
    final result = await usecase.call(RegistrarEvaluacionParams(
      citaId: solicitud.citaId!,
      puntuacion: resultado.puntuacion,
      comentario: resultado.comentario,
    ));

    result.fold(
      (failure) => messenger.showSnackBar(
        SnackBar(content: Text(failure.message)),
      ),
      (_) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Gracias por tu calificación')),
        );
        final profileId = context.read<AuthCubit>().currentProfile?.id;
        if (profileId != null && profileId.isNotEmpty) {
          context.read<MisSolicitudesCubit>().load(profileId);
        }
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppTheme.cMutedText),
          const SizedBox(width: 8),
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.cMutedText)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
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

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, color: AppTheme.cMutedText, size: 48),
            SizedBox(height: 12),
            Text('Aún no tienes solicitudes.',
                style: TextStyle(fontSize: 14, color: AppTheme.cMutedText)),
            SizedBox(height: 4),
            Text(
              'Selecciona un servicio del catálogo para crear una reserva.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppTheme.cMutedText),
            ),
          ],
        ),
      ),
    );
  }
}

({String label, Color color}) _estadoInfo(String estado) {
  switch (estado) {
    case 'PENDIENTE_PAGO':
      return (label: 'Pendiente de pago', color: Colors.orange.shade800);
    case 'BORRADOR':
      return (label: 'Borrador', color: Colors.blueGrey);
    case 'PUBLICADA':
    case 'BUSCANDO_ESPECIALISTA':
      return (label: 'Buscando especialista', color: AppTheme.cBrandGreen);
    case 'ACEPTADA':
      return (label: 'Aceptada', color: AppTheme.cDeepAccent);
    case 'CANCELADA':
      return (label: 'Cancelada', color: Colors.redAccent);
    case 'EXPIRADA':
      return (label: 'Expirada', color: Colors.grey);
    default:
      return (label: estado, color: AppTheme.cMutedText);
  }
}

String _citaLabel(String estado) {
  switch (estado) {
    case 'PROGRAMADA':
      return 'Programada';
    case 'EN_CAMINO':
      return 'Especialista en camino';
    case 'LLEGO':
      return 'Especialista en el lugar';
    case 'EN_PROCESO':
      return 'En proceso';
    case 'FINALIZADA':
      return 'Finalizada';
    case 'CANCELADA':
      return 'Cancelada';
    default:
      return estado;
  }
}

String _fecha(DateTime fecha) {
  final local = fecha.toLocal();
  final dia = local.day.toString().padLeft(2, '0');
  final mes = local.month.toString().padLeft(2, '0');
  final hora = local.hour.toString().padLeft(2, '0');
  final min = local.minute.toString().padLeft(2, '0');
  return '$dia/$mes/${local.year} $hora:$min';
}
