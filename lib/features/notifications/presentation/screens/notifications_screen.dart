import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import 'package:esteticaybellezastrani/app/core/di/injection.dart';
import 'package:esteticaybellezastrani/features/auth_users/presentation/cubits/auth_cubit.dart';
import '../../domain/entities/notificacion_entity.dart';
import '../cubits/notifications_cubit.dart';

/// Pantalla de notificaciones del usuario (in-app).
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final usuarioId = context.read<AuthCubit>().currentProfile?.id;
      if (usuarioId != null && usuarioId.isNotEmpty) {
        context.read<NotificationsCubit>().load(usuarioId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          TextButton(
            onPressed: () => context.read<NotificationsCubit>().markAllRead(),
            child: const Text('Marcar todas'),
          ),
        ],
      ),
      body: BlocBuilder<NotificationsCubit, NotificationsState>(
        bloc: sl<NotificationsCubit>(),
        builder: (context, state) {
          if (state is NotificationsLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is NotificationsError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(state.message, textAlign: TextAlign.center),
              ),
            );
          }
          if (state is! NotificationsLoaded) {
            return const SizedBox.shrink();
          }
          if (state.notificaciones.isEmpty) {
            return const Center(
              child: Text('No tienes notificaciones.',
                  style: TextStyle(color: AppTheme.cMutedText)),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              final usuarioId = context.read<AuthCubit>().currentProfile?.id;
              if (usuarioId != null) {
                await context.read<NotificationsCubit>().load(usuarioId);
              }
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: state.notificaciones.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final n = state.notificaciones[index];
                return _NotificacionTile(
                  notificacion: n,
                  onTap: () => context
                      .read<NotificationsCubit>()
                      .markRead(n.id),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _NotificacionTile extends StatelessWidget {
  final NotificacionEntity notificacion;
  final VoidCallback onTap;
  const _NotificacionTile({required this.notificacion, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final esDocRechazado = notificacion.tipo == 'DOCUMENTO_RECHAZADO';
    final color =
        esDocRechazado ? Colors.redAccent : AppTheme.cBrandGreen;
    return Card(
      color: notificacion.leida
          ? AppTheme.cSurface
          : color.withValues(alpha: 0.06),
      child: ListTile(
        leading: Icon(
          esDocRechazado
              ? Icons.cancel_outlined
              : Icons.verified_user_rounded,
          color: color,
        ),
        title: Text(
          notificacion.titulo,
          style: TextStyle(
            fontWeight:
                notificacion.leida ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Text(
          '${notificacion.mensaje}\n${_format(notificacion.fechaEnvio)}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: notificacion.leida
            ? null
            : Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppTheme.cDeepAccent,
                  shape: BoxShape.circle,
                ),
              ),
        onTap: onTap,
      ),
    );
  }

  String _format(DateTime d) {
    final local = d.toLocal();
    return '${local.day}/${local.month}/${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}
