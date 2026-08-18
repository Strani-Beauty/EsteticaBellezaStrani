import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:esteticaybellezastrani/app/config/app_routes.dart';
import 'package:esteticaybellezastrani/app/core/di/injection.dart';
import '../cubits/notifications_cubit.dart';

/// Campana de notificaciones con badge de no leídas para el AppBar del panel.
class NotificacionesBell extends StatelessWidget {
  const NotificacionesBell({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotificationsCubit, NotificationsState>(
      bloc: sl<NotificationsCubit>(),
      builder: (context, state) {
        final noLeidas = state is NotificationsLoaded ? state.noLeidas : 0;
        return IconButton(
          tooltip: 'Notificaciones',
          icon: Badge(
            isLabelVisible: noLeidas > 0,
            label: Text('$noLeidas'),
            child: const Icon(Icons.notifications_none_rounded),
          ),
          onPressed: () => context.push(AppRoutes.notifications),
        );
      },
    );
  }
}
