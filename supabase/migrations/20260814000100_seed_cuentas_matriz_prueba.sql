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
-- El search_path de la conexión de `supabase db push` no incluye el esquema de la
-- extensión por defecto; se añade explícitamente para que crypt/gen_salt resuelvan.
CREATE EXTENSION IF NOT EXISTS pgcrypto;
SET search_path = public, extensions;

-- Los triggers de verificación/revisión tratan la sesión de migración como
-- no-admin (auth.uid() = NULL) y bloquearían insertar los estados finales de la
-- matriz (EN_REVISION/APROBADO/RECHAZADO/BLOQUEADO en especialistas y APROBADO
-- en documentos). Se desactivan solo durante el seed y se reactivan al final.
ALTER TABLE public.especialistas DISABLE TRIGGER trg_proteger_verificacion_especialista;
ALTER TABLE public.documentos_especialista DISABLE TRIGGER trg_proteger_revision_documento;

-- 1. Usuarios auth ---------------------------------------------------------------
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  confirmation_token, recovery_token, email_change, email_change_token_new,
  created_at, updated_at
)
SELECT * FROM (VALUES
 ('00000000-0000-0000-0000-000000000000'::uuid, '90000000-0000-0000-0000-000000000001'::uuid, 'authenticated', 'authenticated',
  'admin@test', crypt('Test1234!', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{"role":"Administrador","full_name":"Administrador Test","phone":"+1 555 0100"}'::jsonb, '', '', '', '', now(), now()),
 ('00000000-0000-0000-0000-000000000000', '90000000-0000-0000-0000-000000000002',
  'authenticated', 'authenticated', 'esp.nuevo@test', crypt('Test1234!', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  '{"role":"Especialista","full_name":"Especialista Nuevo","phone":"+1 555 0101"}', '', '', '', '', now(), now()),
 ('00000000-0000-0000-0000-000000000000', '90000000-0000-0000-0000-000000000003',
  'authenticated', 'authenticated', 'esp.revision@test', crypt('Test1234!', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  '{"role":"Especialista","full_name":"Esp. En Revisión","phone":"+1 555 0102"}', '', '', '', '', now(), now()),
 ('00000000-0000-0000-0000-000000000000', '90000000-0000-0000-0000-000000000004',
  'authenticated', 'authenticated', 'esp.aprobado@test', crypt('Test1234!', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  '{"role":"Especialista","full_name":"Dra. Aprobada Test","phone":"+1 555 0103"}', '', '', '', '', now(), now()),
 ('00000000-0000-0000-0000-000000000000', '90000000-0000-0000-0000-000000000005',
  'authenticated', 'authenticated', 'esp.rechazado@test', crypt('Test1234!', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  '{"role":"Especialista","full_name":"Esp. Rechazado","phone":"+1 555 0104"}', '', '', '', '', now(), now()),
 ('00000000-0000-0000-0000-000000000000', '90000000-0000-0000-0000-000000000006',
  'authenticated', 'authenticated', 'esp.bloqueado@test', crypt('Test1234!', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  '{"role":"Especialista","full_name":"Esp. Bloqueado","phone":"+1 555 0105"}', '', '', '', '', now(), now()),
 ('00000000-0000-0000-0000-000000000000', '90000000-0000-0000-0000-000000000007',
  'authenticated', 'authenticated', 'esp.desactivado@test', crypt('Test1234!', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  '{"role":"Especialista","full_name":"Esp. Desactivado","phone":"+1 555 0106"}', '', '', '', '', now(), now()),
 ('00000000-0000-0000-0000-000000000000', '90000000-0000-0000-0000-000000000008',
  'authenticated', 'authenticated', 'pac.nuevo@test', crypt('Test1234!', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  '{"role":"Paciente","full_name":"Paciente Nuevo","phone":"+1 555 0107"}', '', '', '', '', now(), now()),
 ('00000000-0000-0000-0000-000000000000', '90000000-0000-0000-0000-000000000009',
  'authenticated', 'authenticated', 'pac.activo@test', crypt('Test1234!', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  '{"role":"Paciente","full_name":"Paciente Activo","phone":"+1 555 0108"}', '', '', '', '', now(), now()),
 ('00000000-0000-0000-0000-000000000000', '90000000-0000-0000-0000-00000000000A',
  'authenticated', 'authenticated', 'pac.vencido@test', crypt('Test1234!', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  '{"role":"Paciente","full_name":"Paciente Vencido","phone":"+1 555 0109"}', '', '', '', '', now(), now()),
 ('00000000-0000-0000-0000-000000000000', '90000000-0000-0000-0000-00000000000B',
  'authenticated', 'authenticated', 'pac.rechazado@test', crypt('Test1234!', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  '{"role":"Paciente","full_name":"Paciente Rechazado","phone":"+1 555 0110"}', '', '', '', '', now(), now()),
 ('00000000-0000-0000-0000-000000000000', '90000000-0000-0000-0000-00000000000C',
  'authenticated', 'authenticated', 'pac.desactivado@test', crypt('Test1234!', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  '{"role":"Paciente","full_name":"Paciente Desactivado","phone":"+1 555 0111"}', '', '', '', '', now(), now())
) AS v(instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
WHERE NOT EXISTS (SELECT 1 FROM auth.users u WHERE u.email = v.email);

-- 1b. Identidades auth (obligatorias para el login con contraseña en gotrue v2) -----
INSERT INTO auth.identities (
  id, provider_id, user_id, identity_data, provider,
  last_sign_in_at, created_at, updated_at
)
SELECT gen_random_uuid(), u.id::text, u.id,
       jsonb_build_object('sub', u.id::text, 'email', u.email, 'email_verified', TRUE, 'phone_verified', FALSE),
       'email', now(), now(), now()
FROM auth.users u
WHERE u.email LIKE '%@test'
  AND NOT EXISTS (SELECT 1 FROM auth.identities i WHERE i.user_id = u.id);

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

-- 8. Reactivar triggers de verificación/revisión ---------------------------------
ALTER TABLE public.especialistas ENABLE TRIGGER trg_proteger_verificacion_especialista;
ALTER TABLE public.documentos_especialista ENABLE TRIGGER trg_proteger_revision_documento;

-- 9. Resumen ------------------------------------------------------------------------
SELECT 'Usuarios matriz' AS seccion, count(*) FROM public.profiles WHERE email LIKE '%@test';
