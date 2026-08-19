import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/features/catalog_services/domain/entities/categoria_servicio_entity.dart';
import 'package:esteticaybellezastrani/features/catalog_services/domain/entities/servicio_entity.dart';
import 'package:esteticaybellezastrani/features/catalog_services/domain/usecases/get_categorias_admin.dart';
import 'package:esteticaybellezastrani/features/catalog_services/domain/usecases/get_servicios_admin.dart';
import 'package:esteticaybellezastrani/features/catalog_services/domain/usecases/guardar_categoria.dart';
import 'package:esteticaybellezastrani/features/catalog_services/domain/usecases/guardar_cuestionarios_servicio.dart';
import 'package:esteticaybellezastrani/features/catalog_services/domain/usecases/guardar_especialidades_servicio.dart';
import 'package:esteticaybellezastrani/features/catalog_services/domain/usecases/guardar_servicio.dart';
import 'package:esteticaybellezastrani/features/catalog_services/presentation/cubits/admin_catalog_cubit.dart';
import 'package:esteticaybellezastrani/features/patients_compliance/domain/usecases/get_cuestionarios.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/entities/especialidad_entity.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/usecases/get_especialidades.dart';

class MockGetCategoriasAdmin extends Mock implements GetCategoriasAdmin {}
class MockGetServiciosAdmin extends Mock implements GetServiciosAdmin {}
class MockGuardarCategoria extends Mock implements GuardarCategoria {}
class MockGuardarServicio extends Mock implements GuardarServicio {}
class MockGuardarEspecialidadesServicio extends Mock
    implements GuardarEspecialidadesServicio {}
class MockGuardarCuestionariosServicio extends Mock
    implements GuardarCuestionariosServicio {}
class MockGetEspecialidades extends Mock implements GetEspecialidades {}
class MockGetCuestionarios extends Mock implements GetCuestionarios {}

AdminCatalogCubit _buildCubit({
  required MockGetCategoriasAdmin getCategoriasAdmin,
  required MockGetServiciosAdmin getServiciosAdmin,
  required MockGuardarCategoria guardarCategoria,
  required MockGuardarServicio guardarServicio,
  required MockGuardarEspecialidadesServicio guardarEspecialidadesServicio,
  required MockGuardarCuestionariosServicio guardarCuestionariosServicio,
  required MockGetEspecialidades getEspecialidades,
  required MockGetCuestionarios getCuestionarios,
}) {
  return AdminCatalogCubit(
    getCategoriasAdmin: getCategoriasAdmin,
    getServiciosAdmin: getServiciosAdmin,
    guardarCategoria: guardarCategoria,
    guardarServicio: guardarServicio,
    guardarEspecialidadesServicio: guardarEspecialidadesServicio,
    guardarCuestionariosServicio: guardarCuestionariosServicio,
    getEspecialidades: getEspecialidades,
    getCuestionarios: getCuestionarios,
  );
}

void main() {
  late MockGetCategoriasAdmin getCategoriasAdmin;
  late MockGetServiciosAdmin getServiciosAdmin;
  late MockGuardarCategoria guardarCategoria;
  late MockGuardarServicio guardarServicio;
  late MockGuardarEspecialidadesServicio guardarEspecialidadesServicio;
  late MockGuardarCuestionariosServicio guardarCuestionariosServicio;
  late MockGetEspecialidades getEspecialidades;
  late MockGetCuestionarios getCuestionarios;

  setUp(() {
    getCategoriasAdmin = MockGetCategoriasAdmin();
    getServiciosAdmin = MockGetServiciosAdmin();
    guardarCategoria = MockGuardarCategoria();
    guardarServicio = MockGuardarServicio();
    guardarEspecialidadesServicio = MockGuardarEspecialidadesServicio();
    guardarCuestionariosServicio = MockGuardarCuestionariosServicio();
    getEspecialidades = MockGetEspecialidades();
    getCuestionarios = MockGetCuestionarios();
  });

  setUpAll(() {
    registerFallbackValue(const GetCuestionariosParams());
    registerFallbackValue(
      const GuardarCategoriaParams(nombre: '', activo: true),
    );
    registerFallbackValue(
      const GuardarServicioParams(nombre: '', precioBase: 0),
    );
    registerFallbackValue(
      const GuardarEspecialidadesServicioParams(
        servicioId: '',
        especialidadIds: [],
      ),
    );
    registerFallbackValue(
      const GuardarCuestionariosServicioParams(servicioId: '', items: []),
    );
  });

  final categoria = CategoriaServicioEntity(
    id: 7,
    nombre: 'Inyectables',
    descripcion: null,
    activo: true,
  );
  final servicio = ServicioEntity(
    id: 'uuid-1',
    categoriaId: 7,
    nombre: 'Toxina Botulínica',
    precioBase: 150,
    tipoPrecio: TipoPrecio.porUnidad,
    activo: true,
  );
  final especialidad = EspecialidadEntity(
    id: 1,
    nombre: 'Médico Estético',
    activo: true,
    createdAt: DateTime(2026, 8, 13),
  );

  group('load', () {
    blocTest<AdminCatalogCubit, AdminCatalogState>(
      'emite Loading y luego Loaded con los datos',
      build: () => _buildCubit(
        getCategoriasAdmin: getCategoriasAdmin,
        getServiciosAdmin: getServiciosAdmin,
        guardarCategoria: guardarCategoria,
        guardarServicio: guardarServicio,
        guardarEspecialidadesServicio: guardarEspecialidadesServicio,
        guardarCuestionariosServicio: guardarCuestionariosServicio,
        getEspecialidades: getEspecialidades,
        getCuestionarios: getCuestionarios,
      ),
      setUp: () {
        when(() => getCategoriasAdmin())
            .thenAnswer((_) async => Right([categoria]));
        when(() => getServiciosAdmin())
            .thenAnswer((_) async => Right([servicio]));
        when(() => getEspecialidades())
            .thenAnswer((_) async => Right([especialidad]));
        when(() => getCuestionarios(any()))
            .thenAnswer((_) async => const Right([]));
      },
      act: (cubit) => cubit.load(),
      expect: () => [
        isA<AdminCatalogLoading>(),
        isA<AdminCatalogLoaded>()
            .having((s) => s.categorias.length, 'categorias.length', 1)
            .having((s) => s.servicios.length, 'servicios.length', 1)
            .having((s) => s.especialidades.length, 'especialidades.length', 1),
      ],
    );

    blocTest<AdminCatalogCubit, AdminCatalogState>(
      'emite Error cuando falla una de las consultas',
      build: () => _buildCubit(
        getCategoriasAdmin: getCategoriasAdmin,
        getServiciosAdmin: getServiciosAdmin,
        guardarCategoria: guardarCategoria,
        guardarServicio: guardarServicio,
        guardarEspecialidadesServicio: guardarEspecialidadesServicio,
        guardarCuestionariosServicio: guardarCuestionariosServicio,
        getEspecialidades: getEspecialidades,
        getCuestionarios: getCuestionarios,
      ),
      setUp: () {
        when(() => getCategoriasAdmin())
            .thenAnswer((_) async => Left(ServerFailure('categorias')));
        when(() => getServiciosAdmin())
            .thenAnswer((_) async => Right([servicio]));
        when(() => getEspecialidades())
            .thenAnswer((_) async => Right([especialidad]));
        when(() => getCuestionarios(any()))
            .thenAnswer((_) async => const Right([]));
      },
      act: (cubit) => cubit.load(),
      expect: () => [
        isA<AdminCatalogLoading>(),
        isA<AdminCatalogError>().having((s) => s.message, 'message', 'categorias'),
      ],
    );
  });

  group('guardarCategoria', () {
    blocTest<AdminCatalogCubit, AdminCatalogState>(
      'crea la categoría y recarga el listado',
      build: () => _buildCubit(
        getCategoriasAdmin: getCategoriasAdmin,
        getServiciosAdmin: getServiciosAdmin,
        guardarCategoria: guardarCategoria,
        guardarServicio: guardarServicio,
        guardarEspecialidadesServicio: guardarEspecialidadesServicio,
        guardarCuestionariosServicio: guardarCuestionariosServicio,
        getEspecialidades: getEspecialidades,
        getCuestionarios: getCuestionarios,
      ),
      setUp: () {
        when(() => getCategoriasAdmin())
            .thenAnswer((_) async => Right([categoria]));
        when(() => getServiciosAdmin())
            .thenAnswer((_) async => Right([servicio]));
        when(() => getEspecialidades())
            .thenAnswer((_) async => Right([especialidad]));
        when(() => getCuestionarios(any()))
            .thenAnswer((_) async => const Right([]));
        when(() => guardarCategoria(any()))
            .thenAnswer((_) async => Right(categoria));
      },
      seed: () => AdminCatalogLoaded(
        categorias: [categoria],
        servicios: [servicio],
        especialidades: [especialidad],
      ),
      act: (cubit) => cubit.guardarCategoria(
        nombre: 'Inyectables',
        activo: true,
      ),
      expect: () => [
        isA<AdminCatalogLoaded>().having((s) => s.saving, 'saving', true),
        isA<AdminCatalogLoaded>()
            .having((s) => s.saving, 'saving', false)
            .having((s) => s.feedback, 'feedback', 'Categoría creada correctamente'),
      ],
    );

    blocTest<AdminCatalogCubit, AdminCatalogState>(
      'emite error si el guardado falla',
      build: () => _buildCubit(
        getCategoriasAdmin: getCategoriasAdmin,
        getServiciosAdmin: getServiciosAdmin,
        guardarCategoria: guardarCategoria,
        guardarServicio: guardarServicio,
        guardarEspecialidadesServicio: guardarEspecialidadesServicio,
        guardarCuestionariosServicio: guardarCuestionariosServicio,
        getEspecialidades: getEspecialidades,
        getCuestionarios: getCuestionarios,
      ),
      setUp: () {
        when(() => guardarCategoria(any()))
            .thenAnswer((_) async => Left(ServerFailure('insert fallido')));
      },
      seed: () => const AdminCatalogLoaded(),
      act: (cubit) => cubit.guardarCategoria(
        nombre: 'X',
        activo: true,
      ),
      expect: () => [
        isA<AdminCatalogLoaded>()
            .having((s) => s.saving, 'saving', true)
            .having((s) => s.error, 'error', isNull),
        isA<AdminCatalogLoaded>()
            .having((s) => s.saving, 'saving', false)
            .having((s) => s.error, 'error', 'insert fallido'),
      ],
    );
  });

  group('guardarEspecialidadesServicio', () {
    blocTest<AdminCatalogCubit, AdminCatalogState>(
      'retorna true y emite feedback al reemplazar',
      build: () => _buildCubit(
        getCategoriasAdmin: getCategoriasAdmin,
        getServiciosAdmin: getServiciosAdmin,
        guardarCategoria: guardarCategoria,
        guardarServicio: guardarServicio,
        guardarEspecialidadesServicio: guardarEspecialidadesServicio,
        guardarCuestionariosServicio: guardarCuestionariosServicio,
        getEspecialidades: getEspecialidades,
        getCuestionarios: getCuestionarios,
      ),
      setUp: () {
        when(() => guardarEspecialidadesServicio(any()))
            .thenAnswer((_) async => const Right(null));
      },
      seed: () => const AdminCatalogLoaded(),
      act: (cubit) async {
        final ok = await cubit.guardarEspecialidadesServicio('uuid-1', const [1]);
        expect(ok, isTrue);
      },
      expect: () => [
        isA<AdminCatalogLoaded>()
            .having((s) => s.feedback, 'feedback', 'Especialidades guardadas'),
      ],
    );
  });
}