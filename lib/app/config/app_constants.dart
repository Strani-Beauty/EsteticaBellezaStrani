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

  // ── Estados de Solicitud ────────────────────────────────────
  static const String solicitudBorrador = 'BORRADOR';
  static const String solicitudPendientePago = 'PENDIENTE_PAGO';
  static const String solicitudPublicada = 'PUBLICADA';
  static const String solicitudBuscandoEspecialista = 'BUSCANDO_ESPECIALISTA';
  static const String solicitudAceptada = 'ACEPTADA';
  static const String solicitudCancelada = 'CANCELADA';
  static const String solicitudExpirada = 'EXPIRADA';

  // ── Estados de Cita ─────────────────────────────────────────
  static const String citaProgramada = 'PROGRAMADA';
  static const String citaEnCamino = 'EN_CAMINO';
  static const String citaLlego = 'LLEGO';
  static const String citaEnProceso = 'EN_PROCESO';
  static const String citaFinalizada = 'FINALIZADA';
  static const String citaCancelada = 'CANCELADA';
  static const String citaNoCompletada = 'NO_COMPLETADA';

  // ── Estados de Tratamiento ─────────────────────────────────
  static const String tratamientoIniciado = 'INICIADO';
  static const String tratamientoPendienteFirma = 'PENDIENTE_FIRMA';
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
  static const String txPagoTotal = 'PAGO_TOTAL';
  static const String txSaldo = 'SALDO';
  static const String txReembolso = 'REEMBOLSO';
  static const String txAjuste = 'AJUSTE';

  // ── Estados de Transacción ─────────────────────────────────
  static const String txEstadoPendiente = 'PENDIENTE';
  static const String txEstadoProcesada = 'PROCESADA';
  static const String txEstadoAprobado = 'APROBADO';
  static const String txEstadoFallida = 'FALLIDA';
  static const String txEstadoReembolsada = 'REEMBOLSADA';

  // ── Estados de Liquidación ─────────────────────────────────
  static const String liquidacionPendiente = 'PENDIENTE';
  static const String liquidacionEnRevision = 'EN_REVISION';
  static const String liquidacionAprobada = 'APROBADA';
  static const String liquidacionPagada = 'PAGADA';
  static const String liquidacionAnulada = 'ANULADA';

  // ── Supabase Storage Buckets ───────────────────────────────
  static const String bucketDocumentos = 'documentos-especialistas';
  static const String bucketContratos = 'contratos';
  static const String bucketFotografias = 'fotografias-tratamiento';
  static const String bucketFirmas = 'firmas-consentimiento';
  static const String bucketAvatars = 'avatars';
  static const String bucketImagenesServicios = 'imagenes-servicios';
  static const String bucketComprobantes = 'comprobantes-pagos';

  // ── Supabase RPCs ──────────────────────────────────────────
  static const String rpcAceptarSolicitud = 'aceptar_solicitud';
  static const String rpcBuscarEspecialistasCercanos =
      'buscar_especialistas_cercanos';
  static const String rpcObtenerSolicitudesPublicadasGeo =
      'obtener_solicitudes_publicadas_geo';
  static const String rpcCrearSolicitudReserva = 'crear_solicitud_reserva';
  static const String rpcConfirmarDepositoSolicitud =
      'confirmar_deposito_solicitud';
  static const String rpcConfirmarPagoSaldo = 'confirmar_pago_saldo';
  static const String rpcRegistrarPagoFallido = 'registrar_pago_fallido';
  static const String rpcGenerarLiquidaciones = 'generar_liquidaciones';
  static const String rpcCambiarEstadoLiquidacion =
      'cambiar_estado_liquidacion';
  static const String rpcRegistrarPagoEspecialista =
      'registrar_pago_especialista';
  static const String rpcAdminResumenKpis = 'admin_resumen_kpis';
  static const String rpcMisPermisos = 'mis_permisos';
  static const String rpcRegistrarEvaluacion = 'registrar_evaluacion';
  static const String rpcGetPromedioEspecialista =
      'get_promedio_especialista';

  // ── Conceptos de pago (metadata de Stripe) ────────────────
  static const String conceptoAdelanto = 'ADELANTO';
  static const String conceptoPagoTotal = 'PAGO_TOTAL';
  static const String conceptoDeposito = 'DEPOSITO';
  static const String conceptoSaldo = 'SALDO';

  // ── Claves de configuración del sistema ─────────────────────
  /// Cuando es 'true', el especialista puede simular la llegada al domicilio
  /// usando las coordenadas del paciente (útil en pruebas fuera del país).
  static const String simularLlegadaClave = 'simular_llegada';

  /// Día de inicio de la semana de liquidación (1=Lunes, 7=Domingo).
  static const String inicioSemanaLiquidacionClave = 'inicio_semana_liquidacion';

  // ── Presencia (online/offline) ─────────────────────────────
  /// Intervalo del heartbeat de presencia mientras la app está en foreground.
  static const Duration heartbeatPresencia = Duration(seconds: 60);

  /// Un especialista se considera online si su último heartbeat es más reciente
  /// que este umbral (espejo del `interval '3 minutes'` del SQL).
  static const int umbralOnlineSegundos = 180;

  // ── Durations ──────────────────────────────────────────────
  static const Duration debounceDuration = Duration(milliseconds: 500);
  static const Duration timeoutDuration = Duration(seconds: 30);
}
