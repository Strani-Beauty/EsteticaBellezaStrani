# Plan: Semana 6 — Catálogo de Servicios y Tratamientos

| | |
|---|---|
| **Fecha** | 2026-08-19 |
| **Estado** | APROBADO por el usuario (2026-08-19) |
| **Proyecto Supabase** | `hhyjremkguvphmjuaazp` |
| **Decisiones tomadas** | Ver sección "Decisiones" |

## Contexto

Módulo `catalog_services` parcial: lectura paciente (categorías + servicios activos), gate RN-020 global y pago/reserva. Faltan el CRUD admin (categorías/servicios), las relaciones `servicio_especialidades` y `servicio_cuestionarios`, el refuerzo BD del match de especialidades, la validación de requisitos por servicio y la muestra de duración.

Verificación previa (2026-08-19): trabajo E2E de compliance de la PC presente y en verde (commit `75f57c1`; `dart analyze` 0 issues; `flutter test` 95/95).

## Decisiones (confirmadas por el usuario)

1. **UI admin del catálogo**: nueva pantalla `/admin/catalog` (`AdminCatalogScreen`), accesible desde el dashboard admin; el guard ya protege `/admin/*` por rol.
2. **Gate RN-020**: se **mantiene global** en la app (bloquea toda reserva sin evaluación vigente) + flag `requiere_telemedicina` configurable por servicio (alineado al trigger BD `validar_rn020_solicitud`).
3. **Validación por servicio**: cuestionario obligatorio vinculado sin evaluación `APTO` de ese `cuestionario_id` → bloquea con modal que guía a responderlo; `requiere_fotos`/`requiere_consentimiento` se muestran como requisitos informativos (son de ejecución).
4. **Match de especialidades (Act. 5)**: especialista debe estar `estado_verificacion='APROBADO'` y `activo`, y su `especialista_especialidades` debe intersectar con `servicio_especialidades` del servicio de la solicitud. **Servicios sin `servicio_especialidades` configuradas → visibles para todos** (no romper el marketplace actual). Refuerzo a nivel BD en `obtener_solicitudes_publicadas_geo` y `aceptar_solicitud`.

## Actividades → implementación

### A. Migración BD `supabase/migrations/20260819000000_catalog_admin_rls_relaciones.sql` (idempotente)

- [x] A1. RLS escritura solo admin en `categorias_servicio`, `servicios`, `servicio_especialidades`, `servicio_cuestionarios` (`FOR ALL` con `USING/CHECK role='Administrador'`) + `GRANT INSERT/UPDATE/DELETE` a `authenticated`. Se conservan las policies públicas de SELECT.
- [x] A2. RPC `reemplazar_servicio_especialidades(p_servicio_id uuid, p_ids bigint[])` — replace atómico, `security definer`, valida rol admin.
- [x] A3. RPC `reemplazar_servicio_cuestionarios(p_servicio_id uuid, p_items jsonb)` — `[{"cuestionario_id":n,"obligatorio":b,"orden":n}]`, mismo patrón.
- [x] A4. `obtener_solicitudes_publicadas_geo`: añade filtro de intersección de especialidades (servicio sin filas en `servicio_especialidades` → sin restricción).
- [x] A5. `aceptar_solicitud`: misma validación → motivo `NO_COINCIDE_ESPECIALIDAD`.
- [x] A6. Seeds idempotentes: `servicio_especialidades` para los 19 servicios reales; `servicio_cuestionarios` con "Cuestionario de Salud" (id=4) obligatorio para los inyectables.

### B. Capa de datos `catalog_services`

- [x] B1. Datasource: `fetchCategoriasAdmin`, `fetchServiciosAdmin` (incl. inactivos), `insertCategoria`, `updateCategoria`, `insertServicio`, `updateServicio` (nombre, descripcion, categoria_id, precio_base, tipo_precio, duracion_estimada, requiere_telemedicina/face_map/fotos/consentimiento, activo), RPC de reemplazo, `fetchRequisitosServicio` (servicio_cuestionarios + cuestionarios + servicio_especialidades).
- [x] B2. Repository: métodos nuevos en `Either<Failure,T>`.
- [x] B3. Entidad `ServicioCuestionarioEntity(cuestionarioId, nombre, obligatorio, orden)`.
- [x] B4. Usecases: `GetCategoriasAdmin`, `GuardarCategoria`, `GetServiciosAdmin`, `GuardarServicio`, `GetRequisitosServicio`, `GuardarEspecialidadesServicio`, `GuardarCuestionariosServicio`, `ValidarRequisitosServicio` (inyecta `ICatalogRepository` + `IPatientsComplianceRepository`).
- [x] B5. `AdminCatalogCubit` + registro en DI (inyección por nombre, regla del proyecto).

### C. UI Admin `/admin/catalog`

- [x] C1. Ruta `adminCatalog = '/admin/catalog'` en `app_routes.dart` + enlace desde `AdminDashboardScreen`.
- [x] C2. `AdminCatalogScreen` con pestañas Categorías / Servicios (listado incl. inactivos, alta/edición, activar/desactivar sin borrar).
- [x] C3. `AdminServicioDetailScreen`: formulario completo (nombre, descripción, categoría, precio, `tipo_precio` dropdown, duración, flags, activo) + sección Especialidades (multi-select `GetEspecialidades`) + sección Cuestionarios (lista `GetCuestionarios` con obligatorio/orden).

### D. App Paciente — catálogo

- [x] D1. Act. 9: mostrar `duracion_estimada` (min) en card y en modal de pago/reserva (descripción + duración + precio).
- [x] D2. Act. 10: `ValidarRequisitosServicio` en `_onServiceSelected` tras gate RN-020 y face map → modal "Requisito de salud pendiente" → navegar al cuestionario; requisitos informativos para fotos/consentimiento.

### E. Tests y E2E

- [x] E1. Tests unitarios: mapping `TipoPrecio`/`ServicioModel`/`CategoriaServicioModel`; repo impl con datasource mock (patrón `specialists_repository_impl_test`); cubit admin; `ValidarRequisitosServicio`. Suite completa **130/130** en verde; `flutter analyze` sin issues.
- [x] E2. E2E manual `docs/pruebas/2026-08-19_catalogos_servicios_e2e.md` (Act. 12 y 13) — ver doc creado.
- [x] E3. Migración `20260819000000` aplicada al remoto (`supabase db push`) y verificada: RPCs creados, `servicio_especialidades`=31, `servicio_cuestionarios`=18. Pendiente pendiente: re-link de enlaces obsoletos a v1 (ver Nota 1).

## Entorno / comandos

- CLI Supabase instalado vía `npm install -g supabase` (2.115.0). Proyecto **vinculado** (`supabase link --project-ref hhyjremkguvphmjuaazp`, 2026-08-19) y migración `20260819000000` **aplicada al remoto** vía `supabase db push` (verificada).
- Migraciones: `supabase migration list` (aplicadas) y `supabase db push` (pendientes). Alternativa: Dashboard → SQL Editor.
- E2E manual (Act. 12-13): **pendiente para el día siguiente** (`docs/pruebas/2026-08-19_catalogos_servicios_e2e.md`).

## Nota 1 — enlaces obsoletos a "Cuestionario de Salud" v1 (2026-08-19)

Tras aplicar la migración se verificó que `cuestionarios` tiene "Cuestionario de Salud" v1 (id=4, **inactivo**) y v2 (id=5, **activo**). El seed 7.2 enlazó correctamente al v2 activo (12 servicios). Pero quedan **5 servicios con enlaces previos al v1 inactivo** (creados por el flujo de compliance de la PC): `Ácido Hialurónico`, `Lipólisis Alta Frecuencia`, `Microneedling`, `Peelings Médicos`, `Toxina Botulínica`. Al validar `tieneEvaluacionAptaDeCuestionario(id=4)` estos servicios nunca encontrarían una evaluación APTO (los pacientes contestan la v2/id=5) → bloqueo falso de reserva. **Propuesto**: migración idempotente que re-enlace esas filas al v2 activo (mismo nombre de cuestionario), conservando `obligatorio`/`orden`. Pendiente de confirmación del usuario.