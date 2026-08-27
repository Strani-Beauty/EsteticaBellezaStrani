import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import '../entities/categoria_servicio_entity.dart';
import '../entities/servicio_cuestionario_entity.dart';
import '../entities/servicio_entity.dart';

/// Contrato del catálogo de servicios.
/// Se usa fpdart [Either] para errores tipados.
/// La implementación vive en data/repositories/catalog_repository_impl.dart
abstract class ICatalogRepository {
  /// Categorías activas del catálogo.
  Future<Either<Failure, List<CategoriaServicioEntity>>> getCategorias();

  /// Servicios activos, opcionalmente filtrados por categoría.
  Future<Either<Failure, List<ServicioEntity>>> getServicios({
    int? categoriaId,
  });

  // ── Admin ─────────────────────────────────────────────────────────────────

  /// Todas las categorías (incl. inactivas) — mantenimiento admin.
  Future<Either<Failure, List<CategoriaServicioEntity>>> getCategoriasAdmin();

  /// Crea (id == 0) o actualiza (id > 0) una categoría.
  Future<Either<Failure, CategoriaServicioEntity>> guardarCategoria({
    int id = 0,
    required String nombre,
    String? descripcion,
    required bool activo,
  });

  /// Todos los servicios (incl. inactivos) — mantenimiento admin.
  Future<Either<Failure, List<ServicioEntity>>> getServiciosAdmin();

  /// Crea (id vacío) o actualiza (id presente) un servicio.
  Future<Either<Failure, ServicioEntity>> guardarServicio({
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
    String? imagenUrl,
  });

  /// Elimina un servicio del catálogo (RPC seguro, solo admin).
  Future<Either<Failure, void>> eliminarServicio(String servicioId);

  /// Sube la imagen de un servicio al bucket público y guarda la URL en
  /// `servicios.imagen_url`. Devuelve la URL pública (solo admin).
  Future<Either<Failure, String>> subirImagenServicio({
    required String servicioId,
    required Uint8List bytes,
    required String nombreArchivo,
  });

  /// Requisitos configurados de un servicio (especialidades + cuestionarios).
  Future<Either<Failure, ServicioRequisitosEntity>> getRequisitosServicio(
    String servicioId,
  );

  /// Reemplaza las especialidades de un servicio (RPC atómico, solo admin).
  Future<Either<Failure, void>> guardarEspecialidadesServicio(
    String servicioId,
    List<int> especialidadIds,
  );

  /// Reemplaza los cuestionarios de un servicio (RPC atómico, solo admin).
  Future<Either<Failure, void>> guardarCuestionariosServicio(
    String servicioId,
    List<ServicioCuestionarioEntity> items,
  );
}