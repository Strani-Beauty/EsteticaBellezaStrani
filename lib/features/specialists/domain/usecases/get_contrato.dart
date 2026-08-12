import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/app/core/usecases/use_case.dart';
import '../entities/contrato_entity.dart';
import '../repositories/i_specialists_repository.dart';

class GetContratoParams {
  final String especialistaId;
  const GetContratoParams(this.especialistaId);
}

/// Obtiene el contrato vigente del especialista.
class GetContrato extends UseCase<ContratoEntity?, GetContratoParams> {
  final ISpecialistsRepository _repository;
  GetContrato(this._repository);

  @override
  Future<Either<Failure, ContratoEntity?>> call(GetContratoParams params) {
    return _repository.getContrato(params.especialistaId);
  }
}

class FirmarContratoParams {
  final String especialistaId;
  final MetodoFirma metodoFirma;
  final String? urlDocumento;
  final int versionContrato;
  const FirmarContratoParams({
    required this.especialistaId,
    required this.metodoFirma,
    this.urlDocumento,
    this.versionContrato = 1,
  });
}

/// Registra la firma del contrato del especialista.
class FirmarContrato extends UseCase<ContratoEntity, FirmarContratoParams> {
  final ISpecialistsRepository _repository;
  FirmarContrato(this._repository);

  @override
  Future<Either<Failure, ContratoEntity>> call(FirmarContratoParams params) {
    return _repository.firmarContrato(
      params.especialistaId,
      metodoFirma: params.metodoFirma,
      urlDocumento: params.urlDocumento,
      versionContrato: params.versionContrato,
    );
  }
}

class SubirFirmaContratoParams {
  final String especialistaId;
  final Uint8List bytes;
  const SubirFirmaContratoParams({
    required this.especialistaId,
    required this.bytes,
  });
}

/// Sube la imagen de la firma manuscrita del contrato al storage y devuelve la URL.
class SubirFirmaContrato
    extends UseCase<String, SubirFirmaContratoParams> {
  final ISpecialistsRepository _repository;
  SubirFirmaContrato(this._repository);

  @override
  Future<Either<Failure, String>> call(SubirFirmaContratoParams params) {
    return _repository.subirFirmaContrato(
      especialistaId: params.especialistaId,
      bytes: params.bytes,
    );
  }
}