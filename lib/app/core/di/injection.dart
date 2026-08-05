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

void _registerSpecialists() {}

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

void _registerPaymentsStripe() {
  sl.registerLazySingleton<IPaymentsRepository>(
    () => const PaymentsRepositoryImpl(),
  );
}
void _registerAdminConfig() {}
void _registerReportsDashboards() {}
