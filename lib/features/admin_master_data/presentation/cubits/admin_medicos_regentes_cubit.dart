import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Los usecases se inyectan por nombre; esta regla no aplica aquí.
// ignore_for_file: prefer_initializing_formals

import 'package:esteticaybellezastrani/features/specialists/domain/entities/medico_regente_entity.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/usecases/aprobar_medico_regente.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/usecases/create_medico_regente.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/usecases/get_medicos_regentes.dart';

abstract class AdminMedicosRegentesState extends Equatable {
  const AdminMedicosRegentesState();
  @override
  List<Object?> get props => [];
}

class AdminMedicosRegentesInitial extends AdminMedicosRegentesState {
  const AdminMedicosRegentesInitial();
}

class AdminMedicosRegentesLoading extends AdminMedicosRegentesState {
  const AdminMedicosRegentesLoading();
}

class AdminMedicosRegentesLoaded extends AdminMedicosRegentesState {
  final List<MedicoRegenteEntity> items;
  const AdminMedicosRegentesLoaded(this.items);
  @override
  List<Object?> get props => [items];
}

class AdminMedicosRegentesError extends AdminMedicosRegentesState {
  final String message;
  const AdminMedicosRegentesError(this.message);
  @override
  List<Object?> get props => [message];
}

class AdminMedicosRegentesCubit extends Cubit<AdminMedicosRegentesState> {
  final GetMedicosRegentes _getMedicos;
  final CreateMedicoRegente _createMedico;
  final AprobarMedicoRegente _aprobarMedico;

  AdminMedicosRegentesCubit({
    required GetMedicosRegentes getMedicos,
    required CreateMedicoRegente createMedico,
    required AprobarMedicoRegente aprobarMedico,
  })  : _getMedicos = getMedicos,
        _createMedico = createMedico,
        _aprobarMedico = aprobarMedico,
        super(const AdminMedicosRegentesInitial());

  Future<void> load() async {
    emit(const AdminMedicosRegentesLoading());
    final result =
        await _getMedicos(const GetMedicosRegentesParams(soloActivos: false));
    result.fold(
      (f) => emit(AdminMedicosRegentesError(f.message)),
      (items) => emit(AdminMedicosRegentesLoaded(items)),
    );
  }

  Future<bool> crear({
    required String nombre,
    String? numeroLicencia,
    String? telefono,
    String? correo,
  }) async {
    final result = await _createMedico(CreateMedicoRegenteParams(
      nombre: nombre,
      numeroLicencia: numeroLicencia,
      telefono: telefono,
      correo: correo,
    ));
    var ok = false;
    result.fold((f) => emit(AdminMedicosRegentesError(f.message)), (_) => ok = true);
    if (ok) await load();
    return ok;
  }

  Future<bool> aprobar(String id) async {
    final result = await _aprobarMedico(AprobarMedicoRegenteParams(id));
    var ok = false;
    result.fold((f) => emit(AdminMedicosRegentesError(f.message)), (_) => ok = true);
    if (ok) await load();
    return ok;
  }
}
