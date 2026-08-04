/// Contrato del catálogo de servicios.
/// La implementación vive en data/. Las pantallas migrarán de SupabaseService
/// a este contrato vía GetIt.
abstract class ICatalogRepository {
  /// Categorías activas del catálogo.
  Future<List<Map<String, dynamic>>> fetchCategories();

  /// Servicios activos del catálogo, opcionalmente filtrados por categoría.
  Future<List<Map<String, dynamic>>> fetchServices({String? categoriaId});

  /// Verifica los prerrequisitos de un servicio para el paciente.
  Future<Map<String, bool>> checkServicePrerequisites({
    required Map<String, dynamic> serviceData,
    required String profileId,
  });

  /// Crea la solicitud/pago de un servicio evaluado.
  Future<String?> createServicePayment({
    required String profileId,
    required String serviceTitle,
    required double servicePrice,
    required bool payFullAmount,
  });
}
