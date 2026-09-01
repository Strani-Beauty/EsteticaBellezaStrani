import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esteticaybellezastrani/app/core/utils/geo_service.dart';
import 'package:esteticaybellezastrani/features/admin_users/data/datasources/admin_users_supabase_datasource.dart';
import 'package:esteticaybellezastrani/features/admin_users/data/repositories/admin_users_repository_impl.dart';
import 'package:esteticaybellezastrani/features/admin_users/domain/repositories/i_admin_users_repository.dart';
import 'package:esteticaybellezastrani/features/admin_users/domain/usecases/get_usuarios.dart';
import 'package:esteticaybellezastrani/features/admin_users/domain/usecases/set_usuario_activo.dart';
import 'package:esteticaybellezastrani/features/admin_users/presentation/cubits/admin_users_cubit.dart';
import 'package:esteticaybellezastrani/features/auth_users/data/datasources/auth_supabase_datasource.dart';
import 'package:esteticaybellezastrani/features/auth_users/data/repositories/auth_repository_impl.dart';
import 'package:esteticaybellezastrani/features/auth_users/data/services/fcm_token_service.dart';
import 'package:esteticaybellezastrani/features/auth_users/domain/repositories/i_auth_repository.dart';
import 'package:esteticaybellezastrani/features/auth_users/domain/usecases/generar_url_firmada_avatar.dart';
import 'package:esteticaybellezastrani/features/auth_users/domain/usecases/register_fcm_token.dart';
import 'package:esteticaybellezastrani/features/auth_users/presentation/cubits/auth_cubit.dart';
import 'package:esteticaybellezastrani/features/catalog_services/data/datasources/catalog_services_supabase_datasource.dart';
import 'package:esteticaybellezastrani/features/catalog_services/data/repositories/catalog_repository_impl.dart';
import 'package:esteticaybellezastrani/features/catalog_services/domain/repositories/i_catalog_repository.dart';
import 'package:esteticaybellezastrani/features/catalog_services/domain/usecases/eliminar_servicio.dart';
import 'package:esteticaybellezastrani/features/catalog_services/domain/usecases/subir_imagen_servicio.dart';
import 'package:esteticaybellezastrani/features/catalog_services/domain/usecases/get_categorias.dart';
import 'package:esteticaybellezastrani/features/catalog_services/domain/usecases/get_categorias_admin.dart';
import 'package:esteticaybellezastrani/features/catalog_services/domain/usecases/get_requisitos_servicio.dart';
import 'package:esteticaybellezastrani/features/catalog_services/domain/usecases/get_servicios.dart';
import 'package:esteticaybellezastrani/features/catalog_services/domain/usecases/get_servicios_admin.dart';
import 'package:esteticaybellezastrani/features/catalog_services/domain/usecases/guardar_categoria.dart';
import 'package:esteticaybellezastrani/features/catalog_services/domain/usecases/guardar_cuestionarios_servicio.dart';
import 'package:esteticaybellezastrani/features/catalog_services/domain/usecases/guardar_especialidades_servicio.dart';
import 'package:esteticaybellezastrani/features/catalog_services/domain/usecases/guardar_servicio.dart';
import 'package:esteticaybellezastrani/features/catalog_services/domain/usecases/validar_requisitos_servicio.dart';
import 'package:esteticaybellezastrani/features/catalog_services/presentation/cubits/admin_catalog_cubit.dart';
import 'package:esteticaybellezastrani/features/catalog_services/presentation/cubits/catalog_cubit.dart';
import 'package:esteticaybellezastrani/features/marketplace_citas/data/datasources/marketplace_supabase_datasource.dart';
import 'package:esteticaybellezastrani/features/marketplace_citas/data/repositories/marketplace_repository_impl.dart';
import 'package:esteticaybellezastrani/features/marketplace_citas/domain/repositories/i_marketplace_repository.dart';
import 'package:esteticaybellezastrani/features/marketplace_citas/domain/usecases/aceptar_solicitud.dart';
import 'package:esteticaybellezastrani/features/marketplace_citas/domain/usecases/get_especialistas_aprobados.dart';
import 'package:esteticaybellezastrani/features/marketplace_citas/domain/usecases/get_mi_ubicacion.dart';
import 'package:esteticaybellezastrani/features/marketplace_citas/domain/usecases/get_solicitudes_pendientes.dart';
import 'package:esteticaybellezastrani/features/marketplace_citas/presentation/cubits/marketplace_cubit.dart';
import 'package:esteticaybellezastrani/features/notifications/data/datasources/notifications_supabase_datasource.dart';
import 'package:esteticaybellezastrani/features/notifications/data/repositories/notifications_repository_impl.dart';
import 'package:esteticaybellezastrani/features/notifications/domain/repositories/i_notifications_repository.dart';
import 'package:esteticaybellezastrani/features/notifications/domain/usecases/get_notificaciones.dart';
import 'package:esteticaybellezastrani/features/notifications/domain/usecases/marcar_leida.dart';
import 'package:esteticaybellezastrani/features/notifications/presentation/cubits/notifications_cubit.dart';
import 'package:esteticaybellezastrani/features/patients_compliance/data/datasources/patients_compliance_supabase_datasource.dart';
import 'package:esteticaybellezastrani/features/patients_compliance/data/repositories/patients_compliance_repository_impl.dart';
import 'package:esteticaybellezastrani/features/patients_compliance/domain/repositories/i_patients_compliance_repository.dart';
import 'package:esteticaybellezastrani/features/patients_compliance/domain/usecases/activar_version_cuestionario.dart';
import 'package:esteticaybellezastrani/features/patients_compliance/domain/usecases/consultar_estado_salud.dart';
import 'package:esteticaybellezastrani/features/patients_compliance/domain/usecases/crear_nueva_version_cuestionario.dart';
import 'package:esteticaybellezastrani/features/patients_compliance/domain/usecases/get_cuestionario_activo.dart';
import 'package:esteticaybellezastrani/features/patients_compliance/domain/usecases/get_cuestionario_preguntas.dart';
import 'package:esteticaybellezastrani/features/patients_compliance/domain/usecases/get_cuestionarios.dart';
import 'package:esteticaybellezastrani/features/patients_compliance/domain/usecases/get_mi_paciente.dart';
import 'package:esteticaybellezastrani/features/patients_compliance/domain/usecases/guardar_respuestas_evaluacion.dart';
import 'package:esteticaybellezastrani/features/patients_compliance/domain/usecases/registrar_validacion_telemedicina.dart';
import 'package:esteticaybellezastrani/features/patients_compliance/domain/usecases/update_mi_paciente.dart';
import 'package:esteticaybellezastrani/features/patients_compliance/domain/usecases/update_pregunta.dart';
import 'package:esteticaybellezastrani/features/patients_compliance/domain/usecases/validar_acceso_rn020.dart';
import 'package:esteticaybellezastrani/features/patients_compliance/presentation/cubits/admin_cuestionario_cubit.dart';
import 'package:esteticaybellezastrani/features/patients_compliance/presentation/cubits/patient_health_cubit.dart';
import 'package:esteticaybellezastrani/features/payments_stripe/data/datasources/payments_supabase_datasource.dart';
import 'package:esteticaybellezastrani/features/payments_stripe/data/repositories/payments_repository_impl.dart';
import 'package:esteticaybellezastrani/features/payments_stripe/domain/repositories/i_payments_repository.dart';
import 'package:esteticaybellezastrani/features/payments_stripe/domain/usecases/consultar_pago.dart';
import 'package:esteticaybellezastrani/features/payments_stripe/domain/usecases/crear_payment_intent.dart';
import 'package:esteticaybellezastrani/features/payments_stripe/domain/usecases/crear_solicitud_deposito.dart';
import 'package:esteticaybellezastrani/features/payments_stripe/domain/usecases/pagar_servicio.dart';
import 'package:esteticaybellezastrani/features/payments_stripe/domain/usecases/registrar_pago_inicial.dart';
import 'package:esteticaybellezastrani/features/payments_stripe/domain/usecases/confirmar_pago_saldo.dart';
import 'package:esteticaybellezastrani/features/payments_stripe/domain/usecases/registrar_pago_fallido.dart';
import 'package:esteticaybellezastrani/features/payments_stripe/domain/usecases/get_transacciones_admin.dart';
import 'package:esteticaybellezastrani/features/payments_stripe/domain/usecases/get_comisiones_admin.dart';
import 'package:esteticaybellezastrani/features/payments_stripe/domain/usecases/get_detalle_financiero_cita.dart';
import 'package:esteticaybellezastrani/features/payments_stripe/domain/usecases/generar_liquidaciones.dart';
import 'package:esteticaybellezastrani/features/payments_stripe/presentation/cubits/admin_conciliacion_cubit.dart';
import 'package:esteticaybellezastrani/features/payments_stripe/presentation/cubits/payments_cubit.dart';
import 'package:esteticaybellezastrani/features/specialists/data/datasources/specialists_supabase_datasource.dart';
import 'package:esteticaybellezastrani/features/specialists/data/repositories/specialists_repository_impl.dart';
import 'package:esteticaybellezastrani/features/specialists/data/services/presence_service.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/repositories/i_specialists_repository.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/usecases/aprobar_medico_regente.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/usecases/asignar_especialidades.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/usecases/create_especialista.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/usecases/create_medico_regente.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/usecases/get_all_especialistas.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/usecases/get_contrato.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/usecases/get_disponibilidad.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/usecases/get_documentos.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/usecases/get_especialidades.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/usecases/get_medicos_regentes.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/usecases/get_my_specialist.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/usecases/revisar_documento.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/usecases/save_ubicacion.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/usecases/set_disponibilidad.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/usecases/solicitar_verificacion.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/usecases/update_especialista.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/usecases/update_perfil_especialista.dart';
import 'package:esteticaybellezastrani/features/specialists/presentation/cubits/specialists_cubit.dart';
import 'package:esteticaybellezastrani/features/solicitudes_reserva/data/datasources/solicitudes_reserva_supabase_datasource.dart';
import 'package:esteticaybellezastrani/features/solicitudes_reserva/data/repositories/solicitudes_reserva_repository_impl.dart';
import 'package:esteticaybellezastrani/features/solicitudes_reserva/domain/repositories/i_solicitudes_reserva_repository.dart';
import 'package:esteticaybellezastrani/features/solicitudes_reserva/domain/usecases/confirmar_pago_deposito.dart';
import 'package:esteticaybellezastrani/features/solicitudes_reserva/domain/usecases/crear_solicitud_reserva.dart';
import 'package:esteticaybellezastrani/features/solicitudes_reserva/domain/usecases/get_config_reserva.dart';
import 'package:esteticaybellezastrani/features/solicitudes_reserva/domain/usecases/get_mi_direccion_principal.dart';
import 'package:esteticaybellezastrani/features/solicitudes_reserva/domain/usecases/get_mis_solicitudes.dart';
import 'package:esteticaybellezastrani/features/solicitudes_reserva/presentation/cubits/mis_solicitudes_cubit.dart';
import 'package:esteticaybellezastrani/features/solicitudes_reserva/presentation/cubits/solicitud_reserva_cubit.dart';
import 'package:esteticaybellezastrani/features/admin_config/data/datasources/admin_config_supabase_datasource.dart';
import 'package:esteticaybellezastrani/features/admin_config/data/repositories/admin_config_repository_impl.dart';
import 'package:esteticaybellezastrani/features/admin_config/domain/repositories/i_admin_config_repository.dart';
import 'package:esteticaybellezastrani/features/admin_config/domain/usecases/get_admin_kpis.dart';
import 'package:esteticaybellezastrani/features/admin_config/domain/usecases/get_config_sistema.dart';
import 'package:esteticaybellezastrani/features/admin_config/domain/usecases/update_config_sistema.dart';
import 'package:esteticaybellezastrani/features/admin_config/presentation/cubits/admin_dashboard_cubit.dart';
import 'package:esteticaybellezastrani/features/admin_config/presentation/cubits/admin_configuracion_cubit.dart';
import 'package:esteticaybellezastrani/features/admin_master_data/data/datasources/admin_master_data_supabase_datasource.dart';
import 'package:esteticaybellezastrani/features/admin_master_data/data/repositories/admin_master_data_repository_impl.dart';
import 'package:esteticaybellezastrani/features/admin_master_data/domain/repositories/i_admin_master_data_repository.dart';
import 'package:esteticaybellezastrani/features/admin_master_data/domain/usecases/especialidades_usecases.dart';
import 'package:esteticaybellezastrani/features/admin_master_data/domain/usecases/financiero_usecases.dart';
import 'package:esteticaybellezastrani/features/admin_master_data/domain/usecases/roles_usecases.dart';
import 'package:esteticaybellezastrani/features/admin_master_data/presentation/cubits/admin_comisiones_cubit.dart';
import 'package:esteticaybellezastrani/features/admin_master_data/presentation/cubits/admin_especialidades_cubit.dart';
import 'package:esteticaybellezastrani/features/admin_master_data/presentation/cubits/admin_medicos_regentes_cubit.dart';
import 'package:esteticaybellezastrani/features/admin_master_data/presentation/cubits/admin_roles_cubit.dart';
import 'package:esteticaybellezastrani/features/admin_master_data/presentation/cubits/mis_liquidaciones_cubit.dart';
import 'package:esteticaybellezastrani/features/treatment_photos/data/datasources/treatment_photos_supabase_datasource.dart';
import 'package:esteticaybellezastrani/features/treatment_photos/data/repositories/treatment_photos_repository_impl.dart';
import 'package:esteticaybellezastrani/features/treatment_photos/domain/repositories/i_treatment_photos_repository.dart';
import 'package:esteticaybellezastrani/features/treatment_photos/domain/usecases/eliminar_fotografia.dart';
import 'package:esteticaybellezastrani/features/treatment_photos/domain/usecases/get_fotografias.dart';
import 'package:esteticaybellezastrani/features/treatment_photos/domain/usecases/registrar_fotografia_por_url.dart';
import 'package:esteticaybellezastrani/features/treatment_photos/domain/usecases/subir_fotografia.dart';
import 'package:esteticaybellezastrani/features/treatment_photos/presentation/cubits/treatment_photos_cubit.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/data/datasources/treatment_execution_supabase_datasource.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/data/repositories/treatment_execution_repository_impl.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/repositories/i_treatment_execution_repository.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/usecases/actualizar_tratamiento.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/usecases/agregar_producto.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/usecases/avanzar_estado_cita.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/usecases/cancelar_cita.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/usecases/eliminar_producto.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/usecases/finalizar_tratamiento.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/usecases/get_cita_detalle.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/usecases/get_citas_historial.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/usecases/get_consentimiento.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/usecases/get_face_map_por_tratamiento.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/usecases/guardar_face_map_por_tratamiento.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/usecases/get_mis_citas.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/usecases/get_productos.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/usecases/get_simular_llegada.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/usecases/iniciar_tratamiento.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/usecases/registrar_consentimiento.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/usecases/registrar_llegada.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/usecases/subir_firma.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/presentation/cubits/treatment_execution_cubit.dart';

final GetIt sl = GetIt.instance;

/// Registra todas las dependencias de la aplicación.
/// Llamar en main() antes de runApp().
void setupDependencies() {
  // ── Supabase Client (singleton) ────────────────────────────
  sl.registerLazySingleton<SupabaseClient>(() => Supabase.instance.client);

  // ── Core: Geo Service (GPS en vivo) ────────────────────────
  sl.registerLazySingleton<GeoService>(() => GeoService());

  // ── Features: Auth Users ───────────────────────────────────
  _registerAuthUsers();

  // ── Features: Notifications ────────────────────────────────
  _registerNotifications();

  // ── Features: Specialists ─────────────────────────────────
  _registerSpecialists();

  // ── Features: Patients Compliance ────────────────────────
  _registerPatientsCompliance();

  // ── Features: Catalog Services ────────────────────────────
  _registerCatalogServices();

  // ── Features: Marketplace Citas ───────────────────────────
  _registerMarketplaceCitas();

  // ── Features: Treatment Execution ────────────────────────
  _registerTreatmentExecution();

  // ── Features: Treatment Photos ───────────────────────────
  _registerTreatmentPhotos();

  // ── Features: Admin Users ──────────────────────────────────
  _registerAdminUsers();

  // ── Features: Payments Stripe ─────────────────────────────
  _registerPaymentsStripe();

  // ── Features: Solicitudes Reserva ─────────────────────────
  _registerSolicitudesReserva();

  // ── Features: Admin Config (dashboard) ────────────────────
  _registerAdminConfig();

  // ── Features: Admin Master Data ───────────────────────────
  _registerAdminMasterData();

  // ── Features: Reports Dashboards ─────────────────────────
  _registerReportsDashboards();
}

void _registerAuthUsers() {
  sl.registerLazySingleton<AuthSupabaseDataSource>(
    () => AuthSupabaseDataSource(sl<SupabaseClient>()),
  );
  sl.registerLazySingleton<IAuthRepository>(
    () => AuthRepositoryImpl(sl<AuthSupabaseDataSource>()),
  );
  sl.registerLazySingleton<AuthCubit>(
    () => AuthCubit(sl<IAuthRepository>()),
  );
  sl.registerLazySingleton<RegisterFcmToken>(
    () => RegisterFcmToken(sl<IAuthRepository>()),
  );
  sl.registerLazySingleton<FcmTokenService>(
    () => FcmTokenService(sl<IAuthRepository>()),
  );
  sl.registerLazySingleton<GenerarUrlFirmadaAvatar>(
    () => GenerarUrlFirmadaAvatar(sl<IAuthRepository>()),
  );
}

void _registerSpecialists() {
  sl.registerLazySingleton<SpecialistsSupabaseDataSource>(
    () => SpecialistsSupabaseDataSource(sl<SupabaseClient>()),
  );
  sl.registerLazySingleton<ISpecialistsRepository>(
    () => SpecialistsRepositoryImpl(sl<SpecialistsSupabaseDataSource>()),
  );
  sl.registerLazySingleton<PresenceService>(
    () => PresenceService(sl<ISpecialistsRepository>()),
  );
  sl.registerLazySingleton<SpecialistsCubit>(
    () => SpecialistsCubit(
      getMySpecialist: GetMySpecialist(sl<ISpecialistsRepository>()),
      createEspecialista: CreateEspecialista(sl<ISpecialistsRepository>()),
      getMedicosRegentes: GetMedicosRegentes(sl<ISpecialistsRepository>()),
      getEspecialidades: GetEspecialidades(sl<ISpecialistsRepository>()),
      getDisponibilidad: GetDisponibilidad(sl<ISpecialistsRepository>()),
      getDocumentos: GetDocumentos(sl<ISpecialistsRepository>()),
      registerDocumento: RegisterDocumento(sl<ISpecialistsRepository>()),
      subirDocumento: SubirDocumento(sl<ISpecialistsRepository>()),
      upsertDisponibilidad: UpsertDisponibilidad(sl<ISpecialistsRepository>()),
      getContrato: GetContrato(sl<ISpecialistsRepository>()),
      firmarContrato: FirmarContrato(sl<ISpecialistsRepository>()),
      subirFirmaContrato: SubirFirmaContrato(sl<ISpecialistsRepository>()),
      saveUbicacion: SaveUbicacion(sl<ISpecialistsRepository>()),
      updateEspecialista: UpdateEspecialista(sl<ISpecialistsRepository>()),
      getAllEspecialistas: GetAllEspecialistas(sl<ISpecialistsRepository>()),
      asignarEspecialidades: AsignarEspecialidades(sl<ISpecialistsRepository>()),
      createMedicoRegente: CreateMedicoRegente(sl<ISpecialistsRepository>()),
      aprobarMedicoRegente: AprobarMedicoRegente(sl<ISpecialistsRepository>()),
      updatePerfilEspecialista:
          UpdatePerfilEspecialista(sl<ISpecialistsRepository>()),
      getEspecialidadesDelEspecialista:
          GetEspecialistaEspecialidades(sl<ISpecialistsRepository>()),
      solicitarVerificacion: SolicitarVerificacion(sl<ISpecialistsRepository>()),
      revisarDocumento: RevisarDocumento(sl<ISpecialistsRepository>()),
      generarUrlFirmadaDocumento:
          GenerarUrlFirmadaDocumento(sl<ISpecialistsRepository>()),
    ),
  );
}

void _registerNotifications() {
  sl.registerLazySingleton<NotificationsSupabaseDataSource>(
    () => NotificationsSupabaseDataSource(sl<SupabaseClient>()),
  );
  sl.registerLazySingleton<INotificationsRepository>(
    () => NotificationsRepositoryImpl(sl<NotificationsSupabaseDataSource>()),
  );
  sl.registerLazySingleton<GetNotificaciones>(
    () => GetNotificaciones(sl<INotificationsRepository>()),
  );
  sl.registerLazySingleton<MarcarNotificacionLeida>(
    () => MarcarNotificacionLeida(sl<INotificationsRepository>()),
  );
  sl.registerLazySingleton<MarcarTodasLeidas>(
    () => MarcarTodasLeidas(sl<INotificationsRepository>()),
  );
  sl.registerLazySingleton<NotificationsCubit>(
    () => NotificationsCubit(
      getNotificaciones: sl<GetNotificaciones>(),
      marcarLeida: sl<MarcarNotificacionLeida>(),
      marcarTodasLeidas: sl<MarcarTodasLeidas>(),
    ),
  );
}

void _registerPatientsCompliance() {
  sl.registerLazySingleton<PatientsComplianceSupabaseDataSource>(
    () => PatientsComplianceSupabaseDataSource(sl<SupabaseClient>()),
  );
  sl.registerLazySingleton<IPatientsComplianceRepository>(
    () => PatientsComplianceRepositoryImpl(sl<PatientsComplianceSupabaseDataSource>()),
  );

  sl.registerLazySingleton<GetMiPaciente>(
    () => GetMiPaciente(sl<IPatientsComplianceRepository>()),
  );
  sl.registerLazySingleton<UpdateMiPaciente>(
    () => UpdateMiPaciente(sl<IPatientsComplianceRepository>()),
  );
  sl.registerLazySingleton<GetCuestionarios>(
    () => GetCuestionarios(sl<IPatientsComplianceRepository>()),
  );
  sl.registerLazySingleton<GetCuestionarioActivo>(
    () => GetCuestionarioActivo(sl<IPatientsComplianceRepository>()),
  );
  sl.registerLazySingleton<GetCuestionarioPreguntas>(
    () => GetCuestionarioPreguntas(sl<IPatientsComplianceRepository>()),
  );
  sl.registerLazySingleton<CrearNuevaVersionCuestionario>(
    () => CrearNuevaVersionCuestionario(sl<IPatientsComplianceRepository>()),
  );
  sl.registerLazySingleton<ActivarVersionCuestionario>(
    () => ActivarVersionCuestionario(sl<IPatientsComplianceRepository>()),
  );
  sl.registerLazySingleton<UpdatePregunta>(
    () => UpdatePregunta(sl<IPatientsComplianceRepository>()),
  );
  sl.registerLazySingleton<GuardarRespuestasEvaluacion>(
    () => GuardarRespuestasEvaluacion(sl<IPatientsComplianceRepository>()),
  );
  sl.registerLazySingleton<RegistrarValidacionTelemedicina>(
    () => RegistrarValidacionTelemedicina(sl<IPatientsComplianceRepository>()),
  );
  sl.registerLazySingleton<ConsultarEstadoSalud>(
    () => ConsultarEstadoSalud(sl<IPatientsComplianceRepository>()),
  );
  sl.registerLazySingleton<ValidarAccesoRN020>(
    () => ValidarAccesoRN020(sl<IPatientsComplianceRepository>()),
  );

  sl.registerLazySingleton<PatientHealthCubit>(
    () => PatientHealthCubit(
      consultarEstadoSalud: sl<ConsultarEstadoSalud>(),
      getCuestionarioActivo: sl<GetCuestionarioActivo>(),
      getCuestionarioPreguntas: sl<GetCuestionarioPreguntas>(),
      guardarRespuestasEvaluacion: sl<GuardarRespuestasEvaluacion>(),
      registrarValidacionTelemedicina: sl<RegistrarValidacionTelemedicina>(),
    ),
  );
  sl.registerLazySingleton<AdminCuestionarioCubit>(
    () => AdminCuestionarioCubit(
      getCuestionarios: sl<GetCuestionarios>(),
      getCuestionarioPreguntas: sl<GetCuestionarioPreguntas>(),
      crearNuevaVersion: sl<CrearNuevaVersionCuestionario>(),
      activarVersion: sl<ActivarVersionCuestionario>(),
      updatePregunta: sl<UpdatePregunta>(),
    ),
  );
}

void _registerCatalogServices() {
  sl.registerLazySingleton<CatalogServicesSupabaseDataSource>(
    () => CatalogServicesSupabaseDataSource(sl<SupabaseClient>()),
  );
  sl.registerLazySingleton<ICatalogRepository>(
    () => CatalogRepositoryImpl(sl<CatalogServicesSupabaseDataSource>()),
  );
  sl.registerLazySingleton<CatalogCubit>(
    () => CatalogCubit(
      getCategorias: GetCategorias(sl<ICatalogRepository>()),
      getServicios: GetServicios(sl<ICatalogRepository>()),
    ),
  );

  // ── Mantenimiento admin ──────────────────────────────────
  sl.registerLazySingleton<GetCategoriasAdmin>(
    () => GetCategoriasAdmin(sl<ICatalogRepository>()),
  );
  sl.registerLazySingleton<GetServiciosAdmin>(
    () => GetServiciosAdmin(sl<ICatalogRepository>()),
  );
  sl.registerLazySingleton<GuardarCategoria>(
    () => GuardarCategoria(sl<ICatalogRepository>()),
  );
  sl.registerLazySingleton<GuardarServicio>(
    () => GuardarServicio(sl<ICatalogRepository>()),
  );
  sl.registerLazySingleton<EliminarServicio>(
    () => EliminarServicio(sl<ICatalogRepository>()),
  );
  sl.registerLazySingleton<SubirImagenServicio>(
    () => SubirImagenServicio(sl<ICatalogRepository>()),
  );
  sl.registerLazySingleton<GetRequisitosServicio>(
    () => GetRequisitosServicio(sl<ICatalogRepository>()),
  );
  sl.registerLazySingleton<GuardarEspecialidadesServicio>(
    () => GuardarEspecialidadesServicio(sl<ICatalogRepository>()),
  );
  sl.registerLazySingleton<GuardarCuestionariosServicio>(
    () => GuardarCuestionariosServicio(sl<ICatalogRepository>()),
  );
  sl.registerLazySingleton<ValidarRequisitosServicio>(
    () => ValidarRequisitosServicio(
      sl<ICatalogRepository>(),
      sl<IPatientsComplianceRepository>(),
    ),
  );
  sl.registerLazySingleton<AdminCatalogCubit>(
    () => AdminCatalogCubit(
      getCategoriasAdmin: GetCategoriasAdmin(sl<ICatalogRepository>()),
      getServiciosAdmin: GetServiciosAdmin(sl<ICatalogRepository>()),
      guardarCategoria: GuardarCategoria(sl<ICatalogRepository>()),
      guardarServicio: GuardarServicio(sl<ICatalogRepository>()),
      eliminarServicio: EliminarServicio(sl<ICatalogRepository>()),
      subirImagenServicio: SubirImagenServicio(sl<ICatalogRepository>()),
      guardarEspecialidadesServicio:
          GuardarEspecialidadesServicio(sl<ICatalogRepository>()),
      guardarCuestionariosServicio:
          GuardarCuestionariosServicio(sl<ICatalogRepository>()),
      getEspecialidades: GetEspecialidades(sl<ISpecialistsRepository>()),
      getCuestionarios: GetCuestionarios(sl<IPatientsComplianceRepository>()),
    ),
  );
}

void _registerMarketplaceCitas() {
  sl.registerLazySingleton<MarketplaceSupabaseDataSource>(
    () => MarketplaceSupabaseDataSource(sl<SupabaseClient>()),
  );
  sl.registerLazySingleton<IMarketplaceRepository>(
    () => MarketplaceRepositoryImpl(sl<MarketplaceSupabaseDataSource>()),
  );
  sl.registerLazySingleton<MarketplaceCubit>(
    () => MarketplaceCubit(
      getSolicitudesPendientes:
          GetSolicitudesPendientes(sl<IMarketplaceRepository>()),
      getEspecialistasAprobados:
          GetEspecialistasAprobados(sl<IMarketplaceRepository>()),
      getMiUbicacion: GetMiUbicacion(sl<IMarketplaceRepository>()),
      aceptarSolicitud: AceptarSolicitud(sl<IMarketplaceRepository>()),
    ),
  );
}

void _registerTreatmentExecution() {
  sl.registerLazySingleton<TreatmentExecutionSupabaseDataSource>(
    () => TreatmentExecutionSupabaseDataSource(sl<SupabaseClient>()),
  );
  sl.registerLazySingleton<ITreatmentExecutionRepository>(
    () => TreatmentExecutionRepositoryImpl(
      sl<TreatmentExecutionSupabaseDataSource>(),
    ),
  );
  sl.registerLazySingleton<TreatmentExecutionCubit>(
    () => TreatmentExecutionCubit(
      getMisCitas: GetMisCitas(sl<ITreatmentExecutionRepository>()),
      getCitaDetalle: GetCitaDetalle(sl<ITreatmentExecutionRepository>()),
      getProductos: GetProductos(sl<ITreatmentExecutionRepository>()),
      getConsentimiento: GetConsentimiento(sl<ITreatmentExecutionRepository>()),
      avanzarEstadoCita:
          AvanzarEstadoCita(sl<ITreatmentExecutionRepository>()),
      iniciarTratamiento:
          IniciarTratamiento(sl<ITreatmentExecutionRepository>()),
      actualizarTratamiento:
          ActualizarTratamiento(sl<ITreatmentExecutionRepository>()),
      agregarProducto: AgregarProducto(sl<ITreatmentExecutionRepository>()),
      eliminarProducto: EliminarProducto(sl<ITreatmentExecutionRepository>()),
      registrarConsentimiento: RegistrarConsentimiento(
        sl<ITreatmentExecutionRepository>(),
      ),
      subirFirma: SubirFirma(sl<ITreatmentExecutionRepository>()),
      finalizarTratamiento: FinalizarTratamiento(
        sl<ITreatmentExecutionRepository>(),
      ),
      getCitasHistorial: GetCitasHistorial(sl<ITreatmentExecutionRepository>()),
      registrarLlegada: RegistrarLlegada(sl<ITreatmentExecutionRepository>()),
      cancelarCita: CancelarCita(sl<ITreatmentExecutionRepository>()),
      getFotografias: GetFotografias(sl<ITreatmentPhotosRepository>()),
      getFaceMapPorTratamiento: GetFaceMapPorTratamiento(
        sl<ITreatmentExecutionRepository>(),
      ),
      guardarFaceMapPorTratamiento: GuardarFaceMapPorTratamiento(
        sl<ITreatmentExecutionRepository>(),
      ),
      getSimularLlegada: GetSimularLlegada(sl<ITreatmentExecutionRepository>()),
    ),
  );
}

void _registerTreatmentPhotos() {
  sl.registerLazySingleton<TreatmentPhotosSupabaseDataSource>(
    () => TreatmentPhotosSupabaseDataSource(sl<SupabaseClient>()),
  );
  sl.registerLazySingleton<ITreatmentPhotosRepository>(
    () => TreatmentPhotosRepositoryImpl(sl<TreatmentPhotosSupabaseDataSource>()),
  );
  sl.registerLazySingleton<TreatmentPhotosCubit>(
    () => TreatmentPhotosCubit(
      getFotografias: GetFotografias(sl<ITreatmentPhotosRepository>()),
      subirFotografia: SubirFotografia(sl<ITreatmentPhotosRepository>()),
      registrarFotografiaPorUrl:
          RegistrarFotografiaPorUrl(sl<ITreatmentPhotosRepository>()),
      eliminarFotografia: EliminarFotografia(sl<ITreatmentPhotosRepository>()),
    ),
  );
}

void _registerPaymentsStripe() {
  sl.registerLazySingleton<PaymentsSupabaseDataSource>(
    () => PaymentsSupabaseDataSource(sl<SupabaseClient>()),
  );
  sl.registerLazySingleton<IPaymentsRepository>(
    () => PaymentsRepositoryImpl(sl<PaymentsSupabaseDataSource>()),
  );
  sl.registerFactory<PaymentsCubit>(
    () => PaymentsCubit(
      crearPaymentIntent: CrearPaymentIntent(sl<IPaymentsRepository>()),
      registrarPagoInicial: RegistrarPagoInicial(sl<IPaymentsRepository>()),
      crearSolicitudDeposito: CrearSolicitudDeposito(sl<IPaymentsRepository>()),
      pagarServicio: PagarServicio(sl<IPaymentsRepository>()),
      consultarPago: ConsultarPago(sl<IPaymentsRepository>()),
    ),
  );
  sl.registerLazySingleton<ConfirmarPagoSaldo>(
    () => ConfirmarPagoSaldo(sl<IPaymentsRepository>()),
  );
  sl.registerLazySingleton<RegistrarPagoFallido>(
    () => RegistrarPagoFallido(sl<IPaymentsRepository>()),
  );
  sl.registerLazySingleton<GetTransaccionesAdmin>(
    () => GetTransaccionesAdmin(sl<IPaymentsRepository>()),
  );
  sl.registerLazySingleton<GetComisionesAdmin>(
    () => GetComisionesAdmin(sl<IPaymentsRepository>()),
  );
  sl.registerLazySingleton<GetDetalleFinancieroCita>(
    () => GetDetalleFinancieroCita(sl<IPaymentsRepository>()),
  );
  sl.registerLazySingleton<GenerarLiquidaciones>(
    () => GenerarLiquidaciones(sl<IPaymentsRepository>()),
  );
  sl.registerFactory<AdminConciliacionCubit>(
    () => AdminConciliacionCubit(
      getTransacciones: sl<GetTransaccionesAdmin>(),
      getComisiones: sl<GetComisionesAdmin>(),
      getDetalle: sl<GetDetalleFinancieroCita>(),
      generarLiquidaciones: sl<GenerarLiquidaciones>(),
      getCitasFinalizadas: sl<GetCitasFinalizadasAdmin>(),
      getInicioSemana: sl<GetInicioSemanaLiquidacion>(),
    ),
  );
}
void _registerAdminUsers() {
  sl.registerLazySingleton<AdminUsersSupabaseDataSource>(
    () => AdminUsersSupabaseDataSource(sl<SupabaseClient>()),
  );
  sl.registerLazySingleton<IAdminUsersRepository>(
    () => AdminUsersRepositoryImpl(sl<AdminUsersSupabaseDataSource>()),
  );
  sl.registerLazySingleton<AdminUsersCubit>(
    () => AdminUsersCubit(
      GetUsuarios(sl<IAdminUsersRepository>()),
      SetUsuarioActivo(sl<IAdminUsersRepository>()),
    ),
  );
}

void _registerAdminConfig() {
  sl.registerLazySingleton<AdminConfigSupabaseDataSource>(
    () => AdminConfigSupabaseDataSource(sl<SupabaseClient>()),
  );
  sl.registerLazySingleton<IAdminConfigRepository>(
    () => AdminConfigRepositoryImpl(sl<AdminConfigSupabaseDataSource>()),
  );
  sl.registerLazySingleton<GetAdminKpis>(
    () => GetAdminKpis(sl<IAdminConfigRepository>()),
  );
  sl.registerLazySingleton<GetConfigSistema>(
    () => GetConfigSistema(sl<IAdminConfigRepository>()),
  );
  sl.registerLazySingleton<UpdateConfigSistema>(
    () => UpdateConfigSistema(sl<IAdminConfigRepository>()),
  );
  sl.registerLazySingleton<AdminDashboardCubit>(
    () => AdminDashboardCubit(getKpis: sl<GetAdminKpis>()),
  );
  sl.registerLazySingleton<AdminConfiguracionCubit>(
    () => AdminConfiguracionCubit(
      getConfiguracion: sl<GetConfigSistema>(),
      updateConfiguracion: sl<UpdateConfigSistema>(),
    ),
  );
}

void _registerAdminMasterData() {
  sl.registerLazySingleton<AdminMasterDataSupabaseDataSource>(
    () => AdminMasterDataSupabaseDataSource(sl<SupabaseClient>()),
  );
  sl.registerLazySingleton<IAdminMasterDataRepository>(
    () => AdminMasterDataRepositoryImpl(
      sl<AdminMasterDataSupabaseDataSource>(),
    ),
  );
  sl.registerLazySingleton<GetRoles>(
    () => GetRoles(sl<IAdminMasterDataRepository>()),
  );
  sl.registerLazySingleton<GetPermisos>(
    () => GetPermisos(sl<IAdminMasterDataRepository>()),
  );
  sl.registerLazySingleton<GuardarRol>(
    () => GuardarRol(sl<IAdminMasterDataRepository>()),
  );
  sl.registerLazySingleton<SetRolActivo>(
    () => SetRolActivo(sl<IAdminMasterDataRepository>()),
  );
  sl.registerLazySingleton<AsignarPermisoRol>(
    () => AsignarPermisoRol(sl<IAdminMasterDataRepository>()),
  );
  sl.registerLazySingleton<QuitarPermisoRol>(
    () => QuitarPermisoRol(sl<IAdminMasterDataRepository>()),
  );
  sl.registerLazySingleton<GetEspecialidadesAdmin>(
    () => GetEspecialidadesAdmin(sl<IAdminMasterDataRepository>()),
  );
  sl.registerLazySingleton<GuardarEspecialidad>(
    () => GuardarEspecialidad(sl<IAdminMasterDataRepository>()),
  );
  sl.registerLazySingleton<SetEspecialidadActivo>(
    () => SetEspecialidadActivo(sl<IAdminMasterDataRepository>()),
  );
  sl.registerLazySingleton<GetLiquidaciones>(
    () => GetLiquidaciones(sl<IAdminMasterDataRepository>()),
  );
  sl.registerLazySingleton<GetPagosEspecialistas>(
    () => GetPagosEspecialistas(sl<IAdminMasterDataRepository>()),
  );
  sl.registerLazySingleton<GetCitasFinalizadasAdmin>(
    () => GetCitasFinalizadasAdmin(sl<IAdminMasterDataRepository>()),
  );
  sl.registerLazySingleton<GetLiquidacionDetalles>(
    () => GetLiquidacionDetalles(sl<IAdminMasterDataRepository>()),
  );
  sl.registerLazySingleton<CambiarEstadoLiquidacion>(
    () => CambiarEstadoLiquidacion(sl<IAdminMasterDataRepository>()),
  );
  sl.registerLazySingleton<RegistrarPagoEspecialista>(
    () => RegistrarPagoEspecialista(sl<IAdminMasterDataRepository>()),
  );
  sl.registerLazySingleton<SubirComprobantePago>(
    () => SubirComprobantePago(sl<IAdminMasterDataRepository>()),
  );
  sl.registerLazySingleton<GetInicioSemanaLiquidacion>(
    () => GetInicioSemanaLiquidacion(sl<IAdminMasterDataRepository>()),
  );
  sl.registerLazySingleton<FirmarComprobante>(
    () => FirmarComprobante(sl<IAdminMasterDataRepository>()),
  );
  sl.registerLazySingleton<GetMisLiquidaciones>(
    () => GetMisLiquidaciones(sl<IAdminMasterDataRepository>()),
  );
  sl.registerLazySingleton<GetMisPagosEspecialistas>(
    () => GetMisPagosEspecialistas(sl<IAdminMasterDataRepository>()),
  );
  sl.registerLazySingleton<AdminRolesCubit>(
    () => AdminRolesCubit(
      getRoles: sl<GetRoles>(),
      getPermisos: sl<GetPermisos>(),
      guardarRol: sl<GuardarRol>(),
      setRolActivo: sl<SetRolActivo>(),
      asignarPermiso: sl<AsignarPermisoRol>(),
      quitarPermiso: sl<QuitarPermisoRol>(),
    ),
  );
  sl.registerLazySingleton<AdminEspecialidadesCubit>(
    () => AdminEspecialidadesCubit(
      getEspecialidades: sl<GetEspecialidadesAdmin>(),
      guardarEspecialidad: sl<GuardarEspecialidad>(),
      setActivo: sl<SetEspecialidadActivo>(),
    ),
  );
  sl.registerLazySingleton<AdminComisionesCubit>(
    () => AdminComisionesCubit(
      getLiquidaciones: sl<GetLiquidaciones>(),
      getPagos: sl<GetPagosEspecialistas>(),
      getDetalles: sl<GetLiquidacionDetalles>(),
      cambiarEstado: sl<CambiarEstadoLiquidacion>(),
      registrarPago: sl<RegistrarPagoEspecialista>(),
      subirComprobante: sl<SubirComprobantePago>(),
    ),
  );
  sl.registerLazySingleton<AdminMedicosRegentesCubit>(
    () => AdminMedicosRegentesCubit(
      getMedicos: GetMedicosRegentes(sl<ISpecialistsRepository>()),
      createMedico: CreateMedicoRegente(sl<ISpecialistsRepository>()),
      aprobarMedico: AprobarMedicoRegente(sl<ISpecialistsRepository>()),
    ),
  );
  sl.registerLazySingleton<MisLiquidacionesCubit>(
    () => MisLiquidacionesCubit(
      getLiquidaciones: sl<GetMisLiquidaciones>(),
      getPagos: sl<GetMisPagosEspecialistas>(),
      firmarComprobante: sl<FirmarComprobante>(),
    ),
  );
}
void _registerReportsDashboards() {}

void _registerSolicitudesReserva() {
  sl.registerLazySingleton<SolicitudesReservaSupabaseDataSource>(
    () => SolicitudesReservaSupabaseDataSource(sl<SupabaseClient>()),
  );
  sl.registerLazySingleton<ISolicitudesReservaRepository>(
    () => SolicitudesReservaRepositoryImpl(
      sl<SolicitudesReservaSupabaseDataSource>(),
    ),
  );
  sl.registerLazySingleton<CrearSolicitudReserva>(
    () => CrearSolicitudReserva(sl<ISolicitudesReservaRepository>()),
  );
  sl.registerLazySingleton<ConfirmarPagoDeposito>(
    () => ConfirmarPagoDeposito(sl<ISolicitudesReservaRepository>()),
  );
  sl.registerLazySingleton<GetMisSolicitudes>(
    () => GetMisSolicitudes(sl<ISolicitudesReservaRepository>()),
  );
  sl.registerLazySingleton<GetMiDireccionPrincipal>(
    () => GetMiDireccionPrincipal(sl<ISolicitudesReservaRepository>()),
  );
  sl.registerLazySingleton<GetConfigReserva>(
    () => GetConfigReserva(sl<ISolicitudesReservaRepository>()),
  );
  sl.registerLazySingleton<SolicitudReservaCubit>(
    () => SolicitudReservaCubit(
      getConfigReserva: sl<GetConfigReserva>(),
      getMiDireccionPrincipal: sl<GetMiDireccionPrincipal>(),
      crearSolicitudReserva: sl<CrearSolicitudReserva>(),
      confirmarPagoDeposito: sl<ConfirmarPagoDeposito>(),
    ),
  );
  sl.registerLazySingleton<MisSolicitudesCubit>(
    () => MisSolicitudesCubit(
      getMisSolicitudes: sl<GetMisSolicitudes>(),
    ),
  );
}