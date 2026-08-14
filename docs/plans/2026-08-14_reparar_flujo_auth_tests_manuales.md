# Plan: Reparar flujo de auth y aplicar migraciones al remoto

| | |
|---|---|
| **Fecha** | 2026-08-14 |
| **Objetivo** | Que AU-H-01…AU-H-07 (y doc 01 completo) pasen. |
| **Origen** | Pruebas manuales: AU-H-02 (Phone=NULL), AU-H-03 (no llega correo), AU-H-04 (login paciente), AU-H-05 (especialista), AU-H-06 (admin). |
| **Estado** | EN EJECUCIÓN — reanudar desde los checkpoints. |

> Este plan es **autocontenido**: incluye el SQL de las migraciones y los cambios de código exactos. Se puede ejecutar desde otra PC con `git pull` + `opencode --continue`.

---

## Diagnóstico (causas raíz)

1. **Migraciones no aplicadas al remoto** (`supabase db push` pendiente o nunca hecho).
   - Sin el trigger `handle_new_user`, el registro no crea `profiles` ni `pacientes` → las cuentas creadas a mano quedan huérfanas (auth.users sin perfil).
   - Eso produce AU-H-04 ("paciente no existe"), AU-H-06 ("Perfil no encontrado, contacta soporte", `auth_repository_impl.dart:27`) y AU-H-05 (tabla `especialistas` inexistente → excepción → `SpecialistsError`, `specialists_cubit.dart:235`).
2. **Email provider ON pero sin SMTP** → los correos de confirmación no se entregan → AU-H-03 bloqueado y AU-H-04 no confirmable.
3. **Bug de app: `phone` se descarta en el signUp**. `auth_supabase_datasource.dart:37-44` solo envía `full_name`/`role` a `data:`; el trigger tampoco lee phone → `profiles.phone = NULL` (AU-H-02).
4. **Las tablas `disponibilidad_especialista`, `ubicaciones_especialista` y `contratos` NO están en ninguna migración** (se crearon a mano en el dashboard). No bloquea auth; queda como seguimiento.

## Confirmado en entrevista

- Migraciones: NO aplicadas / no seguro.
- Cuentas de la matriz (`admin@test`, `esp.*`, `pac.*`): creadas a mano (sin perfil si no hay trigger).
- Email: Confirmar email ON, sin SMTP.

---

## Fase 0 — Verificación (leer antes de aplicar)

En la otra PC, con el repo clonado y `supabase` CLI linkeado:

```powershell
supabase migration list          # qué migraciones están pendientes en remoto
```

En SQL Editor del dashboard (solo lectura):

```sql
-- ¿Existe el trigger / función?
SELECT proname FROM pg_proc WHERE proname = 'handle_new_user';
SELECT tgname FROM pg_trigger WHERE tgname = 'on_auth_user_created';
-- ¿Existen las columnas?
SELECT column_name FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles';
-- ¿Hay cuentas sin perfil (huérfanas)?
SELECT u.email, u.created_at FROM auth.users u
LEFT JOIN public.profiles p ON p.id = u.id WHERE p.id IS NULL;
```

---

## Fase 1 — Base de datos (el arreglo crítico)

### 1.1 Aplicar migraciones

```powershell
supabase db push
```

Aplica en orden ascendente las ~22 migraciones (todas idempotentes). **Si `db push` falla por tablas que ya existen con tipo distinto, aplicar los ficheros de las Fases 1.2/1.3 por el SQL Editor.**

### 1.2 Migración nueva: `supabase/migrations/20260814000000_auth_phone_trigger_y_backfill.sql`

```sql
-- =============================================================================
-- Migración: phone en el registro + backfill de perfiles huérfanos.
-- -----------------------------------------------------------------------------
-- 1) El trigger `handle_new_user` ahora guarda `profiles.phone` desde el
--    `raw_user_meta_data` que envía la app (fix AU-H-02).
-- 2) Backfill idempotente: crea `profiles` (y `pacientes` si rol Paciente) para
--    los auth.users que quedaron huérfanos (cuentas creadas a mano sin trigger).
-- 3) Backfill de `phone` desde metadata en perfiles existentes.
-- Idempotente (CREATE OR REPLACE, INSERT ... SELECT con anti-join, ON CONFLICT).
-- =============================================================================

-- 1. Trigger actualizado: incluye phone ----------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_role      TEXT;
    v_role_id   BIGINT;
    v_activo    BOOLEAN;
    v_phone     TEXT;
BEGIN
    v_role := COALESCE(NULLIF(TRIM(new.raw_user_meta_data ->> 'role'), ''), 'Paciente');
    v_role := CASE WHEN lower(v_role) IN ('paciente', 'cliente') THEN 'Paciente'
                   WHEN lower(v_role) IN ('especialista')        THEN 'Especialista'
                   WHEN lower(v_role) IN ('administrador', 'admin') THEN 'Administrador'
                   ELSE 'Paciente'
              END;
    v_activo := v_role <> 'Paciente';
    v_phone  := NULLIF(TRIM(new.raw_user_meta_data ->> 'phone'), '');

    SELECT id INTO v_role_id FROM public.roles WHERE name = v_role LIMIT 1;

    INSERT INTO public.profiles (id, email, full_name, role, role_id, activo, payment_completed, evaluation_passed, phone)
    VALUES (new.id,
            new.email,
            COALESCE(new.raw_user_meta_data ->> 'full_name', ''),
            v_role,
            v_role_id,
            v_activo, false, false,
            v_phone)
    ON CONFLICT (id) DO NOTHING;

    IF v_role = 'Paciente' THEN
        INSERT INTO public.pacientes (usuario_id, activo, created_at, updated_at)
        VALUES (new.id, false, NOW(), NOW())
        ON CONFLICT (usuario_id) DO NOTHING;
    END IF;

    RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 2. Backfill: perfiles huérfanos (auth.users sin fila en profiles) ------------
INSERT INTO public.profiles (id, email, full_name, role, role_id, activo, payment_completed, evaluation_passed, phone)
SELECT
    u.id,
    u.email,
    COALESCE(NULLIF(TRIM(u.raw_user_meta_data ->> 'full_name'), ''), split_part(u.email, '@', 1)),
    x.v_role,
    r.id,
    x.v_role <> 'Paciente',
    FALSE,
    FALSE,
    NULLIF(TRIM(u.raw_user_meta_data ->> 'phone'), '')
FROM auth.users u
LEFT JOIN public.profiles p ON p.id = u.id
CROSS JOIN LATERAL (
    SELECT CASE
        WHEN lower(COALESCE(NULLIF(TRIM(u.raw_user_meta_data ->> 'role'), ''), 'Paciente'))
             IN ('paciente', 'cliente') THEN 'Paciente'
        WHEN lower(COALESCE(NULLIF(TRIM(u.raw_user_meta_data ->> 'role'), ''), 'Paciente'))
             IN ('especialista') THEN 'Especialista'
        WHEN lower(COALESCE(NULLIF(TRIM(u.raw_user_meta_data ->> 'role'), ''), 'Paciente'))
             IN ('administrador', 'admin') THEN 'Administrador'
        ELSE 'Paciente'
    END AS v_role
) x
JOIN public.roles r ON r.name = x.v_role
WHERE p.id IS NULL;

-- 3. Backfill: pacientes para perfiles Paciente recién creados ------------------
INSERT INTO public.pacientes (usuario_id, activo, created_at, updated_at)
SELECT p.id, p.activo, NOW(), NOW()
FROM public.profiles p
LEFT JOIN public.pacientes pac ON pac.usuario_id = p.id
WHERE p.role = 'Paciente' AND pac.usuario_id IS NULL
ON CONFLICT (usuario_id) DO NOTHING;

-- 4. Backfill: phone desde metadata en perfiles existentes ----------------------
UPDATE public.profiles p
SET phone = NULLIF(TRIM(u.raw_user_meta_data ->> 'phone'), ''),
    updated_at = NOW()
FROM auth.users u
WHERE p.id = u.id
  AND (p.phone IS NULL OR p.phone = '')
  AND NULLIF(TRIM(u.raw_user_meta_data ->> 'phone'), '') IS NOT NULL;
```

### 1.3 Migración nueva: `supabase/migrations/20260814000100_seed_cuentas_matriz_prueba.sql`

Crea las 12 cuentas de la matriz de pruebas (doc 00). Clave para todas: `Test1234!`.
Idempotente: inserta en `auth.users` solo si el email no existe; especialistas vía
`ON CONFLICT (usuario_id) DO UPDATE`; guarda contra duplicados en documentos.

```sql
-- =============================================================================
-- Migración: seed de cuentas de la matriz de pruebas manuales (doc 00).
-- -----------------------------------------------------------------------------
-- Cuentas (clave Test1234!):
--   admin@test, esp.nuevo@test, esp.revision@test, esp.aprobado@test,
--   esp.rechazado@test, esp.bloqueado@test, esp.desactivado@test,
--   pac.nuevo@test, pac.activo@test, pac.vencido@test, pac.rechazado@test,
--   pac.desactivado@test
-- El trigger handle_new_user (aplicado antes) crea profiles/pacientes al insertar
-- en auth.users. Esta migración NO toca cuentas que ya existan con el mismo email.
-- Idempotente. Correr SIEMPRE después de la migración 20260814000000.
-- =============================================================================

-- 0. Extensión pgcrypto (crypt/gen_salt) si no está ------------------------------
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1. Usuarios auth ---------------------------------------------------------------
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at
)
SELECT * FROM (VALUES
 ('00000000-0000-0000-0000-000000000000'::uuid, '90000000-0000-0000-0000-000000000001'::uuid, 'authenticated', 'authenticated',
  'admin@test', crypt('Test1234!', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{"role":"Administrador","full_name":"Administrador Test","phone":"+1 555 0100"}'::jsonb, now(), now()),
 ('00000000-0000-0000-0000-000000000000', '90000000-0000-0000-0000-000000000002',
  'authenticated', 'authenticated', 'esp.nuevo@test', crypt('Test1234!', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  '{"role":"Especialista","full_name":"Especialista Nuevo","phone":"+1 555 0101"}', now(), now()),
 ('00000000-0000-0000-0000-000000000000', '90000000-0000-0000-0000-000000000003',
  'authenticated', 'authenticated', 'esp.revision@test', crypt('Test1234!', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  '{"role":"Especialista","full_name":"Esp. En Revisión","phone":"+1 555 0102"}', now(), now()),
 ('00000000-0000-0000-0000-000000000000', '90000000-0000-0000-0000-000000000004',
  'authenticated', 'authenticated', 'esp.aprobado@test', crypt('Test1234!', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  '{"role":"Especialista","full_name":"Dra. Aprobada Test","phone":"+1 555 0103"}', now(), now()),
 ('00000000-0000-0000-0000-000000000000', '90000000-0000-0000-0000-000000000005',
  'authenticated', 'authenticated', 'esp.rechazado@test', crypt('Test1234!', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  '{"role":"Especialista","full_name":"Esp. Rechazado","phone":"+1 555 0104"}', now(), now()),
 ('00000000-0000-0000-0000-000000000000', '90000000-0000-0000-0000-000000000006',
  'authenticated', 'authenticated', 'esp.bloqueado@test', crypt('Test1234!', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  '{"role":"Especialista","full_name":"Esp. Bloqueado","phone":"+1 555 0105"}', now(), now()),
 ('00000000-0000-0000-0000-000000000000', '90000000-0000-0000-0000-000000000007',
  'authenticated', 'authenticated', 'esp.desactivado@test', crypt('Test1234!', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  '{"role":"Especialista","full_name":"Esp. Desactivado","phone":"+1 555 0106"}', now(), now()),
 ('00000000-0000-0000-0000-000000000000', '90000000-0000-0000-0000-000000000008',
  'authenticated', 'authenticated', 'pac.nuevo@test', crypt('Test1234!', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  '{"role":"Paciente","full_name":"Paciente Nuevo","phone":"+1 555 0107"}', now(), now()),
 ('00000000-0000-0000-0000-000000000000', '90000000-0000-0000-0000-000000000009',
  'authenticated', 'authenticated', 'pac.activo@test', crypt('Test1234!', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  '{"role":"Paciente","full_name":"Paciente Activo","phone":"+1 555 0108"}', now(), now()),
 ('00000000-0000-0000-0000-000000000000', '90000000-0000-0000-0000-00000000000A',
  'authenticated', 'authenticated', 'pac.vencido@test', crypt('Test1234!', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  '{"role":"Paciente","full_name":"Paciente Vencido","phone":"+1 555 0109"}', now(), now()),
 ('00000000-0000-0000-0000-000000000000', '90000000-0000-0000-0000-00000000000B',
  'authenticated', 'authenticated', 'pac.rechazado@test', crypt('Test1234!', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  '{"role":"Paciente","full_name":"Paciente Rechazado","phone":"+1 555 0110"}', now(), now()),
 ('00000000-0000-0000-0000-000000000000', '90000000-0000-0000-0000-00000000000C',
  'authenticated', 'authenticated', 'pac.desactivado@test', crypt('Test1234!', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  '{"role":"Paciente","full_name":"Paciente Desactivado","phone":"+1 555 0111"}', now(), now())
) AS v(instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
WHERE NOT EXISTS (SELECT 1 FROM auth.users u WHERE u.email = v.email);

-- 2. Estados de profiles ---------------------------------------------------------
UPDATE public.profiles p SET activo = TRUE, updated_at = now()
WHERE p.email IN ('admin@test', 'esp.aprobado@test');

UPDATE public.profiles p SET activo = FALSE, updated_at = now()
WHERE p.email IN ('esp.desactivado@test', 'pac.desactivado@test');

-- pac.activo: onboarding completo (dirección+cuota+evaluación) -------------------
UPDATE public.profiles p
SET activo = TRUE, payment_completed = TRUE, evaluation_passed = TRUE, updated_at = now()
WHERE p.email = 'pac.activo@test';

UPDATE public.pacientes pac
SET activo = TRUE, updated_at = now()
FROM public.profiles p
WHERE pac.usuario_id = p.id AND p.email = 'pac.activo@test';

-- 3. Evaluaciones de telemedicina -------------------------------------------------
INSERT INTO public.validaciones_telemedicina (
  id, paciente_id, proveedor, codigo_referencia, fecha_validacion,
  fecha_vencimiento, estado, created_at, updated_at
)
SELECT 'A0000000-0000-0000-0000-000000000001'::uuid, pac.id, 'Telemedicina',
       'MAT-' || pac.id, now(), now() + interval '365 days', 'APROBADA', now(), now()
FROM public.pacientes pac
JOIN public.profiles p ON p.id = pac.usuario_id
WHERE p.email = 'pac.activo@test'
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.validaciones_telemedicina (
  id, paciente_id, proveedor, codigo_referencia, fecha_validacion,
  fecha_vencimiento, estado, created_at, updated_at
)
SELECT 'A0000000-0000-0000-0000-000000000002'::uuid, pac.id, 'Telemedicina',
       'MAT-' || pac.id, now() - interval '400 days', now() - interval '35 days', 'VENCIDA', now(), now()
FROM public.pacientes pac
JOIN public.profiles p ON p.id = pac.usuario_id
WHERE p.email = 'pac.vencido@test'
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.validaciones_telemedicina (
  id, paciente_id, proveedor, codigo_referencia, fecha_validacion,
  fecha_vencimiento, estado, created_at, updated_at
)
SELECT 'A0000000-0000-0000-0000-000000000003'::uuid, pac.id, 'Telemedicina',
       'MAT-' || pac.id, now() - interval '20 days', now() + interval '345 days', 'RECHAZADA', now(), now()
FROM public.pacientes pac
JOIN public.profiles p ON p.id = pac.usuario_id
WHERE p.email = 'pac.rechazado@test'
ON CONFLICT (id) DO NOTHING;

-- 4. Médico regente (para que esp.aprobado pase el wizard profesional) ------------
INSERT INTO public.medicos_regentes (id, nombre, numero_licencia, estado, activo, created_at, updated_at)
VALUES ('B0000000-0000-0000-0000-000000000001', 'Dr. Regente Test', 'TX-REG-9000', 'ACTIVO', TRUE, now(), now())
ON CONFLICT (id) DO NOTHING;

-- 5. Filas de especialistas por usuario -------------------------------------------
INSERT INTO public.especialistas (
  id, usuario_id, medico_regente_id, numero_licencia, estado_verificacion,
  fecha_solicitud_verificacion, fecha_aprobacion, observacion, disponible, activo,
  created_at, updated_at
)
SELECT 'C0000000-0000-0000-0000-000000000001'::uuid, p.id, NULL, 'TX-LIC-REV1', 'EN_REVISION',
       now() - interval '2 days', NULL, NULL, FALSE, TRUE, now(), now()
FROM public.profiles p WHERE p.email = 'esp.revision@test'
ON CONFLICT (usuario_id) DO UPDATE SET
  estado_verificacion = EXCLUDED.estado_verificacion,
  updated_at = now();

INSERT INTO public.especialistas (
  id, usuario_id, medico_regente_id, numero_licencia, estado_verificacion,
  fecha_solicitud_verificacion, fecha_aprobacion, observacion, disponible, activo,
  created_at, updated_at
)
SELECT 'C0000000-0000-0000-0000-000000000002'::uuid, p.id, 'B0000000-0000-0000-0000-000000000001'::uuid,
       'TX-MD-9901', 'APROBADO',
       now() - interval '10 days', now(), NULL, TRUE, TRUE, now(), now()
FROM public.profiles p WHERE p.email = 'esp.aprobado@test'
ON CONFLICT (usuario_id) DO UPDATE SET
  medico_regente_id = EXCLUDED.medico_regente_id,
  estado_verificacion = EXCLUDED.estado_verificacion,
  fecha_aprobacion = EXCLUDED.fecha_aprobacion,
  disponible = EXCLUDED.disponible,
  activo = EXCLUDED.activo,
  updated_at = now();

INSERT INTO public.especialistas (
  id, usuario_id, medico_regente_id, numero_licencia, estado_verificacion,
  fecha_solicitud_verificacion, fecha_aprobacion, observacion, disponible, activo,
  created_at, updated_at
)
SELECT 'C0000000-0000-0000-0000-000000000003'::uuid, p.id, NULL, 'TX-LIC-REC1', 'RECHAZADO',
       now() - interval '5 days', NULL, 'Documentación ilegible. Reenvíe licencia vigente.', FALSE, TRUE, now(), now()
FROM public.profiles p WHERE p.email = 'esp.rechazado@test'
ON CONFLICT (usuario_id) DO UPDATE SET
  estado_verificacion = EXCLUDED.estado_verificacion,
  observacion = EXCLUDED.observacion,
  updated_at = now();

INSERT INTO public.especialistas (
  id, usuario_id, medico_regente_id, numero_licencia, estado_verificacion,
  fecha_solicitud_verificacion, fecha_aprobacion, observacion, disponible, activo,
  created_at, updated_at
)
SELECT 'C0000000-0000-0000-0000-000000000004'::uuid, p.id, NULL, 'TX-LIC-BLO1', 'BLOQUEADO',
       now() - interval '8 days', NULL, 'Cuenta bloqueada por incumplimiento contractual.', FALSE, TRUE, now(), now()
FROM public.profiles p WHERE p.email = 'esp.bloqueado@test'
ON CONFLICT (usuario_id) DO UPDATE SET
  estado_verificacion = EXCLUDED.estado_verificacion,
  observacion = EXCLUDED.observacion,
  updated_at = now();

INSERT INTO public.especialistas (
  id, usuario_id, medico_regente_id, numero_licencia, estado_verificacion,
  fecha_solicitud_verificacion, fecha_aprobacion, observacion, disponible, activo,
  created_at, updated_at
)
SELECT 'C0000000-0000-0000-0000-000000000005'::uuid, p.id, NULL, 'TX-LIC-DES1', 'APROBADO',
       now() - interval '3 days', now(), NULL, FALSE, FALSE, now(), now()
FROM public.profiles p WHERE p.email = 'esp.desactivado@test'
ON CONFLICT (usuario_id) DO UPDATE SET
  estado_verificacion = EXCLUDED.estado_verificacion,
  activo = EXCLUDED.activo,
  updated_at = now();

-- 6. Especialidades del especialista aprobado --------------------------------------
INSERT INTO public.especialista_especialidades (especialista_id, especialidad_id, created_at)
SELECT esp.id, esp2.id, now()
FROM public.especialistas esp
JOIN public.profiles p ON p.id = esp.usuario_id
JOIN public.especialidades esp2 ON esp2.nombre = 'Medicina Estética'
WHERE p.email = 'esp.aprobado@test'
ON CONFLICT (especialista_id, especialidad_id) DO NOTHING;

INSERT INTO public.especialista_especialidades (especialista_id, especialidad_id, created_at)
SELECT esp.id, esp2.id, now()
FROM public.especialistas esp
JOIN public.profiles p ON p.id = esp.usuario_id
JOIN public.especialidades esp2 ON esp2.nombre = 'Toxina Botulínica'
WHERE p.email = 'esp.aprobado@test'
ON CONFLICT (especialista_id, especialidad_id) DO NOTHING;

-- 7. Documentos requeridos del especialista aprobado (para no reenviar al wizard) --
INSERT INTO public.documentos_especialista (
  id, especialista_id, tipo_documento, nombre_archivo, url_archivo,
  estado_revision, observacion_revision, fecha_revision, version_documento,
  activo, created_at, updated_at
)
SELECT 'D0000000-0000-0000-0000-000000000001'::uuid, esp.id,
       'IDENTIFICACION'::public.tipo_documento_enum, 'identificacion.pdf',
       'documentos-especialistas/' || esp.id || '/identificacion.pdf',
       'APROBADO'::public.estado_revision_enum, NULL, now(), 1, TRUE, now(), now()
FROM public.especialistas esp
JOIN public.profiles p ON p.id = esp.usuario_id
WHERE p.email = 'esp.aprobado@test'
  AND NOT EXISTS (SELECT 1 FROM public.documentos_especialista d
                  WHERE d.especialista_id = esp.id AND d.tipo_documento = 'IDENTIFICACION');

INSERT INTO public.documentos_especialista (
  id, especialista_id, tipo_documento, nombre_archivo, url_archivo,
  estado_revision, observacion_revision, fecha_revision, version_documento,
  activo, created_at, updated_at
)
SELECT 'D0000000-0000-0000-0000-000000000002'::uuid, esp.id,
       'LICENCIA'::public.tipo_documento_enum, 'licencia.pdf',
       'documentos-especialistas/' || esp.id || '/licencia.pdf',
       'APROBADO'::public.estado_revision_enum, NULL, now(), 1, TRUE, now(), now()
FROM public.especialistas esp
JOIN public.profiles p ON p.id = esp.usuario_id
WHERE p.email = 'esp.aprobado@test'
  AND NOT EXISTS (SELECT 1 FROM public.documentos_especialista d
                  WHERE d.especialista_id = esp.id AND d.tipo_documento = 'LICENCIA');

-- 8. Resumen ------------------------------------------------------------------------
SELECT 'Usuarios matriz' AS seccion, count(*) FROM public.profiles WHERE email LIKE '%@test';
```

> **Nota**: `disponibilidad_especialista`, `ubicaciones_especialista` y `contratos`
> (necesarias para "esp.aprobado 100% operativo en el mapa") no están versionadas en
> ninguna migración — se crearon a mano en el dashboard. Se pueden dejar para que el
> especialista las rellene por la app (docs 02/09) o versionarlas en un seguimiento.

### 1.4 Verificación post-`db push`

```sql
SELECT email, role, activo, phone FROM public.profiles ORDER BY email;
SELECT email, estado_verificacion FROM public.profiles p
LEFT JOIN public.especialistas e ON e.usuario_id = p.id
WHERE p.role = 'Especialista' ORDER BY p.email;
```

---

## Fase 2 — Fixes de código (ya hechos en esta rama)

### 2.1 `lib/features/auth_users/data/datasources/auth_supabase_datasource.dart`

**`signUp`** — enviar `phone` en metadata (antes solo `full_name`/`role`):

```dart
final response = await _client.auth.signUp(
  email: email,
  password: password,
  data: {
    'full_name': fullName,
    'role': role,
    if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
  },
);
```

**`createProfile`** — escribir `null` (no `''`) cuando no hay teléfono:
- Línea ~149: `'phone': phone,` (antes `'phone': phone ?? ''`).
- Fallback update (~167): `'phone': phone,`.

**Nuevo método** (reenvío de confirmación, cubre AU-V-07):

```dart
Future<void> resendConfirmationEmail(String email) async {
  await _client.auth.resend(email: email, type: OtpType.signup);
}
```

### 2.2 `lib/features/auth_users/domain/repositories/i_auth_repository.dart`

```dart
Future<Either<Failure, void>> resendConfirmationEmail(String email);
```

### 2.3 `lib/features/auth_users/data/repositories/auth_repository_impl.dart`

```dart
@override
Future<Either<Failure, void>> resendConfirmationEmail(String email) async {
  try {
    await _dataSource.resendConfirmationEmail(email);
    return const Right(null);
  } on sb.AuthException catch (e) {
    return Left(AuthFailure(e.message, code: e.code));
  } catch (e) {
    return Left(ServerFailure(e.toString()));
  }
}
```

### 2.4 `lib/features/auth_users/presentation/cubits/auth_cubit.dart`

```dart
Future<void> resendConfirmationEmail(String email) async {
  final result = await _authRepository.resendConfirmationEmail(email);
  result.fold(
    (failure) => emit(AuthError(failure.message)),
    (_) => emit(const AuthConfirmationResent()),
  );
}
```

Nuevo estado `AuthConfirmationResent` junto a `AuthEmailConfirmationSent`.

### 2.5 `lib/features/auth_users/presentation/screens/login_screen.dart`

En `_showEmailConfirmation` añadir botón "Reenviar correo":

```dart
actions: [
  TextButton(
    onPressed: () {
      context.read<AuthCubit>().resendConfirmationEmail(email);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Correo de confirmación reenviado. Revisa tu bandeja.'),
      ));
    },
    child: const Text('Reenviar correo'),
  ),
  ElevatedButton(
    onPressed: () {
      Navigator.pop(ctx);
      setState(() => _mode = _AuthMode.signIn);
    },
    child: const Text('Entendido'),
  ),
],
```

En el `BlocListener`, el estado `AuthConfirmationResent` no navega (se muestra el snackbar).

---

## Fase 3 — Config dashboard (manual, en la otra PC)

1. Supabase → Authentication → Providers → Email: mantener **Confirm email ON**.
2. **Configurar SMTP** (Authentication → Email → SMTP settings) con un proveedor
   real (Resend/SendGrid/Mailgun). Sin SMTP, Supabase no entrega los correos.
   - Alternativa para pruebas sin SMTP: Supabase → Authentication → Logs / Emails →
     copiar el enlace de confirmación generado.
3. Authentication → URL Configuration: **Site URL** y **Redirect URLs** correctos
   para la plataforma de prueba (p. ej. `http://localhost` para web, y el deep link
   `com.example.esteticaybellezastrani://`).

---

## Fase 4 — Re-pruebas

1. Re-ejecutar AU-H-01…AU-H-12 y AU-V-01…AU-V-12 de `docs/Pruebas manuales/01_auth_users.md`.
2. Actualizar la columna Resultado y el resumen del doc.
3. (Seguimiento) Versionar `disponibilidad_especialista`, `ubicaciones_especialista`
   y `contratos` en una migración.

---

## Checklist

- [x] Plan persistido en `docs/plans/` (este archivo).
- [x] Fixes de código (Fase 2).
- [x] Migraciones nuevas (Fase 1.2 y 1.3) creadas en `supabase/migrations/`.
- [x] `flutter analyze` y `flutter test` pasan.
- [ ] Commit + push (mensaje en español).
- [ ] En la otra PC: `git pull`, copiar `.env`, `supabase db push`, configurar SMTP.
- [ ] Re-pruebas doc 01.
