import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../../../app/core/usecases/use_case.dart';
import '../../../../features/patients_compliance/domain/repositories/i_patients_compliance_repository.dart';
import '../entities/servicio_cuestionario_entity.dart';
import '../repositories/i_catalog_repository.dart';

class ValidarRequisitosServicioParams {
  final String servicioId;
  final bool requiereFotos;
  final bool requiereConsentimiento;

  const ValidarRequisitosServicioParams({
    required this.servicioId,
    this.requiereFotos = false,
    this.requiereConsentimiento = false,
  });
}

/// Resultado de la validación de requisitos de salud por servicio.
class ValidarRequisitosServicioResult extends Equatable {
  final bool cumple;
  final List<ServicioCuestionarioEntity> cuestionariosPendientes;
  final bool requiereFotos;
  final bool requiereConsentimiento;

  const ValidarRequisitosServicioResult({
    required this.cumple,
    this.cuestionariosPendientes = const [],
    this.requiereFotos = false,
    this.requiereConsentimiento = false,
  });

  @override
  List<Object?> get props =>
      [cumple, cuestionariosPendientes, requiereFotos, requiereConsentimiento];
}

/// Valida que el paciente cumpla los requisitos configurados del servicio
/// (Act. 10): cada cuestionario obligatorio vinculado (`servicio_cuestionarios`)
/// debe tener una evaluación APTO de ese cuestionario.
class ValidarRequisitosServicio
    extends UseCase<ValidarRequisitosServicioResult, ValidarRequisitosServicioParams> {
  final ICatalogRepository _catalogRepository;
  final IPatientsComplianceRepository _complianceRepository;

  ValidarRequisitosServicio(this._catalogRepository, this._complianceRepository);

  @override
  Future<Either<Failure, ValidarRequisitosServicioResult>> call(
      ValidarRequisitosServicioParams params) async {
    final requisitosRes =
        await _catalogRepository.getRequisitosServicio(params.servicioId);
    return requisitosRes.fold(
      (f) => Left(f),
      (requisitos) async {
        final pendientes = <ServicioCuestionarioEntity>[];
        for (final c in requisitos.cuestionariosObligatorios) {
          final aptaRes = await _complianceRepository
              .tieneEvaluacionAptaDeCuestionario(c.cuestionarioId);
          final apta = aptaRes.fold((_) => false, (r) => r);
          if (!apta) pendientes.add(c);
        }
        return Right(ValidarRequisitosServicioResult(
          cumple: pendientes.isEmpty,
          cuestionariosPendientes: pendientes,
          requiereFotos: params.requiereFotos,
          requiereConsentimiento: params.requiereConsentimiento,
        ));
      },
    );
  }
}