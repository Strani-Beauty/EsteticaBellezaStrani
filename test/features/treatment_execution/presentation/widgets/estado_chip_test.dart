import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/entities/cita_ejecucion_entity.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/presentation/widgets/estado_chip.dart';

void main() {
  const casos = <(EstadoCitaEjecucion, String)>[
    (EstadoCitaEjecucion.programada, 'Programada'),
    (EstadoCitaEjecucion.enCamino, 'En camino'),
    (EstadoCitaEjecucion.llego, 'Llegó'),
    (EstadoCitaEjecucion.enProceso, 'En proceso'),
    (EstadoCitaEjecucion.finalizada, 'Finalizada'),
    (EstadoCitaEjecucion.cancelada, 'Cancelada'),
    (EstadoCitaEjecucion.noCompletada, 'No completada'),
  ];

  for (final caso in casos) {
    testWidgets('EstadoChip muestra "${caso.$2}" para ${caso.$1.name}',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: EstadoChip(estado: caso.$1))),
      );
      expect(find.text(caso.$2), findsOneWidget);
    });
  }
}