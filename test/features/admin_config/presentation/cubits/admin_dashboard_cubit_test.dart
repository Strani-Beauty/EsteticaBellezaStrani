import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/features/admin_config/domain/entities/admin_kpis_entity.dart';
import 'package:esteticaybellezastrani/features/admin_config/domain/usecases/get_admin_kpis.dart';
import 'package:esteticaybellezastrani/features/admin_config/presentation/cubits/admin_dashboard_cubit.dart';

class MockGetAdminKpis extends Mock implements GetAdminKpis {}

void main() {
  late MockGetAdminKpis getKpis;

  setUp(() {
    getKpis = MockGetAdminKpis();
  });

  AdminDashboardCubit buildCubit() =>
      AdminDashboardCubit(getKpis: getKpis);

  const kpis = AdminKpisEntity(
    solicitudesPorEstado: {'PUBLICADA': 3, 'ACEPTADA': 2},
    citasActivas: 4,
    especialistasPendientes: 2,
    medicosPendientes: 1,
    ingresosTotales: 1250.5,
    totalUsuarios: 32,
  );

  test('estado inicial', () {
    expect(buildCubit().state, const AdminDashboardInitial());
  });

  test('AdminKpisEntity.fromJson parsea correctamente', () {
    final entity = AdminKpisEntity.fromJson({
      'solicitudes_por_estado': {'PUBLICADA': 3, 'ACEPTADA': 2},
      'citas_activas': 4,
      'especialistas_pendientes': 2,
      'medicos_pendientes': 1,
      'ingresos_totales': 1250.5,
      'total_usuarios': 32,
    });
    expect(entity.solicitudesPorEstado['PUBLICADA'], 3);
    expect(entity.citasActivas, 4);
    expect(entity.especialistasPendientes, 2);
    expect(entity.ingresosTotales, 1250.5);
    expect(entity.totalUsuarios, 32);
  });

  blocTest<AdminDashboardCubit, AdminDashboardState>(
    'load emite Loaded con los KPIs',
    build: buildCubit,
    act: (cubit) async {
      when(() => getKpis()).thenAnswer((_) async => const Right(kpis));
      await cubit.load();
    },
    expect: () => [
      const AdminDashboardLoading(),
      const AdminDashboardLoaded(kpis),
    ],
  );

  blocTest<AdminDashboardCubit, AdminDashboardState>(
    'load emite Error cuando falla',
    build: buildCubit,
    act: (cubit) async {
      when(() => getKpis())
          .thenAnswer((_) async => const Left(ServerFailure('Sin red')));
      await cubit.load();
    },
    expect: () => [
      const AdminDashboardLoading(),
      const AdminDashboardError('Sin red'),
    ],
  );
}
