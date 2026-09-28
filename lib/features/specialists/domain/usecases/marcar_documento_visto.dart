import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/usecases/use_case.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import '../entities/documento_especialista_entity.dart';
import '../repositories/i_specialists_repository.dart';

class MarcarDocumentoVistoParams {
  final String documentoId;
  const MarcarDocumentoVistoParams({required this.documentoId});
}

/// Registra que el administrador abrió/revisó el archivo del documento.
/// Habilita los botones de aprobar/rechazar (gate ePHI).
class MarcarDocumentoVisto
    extends UseCase<DocumentoEspecialistaEntity, MarcarDocumentoVistoParams> {
  final ISpecialistsRepository _repository;
  MarcarDocumentoVisto(this._repository);

  @override
  Future<Either<Failure, DocumentoEspecialistaEntity>> call(
      MarcarDocumentoVistoParams params) {
    return _repository.marcarDocumentoVisto(params.documentoId);
  }
}
