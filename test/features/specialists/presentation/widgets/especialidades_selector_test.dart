import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/entities/especialidad_entity.dart';
import 'package:esteticaybellezastrani/features/specialists/presentation/widgets/especialidades_selector.dart';

EspecialidadEntity _esp(int id, String nombre) => EspecialidadEntity(
      id: id,
      nombre: nombre,
      activo: true,
      createdAt: DateTime(2026, 8, 13),
    );

void main() {
  testWidgets('muestra mensaje cuando no hay especialidades', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: EspecialidadesSelector(
          especialidades: [],
          seleccionadas: {},
          onChanged: _noop,
        ),
      ),
    ));

    expect(
      find.text('Aún no hay especialidades disponibles en el catálogo.'),
      findsOneWidget,
    );
  });

  testWidgets('muestra un chip por especialidad', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EspecialidadesSelector(
          especialidades: [_esp(1, 'Facial'), _esp(2, 'Corporal')],
          seleccionadas: {1},
          onChanged: _noop,
        ),
      ),
    ));

    expect(find.text('Facial'), findsOneWidget);
    expect(find.text('Corporal'), findsOneWidget);
    expect(find.byType(FilterChip), findsNWidgets(2));
  });

  testWidgets('al seleccionar un chip llama onChanged con el nuevo set',
      (tester) async {
    Set<int>? result;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EspecialidadesSelector(
          especialidades: [_esp(1, 'Facial'), _esp(2, 'Corporal')],
          seleccionadas: {1},
          onChanged: (s) => result = s,
        ),
      ),
    ));

    await tester.tap(find.text('Corporal'));

    expect(result, {1, 2});
  });

  testWidgets('al deseleccionar un chip lo quita del set', (tester) async {
    Set<int>? result;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EspecialidadesSelector(
          especialidades: [_esp(1, 'Facial')],
          seleccionadas: {1},
          onChanged: (s) => result = s,
        ),
      ),
    ));

    await tester.tap(find.text('Facial'));

    expect(result, isEmpty);
  });
}

void _noop(Set<int> _) {}
