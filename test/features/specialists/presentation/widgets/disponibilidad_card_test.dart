import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/entities/disponibilidad_entity.dart';
import 'package:esteticaybellezastrani/features/specialists/presentation/cubits/specialists_cubit.dart';
import 'package:esteticaybellezastrani/features/specialists/presentation/widgets/disponibilidad_card.dart';

class MockSpecialistsCubit extends Mock implements SpecialistsCubit {}

void main() {
  late MockSpecialistsCubit cubit;

  setUp(() {
    cubit = MockSpecialistsCubit();
    when(() => cubit.stream)
        .thenAnswer((_) => const Stream<SpecialistsState>.empty());
  });

  Widget wrap(Widget child) => MaterialApp(
        home: BlocProvider<SpecialistsCubit>.value(
          value: cubit,
          child: Scaffold(body: child),
        ),
      );

  final disponible = DisponibilidadEntity(
    id: 'disp-1',
    especialistaId: 'esp-1',
    estado: EstadoDisponibilidad.disponible,
    createdAt: DateTime(2026, 8, 13),
  );

  testWidgets('muestra "Disponible para citas" cuando está disponible',
      (tester) async {
    await tester.pumpWidget(wrap(DisponibilidadCard(
      especialistaId: 'esp-1',
      disponibilidad: disponible,
    )));

    expect(find.text('Disponible para citas'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
  });

  testWidgets('muestra "No disponible" cuando no hay disponibilidad',
      (tester) async {
    await tester.pumpWidget(wrap(const DisponibilidadCard(
      especialistaId: 'esp-1',
      disponibilidad: null,
    )));

    expect(find.text('No disponible'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });

  testWidgets('al tocar el switch llama toggleDisponibilidad', (tester) async {
    when(() => cubit.toggleDisponibilidad(
        especialistaId: any(named: 'especialistaId'))).thenAnswer((_) async {});

    await tester.pumpWidget(wrap(DisponibilidadCard(
      especialistaId: 'esp-1',
      disponibilidad: disponible,
    )));

    await tester.tap(find.byType(Switch));
    await tester.pump();

    verify(() => cubit.toggleDisponibilidad(especialistaId: 'esp-1')).called(1);
  });
}
