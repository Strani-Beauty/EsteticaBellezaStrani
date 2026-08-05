import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esteticaybellezastrani/features/auth_users/data/datasources/auth_supabase_datasource.dart';
import 'package:esteticaybellezastrani/features/auth_users/data/repositories/auth_repository_impl.dart';
import 'package:esteticaybellezastrani/features/auth_users/domain/repositories/i_auth_repository.dart';
import 'package:esteticaybellezastrani/features/auth_users/presentation/cubits/auth_cubit.dart';
import 'package:esteticaybellezastrani/features/catalog_services/data/repositories/catalog_repository_impl.dart';
import 'package:esteticaybellezastrani/features/catalog_services/domain/repositories/i_catalog_repository.dart';
import 'package:esteticaybellezastrani/features/patients_compliance/data/repositories/patients_compliance_repository_impl.dart';
import 'package:esteticaybellezastrani/features/patients_compliance/domain/repositories/i_patients_compliance_repository.dart';
import 'package:esteticaybellezastrani/features/payments_stripe/data/repositories/payments_repository_impl.dart';
import 'package:esteticaybellezastrani/features/payments_stripe/domain/repositories/i_payments_repository.dart';
import 'package:esteticaybellezastrani/features/specialists/data/datasources/specialists_supabase_datasource.dart';
import 'package:esteticaybellezastrani/features/specialists/data/repositories/specialists_repository_impl.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/repositories/i_specialists_repository.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/usecases/create_especialista.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/usecases/get_contrato.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/usecases/get_disponibilidad.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/usecases/get_documentos.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/usecases/get_especialidades.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/usecases/get_medicos_regentes.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/usecases/get_my_specialist.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/usecases/save_ubicacion.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/usecases/set_disponibilidad.dart';
import 'package:esteticaybellezastrani/features/specialists/presentation/cubits/specialists_cubit.dart';
import 'package:esteticaybellezastrani/features/treatment_photos/data/datasources/treatment_photos_supabase_datasource.dart';
import 'package:esteticaybellezastrani/features/treatment_photos/data/repositories/treatment_photos_repository_impl.dart';
import 'package:esteticaybellezastrani/features/treatment_photos/domain/repositories/i_treatment_photos_repository.dart';
import 'package:esteticaybellezastrani/features/treatment_photos/domain/usecases/eliminar_fotografia.dart';
import 'package:esteticaybellezastrani/features/treatment_photos/domain/usecases/get_fotografias.dart';
import 'package:esteticaybellezastrani/features/treatment_photos/domain/usecases/registrar_fotografia_por_url.dart';
import 'package:esteticaybellezastrani/features/treatment_photos/domain/usecases/subir_fotografia.dart';
import 'package:esteticaybellezastrani/features/treatment_photos/presentation/cubits/treatment_photos_cubit.dart';

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
}

void _registerSpecialists() {
  sl.registerLazySingleton<SpecialistsSupabaseDataSource>(
    () => SpecialistsSupabaseDataSource(sl<SupabaseClient>()),
  );
  sl.registerLazySingleton<ISpecialistsRepository>(
    () => SpecialistsRepositoryImpl(sl<SpecialistsSupabaseDataSource>()),
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
      setDisponibilidad: SetDisponibilidad(sl<ISpecialistsRepository>()),
      getContrato: GetContrato(sl<ISpecialistsRepository>()),
      firmarContrato: FirmarContrato(sl<ISpecialistsRepository>()),
      saveUbicacion: SaveUbicacion(sl<ISpecialistsRepository>()),
    ),
  );
}

void _registerPatientsCompliance() {
  sl.registerLazySingleton<IPatientsComplianceRepository>(
    () => const PatientsComplianceRepositoryImpl(),
  );
}

void _registerCatalogServices() {
  sl.registerLazySingleton<ICatalogRepository>(
    () => const CatalogRepositoryImpl(),
  );
}

void _registerMarketplaceCitas() {}

void _registerTreatmentExecution() {}

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
  sl.registerLazySingleton<IPaymentsRepository>(
    () => const PaymentsRepositoryImpl(),
  );
}
void _registerAdminConfig() {}
void _registerReportsDashboards() {}
