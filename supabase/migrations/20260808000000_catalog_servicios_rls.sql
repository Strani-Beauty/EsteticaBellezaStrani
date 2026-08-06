-- =============================================================================
-- Migración: RLS lectura pública del catálogo (servicios y categorías)
-- Aplicar con `supabase db push` o desde el SQL Editor del dashboard.
-- -----------------------------------------------------------------------------
-- El catálogo es público (solo nombres/descripciones/precios). El RLS estaba
-- habilitado en estas tablas SIN ninguna política de SELECT, por lo que la app
-- (anon/authenticated) leía 0 filas aunque los datos existieran. Se replica el
-- patrón de `public.roles` ("Permitir lectura publica de roles").
-- Idempotente.
-- =============================================================================

-- 1. Tabla `servicios` --------------------------------------------------------
ALTER TABLE public.servicios ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "catalogo_servicios_public_select" ON public.servicios;
CREATE POLICY "catalogo_servicios_public_select"
ON public.servicios FOR SELECT TO anon, authenticated USING (true);

-- 2. Tabla `categorias_servicio` ----------------------------------------------
ALTER TABLE public.categorias_servicio ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "catalogo_categorias_public_select" ON public.categorias_servicio;
CREATE POLICY "catalogo_categorias_public_select"
ON public.categorias_servicio FOR SELECT TO anon, authenticated USING (true);

-- 3. Grants de lectura (cubren también el join embebido en servicios) ----------
GRANT SELECT ON public.servicios TO anon, authenticated;
GRANT SELECT ON public.categorias_servicio TO anon, authenticated;