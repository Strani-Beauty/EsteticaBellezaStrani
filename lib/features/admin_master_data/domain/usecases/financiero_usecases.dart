import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../../../app/core/usecases/use_case.dart';
import '../entities/financiero_entity.dart';
import '../repositories/i_admin_master_data_repository.dart';

class GetLiquidaciones extends NoParamsUseCase<List<LiquidacionEntity>> {
  final IAdminMasterDataRepository _repository;
  GetLiquidaciones(this._repository);
  @override
  Future<Either<Failure, List<LiquidacionEntity>>> call() async {
    try {
      return await _repository.getLiquidaciones();
    } catch (e) {
      return Left(ServerFailure('No se pudieron cargar las liquidaciones: $e'));
    }
  }
}

class GetPagosEspecialistas
    extends NoParamsUseCase<List<PagoEspecialistaEntity>> {
  final IAdminMasterDataRepository _repository;
  GetPagosEspecialistas(this._repository);
  @override
  Future<Either<Failure, List<PagoEspecialistaEntity>>> call() async {
    try {
      return await _repository.getPagosEspecialistas();
    } catch (e) {
      return Left(
          ServerFailure('No se pudieron cargar los pagos a especialistas: $e'));
    }
  }
}

class GetMisLiquidacionesParams {
  final String especialistaId;
  const GetMisLiquidacionesParams(this.especialistaId);
}

class GetMisLiquidaciones
    extends UseCase<List<LiquidacionEntity>, GetMisLiquidacionesParams> {
  final IAdminMasterDataRepository _repository;
  GetMisLiquidaciones(this._repository);
  @override
  Future<Either<Failure, List<LiquidacionEntity>>> call(
      GetMisLiquidacionesParams params) async {
    try {
      return await _repository.getMisLiquidaciones(params.especialistaId);
    } catch (e) {
      return Left(
          ServerFailure('No se pudieron cargar tus liquidaciones: $e'));
    }
  }
}

class GetMisPagosEspecialistasParams {
  final String especialistaId;
  const GetMisPagosEspecialistasParams(this.especialistaId);
}

class GetMisPagosEspecialistas extends UseCase<List<PagoEspecialistaEntity>,
    GetMisPagosEspecialistasParams> {
  final IAdminMasterDataRepository _repository;
  GetMisPagosEspecialistas(this._repository);
  @override
  Future<Either<Failure, List<PagoEspecialistaEntity>>> call(
      GetMisPagosEspecialistasParams params) async {
    try {
      return await _repository.getMisPagosEspecialistas(params.especialistaId);
    } catch (e) {
      return Left(ServerFailure('No se pudieron cargar tus pagos: $e'));
    }
  }
}

class GetCitasFinalizadasAdminParams {
  final DateTime desde;
  final DateTime hasta;
  const GetCitasFinalizadasAdminParams({
    required this.desde,
    required this.hasta,
  });
}

class GetCitasFinalizadasAdmin extends UseCase<List<CitaFinalizadaAdminEntity>,
    GetCitasFinalizadasAdminParams> {
  final IAdminMasterDataRepository _repository;
  GetCitasFinalizadasAdmin(this._repository);
  @override
  Future<Either<Failure, List<CitaFinalizadaAdminEntity>>> call(
      GetCitasFinalizadasAdminParams params) async {
    try {
      return await _repository.getCitasFinalizadasAdmin(
        desde: params.desde,
        hasta: params.hasta,
      );
    } catch (e) {
      return Left(
          ServerFailure('No se pudieron cargar las citas terminadas: $e'));
    }
  }
}

class GetLiquidacionDetallesParams {
  final String liquidacionId;
  const GetLiquidacionDetallesParams(this.liquidacionId);
}

class GetLiquidacionDetalles extends UseCase<List<DetalleLiquidacionEntity>,
    GetLiquidacionDetallesParams> {
  final IAdminMasterDataRepository _repository;
  GetLiquidacionDetalles(this._repository);
  @override
  Future<Either<Failure, List<DetalleLiquidacionEntity>>> call(
      GetLiquidacionDetallesParams params) async {
    try {
      return await _repository.getLiquidacionDetalles(params.liquidacionId);
    } catch (e) {
      return Left(ServerFailure('No se pudieron cargar los detalles: $e'));
    }
  }
}

class CambiarEstadoLiquidacionParams {
  final String liquidacionId;
  final String nuevoEstado;
  const CambiarEstadoLiquidacionParams({
    required this.liquidacionId,
    required this.nuevoEstado,
  });
}

class CambiarEstadoLiquidacion
    extends UseCase<String, CambiarEstadoLiquidacionParams> {
  final IAdminMasterDataRepository _repository;
  CambiarEstadoLiquidacion(this._repository);
  @override
  Future<Either<Failure, String>> call(
      CambiarEstadoLiquidacionParams params) async {
    try {
      return await _repository.cambiarEstadoLiquidacion(
          params.liquidacionId, params.nuevoEstado);
    } catch (e) {
      return Left(ServerFailure('No se pudo cambiar el estado: $e'));
    }
  }
}

class RegistrarPagoEspecialistaParams {
  final String liquidacionId;
  final String metodoPago;
  final String? referenciaPago;
  final String? comprobanteUrl;
  final String? notas;
  final double? montoPagado;
  const RegistrarPagoEspecialistaParams({
    required this.liquidacionId,
    required this.metodoPago,
    this.referenciaPago,
    this.comprobanteUrl,
    this.notas,
    this.montoPagado,
  });
}

class RegistrarPagoEspecialista
    extends UseCase<String, RegistrarPagoEspecialistaParams> {
  final IAdminMasterDataRepository _repository;
  RegistrarPagoEspecialista(this._repository);
  @override
  Future<Either<Failure, String>> call(
      RegistrarPagoEspecialistaParams params) async {
    try {
      return await _repository.registrarPagoEspecialista(
        liquidacionId: params.liquidacionId,
        metodoPago: params.metodoPago,
        referenciaPago: params.referenciaPago,
        comprobanteUrl: params.comprobanteUrl,
        notas: params.notas,
        montoPagado: params.montoPagado,
      );
    } catch (e) {
      return Left(ServerFailure('No se pudo registrar el pago: $e'));
    }
  }
}

class SubirComprobantePagoParams {
  final String liquidacionId;
  final List<int> bytes;
  final String nombreArchivo;
  const SubirComprobantePagoParams({
    required this.liquidacionId,
    required this.bytes,
    required this.nombreArchivo,
  });
}

class SubirComprobantePago extends UseCase<String, SubirComprobantePagoParams> {
  final IAdminMasterDataRepository _repository;
  SubirComprobantePago(this._repository);
  @override
  Future<Either<Failure, String>> call(SubirComprobantePagoParams params) async {
    try {
      return await _repository.subirComprobantePago(
        liquidacionId: params.liquidacionId,
        bytes: params.bytes,
        nombreArchivo: params.nombreArchivo,
      );
    } catch (e) {
      return Left(ServerFailure('No se pudo subir el comprobante: $e'));
    }
  }
}

class GetInicioSemanaLiquidacion extends NoParamsUseCase<int> {
  final IAdminMasterDataRepository _repository;
  GetInicioSemanaLiquidacion(this._repository);
  @override
  Future<Either<Failure, int>> call() async {
    try {
      return await _repository.getInicioSemanaLiquidacion();
    } catch (e) {
      return Left(ServerFailure('No se pudo leer la configuración: $e'));
    }
  }
}

class FirmarComprobanteParams {
  final String path;
  const FirmarComprobanteParams({required this.path});
}

class FirmarComprobante extends UseCase<String?, FirmarComprobanteParams> {
  final IAdminMasterDataRepository _repository;
  FirmarComprobante(this._repository);
  @override
  Future<Either<Failure, String?>> call(FirmarComprobanteParams params) async {
    try {
      return await _repository.firmarComprobante(params.path);
    } catch (e) {
      return Left(ServerFailure('No se pudo firmar el comprobante: $e'));
    }
  }
}
