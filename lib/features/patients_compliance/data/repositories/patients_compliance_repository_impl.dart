import 'package:esteticaybellezastrani/features/patients_compliance/domain/repositories/i_patients_compliance_repository.dart';
import 'package:esteticaybellezastrani/supabase_service.dart';
import 'package:latlong2/latlong.dart';

/// Implementación del repositorio de compliance del paciente.
/// Por ahora delega en [SupabaseService]; en una iteración posterior el
/// servicio monolítico migrará a datasources y este impl dejará de delegar.
class PatientsComplianceRepositoryImpl implements IPatientsComplianceRepository {
  const PatientsComplianceRepositoryImpl();

  @override
  Future<LatLng?> geocodeAddress(String address) =>
      SupabaseService.geocodeAddress(address);

  @override
  Future<String?> savePatientAddress({
    required String profileId,
    required String address,
    required double latitude,
    required double longitude,
  }) =>
      SupabaseService.savePatientAddress(
        profileId: profileId,
        address: address,
        latitude: latitude,
        longitude: longitude,
      );

  @override
  Future<bool> saveHealthEvaluation({
    required String profileId,
    required String serviceName,
    required Map<String, String> answers,
  }) =>
      SupabaseService.saveHealthEvaluation(
        profileId: profileId,
        serviceName: serviceName,
        answers: answers,
      );

  @override
  Future<void> saveQualifyTestValidation({
    required String profileId,
    required bool aprobado,
    String proveedor = 'Telemedicina',
  }) =>
      SupabaseService.saveQualifyTestValidation(
        profileId: profileId,
        aprobado: aprobado,
        proveedor: proveedor,
      );

  @override
  Future<bool> saveFaceMapRecord({
    required String profileId,
    String? tratamientoId,
    required List<String> zonasSeleccionadas,
    List<String>? zonasProhibidasIntentadas,
    String? notas,
  }) =>
      SupabaseService.saveFaceMapRecord(
        profileId: profileId,
        tratamientoId: tratamientoId,
        zonasSeleccionadas: zonasSeleccionadas,
        zonasProhibidasIntentadas: zonasProhibidasIntentadas,
        notas: notas,
      );

  @override
  Future<Map<String, dynamic>> checkPatientFlowStatus({
    required String profileId,
  }) =>
      SupabaseService.checkPatientFlowStatus(profileId: profileId);

  @override
  Future<Map<String, dynamic>> validateReservationRulesRN020({
    required String profileId,
  }) =>
      SupabaseService.validateReservationRulesRN020(profileId: profileId);
}
