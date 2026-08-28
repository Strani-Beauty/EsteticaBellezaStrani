# AGENTS.md

Flutter app **Estética y Belleza Strani** — plataforma de gestión de servicios estéticos (especialistas, citas, pagos, tratamientos). Flutter 3.x / Dart SDK `^3.12.2`, backend Supabase.

## Rol de experto Senior en Flutter y Supabase

Actuar SIEMPRE con el criterio de un experto senior en Flutter y Supabase:

- **Seguridad primero**: RLS bien definido, storage privado con URLs firmadas (nunca buckets/URLs públicas para datos sensibles), triggers para cerrar huecos de RLS, y jamás exponer/loggear secretos.
- **Clean Architecture** como está escrito aquí: datasource→repository (`Either<Failure,T>`)→usecase→cubit→UI, sin atajos que rompan la capa (no llamar a Supabase/datasources desde widgets).
- **Calidad y mantenibilidad**: código idempotente y de fácil lectura, siguiendo los patrones existentes antes de inventar otros, y detectando deudas técnicas (repositorios stub, columnas sin índice, policies demasiado amplias).
- **Buenas prácticas de Supabase**: enums/strings mapeados en el dominio, joins embebidos con selects, migraciones idempotentes y ordenadas por nombre, verificar policies de SELECT/INSERT/UPDATE/DELETE y quién puede firmar/leer cada objeto.
- **Rigor de verificación**: ante cambios en la capa de datos o la BD, revisar el impacto en RLS/triggers y confirmar los comandos de verificación; proponer la migración correspondiente en vez de un parche aislado.
- **Visión de producto**: al tocar un flujo de extremo a extremo (p.ej. compliance/verificación), cerrar el ciclo completo (subida → revisión → feedback → reenvío) en lugar de dejar huecos.

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
- **Aplicar migraciones al remoto**: el proyecto está vinculado (`supabase/.temp/linked-project.json`; no hay `config.toml`, así que no hay dev local). Ver pendientes con `supabase migration list` y aplicar con `supabase db push` (alternativa: Dashboard → SQL Editor → pegar el archivo y Run). Las migraciones son idempotentes (`CREATE ... IF NOT EXISTS`, `ON CONFLICT`, `DROP POLICY IF EXISTS`, `ADD COLUMN IF NOT EXISTS`); aplicar siempre en orden de nombre ascendente.
- **Credenciales locales**: el password de BD del proyecto vive en `supabase/.temp/credentials` (archivo ignorado por git, **nunca committear ni loggear**). Si `db push` pide la contraseña de la base de datos, léela de ahí (`SUPABASE_DB_PASSWORD`).
- **Verificación de especialistas — solo admin**: `especialistas.observacion` guarda el motivo de rechazo/bloqueo visible para el especialista. Los triggers `trg_proteger_verificacion_especialista` (`especialistas`) y `trg_proteger_revision_documento` (`documentos_especialista`) cierran el hueco de RLS: el dueño solo puede INSERTar en `PENDIENTE` y autosolicitar revisión (`PENDIENTE/RECHAZADO → EN_REVISION`); aprobar/rechazar/bloquear y revisar documentos (`estado_revision`, `observacion_revision`, `revisado_por`, `fecha_revision`, `activo`) queda reservado al `Administrador`. Si agregas columnas de verificación, mantenlas fuera del UPDATE del dueño o ajusta los triggers.
- Edge functions en `supabase/functions/` (`geocode-address`, con `_shared/auth.ts` y `cors.ts`).

## Auth / Router — peculiaridades importantes

- Rol del usuario en `profiles.role`: `'Paciente' | 'Especialista' | 'Administrador'` (`ProfileEntity.isPatient/isSpecialist/isAdmin`). Ver `app_constants.dart` para los string de roles.
- El redirect de GoRouter (`app/config/app_routes.dart`) **solo** fuerza `/complete-profile` para `isPatient`. Especialistas/administradores no quedan atrapados ahí.
- **Logout**: el estado de sesión NO se deriva de `authStateChanges` (ese stream no se consume en ningún lado); viene de llamadas explícitas del cubit. El datasource de auth (`auth_supabase_datasource.dart`) envuelve `signOut()` en try/catch porque gotrue ya limpia la sesión local antes del revoke en servidor y un fallo de red no debe emitir `AuthError` (rompería la navegación). Preserva este comportamiento si tocas logout.
- `signOut` de gotrue con scope local ignora 401/403/404 pero relanza otros errores de red → de ahí el try/catch.

## Convenciones de código

- Mensajes de commit en **español**, imperativo/descriptivo corto (ej.: `Fija logout offline y panel admin de verificación de licencias con join a profiles`, `Módulo specialists (Clean Architecture alineado a BD real)`).
- **Regla del proyecto: preguntar antes de crear cualquier commit.** No commitear sin confirmación del usuario.

## Planes y cortes de electricidad

- **Antes de implementar un plan aprobado**, persistirlo en `docs/plans/<YYYY-MM-DD>_<slug>.md` (nunca empezar a tocar código sin el plan escrito en disco).
- El plan usa checkpoints visibles: `[x]` hecho / `[ ]` pendiente. Al terminar cada sub-tarea, actualizar el archivo del plan en el mismo ciclo de trabajo.
- Si la sesión se interrumpe (corte de luz, cierre de terminal), retomar con `opencode --continue` y **leer el archivo del plan activo** en `docs/plans/` para reconstruir contexto antes de seguir.
- No borrar ni reescribir planes pasados; solo crear nuevos (historial inmutable).

- Enums mapeados a strings de BD: p.ej. `EstadoVerificacion` (`PENDIENTE|EN_REVISION|APROBADO|RECHAZADO|BLOQUEADO`) y `TipoDocumento` (`IDENTIFICACION|LICENCIA|DIPLOMA|CERTIFICACION|OTRO`) viven en la entidad de dominio con `toDb`/`fromDb`; usar esos mapeos, no strings crudos. La app solo puede autosolicitar (`→ EN_REVISION`); aprobar/rechazar/bloquear lo dispara el admin.
- Joins a Supabase se hacen con select embebido, p.ej. `select('*, profiles (full_name, email)')`; el modelo parsea `json['profiles']` como `Map<String, dynamic>?`.
- Storage buckets definidos en `app_constants.dart` (`bucketDocumentos`, `bucketFotografias`, etc.); subir con `uploadBinary` + `getPublicUrl`.
