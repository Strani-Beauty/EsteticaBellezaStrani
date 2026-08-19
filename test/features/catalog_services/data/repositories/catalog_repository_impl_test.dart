import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/features/catalog_services/data/datasources/catalog_services_supabase_datasource.dart';
import 'package:esteticaybellezastrani/features/catalog_services/data/models/categoria_servicio_model.dart';
import 'package:esteticaybellezastrani/features/catalog_services/data/models/servicio_model.dart';
import 'package:esteticaybellezastrani/features/catalog_services/data/repositories/catalog_repository_impl.dart';
import 'package:esteticaybellezastrani/features/catalog_services/domain/entities/categoria_servicio_entity.dart';
import 'package:esteticaybellezastrani/features/catalog_services/domain/entities/servicio_cuestionario_entity.dart';
import 'package:esteticaybellezastrani/features/catalog_services/domain/entities/servicio_entity.dart';

class MockCatalogDataSource extends Mock
    implements CatalogServicesSupabaseDataSource {}

void main() {
  late CatalogRepositoryImpl repository;
  late MockCatalogDataSource dataSource;

  setUpAll(() {
    registerFallbackValue(TipoPrecio.precioFijo);
  });

  setUp(() {
    dataSource = MockCatalogDataSource();
    repository = CatalogRepositoryImpl(dataSource);
  });

  final categoriaModel = CategoriaServicioModel(
    id: 7,
    nombre: 'Inyectables',
    descripcion: 'Inyectables',
    activo: true,
  );

  final servicioModel = ServicioModel(
    id: 'uuid-1',
    categoriaId: 7,
    nombre: 'Toxina Botulínica',
    descripcion: 'Unidades',
    precioBase: 150,
    tipoPrecio: TipoPrecio.porUnidad,
    duracionEstimada: 30,
    requiereTelemedicina: true,
    requiereFaceMap: true,
    requiereFotos: false,
    requiereConsentimiento: true,
    activo: true,
    categoria: categoriaModel.toEntity(),
  );

  final requisitos = ServicioRequisitosEntity(
    especialidadIds: const [1, 2],
    cuestionarios: const [
      ServicioCuestionarioEntity(
        cuestionarioId: 4,
        nombre: 'Cuestionario de Salud',
        obligatorio: true,
        orden: 0,
      ),
    ],
  );

  group('getCategoriasAdmin', () {
    test('retorna Right(lista de entidades)', () async {
      when(() => dataSource.fetchCategoriasAdmin())
          .thenAnswer((_) async => [categoriaModel]);

      final result = await repository.getCategoriasAdmin();

      expect(result.getRight().toNullable(), [categoriaModel.toEntity()]);
    });

    test('retorna Left(ServerFailure) cuando falla', () async {
      when(() => dataSource.fetchCategoriasAdmin())
          .thenThrow(Exception('boom'));

      final result = await repository.getCategoriasAdmin();

      expect(result, isA<Left<Failure, List<CategoriaServicioEntity>>>());
    });
  });

  group('guardarCategoria', () {
    test('inserta cuando id es 0', () async {
      when(() => dataSource.insertCategoria(
            nombre: any(named: 'nombre'),
            descripcion: any(named: 'descripcion'),
            activo: any(named: 'activo'),
          )).thenAnswer((_) async => categoriaModel);

      final result = await repository.guardarCategoria(
        nombre: 'Inyectables',
        descripcion: 'Inyectables',
        activo: true,
      );

      expect(result, Right(categoriaModel.toEntity()));
    });

    test('actualiza cuando id > 0', () async {
      when(() => dataSource.updateCategoria(
            id: any(named: 'id'),
            nombre: any(named: 'nombre'),
            descripcion: any(named: 'descripcion'),
            activo: any(named: 'activo'),
          )).thenAnswer((_) async => categoriaModel);

      final result = await repository.guardarCategoria(
        id: 7,
        nombre: 'Inyectables',
        activo: false,
      );

      expect(result, Right(categoriaModel.toEntity()));
    });

    test('retorna Left cuando falla', () async {
      when(() => dataSource.insertCategoria(
            nombre: any(named: 'nombre'),
            descripcion: any(named: 'descripcion'),
            activo: any(named: 'activo'),
          )).thenThrow(Exception('insert fallido'));

      final result = await repository.guardarCategoria(
        nombre: 'X',
        activo: true,
      );

      expect(result.isLeft(), isTrue);
    });
  });

  group('getServiciosAdmin', () {
    test('retorna Right(lista de entidades)', () async {
      when(() => dataSource.fetchServiciosAdmin())
          .thenAnswer((_) async => [servicioModel]);

      final result = await repository.getServiciosAdmin();

      expect(result.getRight().toNullable(), [servicioModel.toEntity()]);
    });

    test('retorna Left cuando falla', () async {
      when(() => dataSource.fetchServiciosAdmin())
          .thenThrow(Exception('boom'));

      final result = await repository.getServiciosAdmin();

      expect(result.isLeft(), isTrue);
    });
  });

  group('guardarServicio', () {
    test('inserta cuando id está vacío', () async {
      when(() => dataSource.insertServicio(
            categoriaId: any(named: 'categoriaId'),
            nombre: any(named: 'nombre'),
            descripcion: any(named: 'descripcion'),
            precioBase: any(named: 'precioBase'),
            tipoPrecio: any(named: 'tipoPrecio'),
            duracionEstimada: any(named: 'duracionEstimada'),
            requiereTelemedicina: any(named: 'requiereTelemedicina'),
            requiereFaceMap: any(named: 'requiereFaceMap'),
            requiereFotos: any(named: 'requiereFotos'),
            requiereConsentimiento: any(named: 'requiereConsentimiento'),
            activo: any(named: 'activo'),
          )).thenAnswer((_) async => servicioModel);

      final result = await repository.guardarServicio(
        categoriaId: 7,
        nombre: 'Toxina Botulínica',
        descripcion: 'Unidades',
        precioBase: 150,
        tipoPrecio: TipoPrecio.porUnidad,
        duracionEstimada: 30,
        requiereTelemedicina: true,
        requiereFaceMap: true,
        requiereConsentimiento: true,
      );

      expect(result, Right(servicioModel.toEntity()));
    });

    test('actualiza cuando id no está vacío', () async {
      when(() => dataSource.updateServicio(
            id: any(named: 'id'),
            categoriaId: any(named: 'categoriaId'),
            nombre: any(named: 'nombre'),
            descripcion: any(named: 'descripcion'),
            precioBase: any(named: 'precioBase'),
            tipoPrecio: any(named: 'tipoPrecio'),
            duracionEstimada: any(named: 'duracionEstimada'),
            requiereTelemedicina: any(named: 'requiereTelemedicina'),
            requiereFaceMap: any(named: 'requiereFaceMap'),
            requiereFotos: any(named: 'requiereFotos'),
            requiereConsentimiento: any(named: 'requiereConsentimiento'),
            activo: any(named: 'activo'),
          )).thenAnswer((_) async => servicioModel);

      final result = await repository.guardarServicio(
        id: 'uuid-1',
        nombre: 'Toxina Botulínica',
        precioBase: 150,
        tipoPrecio: TipoPrecio.porUnidad,
        activo: false,
      );

      expect(result, Right(servicioModel.toEntity()));
    });

    test('retorna Left cuando falla', () async {
      when(() => dataSource.insertServicio(
            categoriaId: any(named: 'categoriaId'),
            nombre: any(named: 'nombre'),
            descripcion: any(named: 'descripcion'),
            precioBase: any(named: 'precioBase'),
            tipoPrecio: any(named: 'tipoPrecio'),
            duracionEstimada: any(named: 'duracionEstimada'),
            requiereTelemedicina: any(named: 'requiereTelemedicina'),
            requiereFaceMap: any(named: 'requiereFaceMap'),
            requiereFotos: any(named: 'requiereFotos'),
            requiereConsentimiento: any(named: 'requiereConsentimiento'),
            activo: any(named: 'activo'),
          )).thenThrow(Exception('insert fallido'));

      final result = await repository.guardarServicio(
        nombre: 'X',
        precioBase: 10,
        tipoPrecio: TipoPrecio.precioFijo,
      );

      expect(result.isLeft(), isTrue);
    });
  });

  group('getRequisitosServicio', () {
    test('retorna Right(requisitos)', () async {
      when(() => dataSource.fetchRequisitosServicio(any()))
          .thenAnswer((_) async => requisitos);

      final result = await repository.getRequisitosServicio('uuid-1');

      expect(result, Right(requisitos));
    });

    test('retorna Left cuando falla', () async {
      when(() => dataSource.fetchRequisitosServicio(any()))
          .thenThrow(Exception('boom'));

      final result = await repository.getRequisitosServicio('uuid-1');

      expect(result.isLeft(), isTrue);
    });
  });

  group('guardarEspecialidadesServicio', () {
    test('retorna Right(null) al reemplazar', () async {
      when(() => dataSource.reemplazarEspecialidadesServicio(any(), any()))
          .thenAnswer((_) async {});

      final result =
          await repository.guardarEspecialidadesServicio('uuid-1', const [1, 2]);

      expect(result, const Right(null));
      verify(() =>
              dataSource.reemplazarEspecialidadesServicio('uuid-1', [1, 2]))
          .called(1);
    });

    test('retorna Left cuando falla', () async {
      when(() => dataSource.reemplazarEspecialidadesServicio(any(), any()))
          .thenThrow(Exception('rpc fallido'));

      final result =
          await repository.guardarEspecialidadesServicio('uuid-1', const [1]);

      expect(result.isLeft(), isTrue);
    });
  });

  group('guardarCuestionariosServicio', () {
    test('retorna Right(null) al reemplazar', () async {
      when(() => dataSource.reemplazarCuestionariosServicio(any(), any()))
          .thenAnswer((_) async {});

      final result = await repository.guardarCuestionariosServicio(
          'uuid-1', requisitos.cuestionarios);

      expect(result, const Right(null));
      verify(() => dataSource.reemplazarCuestionariosServicio(
            'uuid-1',
            requisitos.cuestionarios,
          )).called(1);
    });

    test('retorna Left cuando falla', () async {
      when(() => dataSource.reemplazarCuestionariosServicio(any(), any()))
          .thenThrow(Exception('rpc fallido'));

      final result = await repository.guardarCuestionariosServicio(
          'uuid-1', requisitos.cuestionarios);

      expect(result.isLeft(), isTrue);
    });
  });
}