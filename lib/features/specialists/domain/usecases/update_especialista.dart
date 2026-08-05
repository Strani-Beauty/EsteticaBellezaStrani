import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/app/core/usecases/use_case.dart';
import '../entities/especialista_entity.dart';
import '../repositories/i_specialists_repository.dart';

class UpdateEspecialistaParams {
  final String id;
  final String? numeroLicencia;
  final String? medicoRegenteId;
  final bool? disponible;
  final bool? activo;
  final String? estadoVerificacion;
  const UpdateEspecialistaParams({
    required this.id,
    this.numeroLicencia,
    this.medicoRegenteId,
    this.disponible,
    this.activo,
    this.estadoVerificacion,
  });
}

/// Actualiza datos del especialista.
class UpdateEspecialista
    extends UseCase<EspecialistaEntity, UpdateEspecialistaParams> {
  final ISpecialistsRepository _repository;
  UpdateEspecialista(this._repository);

  @override
  Future<Either<Failure, EspecialistaEntity>> call(UpdateEspecialistaParams params) {
    final data = <String, dynamic>{};
    if (params.numeroLicencia != null) data['numero_licencia'] = params.numeroLicencia;
    if (params.medicoRegenteId != null) data['medico_regente_id'] = params.medicoRegenteId;
    if (params.disponible != null) data['disponible'] = params.disponible;
    if (params.activo != null) data['activo'] = params.activo;
    if (params.estadoVerificacion != null) data['estado_verificacion'] = params.estadoVerificacion;
    return _repository.updateEspecialista(params.id, data);
  }
}