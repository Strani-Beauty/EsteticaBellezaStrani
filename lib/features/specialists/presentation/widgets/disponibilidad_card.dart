import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import '../../domain/entities/disponibilidad_entity.dart';
import '../cubits/specialists_cubit.dart';

/// Tarjeta que muestra y alterna la disponibilidad del especialista.
class DisponibilidadCard extends StatelessWidget {
  final String especialistaId;
  final DisponibilidadEntity? disponibilidad;

  const DisponibilidadCard({
    super.key,
    required this.especialistaId,
    required this.disponibilidad,
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
          disponibilidad == null
              ? 'Activa tu disponibilidad para recibir citas.'
              : 'Última actualización ${_format(disponibilidad!.createdAt)}',
        ),
        trailing: Switch(
          value: isAvailable,
          onChanged: (_) => context
              .read<SpecialistsCubit>()
              .toggleDisponibilidad(especialistaId: especialistaId),
        ),
      ),
    );
  }

  String _format(DateTime d) => '${d.day}/${d.month}/${d.year}';
}