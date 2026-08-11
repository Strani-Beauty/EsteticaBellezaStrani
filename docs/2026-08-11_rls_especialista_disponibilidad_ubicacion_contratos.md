# RLS de disponibilidad, ubicación y contratos de especialistas

**Fecha:** 2026-08-11 (sesión 2026-08-11)
**Rama:** `main` — commit `a31b103`
**Migración:** `supabase/migrations/20260812000200_rls_disponibilidad_ubicacion_contratos.sql`

---

## 1. Contexto y motivo

Durante la verificación del flujo de especialistas de punta a punto (registro, onboarding, disponibilidad, ubicación, asignación de solicitudes) se detectó que tres tablas tenían **RLS habilitada pero 0 políticas**:

- `disponibilidad_especialista`
- `ubicaciones_especialista`
- `contratos`

Estas tablas se crearon directamente en el dashboard de Supabase y quedaron fuera de las migraciones RLS versionadas (a diferencia de `especialistas`, `documentos_especialista`, `solicitudes`, `citas`, etc., que sí tienen sus policies en `supabase/migrations/*.sql`).

### Impacto en runtime

Con RLS activada y sin políticas, ningún rol (ni `anon` ni `authenticated`) puede leer ni escribir:

| Funcionalidad | Datasource | Método | Línea |
|---|---|---|---|
| Toggle de disponibilidad | `specialists_supabase_datasource.dart` | `setDisponibilidad` / `updateDisponibilidad` | 366 / 383 |
| Guardar ubicación en onboarding | `specialists_supabase_datasource.dart` | `saveUbicacion` | 460 |
| Leer mi disponibilidad | `specialists_supabase_datasource.dart` | `fetchDisponibilidad` | 349 |
| Leer mi ubicación | `specialists_supabase_datasource.dart` | `fetchUbicacion` | 431 |
| Firmar/leer contrato | `specialists_supabase_datasource.dart` | `firmarContrato` / `fetchContrato` | 413 / 394 |
| Ubicación en el mapa | `marketplace_supabase_datasource.dart` | `fetchMiUbicacion` / join embebido en `fetchEspecialistasAprobados` | 55 / 38 |

Consecuencias observables:

- Los INSERT/UPDATE fallaban con error RLS (`42501`).
- `fetchDisponibilidad` / `fetchUbicacion` devolvían `null` → el especialista siempre aparecía offline y el gate del mapa (en el home) nunca se abría.
- El mapa no resolvía la ubicación propia ni la de especialistas aprobados (join embebido a `ubicaciones_especialista` devolvía `[]`).

---

## 2. Método de investigación

1. Revisión de las migraciones existentes en `supabase/migrations/` → ninguna definía policies para estas 3 tablas.
2. Confirmación del esquema real vía `schema_openapi.json` / `supabase_openapi.json` (PostgREST — fuente de verdad).
3. Inspección del estado real de la BD remota vía Supabase Management API:
   - `pg_class.relrowsecurity` → RLS = `true` en las 3 tablas.
   - `pg_policies` → 0 policies en las 3 tablas.
   - `information_schema.role_table_grants` → grants existentes a `anon`, `authenticated`, `service_role` (poco útiles sin policies RLS).
4. Confirmación de que otras tablas del flujo sí tienen RLS correcta (`especialistas`, `solicitudes`, `direcciones_paciente`, etc.).

---

## 3. Cambio realizado

### Migración nueva

`supabase/migrations/20260812000200_rls_disponibilidad_ubicacion_contratos.sql`

Idempotente (`DROP POLICY IF EXISTS` + `CREATE POLICY`), misma convención que las migraciones existentes. No crea tablas ni columnas: solo policies.

### Tabla de policies

| Tabla | Policy | Cmd | Rol | Criterio (USING / WITH CHECK) |
|---|---|---|---|---|
| `disponibilidad_especialista` | `disponibilidad_own` | ALL | `authenticated` | `especialista_id IN (SELECT id FROM especialistas WHERE usuario_id = auth.uid())` |
| `disponibilidad_especialista` | `disponibilidad_admin_select` | SELECT | `authenticated` | `(SELECT role FROM profiles WHERE id = auth.uid()) = 'Administrador'` |
| `ubicaciones_especialista` | `ubicacion_own` | ALL | `authenticated` | `especialista_id IN (SELECT id FROM especialistas WHERE usuario_id = auth.uid())` |
| `ubicaciones_especialista` | `ubicacion_admin_select` | SELECT | `authenticated` | `(SELECT role FROM profiles WHERE id = auth.uid()) = 'Administrador'` |
| `contratos` | `contrato_own` | ALL | `authenticated` | `especialista_id IN (SELECT id FROM especialistas WHERE usuario_id = auth.uid())` |
| `contratos` | `contrato_admin_select` | SELECT | `authenticated` | `(SELECT role FROM profiles WHERE id = auth.uid()) = 'Administrador'` |

### Decisiones de diseño

- **Especialista dueño**: acceso completo (FOR ALL) a sus propios registros de disponibilidad, ubicación y contratos. La identidad del dueño se resuelve cruzando `especialistas.usuario_id = auth.uid()`.
- **Administrador**: lectura de todos los registros (seguimiento/auditoría). No requiere INSERT/UPDATE en estas tablas.
- **Mapa de especialistas**: solo muestra la ubicación propia + solicitudes de pacientes. **No** se agregó policy de lectura entre especialistas: el join `fetchEspecialistasAprobados` igualmente devuelve solo filas propias por el RLS de `especialistas`, y exponer las ubicaciones de otros aprobados a cualquier autenticado sería una fuga de privacidad innecesaria.
- No se requieren grants adicionales: `anon`/`authenticated` ya tenían privileges en las 3 tablas.

---

## 4. Aplicación

Se aplicaron 3 migraciones pendientes en orden con `supabase db push`:

1. `20260811000100_especialidades_medicos_regentes.sql`
2. `20260812000000_revision_especialistas_feedback.sql`
3. `20260812000200_rls_disponibilidad_ubicacion_contratos.sql`

Verificación post-aplicación vía Management API (`pg_policies`, `supabase migration list`):

- Las 6 policies existen en la BD remota con los criterios correctos.
- `supabase migration list` muestra las 3 migraciones como aplicadas en Local y Remote.

---

## 5. Git

| | |
|---|---|
| Commit | `a31b103` |
| Mensaje | `Agrega RLS de disponibilidad, ubicación y contratos para especialistas` |
| Rama | `main` → pusheado a `origin/main` |
| Archivo | `supabase/migrations/20260812000200_rls_disponibilidad_ubicacion_contratos.sql` |

---

## 6. Pendientes / verificación manual sugerida

Probar en runtime (con la app en modo debug):

1. **Especialista** (cuenta real o de seed):
   - Encender/apagar el toggle de disponibilidad → debe persistir en `disponibilidad_especialista`.
   - Completar el paso de mapa del onboarding → debe guardarse la fila en `ubicaciones_especialista`.
   - Firmar el contrato → debe crearse la fila en `contratos`.
   - Entrar al mapa → debe verse la ubicación propia + solicitudes de pacientes (no las de otros especialistas).
2. **Administrador**:
   - El panel admin debe poder leer disponibilidad/ubicaciones/contratos de todos los especialistas (policy de SELECT).