import 'package:flutter/material.dart';
import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import '../../domain/entities/especialidad_entity.dart';

/// Selector multi-selección de especialidades (chips).
class EspecialidadesSelector extends StatelessWidget {
  final List<EspecialidadEntity> especialidades;
  final Set<int> seleccionadas;
  final ValueChanged<Set<int>> onChanged;

  const EspecialidadesSelector({
    super.key,
    required this.especialidades,
    required this.seleccionadas,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (especialidades.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text(
          'Aún no hay especialidades disponibles en el catálogo.',
          style: TextStyle(color: AppTheme.cMutedText, fontSize: 13),
        ),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final especialidad in especialidades)
          FilterChip(
            label: Text(especialidad.nombre),
            selected: seleccionadas.contains(especialidad.id),
            onSelected: (selected) {
              final next = Set<int>.from(seleccionadas);
              if (selected) {
                next.add(especialidad.id);
              } else {
                next.remove(especialidad.id);
              }
              onChanged(next);
            },
            selectedColor: AppTheme.cPastelPurple,
            checkmarkColor: AppTheme.cDeepAccent,
            labelStyle: const TextStyle(color: AppTheme.cDarkText, fontSize: 12),
          ),
      ],
    );
  }
}
