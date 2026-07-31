import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  // Datasources, Repositories, UseCases, Cubits se registran aquí
  // Ejemplo (se completan en Fase 2):
  // sl.registerLazySingleton<IAuthRepository>(() => AuthRepositoryImpl(sl()));
}

void _registerSpecialists() {}
void _registerPatientsCompliance() {}
void _registerCatalogServices() {}
void _registerMarketplaceCitas() {}
void _registerTreatmentExecution() {}
void _registerPaymentsStripe() {}
void _registerAdminConfig() {}
void _registerReportsDashboards() {}
