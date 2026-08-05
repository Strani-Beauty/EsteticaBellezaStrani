import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/app/core/usecases/use_case.dart';
import '../entities/especialista_entity.dart';
import '../repositories/i_specialists_repository.dart';

class CreateEspecialistaParams {
  final String usuarioId;
  final String? numeroLicencia;
  final String? medicoRegenteId;
  const CreateEspecialistaParams({
    required this.usuarioId,
    this.numeroLicencia,
    this.medicoRegenteId,
  });
}

/// Crea el registro del especialista e inicia el flujo de verificación.
class CreateEspecialista
    extends UseCase<EspecialistaEntity, CreateEspecialistaParams> {
  final ISpecialistsRepository _repository;
  CreateEspecialista(this._repository);

  @override
  Future<Either<Failure, EspecialistaEntity>> call(CreateEspecialistaParams params) {
    return _repository.createEspecialista(
      usuarioId: params.usuarioId,
      numeroLicencia: params.numeroLicencia,
      medicoRegenteId: params.medicoRegenteId,
    );
  }
}