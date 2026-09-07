import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/app/core/usecases/use_case.dart';
import '../entities/medico_regente_entity.dart';
import '../repositories/i_specialists_repository.dart';

class GetMedicosRegentesParams {
  final bool soloActivos;

  /// Cuando es true (flujo admin) incluye datos de contacto (teléfono/correo)
  /// leyendo la tabla `medicos_regentes`. Cuando es false (especialistas) lee
  /// la vista pública `medicos_regentes_publico` sin datos de contacto.
  final bool includeContacto;
  const GetMedicosRegentesParams({
    this.soloActivos = true,
    this.includeContacto = false,
  });
}

/// Lista los médicos regentes. Por defecto solo los activos (validados),
/// lo que permite al especialista elegir un médico regente aprobado.
class GetMedicosRegentes
    extends UseCase<List<MedicoRegenteEntity>, GetMedicosRegentesParams> {
  final ISpecialistsRepository _repository;
  GetMedicosRegentes(this._repository);

  @override
  Future<Either<Failure, List<MedicoRegenteEntity>>> call(
      GetMedicosRegentesParams params) {
    return _repository.getMedicosRegentes(
      soloActivos: params.soloActivos,
      includeContacto: params.includeContacto,
    );
  }
}
