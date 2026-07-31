/// Constantes globales de la aplicación Estética y Belleza Strani.
class AppConstants {
  AppConstants._();

  // ── Negocio ────────────────────────────────────────────────
  static const String appName = 'Estética y Belleza Strani';
  static const String appVersion = '2.0.0';

  /// Monto del depósito inicial (USD) — configurable desde configuracion_sistema
  static const double depositoInicial = 30.0;

  /// Radio de búsqueda de especialistas por defecto (km)
  static const double radioDefaultKm = 10.0;

  /// Días máximos de validez de la evaluación médica (telemedicina)
  static const int diasValidezEvaluacion = 365;

  // ── Roles ──────────────────────────────────────────────────
  static const String rolPaciente = 'Paciente';
  static const String rolEspecialista = 'Especialista';
  static const String rolAdministrador = 'Administrador';

  // ── Estados de Especialista ────────────────────────────────
  static const String estadoPendiente = 'PENDIENTE';
  static const String estadoEnRevision = 'EN_REVISION';
  static const String estadoAprobado = 'APROBADO';
  static const String estadoRechazado = 'RECHAZADO';
  static const String estadoBloqueado = 'BLOQUEADO';

  // ── Estados de Disponibilidad ──────────────────────────────
  static const String disponible = 'DISPONIBLE';
  static const String noDisponible = 'NO_DISPONIBLE';
  static const String ocupado = 'OCUPADO';

  // ── Estados de Cita ─────────────────────────────────────────
  static const String citaSolicitada = 'SOLICITADA';
  static const String citaAceptada = 'ACEPTADA';
  static const String citaEnCamino = 'EN_CAMINO';
  static const String citaEnCurso = 'EN_CURSO';
  static const String citaCompletada = 'COMPLETADA';
  static const String citaCancelada = 'CANCELADA';

  // ── Estados de Tratamiento ─────────────────────────────────
  static const String tratamientoIniciado = 'INICIADO';
  static const String tratamientoEnProceso = 'EN_PROCESO';
  static const String tratamientoCompletado = 'COMPLETADO';

  // ── Estados de Validación Telemedicina ────────────────────
  static const String validacionPendiente = 'PENDIENTE';
  static const String validacionAprobada = 'APROBADA';
  static const String validacionRechazada = 'RECHAZADA';
  static const String validacionVencida = 'VENCIDA';

  // ── Tipos de Precio ────────────────────────────────────────
  static const String precioPrecioFijo = 'PRECIO_FIJO';
  static const String precioPorUnidad = 'POR_UNIDAD';
  static const String precioPorJeringa = 'POR_JERINGA';
  static const String precioPorSesion = 'POR_SESION';
  static const String precioPorPlan = 'POR_PLAN';

  // ── Tipos de Firma ─────────────────────────────────────────
  static const String firmaTouch = 'TOUCH';
  static const String firmaDigital = 'DIGITAL';

  // ── Tipos de Transacción ───────────────────────────────────
  static const String txDeposito = 'DEPOSITO';
  static const String txSaldo = 'SALDO';
  static const String txReembolso = 'REEMBOLSO';

  // ── Supabase Storage Buckets ───────────────────────────────
  static const String bucketDocumentos = 'documentos-especialistas';
  static const String bucketContratos = 'contratos';
  static const String bucketFotografias = 'fotografias-tratamiento';
  static const String bucketFirmas = 'firmas-consentimiento';
  static const String bucketAvatars = 'avatars';

  // ── Supabase RPCs ──────────────────────────────────────────
  static const String rpcEspecialistasCercanos = 'especialistas_disponibles_cercanos';
  static const String rpcValidarDisponibilidad = 'validar_disponibilidad_especialista';

  // ── Durations ──────────────────────────────────────────────
  static const Duration debounceDuration = Duration(milliseconds: 500);
  static const Duration timeoutDuration = Duration(seconds: 30);
}
