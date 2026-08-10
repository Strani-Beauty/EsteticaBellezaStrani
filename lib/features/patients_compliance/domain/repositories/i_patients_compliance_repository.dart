import 'package:latlong2/latlong.dart';

/// Contrato de geocodificación y datos del paciente.
/// La implementación vive en data/. Las pantallas migrarán de SupabaseService
/// a este contrato vía GetIt.
abstract class IPatientsComplianceRepository {
  /// Geocodifica una dirección libre a coordenadas (caché + rate-limit).
  Future<LatLng?> geocodeAddress(String address);

  /// Guarda la dirección principal del paciente.
  Future<String?> savePatientAddress({
    required String profileId,
    required String address,
    required double latitude,
    required double longitude,
  });

  /// Guarda las respuestas del cuestionario de salud.
  Future<bool> saveHealthEvaluation({
    required String profileId,
    required String serviceName,
    required Map<String, String> answers,
  });

  /// Guarda el dictamen médico (Telemedicina / Medicina Interna).
  Future<void> saveQualifyTestValidation({
    required String profileId,
    required bool aprobado,
    String proveedor = 'Telemedicina',
  });

  /// Guarda el Face Map del paciente (cabecera en `face_maps` + puntos en
  /// `face_map_puntos`). [puntos] es una lista de mapas
  /// `{ 'zona_anatomica', 'coordenada_x', 'coordenada_y' }`.
  Future<bool> saveFaceMapRecord({
    required String profileId,
    String? tratamientoId,
    required List<Map<String, dynamic>> puntos,
    String? notas,
  });

  /// Estado del flujo del paciente (pago, cuestionario, evaluación, vigencia).
  Future<Map<String, dynamic>> checkPatientFlowStatus({
    required String profileId,
  });

  /// Valida las reglas de negocio RN-020 / RN-022 antes de reservar.
  Future<Map<String, dynamic>> validateReservationRulesRN020({
    required String profileId,
  });
}
