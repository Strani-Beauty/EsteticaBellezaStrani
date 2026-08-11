import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/app/core/usecases/use_case.dart';
import '../entities/documento_especialista_entity.dart';
import '../repositories/i_specialists_repository.dart';

class RevisarDocumentoParams {
  final String documentoId;
  final EstadoRevisionDocumento estado;
  final String? observacion;
  final String revisadoPor;
  const RevisarDocumentoParams({
    required this.documentoId,
    required this.estado,
    this.observacion,
    required this.revisadoPor,
  });
}

/// Revisa un documento del especialista (APROBADO/RECHAZADO) desde el panel
/// de administración. Al rechazarlo se registra la observación visible para
/// el especialista.
class RevisarDocumento
    extends UseCase<DocumentoEspecialistaEntity, RevisarDocumentoParams> {
  final ISpecialistsRepository _repository;
  RevisarDocumento(this._repository);

  @override
  Future<Either<Failure, DocumentoEspecialistaEntity>> call(
      RevisarDocumentoParams params) {
    return _repository.revisarDocumento(
      documentoId: params.documentoId,
      estado: params.estado,
      observacion: params.observacion,
      revisadoPor: params.revisadoPor,
    );
  }
}