import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import 'package:esteticaybellezastrani/app/core/di/injection.dart';
import 'package:esteticaybellezastrani/features/specialists/data/services/presence_service.dart';
import '../../domain/entities/disponibilidad_entity.dart';
import '../cubits/specialists_cubit.dart';

/// Tarjeta que muestra y alterna la disponibilidad del especialista.
/// El toggle queda bloqueado si el especialista aún no está verificado
/// (`habilitado=false`): solo puede operar tras completar su expediente.
class DisponibilidadCard extends StatelessWidget {
  final String especialistaId;
  final DisponibilidadEntity? disponibilidad;
  final bool habilitado;
  final String? usuarioId;

  const DisponibilidadCard({
    super.key,
    required this.especialistaId,
    required this.disponibilidad,
    this.habilitado = false,
    this.usuarioId,
  });

  @override
  Widget build(BuildContext context) {
    final isAvailable = disponibilidad?.isAvailable ?? false;
    return Card(
      child: ListTile(
        leading: Icon(
          isAvailable ? Icons.radio_button_checked : Icons.radio_button_off,
          color: isAvailable ? AppTheme.cBrandGreen : AppTheme.cMutedText,
        ),
        title: Text(isAvailable ? 'Disponible para citas' : 'No disponible'),
        subtitle: Text(
          !habilitado
              ? 'Disponible solo cuando estés verificado.'
              : disponibilidad == null
                  ? 'Activa tu disponibilidad para recibir citas.'
                  : 'Última actualización ${_format(disponibilidad!.createdAt)}',
        ),
        trailing: Switch(
          value: isAvailable && habilitado,
          onChanged: habilitado
              ? (value) {
                  context
                      .read<SpecialistsCubit>()
                      .toggleDisponibilidad(especialistaId: especialistaId);
                  final uid = usuarioId;
                  if (value && uid != null && uid.isNotEmpty) {
                    sl<PresenceService>().start(uid);
                  }
                }
              : null,
        ),
      ),
    );
  }

  String _format(DateTime d) => '${d.day}/${d.month}/${d.year}';
}