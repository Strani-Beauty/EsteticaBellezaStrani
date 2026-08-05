import 'package:esteticaybellezastrani/features/catalog_services/domain/repositories/i_catalog_repository.dart';
import 'package:esteticaybellezastrani/app/core/network/supabase_service.dart';

/// ImplementaciÃ³n del repositorio de catÃ¡logo.
/// Por ahora delega en [SupabaseService]; en una iteraciÃ³n posterior el
/// servicio monolÃ­tico migrarÃ¡ a datasources y este impl dejarÃ¡ de delegar.
class CatalogRepositoryImpl implements ICatalogRepository {
  const CatalogRepositoryImpl();

  @override
  Future<List<Map<String, dynamic>>> fetchCategories() =>
      SupabaseService.fetchCatalogCategories();

  @override
  Future<List<Map<String, dynamic>>> fetchServices({String? categoriaId}) =>
      SupabaseService.fetchCatalogServices(categoriaId: categoriaId);

  @override
  Future<Map<String, bool>> checkServicePrerequisites({
    required Map<String, dynamic> serviceData,
    required String profileId,
  }) =>
      SupabaseService.checkServicePrerequisites(
        serviceData: serviceData,
        profileId: profileId,
      );

  @override
  Future<String?> createServicePayment({
    required String profileId,
    required String serviceTitle,
    required double servicePrice,
    required bool payFullAmount,
  }) =>
      SupabaseService.createServicePayment(
        profileId: profileId,
        serviceTitle: serviceTitle,
        servicePrice: servicePrice,
        payFullAmount: payFullAmount,
      );
}
