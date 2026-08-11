import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/app/core/usecases/use_case.dart';
import '../entities/medico_regente_entity.dart';
import '../repositories/i_specialists_repository.dart';

class CreateMedicoRegenteParams {
  final String nombre;
  final String? numeroLicencia;
  final String? telefono;
  final String? correo;
  const CreateMedicoRegenteParams({
    required this.nombre,
    this.numeroLicencia,
    this.telefono,
    this.correo,
  });
}

/// Registra un médico regente. Queda PENDIENTE hasta validación del admin.
class CreateMedicoRegente
    extends UseCase<MedicoRegenteEntity, CreateMedicoRegenteParams> {
  final ISpecialistsRepository _repository;
  CreateMedicoRegente(this._repository);

  @override
  Future<Either<Failure, MedicoRegenteEntity>> call(
      CreateMedicoRegenteParams params) {
    return _repository.createMedicoRegente(
      nombre: params.nombre,
      numeroLicencia: params.numeroLicencia,
      telefono: params.telefono,
      correo: params.correo,
    );
  }
}
