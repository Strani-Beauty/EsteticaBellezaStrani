import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/app/core/usecases/use_case.dart';
import '../entities/documento_especialista_entity.dart';
import '../repositories/i_specialists_repository.dart';

class GetDocumentosParams {
  final String especialistaId;
  const GetDocumentosParams(this.especialistaId);
}

/// Lista los documentos de un especialista.
class GetDocumentos
    extends UseCase<List<DocumentoEspecialistaEntity>, GetDocumentosParams> {
  final ISpecialistsRepository _repository;
  GetDocumentos(this._repository);

  @override
  Future<Either<Failure, List<DocumentoEspecialistaEntity>>> call(
      GetDocumentosParams params) {
    return _repository.getDocumentos(params.especialistaId);
  }
}

class RegisterDocumentoParams {
  final String especialistaId;
  final TipoDocumento tipoDocumento;
  final String? nombreArchivo;
  final String? urlArchivo;
  final int versionDocumento;
  const RegisterDocumentoParams({
    required this.especialistaId,
    required this.tipoDocumento,
    this.nombreArchivo,
    this.urlArchivo,
    this.versionDocumento = 1,
  });
}

/// Registra un nuevo documento para revisión.
class RegisterDocumento
    extends UseCase<DocumentoEspecialistaEntity, RegisterDocumentoParams> {
  final ISpecialistsRepository _repository;
  RegisterDocumento(this._repository);

  @override
  Future<Either<Failure, DocumentoEspecialistaEntity>> call(
      RegisterDocumentoParams params) {
    return _repository.registerDocumento(
      especialistaId: params.especialistaId,
      tipoDocumento: params.tipoDocumento,
      nombreArchivo: params.nombreArchivo,
      urlArchivo: params.urlArchivo,
      versionDocumento: params.versionDocumento,
    );
  }
}