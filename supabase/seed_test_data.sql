-- =============================================================================
-- SEED DATOS DE PRUEBA — Estética y Belleza Strani (mercado: Houston, TX, USA)
-- =============================================================================
-- Ejecutar en el SQL Editor del dashboard de Supabase (o con `supabase db push`
-- tras copiar a una migración). Es idempotente: si se re-ejecuta no duplica.
--
-- Credenciales de prueba (misma clave para todos):
--   email:  paciente1@test.com ... paciente5@test.com
--           especialista1@test.com ... especialista4@test.com
--           admin@strani.com
--   clave:  Test1234!
--
-- Genera:
--   * 5 pacientes  (con dirección principal + evaluación médica APROBADA)
--   * 4 especialistas APROBADOS con ubicación (visible en el mapa)
--   * 1 administrador
--   * categorías y servicios del catálogo
--   * solicitudes pendientes (PUBLICADA / BUSCANDO_ESPECIALISTA) para el mapa
--   * 1 solicitud ACEPTADA con cita PROGRAMADA (caso "ya asignado")
-- =============================================================================

-- ── 1. USUARIOS (auth.users) ───────────────────────────────────────────────
-- La trigger `handle_new_user` crea automáticamente profiles y pacientes.
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at
) VALUES
-- Pacientes
('00000000-0000-0000-0000-000000000000', '10000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated',
 'paciente1@test.com', crypt('Test1234!', gen_salt('bf')), now(),
 '{"provider":"email","providers":["email"]}',
 '{"role":"Paciente","full_name":"María González"}', now(), now()),
('00000000-0000-0000-0000-000000000000', '10000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated',
 'paciente2@test.com', crypt('Test1234!', gen_salt('bf')), now(),
 '{"provider":"email","providers":["email"]}',
 '{"role":"Paciente","full_name":"Juan Pérez"}', now(), now()),
('00000000-0000-0000-0000-000000000000', '10000000-0000-0000-0000-000000000003', 'authenticated', 'authenticated',
 'paciente3@test.com', crypt('Test1234!', gen_salt('bf')), now(),
 '{"provider":"email","providers":["email"]}',
 '{"role":"Paciente","full_name":"Ana Rodríguez"}', now(), now()),
('00000000-0000-0000-0000-000000000000', '10000000-0000-0000-0000-000000000004', 'authenticated', 'authenticated',
 'paciente4@test.com', crypt('Test1234!', gen_salt('bf')), now(),
 '{"provider":"email","providers":["email"]}',
 '{"role":"Paciente","full_name":"Luis Martínez"}', now(), now()),
('00000000-0000-0000-0000-000000000000', '10000000-0000-0000-0000-000000000005', 'authenticated', 'authenticated',
 'paciente5@test.com', crypt('Test1234!', gen_salt('bf')), now(),
 '{"provider":"email","providers":["email"]}',
 '{"role":"Paciente","full_name":"Carmen López"}', now(), now()),
-- Especialistas (la trigger solo crea profile, no paciente)
('00000000-0000-0000-0000-000000000000', '20000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated',
 'especialista1@test.com', crypt('Test1234!', gen_salt('bf')), now(),
 '{"provider":"email","providers":["email"]}',
 '{"role":"Especialista","full_name":"Dr. Carlos Medina"}', now(), now()),
('00000000-0000-0000-0000-000000000000', '20000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated',
 'especialista2@test.com', crypt('Test1234!', gen_salt('bf')), now(),
 '{"provider":"email","providers":["email"]}',
 '{"role":"Especialista","full_name":"Dra. Laura Fernández"}', now(), now()),
('00000000-0000-0000-0000-000000000000', '20000000-0000-0000-0000-000000000003', 'authenticated', 'authenticated',
 'especialista3@test.com', crypt('Test1234!', gen_salt('bf')), now(),
 '{"provider":"email","providers":["email"]}',
 '{"role":"Especialista","full_name":"Dr. José Ramírez"}', now(), now()),
('00000000-0000-0000-0000-000000000000', '20000000-0000-0000-0000-000000000004', 'authenticated', 'authenticated',
 'especialista4@test.com', crypt('Test1234!', gen_salt('bf')), now(),
 '{"provider":"email","providers":["email"]}',
 '{"role":"Especialista","full_name":"Dra. Sofía Torres"}', now(), now())
ON CONFLICT (id) DO NOTHING;

-- ── 2. PACIENtes: activar + evaluaciones APROBADAS (para gate RN-020) ─────
UPDATE public.profiles
   SET activo = TRUE,
       payment_completed = TRUE,
       evaluation_passed = TRUE,
       updated_at = now()
 WHERE email LIKE 'paciente%@test.com';

UPDATE public.pacientes
   SET activo = TRUE,
       updated_at = now()
 WHERE usuario_id IN (
   SELECT id FROM public.profiles WHERE email LIKE 'paciente%@test.com'
 );

-- Evaluación médica vigente (1 año) para que el flujo de reservas funcione.
INSERT INTO public.validaciones_telemedicina (
  id, paciente_id, proveedor, codigo_referencia, fecha_validacion,
  fecha_vencimiento, estado, created_at, updated_at
)
SELECT '30000000-0000-0000-0000-000000000001', p.id, 'Telemedicina',
       'TST-' || p.id, now(), now() + interval '365 days', 'APROBADA', now(), now()
FROM public.profiles p
WHERE p.email = 'paciente1@test.com'
ON CONFLICT (id) DO NOTHING;

-- ── 3. ADMINISTRADOR ───────────────────────────────────────────────────────
-- La trigger ahora permite Administrador (creado desde el módulo de Administración);
-- no crea fila en pacientes para este rol.
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at
) VALUES (
  '00000000-0000-0000-0000-000000000000', '40000000-0000-0000-0000-000000000001',
  'authenticated', 'authenticated', 'admin@strani.com', crypt('Test1234!', gen_salt('bf')),
  now(), '{"provider":"email","providers":["email"]}',
  '{"role":"Administrador","full_name":"Administrador Strani"}', now(), now()
) ON CONFLICT (id) DO NOTHING;

UPDATE public.profiles
   SET activo = TRUE,
       payment_completed = TRUE,
       evaluation_passed = TRUE,
       updated_at = now()
 WHERE email = 'admin@strani.com';

-- ── 4. ESPECIALISTAS APROBADOS ─────────────────────────────────────────────
INSERT INTO public.especialistas (
  id, usuario_id, numero_licencia, estado_verificacion,
  fecha_solicitud_verificacion, fecha_aprobacion, disponible, activo
)
SELECT '50000000-0000-0000-0000-000000000001', pr.id, 'TX-MD-1001', 'APROBADO',
       now() - interval '10 days', now(), TRUE, TRUE
FROM public.profiles pr WHERE pr.email = 'especialista1@test.com'
UNION ALL
SELECT '50000000-0000-0000-0000-000000000002', pr.id, 'TX-MD-1002', 'APROBADO',
       now() - interval '9 days', now(), TRUE, TRUE
FROM public.profiles pr WHERE pr.email = 'especialista2@test.com'
UNION ALL
SELECT '50000000-0000-0000-0000-000000000003', pr.id, 'TX-MD-1003', 'APROBADO',
       now() - interval '8 days', now(), TRUE, TRUE
FROM public.profiles pr WHERE pr.email = 'especialista3@test.com'
UNION ALL
SELECT '50000000-0000-0000-0000-000000000004', pr.id, 'TX-MD-1004', 'APROBADO',
       now() - interval '7 days', now(), TRUE, TRUE
FROM public.profiles pr WHERE pr.email = 'especialista4@test.com'
ON CONFLICT (id) DO NOTHING;

-- ── 5. UBICACIONES DE ESPECIALISTAS (Houston, TX) ─────────────────────────
INSERT INTO public.ubicaciones_especialista (
  id, especialista_id, latitud, longitud, precision_metros,
  fecha_actualizacion, created_at, ubicacion
) VALUES
('60000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001',
 29.7604, -95.3698, 10, now(), now(), 'SRID=4326;POINT(-95.3698 29.7604)'::geography),   -- Downtown
('60000000-0000-0000-0000-000000000002', '50000000-0000-0000-0000-000000000002',
 29.7380, -95.4650, 10, now(), now(), 'SRID=4326;POINT(-95.4650 29.7380)'::geography),   -- Galleria/Uptown
('60000000-0000-0000-0000-000000000003', '50000000-0000-0000-0000-000000000003',
 29.8034, -95.3964, 10, now(), now(), 'SRID=4326;POINT(-95.3964 29.8034)'::geography),   -- Heights
('60000000-0000-0000-0000-000000000004', '50000000-0000-0000-0000-000000000004',
 29.6197, -95.6349, 10, now(), now(), 'SRID=4326;POINT(-95.6349 29.6197)'::geography)    -- Sugar Land
ON CONFLICT (id) DO NOTHING;

-- ── 6. CATÁLOGO: categorías y servicios ────────────────────────────────────
INSERT INTO public.categorias_servicio (id, nombre, descripcion, activo, created_at, updated_at)
VALUES (1, 'Inyectables', 'Toxina, ácido hialurónico y bioestimuladores', TRUE, now(), now()),
       (2, 'Rejuvenecimiento Facial', 'Peelings, microneedling y terapias celulares', TRUE, now(), now()),
       (3, 'Remodelación Corporal', 'Lipólisis y tratamientos reductores', TRUE, now(), now()),
       (4, 'Láser Médico', 'Depilación y rejuvenecimiento láser', TRUE, now(), now())
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.servicios (
  id, categoria_id, nombre, descripcion, precio_base, tipo_precio,
  duracion_estimada, requiere_telemedicina, requiere_face_map,
  requiere_fotos, requiere_consentimiento, activo, created_at, updated_at
) VALUES
('11111111-1111-1111-1111-111111111111', 1, 'Toxina Botulínica',
 'Toxina botulínica para arrugas de expresión.', 200, 'PRECIO_FIJO',
 60, TRUE, TRUE, TRUE, TRUE, TRUE, now(), now()),
('22222222-2222-2222-2222-222222222222', 1, 'Ácido Hialurónico',
 'Relleno facial con ácido hialurónico.', 250, 'PRECIO_FIJO',
 60, TRUE, TRUE, TRUE, TRUE, TRUE, now(), now()),
('33333333-3333-3333-3333-333333333333', 2, 'Peelings Médicos',
 'Peelings químicos para renovación de piel.', 150, 'PRECIO_FIJO',
 45, TRUE, FALSE, FALSE, TRUE, TRUE, now(), now()),
('44444444-4444-4444-4444-444444444444', 2, 'Microneedling',
 'Microneedling con plasma rico en plaquetas.', 180, 'POR_SESION',
 60, TRUE, FALSE, FALSE, TRUE, TRUE, now(), now()),
('55555555-5555-5555-5555-555555555555', 3, 'Lipólisis Alta Frecuencia',
 'Reducción de grasa localizada.', 220, 'POR_SESION',
 60, TRUE, FALSE, TRUE, TRUE, TRUE, now(), now()),
('66666666-6666-6666-6666-666666666666', 4, 'Depilación Láser',
 'Depilación médica definitiva.', 120, 'POR_SESION',
 45, FALSE, FALSE, FALSE, FALSE, TRUE, now(), now())
ON CONFLICT (id) DO NOTHING;

-- ── 7. DIRECCIONES PRINCIPALES DE PACIENTES (Houston, TX) ─────────────────
INSERT INTO public.direcciones_paciente (
  id, paciente_id, direccion, ciudad, estado, codigo_postal,
  latitud, longitud, es_principal, created_at, ubicacion
)
SELECT '70000000-0000-0000-0000-000000000001', pac.id,
       '2310 Main St', 'Houston', 'TX', '77002',
       29.7410, -95.3727, TRUE, now(),
       'SRID=4326;POINT(-95.3727 29.7410)'::geography
FROM public.pacientes pac
JOIN public.profiles pr ON pr.id = pac.usuario_id
WHERE pr.email = 'paciente1@test.com'
UNION ALL
SELECT '70000000-0000-0000-0000-000000000002', pac.id,
       '1202 Heights Blvd', 'Houston', 'TX', '77008',
       29.8034, -95.3964, TRUE, now(),
       'SRID=4326;POINT(-95.3964 29.8034)'::geography
FROM public.pacientes pac
JOIN public.profiles pr ON pr.id = pac.usuario_id
WHERE pr.email = 'paciente2@test.com'
UNION ALL
SELECT '70000000-0000-0000-0000-000000000003', pac.id,
       '5085 Westheimer Rd', 'Houston', 'TX', '77056',
       29.7380, -95.4650, TRUE, now(),
       'SRID=4326;POINT(-95.4650 29.7380)'::geography
FROM public.pacientes pac
JOIN public.profiles pr ON pr.id = pac.usuario_id
WHERE pr.email = 'paciente3@test.com'
UNION ALL
SELECT '70000000-0000-0000-0000-000000000004', pac.id,
       '700 Waugh Dr', 'Houston', 'TX', '77019',
       29.7445, -95.3916, TRUE, now(),
       'SRID=4326;POINT(-95.3916 29.7445)'::geography
FROM public.pacientes pac
JOIN public.profiles pr ON pr.id = pac.usuario_id
WHERE pr.email = 'paciente4@test.com'
UNION ALL
SELECT '70000000-0000-0000-0000-000000000005', pac.id,
       '2071 N Fry Rd', 'Katy', 'TX', '77449',
       29.7858, -95.8244, TRUE, now(),
       'SRID=4326;POINT(-95.8244 29.7858)'::geography
FROM public.pacientes pac
JOIN public.profiles pr ON pr.id = pac.usuario_id
WHERE pr.email = 'paciente5@test.com'
ON CONFLICT (id) DO NOTHING;

-- ── 8. SOLICITUDES PENDIENTES (mapa del especialista) ─────────────────────
-- Dirección principal de cada paciente.
INSERT INTO public.solicitudes (
  id, paciente_id, servicio_id, direccion_id, estado, fecha_solicitud,
  deposito_requerido, deposito_pagado, radio_busqueda,
  fecha_expiracion, created_at, updated_at
)
SELECT '80000000-0000-0000-0000-000000000001', sol.paciente_id, sol.servicio_id,
       sol.direccion_id, sol.estado, now(), sol.deposito, TRUE, sol.radio,
       sol.expira, now(), now()
FROM (
  SELECT pac.id AS paciente_id,
         '11111111-1111-1111-1111-111111111111'::uuid AS servicio_id,
         d.id AS direccion_id,
         'PUBLICADA' AS estado,
         30 AS deposito, 10 AS radio,
         now() + interval '3 days' AS expira
  FROM public.pacientes pac
  JOIN public.profiles pr ON pr.id = pac.usuario_id
  JOIN public.direcciones_paciente d ON d.paciente_id = pac.id
  WHERE pr.email = 'paciente1@test.com'
  UNION ALL
  SELECT pac.id,
         '22222222-2222-2222-2222-222222222222'::uuid,
         d.id,
         'BUSCANDO_ESPECIALISTA',
         30, 10, now() + interval '3 days'
  FROM public.pacientes pac
  JOIN public.profiles pr ON pr.id = pac.usuario_id
  JOIN public.direcciones_paciente d ON d.paciente_id = pac.id
  WHERE pr.email = 'paciente2@test.com'
  UNION ALL
  SELECT pac.id,
         '33333333-3333-3333-3333-333333333333'::uuid,
         d.id,
         'PUBLICADA',
         30, 10, now() + interval '3 days'
  FROM public.pacientes pac
  JOIN public.profiles pr ON pr.id = pac.usuario_id
  JOIN public.direcciones_paciente d ON d.paciente_id = pac.id
  WHERE pr.email = 'paciente3@test.com'
  UNION ALL
  SELECT pac.id,
         '44444444-4444-4444-4444-444444444444'::uuid,
         d.id,
         'BUSCANDO_ESPECIALISTA',
         30, 10, now() + interval '3 days'
  FROM public.pacientes pac
  JOIN public.profiles pr ON pr.id = pac.usuario_id
  JOIN public.direcciones_paciente d ON d.paciente_id = pac.id
  WHERE pr.email = 'paciente4@test.com'
  UNION ALL
  SELECT pac.id,
         '66666666-6666-6666-6666-666666666666'::uuid,
         d.id,
         'PUBLICADA',
         30, 10, now() + interval '3 days'
  FROM public.pacientes pac
  JOIN public.profiles pr ON pr.id = pac.usuario_id
  JOIN public.direcciones_paciente d ON d.paciente_id = pac.id
  WHERE pr.email = 'paciente5@test.com'
) sol
ON CONFLICT (id) DO NOTHING;

-- ── 9. CASO "YA ASIGNADO": solicitud ACEPTADA + cita PROGRAMADA ───────────
INSERT INTO public.solicitudes (
  id, paciente_id, servicio_id, direccion_id, estado, fecha_solicitud,
  deposito_requerido, deposito_pagado, radio_busqueda,
  fecha_expiracion, created_at, updated_at
)
SELECT '80000000-0000-0000-0000-000000000099', pac.id,
       '11111111-1111-1111-1111-111111111111'::uuid,
       d.id, 'ACEPTADA', now(), 30, TRUE, 10, now() + interval '3 days', now(), now()
FROM public.pacientes pac
JOIN public.profiles pr ON pr.id = pac.usuario_id
JOIN public.direcciones_paciente d ON d.paciente_id = pac.id
WHERE pr.email = 'paciente2@test.com'
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.citas (
  id, solicitud_id, especialista_id, estado, fecha_aceptacion, created_at, updated_at
)
SELECT '90000000-0000-0000-0000-000000000001',
       '80000000-0000-0000-0000-000000000099',
       '50000000-0000-0000-0000-000000000002',
       'PROGRAMADA', now(), now(), now()
WHERE NOT EXISTS (
  SELECT 1 FROM public.citas WHERE solicitud_id = '80000000-0000-0000-0000-000000000099'
);

-- ── RESUMEN ────────────────────────────────────────────────────────────────
SELECT 'Usuarios' AS seccion, count(*) AS total FROM auth.users
UNION ALL
SELECT 'Pacientes', count(*) FROM public.pacientes
UNION ALL
SELECT 'Especialistas aprobados', count(*) FROM public.especialistas WHERE estado_verificacion = 'APROBADO'
UNION ALL
SELECT 'Solicitudes pendientes', count(*) FROM public.solicitudes WHERE estado IN ('PUBLICADA', 'BUSCANDO_ESPECIALISTA')
UNION ALL
SELECT 'Citas', count(*) FROM public.citas;
