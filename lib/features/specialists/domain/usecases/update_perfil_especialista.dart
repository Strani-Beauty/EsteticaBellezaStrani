import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/app/core/usecases/use_case.dart';
import '../repositories/i_specialists_repository.dart';

class UpdatePerfilEspecialistaParams {
  final String userId;
  final String? fullName;
  final String? phone;
  final String? address;
  final double? latitude;
  final double? longitude;
  final double? hourlyRate;
  final String? avatarUrl;
  const UpdatePerfilEspecialistaParams({
    required this.userId,
    this.fullName,
    this.phone,
    this.address,
    this.latitude,
    this.longitude,
    this.hourlyRate,
    this.avatarUrl,
  });
}

/// Actualiza los datos personales del especialista (columnas de `profiles`).
class UpdatePerfilEspecialista
    extends UseCase<void, UpdatePerfilEspecialistaParams> {
  final ISpecialistsRepository _repository;
  UpdatePerfilEspecialista(this._repository);

  @override
  Future<Either<Failure, void>> call(UpdatePerfilEspecialistaParams params) {
    return _repository.updatePerfilEspecialista(
      userId: params.userId,
      fullName: params.fullName,
      phone: params.phone,
      address: params.address,
      latitude: params.latitude,
      longitude: params.longitude,
      hourlyRate: params.hourlyRate,
      avatarUrl: params.avatarUrl,
    );
  }
}
