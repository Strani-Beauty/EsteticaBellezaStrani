# AGENTS.md

Flutter app **Estética y Belleza Strani** — plataforma de gestión de servicios estéticos (especialistas, citas, pagos, tratamientos). Flutter 3.x / Dart SDK `^3.12.2`, backend Supabase.

## Comandos de verificación (siempre tras tocar código)

```powershell
flutter analyze
flutter test
```

No hay linter/formatter extra configurado más allá de `flutter_lints` (`analysis_options.yaml`). Los tests son solo un placeholder (`test/widget_test.dart`); no asumas cobertura existente.

## Arquitectura: Feature-First Clean Architecture

- `lib/app/` — bootstrap (`main.dart`, `app.dart`), configuración (`config/`), núcleo (`core/`: DI, errores, network, usecases).
- `lib/features/<modulo>/` — cada módulo tiene `data/` (`datasources/`, `models/`, `repositories/`), `domain/` (`entities/`, `usecases/`, `repositories/`) y `presentation/` (`cubits/`, `screens/`, `widgets/`).
- **Patrón de datos**: datasource solo habla con Supabase y devuelve Models → repository (fpdart `Either<Failure, T>`) → usecase → cubit → UI.
- **Patrón de errores**: los repositorios envuelven excepciones en `ServerFailure`/`AuthFailure` (`app/core/error/failures.dart`); los cubits emiten un estado `...Error(message)`.

Módulos implementados de punta a punta (usar como referencia de patrón): `specialists`, `treatment_photos`, `auth_users`. Otros módulos (`marketplace_citas`, `treatment_execution`, `reports_dashboards`, `admin_config`, `payments_stripe`, `catalog_services`, `patients_compliance`) son **stubs vacíos o parciales** — sus repositorios en `injection.dart` suelen ser `const RepoImpl()` sin datasource real.

## DI (GetIt) — regla clave

- Todo se registra en `lib/app/core/di/injection.dart`, función `setupDependencies()`, llamada en `main()` **antes** de `runApp()`.
- Cubits con dependencias se construyen inyectando usecases **por nombre**: `SpecialistsCubit(getMySpecialist: GetMySpecialist(sl<ISpecialistsRepository>()), ...)`. Añade SIEMPRE el nuevo usecase al constructor del cubit y a su registro, o rompe en runtime.
- Acceso en widgets: `sl<Cubit>()` o `sl<Repo>()` (importar `app/core/di/injection.dart`).

## Supabase y entorno

- `.env` está en `.gitignore`; el template es `.env.example`. `main.dart` carga `.env` con `flutter_dotenv` y `AppEnv.validate()` (en `app/config/app_env.dart`) lanza `StateError` si faltan `SUPABASE_URL`/`SUPABASE_ANON_KEY`.
- `Supabase.initialize` usa `AuthFlowType.pkce`, `autoRefreshToken: true`, `detectSessionInUri: true`.
- `supabase_flutter` está **pinneado** a `2.5.0` (no `^`). gotrue en caché es `2.26.0`.
- El cliente singleton se registra en DI: `sl.registerLazySingleton<SupabaseClient>(() => Supabase.instance.client)`.
- **Esquema de BD**: `schema_openapi.json` y `supabase_openapi.json` son el esquema real de PostgREST (idénticos, 207 KB). Están en `.gitignore` (`*openapi*.json`) por lo que **no se commitean**, pero son la fuente de verdad para columnas/enums/tablas — consulta antes de asumir nombres de tabla o columna. No uses el viejo `app/core/network/supabase_service.dart` (clase estática legacy) para código nuevo; los módulos nuevos usan datasources por feature.
- Migraciones en `supabase/migrations/*.sql` (hay una migración `20260805000100_especialistas_documentos_storage.sql` sin trackear, dejada así a propósito).
- Edge functions en `supabase/functions/` (`geocode-address`, con `_shared/auth.ts` y `cors.ts`).

## Auth / Router — peculiaridades importantes

- Rol del usuario en `profiles.role`: `'Paciente' | 'Especialista' | 'Administrador'` (`ProfileEntity.isPatient/isSpecialist/isAdmin`). Ver `app_constants.dart` para los string de roles.
- El redirect de GoRouter (`app/config/app_routes.dart`) **solo** fuerza `/complete-profile` para `isPatient`. Especialistas/administradores no quedan atrapados ahí.
- **Logout**: el estado de sesión NO se deriva de `authStateChanges` (ese stream no se consume en ningún lado); viene de llamadas explícitas del cubit. El datasource de auth (`auth_supabase_datasource.dart`) envuelve `signOut()` en try/catch porque gotrue ya limpia la sesión local antes del revoke en servidor y un fallo de red no debe emitir `AuthError` (rompería la navegación). Preserva este comportamiento si tocas logout.
- `signOut` de gotrue con scope local ignora 401/403/404 pero relanza otros errores de red → de ahí el try/catch.

## Convenciones de código

- Mensajes de commit en **español**, imperativo/descriptivo corto (ej.: `Fija logout offline y panel admin de verificación de licencias con join a profiles`, `Módulo specialists (Clean Architecture alineado a BD real)`).
- **Regla del proyecto: preguntar antes de crear cualquier commit.** No commitear sin confirmación del usuario.
- Enums mapeados a strings de BD: p.ej. `EstadoVerificacion` (`PENDIENTE|EN_REVISION|APROBADO|RECHAZADO|BLOQUEADO`) y `TipoDocumento` (`IDENTIFICACION|LICENCIA|DIPLOMA|CERTIFICACION|OTRO`) viven en la entidad de dominio con `toDb`/`fromDb`; usar esos mapeos, no strings crudos.
- Joins a Supabase se hacen con select embebido, p.ej. `select('*, profiles (full_name, email)')`; el modelo parsea `json['profiles']` como `Map<String, dynamic>?`.
- Storage buckets definidos en `app_constants.dart` (`bucketDocumentos`, `bucketFotografias`, etc.); subir con `uploadBinary` + `getPublicUrl`.
