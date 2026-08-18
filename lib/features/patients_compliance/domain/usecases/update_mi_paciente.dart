import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../../../app/core/usecases/use_case.dart';
import '../entities/paciente_entity.dart';
import '../repositories/i_patients_compliance_repository.dart';

class UpdateMiPacienteParams {
  final DateTime? fechaNacimiento;
  final String? genero;
  final String? grupoSanguineo;
  final String? alergias;
  final String? antecedentes;
  final bool? activo;

  const UpdateMiPacienteParams({
    this.fechaNacimiento,
    this.genero,
    this.grupoSanguineo,
    this.alergias,
    this.antecedentes,
    this.activo,
  });
}

/// Actualiza la información básica/clínica del paciente autenticado.
class UpdateMiPaciente extends UseCase<PacienteEntity?, UpdateMiPacienteParams> {
  final IPatientsComplianceRepository _repository;
  UpdateMiPaciente(this._repository);

  @override
  Future<Either<Failure, PacienteEntity?>> call(UpdateMiPacienteParams params) {
    return _repository.updateMiPaciente(
      fechaNacimiento: params.fechaNacimiento,
      genero: params.genero,
      grupoSanguineo: params.grupoSanguineo,
      alergias: params.alergias,
      antecedentes: params.antecedentes,
      activo: params.activo,
    );
  }
}