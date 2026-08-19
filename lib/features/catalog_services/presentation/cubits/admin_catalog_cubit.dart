import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// Los usecases se inyectan por nombre; esta regla no aplica aquí.
// ignore_for_file: prefer_initializing_formals
import '../../../../features/patients_compliance/domain/entities/cuestionario_entity.dart';
import '../../../../features/patients_compliance/domain/usecases/get_cuestionarios.dart';
import '../../../../features/specialists/domain/entities/especialidad_entity.dart';
import '../../../../features/specialists/domain/usecases/get_especialidades.dart';
import '../../domain/entities/categoria_servicio_entity.dart';
import '../../domain/entities/servicio_cuestionario_entity.dart';
import '../../domain/entities/servicio_entity.dart';
import '../../domain/usecases/get_categorias_admin.dart';
import '../../domain/usecases/get_servicios_admin.dart';
import '../../domain/usecases/guardar_categoria.dart';
import '../../domain/usecases/guardar_cuestionarios_servicio.dart';
import '../../domain/usecases/guardar_especialidades_servicio.dart';
import '../../domain/usecases/guardar_servicio.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ESTADOS
// ─────────────────────────────────────────────────────────────────────────────

abstract class AdminCatalogState extends Equatable {
  const AdminCatalogState();
  @override
  List<Object?> get props => [];
}

class AdminCatalogInitial extends AdminCatalogState {
  const AdminCatalogInitial();
}

class AdminCatalogLoading extends AdminCatalogState {
  const AdminCatalogLoading();
}

class AdminCatalogError extends AdminCatalogState {
  final String message;
  const AdminCatalogError(this.message);
  @override
  List<Object?> get props => [message];
}

class AdminCatalogLoaded extends AdminCatalogState {
  final List<CategoriaServicioEntity> categorias;
  final List<ServicioEntity> servicios;
  final List<EspecialidadEntity> especialidades;
  final List<CuestionarioEntity> cuestionarios;
  final bool saving;
  final String? feedback;
  final String? error;

  const AdminCatalogLoaded({
    this.categorias = const [],
    this.servicios = const [],
    this.especialidades = const [],
    this.cuestionarios = const [],
    this.saving = false,
    this.feedback,
    this.error,
  });

  AdminCatalogLoaded copyWith({
    List<CategoriaServicioEntity>? categorias,
    List<ServicioEntity>? servicios,
    List<EspecialidadEntity>? especialidades,
    List<CuestionarioEntity>? cuestionarios,
    bool? saving,
    String? feedback,
    String? error,
    bool clearFeedback = false,
    bool clearError = false,
  }) {
    return AdminCatalogLoaded(
      categorias: categorias ?? this.categorias,
      servicios: servicios ?? this.servicios,
      especialidades: especialidades ?? this.especialidades,
      cuestionarios: cuestionarios ?? this.cuestionarios,
      saving: saving ?? this.saving,
      feedback: clearFeedback ? null : (feedback ?? this.feedback),
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
        categorias,
        servicios,
        especialidades,
        cuestionarios,
        saving,
        feedback,
        error,
      ];
}

// ─────────────────────────────────────────────────────────────────────────────
// CUBIT
// ─────────────────────────────────────────────────────────────────────────────

class AdminCatalogCubit extends Cubit<AdminCatalogState> {
  final GetCategoriasAdmin _getCategoriasAdmin;
  final GetServiciosAdmin _getServiciosAdmin;
  final GuardarCategoria _guardarCategoria;
  final GuardarServicio _guardarServicio;
  final GuardarEspecialidadesServicio _guardarEspecialidadesServicio;
  final GuardarCuestionariosServicio _guardarCuestionariosServicio;
  final GetEspecialidades _getEspecialidades;
  final GetCuestionarios _getCuestionarios;

  AdminCatalogCubit({
    required GetCategoriasAdmin getCategoriasAdmin,
    required GetServiciosAdmin getServiciosAdmin,
    required GuardarCategoria guardarCategoria,
    required GuardarServicio guardarServicio,
    required GuardarEspecialidadesServicio guardarEspecialidadesServicio,
    required GuardarCuestionariosServicio guardarCuestionariosServicio,
    required GetEspecialidades getEspecialidades,
    required GetCuestionarios getCuestionarios,
  })  : _getCategoriasAdmin = getCategoriasAdmin,
        _getServiciosAdmin = getServiciosAdmin,
        _guardarCategoria = guardarCategoria,
        _guardarServicio = guardarServicio,
        _guardarEspecialidadesServicio = guardarEspecialidadesServicio,
        _guardarCuestionariosServicio = guardarCuestionariosServicio,
        _getEspecialidades = getEspecialidades,
        _getCuestionarios = getCuestionarios,
        super(const AdminCatalogInitial());

  Future<void> load() async {
    emit(const AdminCatalogLoading());

    final categoriasRes = await _getCategoriasAdmin();
    if (categoriasRes.isLeft()) {
      emit(AdminCatalogError(categoriasRes.getLeft().toNullable()!.message));
      return;
    }
    final serviciosRes = await _getServiciosAdmin();
    if (serviciosRes.isLeft()) {
      emit(AdminCatalogError(serviciosRes.getLeft().toNullable()!.message));
      return;
    }
    final especialidadesRes = await _getEspecialidades();
    if (especialidadesRes.isLeft()) {
      emit(AdminCatalogError(especialidadesRes.getLeft().toNullable()!.message));
      return;
    }
    final cuestionariosRes = await _getCuestionarios(
      const GetCuestionariosParams(),
    );
    if (cuestionariosRes.isLeft()) {
      emit(AdminCatalogError(cuestionariosRes.getLeft().toNullable()!.message));
      return;
    }

    emit(AdminCatalogLoaded(
      categorias: categoriasRes.getRight().toNullable() ?? const [],
      servicios: serviciosRes.getRight().toNullable() ?? const [],
      especialidades: especialidadesRes.getRight().toNullable() ?? const [],
      cuestionarios: cuestionariosRes.getRight().toNullable() ?? const [],
    ));
  }

  Future<CategoriaServicioEntity?> guardarCategoria({
    int id = 0,
    required String nombre,
    String? descripcion,
    required bool activo,
  }) async {
    if (state is! AdminCatalogLoaded) return null;
    final base = state as AdminCatalogLoaded;
    emit(base.copyWith(saving: true, clearError: true));

    final res = await _guardarCategoria(GuardarCategoriaParams(
      id: id,
      nombre: nombre,
      descripcion: descripcion,
      activo: activo,
    ));
    if (res.isLeft()) {
      emit(base.copyWith(
        saving: false,
        error: res.getLeft().toNullable()?.message,
      ));
      return null;
    }

    final categoriasRes = await _getCategoriasAdmin();
    final categorias =
        categoriasRes.getRight().toNullable() ?? base.categorias;
    emit(AdminCatalogLoaded(
      categorias: categorias,
      servicios: base.servicios,
      especialidades: base.especialidades,
      cuestionarios: base.cuestionarios,
      saving: false,
      feedback:
          id > 0 ? 'Categoría actualizada' : 'Categoría creada correctamente',
    ));
    return res.getRight().toNullable();
  }

  Future<ServicioEntity?> guardarServicio({
    String id = '',
    int? categoriaId,
    required String nombre,
    String? descripcion,
    required double precioBase,
    required TipoPrecio tipoPrecio,
    int? duracionEstimada,
    bool requiereTelemedicina = false,
    bool requiereFaceMap = false,
    bool requiereFotos = false,
    bool requiereConsentimiento = false,
    bool activo = true,
  }) async {
    if (state is! AdminCatalogLoaded) return null;
    final base = state as AdminCatalogLoaded;
    emit(base.copyWith(saving: true, clearError: true));

    final res = await _guardarServicio(GuardarServicioParams(
      id: id,
      categoriaId: categoriaId,
      nombre: nombre,
      descripcion: descripcion,
      precioBase: precioBase,
      tipoPrecio: tipoPrecio,
      duracionEstimada: duracionEstimada,
      requiereTelemedicina: requiereTelemedicina,
      requiereFaceMap: requiereFaceMap,
      requiereFotos: requiereFotos,
      requiereConsentimiento: requiereConsentimiento,
      activo: activo,
    ));
    if (res.isLeft()) {
      emit(base.copyWith(
        saving: false,
        error: res.getLeft().toNullable()?.message,
      ));
      return null;
    }

    final serviciosRes = await _getServiciosAdmin();
    final servicios = serviciosRes.getRight().toNullable() ?? base.servicios;
    emit(AdminCatalogLoaded(
      categorias: base.categorias,
      servicios: servicios,
      especialidades: base.especialidades,
      cuestionarios: base.cuestionarios,
      saving: false,
      feedback:
          id.isEmpty ? 'Servicio creado correctamente' : 'Servicio actualizado',
    ));
    return res.getRight().toNullable();
  }

  Future<bool> guardarEspecialidadesServicio(
    String servicioId,
    List<int> especialidadIds,
  ) async {
    if (state is! AdminCatalogLoaded) return false;
    final base = state as AdminCatalogLoaded;
    final res = await _guardarEspecialidadesServicio(
      GuardarEspecialidadesServicioParams(
        servicioId: servicioId,
        especialidadIds: especialidadIds,
      ),
    );
    return res.fold(
      (f) {
        emit(base.copyWith(error: f.message));
        return false;
      },
      (_) {
        emit(base.copyWith(feedback: 'Especialidades guardadas'));
        return true;
      },
    );
  }

  Future<bool> guardarCuestionariosServicio(
    String servicioId,
    List<ServicioCuestionarioEntity> items,
  ) async {
    if (state is! AdminCatalogLoaded) return false;
    final base = state as AdminCatalogLoaded;
    final res = await _guardarCuestionariosServicio(
      GuardarCuestionariosServicioParams(
        servicioId: servicioId,
        items: items,
      ),
    );
    return res.fold(
      (f) {
        emit(base.copyWith(error: f.message));
        return false;
      },
      (_) {
        emit(base.copyWith(feedback: 'Cuestionarios guardados'));
        return true;
      },
    );
  }
}