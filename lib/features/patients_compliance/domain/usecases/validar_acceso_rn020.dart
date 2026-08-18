import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../../../app/core/usecases/use_case.dart';
import '../repositories/i_patients_compliance_repository.dart';

/// Resultado del gate RN-020 / RN-022 (requisito 12).
class ValidarAccesoRN020Result extends Equatable {
  final bool allowed;
  final String reason; // 'APROBADA' | 'VENCIDA' | 'RECHAZADA' | 'PENDIENTE'
  final String message;

  const ValidarAccesoRN020Result({
    required this.allowed,
    required this.reason,
    required this.message,
  });

  @override
  List<Object?> get props => [allowed, reason, message];
}

/// Regla estricta de reserva: bloquea si la validación médica no está
/// APROBADA y VIGENTE. Fuente limpia: `consultarEstadoSalud`.
class ValidarAccesoRN020 extends NoParamsUseCase<ValidarAccesoRN020Result> {
  final IPatientsComplianceRepository _repository;
  ValidarAccesoRN020(this._repository);

  @override
  Future<Either<Failure, ValidarAccesoRN020Result>> call() async {
    final result = await _repository.consultarEstadoSalud();
    return result.fold(
      (f) => Left(f),
      (estado) {
        final reason = estado.validacionEstado;
        switch (reason) {
          case 'RECHAZADA':
            return Right(const ValidarAccesoRN020Result(
              allowed: false,
              reason: 'RECHAZADA',
              message:
                  'REGLA RN-020/RN-022: Tu evaluación médica fue RECHAZADA. Queda estrictamente bloqueada cualquier reserva hasta obtener un dictamen médico favorable.',
            ));
          case 'VENCIDA':
            return Right(const ValidarAccesoRN020Result(
              allowed: false,
              reason: 'VENCIDA',
              message:
                  'REGLA RN-020/RN-022: Tu evaluación médica tiene más de 1 año (365 días) de emitida y está VENCIDA. Debes abonar el pago de \$30 USD y realizar una nueva evaluación médica.',
            ));
          case 'APROBADA':
            return Right(const ValidarAccesoRN020Result(
              allowed: true,
              reason: 'APROBADA',
              message: 'Evaluación médica aprobada y vigente (< 1 año).',
            ));
          default:
            return Right(const ValidarAccesoRN020Result(
              allowed: false,
              reason: 'PENDIENTE',
              message:
                  'REGLA RN-020/RN-022: No cuentas con una evaluación médica aprobada. Debes completar la cuota inicial de \$30 USD y la evaluación médica clínica.',
            ));
        }
      },
    );
  }
}