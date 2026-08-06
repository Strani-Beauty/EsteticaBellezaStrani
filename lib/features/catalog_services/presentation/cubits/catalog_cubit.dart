import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// Los usecases se inyectan por nombre; esta regla no aplica aquí.
// ignore_for_file: prefer_initializing_formals
import '../../domain/entities/categoria_servicio_entity.dart';
import '../../domain/entities/servicio_entity.dart';
import '../../domain/usecases/get_categorias.dart';
import '../../domain/usecases/get_servicios.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ESTADOS
// ─────────────────────────────────────────────────────────────────────────────

abstract class CatalogState extends Equatable {
  const CatalogState();
  @override
  List<Object?> get props => [];
}

class CatalogInitial extends CatalogState {
  const CatalogInitial();
}

class CatalogLoading extends CatalogState {
  const CatalogLoading();
}

class CatalogLoaded extends CatalogState {
  final List<CategoriaServicioEntity> categorias;
  final List<ServicioEntity> servicios;
  final int? selectedCategoriaId;
  final bool loadingServicios;
  const CatalogLoaded({
    this.categorias = const [],
    this.servicios = const [],
    this.selectedCategoriaId,
    this.loadingServicios = false,
  });

  CatalogLoaded copyWith({
    List<CategoriaServicioEntity>? categorias,
    List<ServicioEntity>? servicios,
    int? selectedCategoriaId,
    bool? loadingServicios,
  }) {
    return CatalogLoaded(
      categorias: categorias ?? this.categorias,
      servicios: servicios ?? this.servicios,
      selectedCategoriaId: selectedCategoriaId,
      loadingServicios: loadingServicios ?? this.loadingServicios,
    );
  }

  @override
  List<Object?> get props => [
        categorias,
        servicios,
        selectedCategoriaId,
        loadingServicios,
      ];
}

class CatalogError extends CatalogState {
  final String message;
  const CatalogError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─────────────────────────────────────────────────────────────────────────────
// CUBIT
// ─────────────────────────────────────────────────────────────────────────────

class CatalogCubit extends Cubit<CatalogState> {
  final GetCategorias _getCategorias;
  final GetServicios _getServicios;

  CatalogCubit({
    required GetCategorias getCategorias,
    required GetServicios getServicios,
  })  : _getCategorias = getCategorias,
        _getServicios = getServicios,
        super(const CatalogInitial());

  Future<void> load() async {
    emit(const CatalogLoading());
    final categoriasResult = await _getCategorias();
    categoriasResult.fold(
      (f) => emit(CatalogError(f.message)),
      (categorias) async {
        final serviciosResult =
            await _getServicios(const GetServiciosParams());
        serviciosResult.fold(
          (f) => emit(CatalogError(f.message)),
          (servicios) => emit(CatalogLoaded(
            categorias: categorias,
            servicios: servicios,
          )),
        );
      },
    );
  }

  Future<void> selectCategoria(int? categoriaId) async {
    final current = state;
    if (current is! CatalogLoaded) return;

    emit(current.copyWith(
      selectedCategoriaId: categoriaId,
      loadingServicios: true,
    ));

    final result =
        await _getServicios(GetServiciosParams(categoriaId: categoriaId));
    result.fold(
      (f) => emit(CatalogError(f.message)),
      (servicios) {
        final base = state is CatalogLoaded
            ? state as CatalogLoaded
            : current;
        emit(base.copyWith(servicios: servicios, loadingServicios: false));
      },
    );
  }
}