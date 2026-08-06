import 'package:flutter/material.dart';
import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import '../../domain/entities/cita_ejecucion_entity.dart';

/// Chip de colores para el estado del ciclo de la cita.
class EstadoChip extends StatelessWidget {
  final EstadoCitaEjecucion estado;
  const EstadoChip({super.key, required this.estado});

  @override
  Widget build(BuildContext context) {
    final (label, color) = _map(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  (String, Color) _map(EstadoCitaEjecucion e) => switch (e) {
        EstadoCitaEjecucion.programada => ('Programada', AppTheme.cDeepAccent),
        EstadoCitaEjecucion.enCamino => ('En camino', Colors.orange),
        EstadoCitaEjecucion.llego => ('Llegó', Colors.teal),
        EstadoCitaEjecucion.enProceso => ('En proceso', AppTheme.cBrandGreen),
        EstadoCitaEjecucion.finalizada => ('Finalizada', AppTheme.cBrandGreen),
        EstadoCitaEjecucion.cancelada => ('Cancelada', Colors.redAccent),
        EstadoCitaEjecucion.noCompletada => ('No completada', Colors.redAccent),
      };
}