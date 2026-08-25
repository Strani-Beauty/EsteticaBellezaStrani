import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/features/treatment_photos/domain/entities/fotografia_tratamiento_entity.dart';
import 'package:esteticaybellezastrani/features/treatment_photos/domain/usecases/registrar_fotografia_por_url.dart';
import '../../mock_repository.dart';

void main() {
  late RegistrarFotografiaPorUrl usecase;
  late MockITreatmentPhotosRepository repository;

  setUpAll(() {
    registerFallbackValue(TipoFotografia.post);
  });

  setUp(() {
    repository = MockITreatmentPhotosRepository();
    usecase = RegistrarFotografiaPorUrl(repository);
  });

  final foto = FotografiaTratamientoEntity(
    id: 'foto-1',
    tratamientoId: 'trat-1',
    tipoFotografia: TipoFotografia.post,
    archivoUrl: 'trat-1/456.png',
    fechaCaptura: DateTime(2026, 8, 25),
    createdAt: DateTime(2026, 8, 25),
  );

  test('delega en el repositorio y retorna la fotografía registrada', () async {
    when(() => repository.registrarPorUrl(
        tratamientoId: any(named: 'tratamientoId'),
        tipoFotografia: any(named: 'tipoFotografia'),
        archivoUrl: any(named: 'archivoUrl'),
        descripcion: any(named: 'descripcion')))
        .thenAnswer((_) async => Right(foto));

    final result = await usecase(const RegistrarFotografiaPorUrlParams(
      tratamientoId: 'trat-1',
      tipoFotografia: TipoFotografia.post,
      archivoUrl: 'trat-1/456.png',
    ));

    expect(result, Right(foto));
    verify(() => repository.registrarPorUrl(
        tratamientoId: 'trat-1',
        tipoFotografia: TipoFotografia.post,
        archivoUrl: 'trat-1/456.png',
        descripcion: null)).called(1);
  });

  test('retorna Failure cuando el repositorio falla', () async {
    when(() => repository.registrarPorUrl(
        tratamientoId: any(named: 'tratamientoId'),
        tipoFotografia: any(named: 'tipoFotografia'),
        archivoUrl: any(named: 'archivoUrl'),
        descripcion: any(named: 'descripcion')))
        .thenAnswer((_) async => const Left(ServerFailure('boom')));

    final result = await usecase(const RegistrarFotografiaPorUrlParams(
      tratamientoId: 'trat-1',
      tipoFotografia: TipoFotografia.post,
      archivoUrl: 'trat-1/456.png',
    ));

    expect(result, const Left(ServerFailure('boom')));
  });
}