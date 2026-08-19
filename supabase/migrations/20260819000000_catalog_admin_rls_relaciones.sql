-- =============================================================================
-- Migración: Catálogo de servicios — admin CRUD (RLS), servicio_especialidades,
-- servicio_cuestionarios, match de especialidades en marketplace y seeds.
-- -----------------------------------------------------------------------------
-- * RLS escritura solo admin en `categorias_servicio`, `servicios`,
--   `servicio_especialidades` y `servicio_cuestionarios` (se conservan las
--   policies públicas de SELECT del catálogo).
-- * RPC atómicos `reemplazar_servicio_especialidades` y
--   `reemplazar_servicio_cuestionarios` (security definer, solo admin).
-- * `obtener_solicitudes_publicadas_geo` y `aceptar_solicitud` ahora exigen que
--   el especialista APROBADO coincida en especialidades con el servicio de la
--   solicitud (servicios sin `servicio_especialidades` quedan abiertos a todos).
-- * Seeds idempotentes de relaciones para el catálogo real.
-- Aplicar con `supabase db push` o desde el SQL Editor del dashboard.
-- Idempotente (CREATE ... IF NOT EXISTS, DROP POLICY IF EXISTS,
-- CREATE OR REPLACE FUNCTION, WHERE NOT EXISTS / ON CONFLICT).
-- =============================================================================

-- 1. RLS escritura solo admin --------------------------------------------------

-- 1.1 categorias_servicio
DROP POLICY IF EXISTS "catalogo_categorias_admin_write" ON public.categorias_servicio;
CREATE POLICY "catalogo_categorias_admin_write"
    ON public.categorias_servicio FOR ALL TO authenticated
    USING ((SELECT p.role FROM public.profiles p WHERE p.id = auth.uid()) = 'Administrador')
    WITH CHECK ((SELECT p.role FROM public.profiles p WHERE p.id = auth.uid()) = 'Administrador');

-- 1.2 servicios
DROP POLICY IF EXISTS "catalogo_servicios_admin_write" ON public.servicios;
CREATE POLICY "catalogo_servicios_admin_write"
    ON public.servicios FOR ALL TO authenticated
    USING ((SELECT p.role FROM public.profiles p WHERE p.id = auth.uid()) = 'Administrador')
    WITH CHECK ((SELECT p.role FROM public.profiles p WHERE p.id = auth.uid()) = 'Administrador');

-- 1.3 servicio_especialidades (relación M:N servicio -> especialidad)
ALTER TABLE public.servicio_especialidades ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "servicio_especialidades_public_select" ON public.servicio_especialidades;
CREATE POLICY "servicio_especialidades_public_select"
    ON public.servicio_especialidades FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "servicio_especialidades_admin_write" ON public.servicio_especialidades;
CREATE POLICY "servicio_especialidades_admin_write"
    ON public.servicio_especialidades FOR ALL TO authenticated
    USING ((SELECT p.role FROM public.profiles p WHERE p.id = auth.uid()) = 'Administrador')
    WITH CHECK ((SELECT p.role FROM public.profiles p WHERE p.id = auth.uid()) = 'Administrador');

-- 1.4 servicio_cuestionarios (relación M:N servicio -> cuestionario)
ALTER TABLE public.servicio_cuestionarios ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "servicio_cuestionarios_public_select" ON public.servicio_cuestionarios;
CREATE POLICY "servicio_cuestionarios_public_select"
    ON public.servicio_cuestionarios FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "servicio_cuestionarios_admin_write" ON public.servicio_cuestionarios;
CREATE POLICY "servicio_cuestionarios_admin_write"
    ON public.servicio_cuestionarios FOR ALL TO authenticated
    USING ((SELECT p.role FROM public.profiles p WHERE p.id = auth.uid()) = 'Administrador')
    WITH CHECK ((SELECT p.role FROM public.profiles p WHERE p.id = auth.uid()) = 'Administrador');

-- 2. Grants --------------------------------------------------------------------

GRANT SELECT ON public.servicio_especialidades TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.servicio_especialidades TO authenticated;
GRANT SELECT ON public.servicio_cuestionarios TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.servicio_cuestionarios TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.servicios TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.categorias_servicio TO authenticated;

-- 3. RPC reemplazo atómico de especialidades de un servicio -------------------

CREATE OR REPLACE FUNCTION public.reemplazar_servicio_especialidades(
    p_servicio_id uuid,
    p_ids bigint[]
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_is_admin boolean;
BEGIN
    SELECT (p.role = 'Administrador')
      INTO v_is_admin
      FROM public.profiles p
     WHERE p.id = auth.uid();

    IF NOT COALESCE(v_is_admin, FALSE) THEN
        RAISE EXCEPTION 'Solo administradores pueden configurar las especialidades de un servicio';
    END IF;

    DELETE FROM public.servicio_especialidades
     WHERE servicio_id = p_servicio_id;

    IF p_ids IS NOT NULL AND array_length(p_ids, 1) > 0 THEN
        INSERT INTO public.servicio_especialidades (servicio_id, especialidad_id)
        SELECT p_servicio_id, unnest(p_ids);
    END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.reemplazar_servicio_especialidades(uuid, bigint[])
    TO authenticated;

-- 4. RPC reemplazo atómico de cuestionarios de un servicio ---------------------

CREATE OR REPLACE FUNCTION public.reemplazar_servicio_cuestionarios(
    p_servicio_id uuid,
    p_items jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_is_admin boolean;
BEGIN
    SELECT (p.role = 'Administrador')
      INTO v_is_admin
      FROM public.profiles p
     WHERE p.id = auth.uid();

    IF NOT COALESCE(v_is_admin, FALSE) THEN
        RAISE EXCEPTION 'Solo administradores pueden configurar los cuestionarios de un servicio';
    END IF;

    DELETE FROM public.servicio_cuestionarios
     WHERE servicio_id = p_servicio_id;

    IF jsonb_typeof(p_items) = 'array' AND jsonb_array_length(p_items) > 0 THEN
        INSERT INTO public.servicio_cuestionarios (servicio_id, cuestionario_id, obligatorio, orden)
        SELECT p_servicio_id,
               (item->>'cuestionario_id')::bigint,
               COALESCE((item->>'obligatorio')::boolean, FALSE),
               COALESCE((item->>'orden')::integer, 0)
          FROM jsonb_array_elements(p_items) AS item;
    END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.reemplazar_servicio_cuestionarios(uuid, jsonb)
    TO authenticated;

-- 5. Marketplace: solo solicitudes cuyo servicio coincida con las -------------
--    especialidades del especialista (defensa en profundidad). ----------------

CREATE OR REPLACE FUNCTION public.obtener_solicitudes_publicadas_geo()
RETURNS TABLE (
    solicitud_id    UUID,
    paciente_nombre TEXT,
    servicio_nombre TEXT,
    precio          NUMERIC,
    latitud_aprox   NUMERIC,
    longitud_aprox  NUMERIC,
    ciudad          TEXT,
    radio_busqueda  NUMERIC,
    fecha_expiracion TIMESTAMPTZ,
    estado          TEXT
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, extensions
AS $$
    SELECT s.id,
           pf.full_name,
           sv.nombre,
           sv.precio_base,
           round(dp.latitud::numeric, 3),
           round(dp.longitud::numeric, 3),
           dp.ciudad,
           s.radio_busqueda,
           s.fecha_expiracion,
           s.estado
    FROM public.solicitudes s
    JOIN public.direcciones_paciente dp ON dp.id = s.direccion_id
    JOIN public.pacientes p            ON p.id  = s.paciente_id
    JOIN public.profiles pf            ON pf.id = p.usuario_id
    JOIN public.servicios sv           ON sv.id = s.servicio_id
    WHERE s.estado IN ('PUBLICADA', 'BUSCANDO_ESPECIALISTA')
      AND EXISTS (
          SELECT 1
            FROM public.especialistas e
           WHERE e.usuario_id = auth.uid()
             AND e.estado_verificacion = 'APROBADO'
             AND e.activo = TRUE
             -- El servicio sin servicio_especialidades es visible para todos;
             -- con filas, el especialista debe coincidir en al menos una
             -- (especialidad activa).
             AND (
                 NOT EXISTS (
                     SELECT 1 FROM public.servicio_especialidades se
                      WHERE se.servicio_id = s.servicio_id
                 )
                 OR EXISTS (
                     SELECT 1
                       FROM public.servicio_especialidades se
                       JOIN public.especialista_especialidades ee
                         ON ee.especialidad_id = se.especialidad_id
                       JOIN public.especialidades esp
                         ON esp.id = ee.especialidad_id
                        AND esp.activo = TRUE
                      WHERE se.servicio_id = s.servicio_id
                        AND ee.especialista_id = e.id
                 )
             )
      )
    ORDER BY s.fecha_solicitud ASC;
$$;

GRANT EXECUTE ON FUNCTION public.obtener_solicitudes_publicadas_geo()
    TO authenticated;

-- 6. aceptar_solicitud: también valida coincidencia de especialidades ---------

CREATE OR REPLACE FUNCTION public.aceptar_solicitud(
    p_solicitud_id uuid,
    p_especialista_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_estado              text;
    v_servicio_id         uuid;
    v_claim               int;
    v_cita_id             uuid;
    v_especialista_valido boolean;
BEGIN
    SELECT estado, servicio_id INTO v_estado, v_servicio_id
      FROM public.solicitudes
     WHERE id = p_solicitud_id;

    IF v_estado IS NULL THEN
        RETURN json_build_object('aceptada', false, 'cita_id', null, 'motivo', 'NO_ENCONTRADA');
    END IF;

    IF v_estado NOT IN ('PUBLICADA', 'BUSCANDO_ESPECIALISTA') THEN
        RETURN json_build_object('aceptada', false, 'cita_id', null, 'motivo', 'ASIGNADA');
    END IF;

    -- Validación de verificación: solo APROBADO y activo.
    SELECT EXISTS (
        SELECT 1 FROM public.especialistas
         WHERE id = p_especialista_id
           AND estado_verificacion = 'APROBADO'
           AND activo = TRUE
    ) INTO v_especialista_valido;

    IF NOT v_especialista_valido THEN
        RETURN json_build_object('aceptada', false, 'cita_id', null, 'motivo', 'NO_APROBADO');
    END IF;

    -- Validación de especialidades: servicio sin filas -> abierto a todos;
    -- con filas, el especialista debe coincidir en al menos una.
    SELECT (EXISTS (
                SELECT 1
                  FROM public.servicio_especialidades se
                  JOIN public.especialista_especialidades ee
                    ON ee.especialidad_id = se.especialidad_id
                  JOIN public.especialidades esp
                    ON esp.id = ee.especialidad_id
                   AND esp.activo = TRUE
                 WHERE se.servicio_id = v_servicio_id
                   AND ee.especialista_id = p_especialista_id
            ))
           OR (NOT EXISTS (
                SELECT 1 FROM public.servicio_especialidades se
                 WHERE se.servicio_id = v_servicio_id
            ))
      INTO v_especialista_valido;

    IF NOT v_especialista_valido THEN
        RETURN json_build_object('aceptada', false, 'cita_id', null, 'motivo', 'NO_COINCIDE_ESPECIALIDAD');
    END IF;

    -- Claim atómico: solo cambia si sigue publicada/buscando y no expirada.
    UPDATE public.solicitudes
       SET estado     = 'ACEPTADA',
           updated_at = now()
     WHERE id = p_solicitud_id
       AND estado IN ('PUBLICADA', 'BUSCANDO_ESPECIALISTA')
       AND (fecha_expiracion IS NULL OR now() < fecha_expiracion);

    GET DIAGNOSTICS v_claim = ROW_COUNT;

    IF v_claim = 0 THEN
        RETURN json_build_object('aceptada', false, 'cita_id', null, 'motivo', 'EXPIRADA');
    END IF;

    INSERT INTO public.citas (solicitud_id, especialista_id, estado, fecha_aceptacion)
    VALUES (p_solicitud_id, p_especialista_id, 'PROGRAMADA', now())
    RETURNING id INTO v_cita_id;

    RETURN json_build_object('aceptada', true, 'cita_id', v_cita_id, 'motivo', 'OK');
END;
$$;

GRANT EXECUTE ON FUNCTION public.aceptar_solicitud(uuid, uuid) TO authenticated;

-- 7. Seeds idempotentes --------------------------------------------------------

-- 7.1 servicio_especialidades: mapeo del catálogo real (resuelve por nombre)
INSERT INTO public.servicio_especialidades (servicio_id, especialidad_id)
SELECT s.id, e.id
  FROM public.servicios s
  JOIN (
       VALUES
           ('Relleno de Labios con Ácido Hialurónico', 'Rellenos Dérmicos'),
           ('Relleno de Labios con Ácido Hialurónico', 'Medicina Estética'),
           ('Botox (Toxina Botulínica)', 'Toxina Botulínica'),
           ('Botox (Toxina Botulínica)', 'Medicina Estética'),
           ('Rejuvenecimiento con Ácido Hialurónico', 'Rellenos Dérmicos'),
           ('Rejuvenecimiento con Ácido Hialurónico', 'Medicina Estética'),
           ('Sculptra', 'Medicina Estética'),
           ('Hilos Tensores', 'Medicina Estética'),
           ('Rinomodelación con Ácido Hialurónico', 'Rellenos Dérmicos'),
           ('Rinomodelación con Ácido Hialurónico', 'Medicina Estética'),
           ('Hidrolipoclasia en Papada', 'Mesoterapia'),
           ('Hidrolipoclasia en Papada', 'Medicina Estética'),
           ('Full Face con Ácido Hialurónico', 'Rellenos Dérmicos'),
           ('Full Face con Ácido Hialurónico', 'Medicina Estética'),
           ('PDRN de Salmón (Rejuvenecimiento Regenerativo)', 'Medicina Estética'),
           ('Exosomas (Regeneración Celular Avanzada)', 'Medicina Estética'),
           ('Fibroblast (Plasma Pen)', 'Medicina Estética'),
           ('Fibroblast (Plasma Pen)', 'Dermatología Cosmética'),
           ('Desintoxicación Facial Profunda Carelika Skin Care', 'Limpieza Facial'),
           ('Desintoxicación Facial Profunda Carelika Skin Care', 'Dermatología Cosmética'),
           ('Microneedling (Inducción de Colágeno)', 'Microneedling'),
           ('Microneedling (Inducción de Colágeno)', 'Medicina Estética'),
           ('Cauterización de Lunares y Skin Tags (Acrocordones)', 'Medicina Estética'),
           ('Cavitación Corporal Ultrasónica', 'Radiofrecuencia'),
           ('Cavitación Corporal Ultrasónica', 'Medicina Estética'),
           ('Radiofrecuencia Facial y Corporal', 'Radiofrecuencia'),
           ('Ultrasonido Estético Facial y Corporal', 'Radiofrecuencia'),
           ('Ultrasonido Estético Facial y Corporal', 'Medicina Estética'),
           ('Drenaje Linfático Facial y Corporal', 'Cosmiatría'),
           ('Postoperatorio de Cirugía Plástica', 'Medicina Estética'),
           ('Postoperatorio de Cirugía Plástica', 'Cosmiatría')
  ) AS v(nombre_servicio, nombre_especialidad) ON TRUE
  JOIN public.especialidades e
    ON e.nombre = v.nombre_especialidad
   AND e.activo = TRUE
 WHERE lower(s.nombre) = lower(v.nombre_servicio)
   AND NOT EXISTS (
       SELECT 1 FROM public.servicio_especialidades se
        WHERE se.servicio_id = s.id
          AND se.especialidad_id = e.id
   );

-- 7.2 servicio_cuestionarios: "Cuestionario de Salud" obligatorio para los
--     servicios con riesgo (inyectables y faciales invasivos).
INSERT INTO public.servicio_cuestionarios (servicio_id, cuestionario_id, obligatorio, orden)
SELECT s.id, c.id, TRUE, 1
  FROM public.servicios s
  JOIN public.cuestionarios c
    ON lower(c.nombre) = 'cuestionario de salud'
   AND c.activo = TRUE
 WHERE lower(s.nombre) IN (
       'relleno de labios con ácido hialurónico',
       'botox (toxina botulínica)',
       'rejuvenecimiento con ácido hialurónico',
       'sculptra',
       'hilos tensores',
       'rinomodelación con ácido hialurónico',
       'hidrolipoclasia en papada',
       'full face con ácido hialurónico',
       'pdrn de salmón (rejuvenecimiento regenerativo)',
       'exosomas (regeneración celular avanzada)',
       'fibroblast (plasma pen)',
       'microneedling (inducción de colágeno)'
   )
   AND NOT EXISTS (
       SELECT 1 FROM public.servicio_cuestionarios sc
        WHERE sc.servicio_id = s.id
          AND sc.cuestionario_id = c.id
   );