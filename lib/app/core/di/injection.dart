import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
import 'package:esteticaybellezastrani/features/catalog_services/domain/usecases/get_categorias.dart';
import 'package:esteticaybellezastrani/features/catalog_services/domain/usecases/get_servicios.dart';
import 'package:esteticaybellezastrani/features/catalog_services/presentation/cubits/catalog_cubit.dart';
import 'package:esteticaybellezastrani/features/marketplace_citas/data/datasources/marketplace_supabase_datasource.dart';
import 'package:esteticaybellezastrani/features/marketplace_citas/data/repositories/marketplace_repository_impl.dart';
import 'package:esteticaybellezastrani/features/marketplace_citas/domain/repositories/i_marketplace_repository.dart';
import 'package:esteticaybellezastrani/features/marketplace_citas/domain/usecases/aceptar_solicitud.dart';
import 'package:esteticaybellezastrani/features/marketplace_citas/domain/usecases/get_especialistas_aprobados.dart';
import 'package:esteticaybellezastrani/features/marketplace_citas/domain/usecases/get_mi_ubicacion.dart';
import 'package:esteticaybellezastrani/features/marketplace_citas/domain/usecases/get_solicitudes_pendientes.dart';
import 'package:esteticaybellezastrani/features/marketplace_citas/presentation/cubits/marketplace_cubit.dart';
import 'package:esteticaybellezastrani/features/patients_compliance/data/repositories/patients_compliance_repository_impl.dart';
import 'package:esteticaybellezastrani/features/patients_compliance/domain/repositories/i_patients_compliance_repository.dart';
import 'package:esteticaybellezastrani/features/payments_stripe/data/datasources/payments_supabase_datasource.dart';
import 'package:esteticaybellezastrani/features/payments_stripe/data/repositories/payments_repository_impl.dart';
import 'package:esteticaybellezastrani/features/payments_stripe/domain/repositories/i_payments_repository.dart';
import 'package:esteticaybellezastrani/features/payments_stripe/domain/usecases/consultar_pago.dart';
import 'package:esteticaybellezastrani/features/payments_stripe/domain/usecases/crear_payment_intent.dart';
import 'package:esteticaybellezastrani/features/payments_stripe/domain/usecases/crear_solicitud_deposito.dart';
import 'package:esteticaybellezastrani/features/payments_stripe/domain/usecases/pagar_servicio.dart';
import 'package:esteticaybellezastrani/features/payments_stripe/domain/usecases/registrar_pago_inicial.dart';
import 'package:esteticaybellezastrani/features/payments_stripe/domain/usecases/registrar_saldo.dart';
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
import 'package:esteticaybellezastrani/features/treatment_execution/domain/usecases/eliminar_producto.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/usecases/finalizar_tratamiento.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/usecases/get_cita_detalle.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/usecases/get_consentimiento.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/usecases/get_mis_citas.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/usecases/get_productos.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/usecases/iniciar_tratamiento.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/usecases/registrar_consentimiento.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/usecases/subir_firma.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/presentation/cubits/treatment_execution_cubit.dart';

final GetIt sl = GetIt.instance;

/// Registra todas las dependencias de la aplicación.
/// Llamar en main() antes de runApp().
void setupDependencies() {
  // ── Supabase Client (singleton) ────────────────────────────
  sl.registerLazySingleton<SupabaseClient>(() => Supabase.instance.client);

  // ── Features: Auth Users ───────────────────────────────────
  _registerAuthUsers();

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

  // ── Features: Admin Config ────────────────────────────────
  _registerAdminConfig();

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

void _registerPatientsCompliance() {
  sl.registerLazySingleton<IPatientsComplianceRepository>(
    () => const PatientsComplianceRepositoryImpl(),
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
      registrarSaldo: RegistrarSaldo(sl<IPaymentsRepository>()),
      consultarPago: ConsultarPago(sl<IPaymentsRepository>()),
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

void _registerAdminConfig() {}
void _registerReportsDashboards() {}
