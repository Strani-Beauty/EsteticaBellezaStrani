-- =============================================================================
-- MIGRACIÓN: descripcion_corta y galería de 4 imágenes en `servicios`.
-- -----------------------------------------------------------------------------
-- La tarjeta del catálogo muestra una descripción corta que debe visualizarse
-- completa en el recuadro. Se agrega `descripcion_corta` (independiente de la
-- descripción larga del formulario) y 4 columnas de URL de imágenes adicionales
-- (`imagen_url_2`..`imagen_url_5`) junto a la principal `imagen_url`.
--
-- * RLS: las columnas nuevas quedan cubiertas por las policies existentes
--   (`catalogo_servicios_public_select` SELECT anon/authenticated y
--   `catalogo_servicios_admin_write` FOR ALL admin). No se requieren policies
--   nuevas. La subida al bucket público `imagenes-servicios` ya está protegida
--   por `servicio_imagen_admin_insert`.
-- * Backfill: los servicios existentes conservan su texto en la tarjeta
--   copiando `descripcion` → `descripcion_corta` donde esté vacía.
-- Aplicar con `supabase db push` o desde el SQL Editor del dashboard.
-- Idempotente (ADD COLUMN IF NOT EXISTS / UPDATE condicionado).
-- =============================================================================

-- ── 1. Descripción corta ─────────────────────────────────────────────────────
ALTER TABLE public.servicios
    ADD COLUMN IF NOT EXISTS descripcion_corta text;

-- ── 2. Imágenes adicionales (4 URLs públicas, junto a imagen_url) ────────────
ALTER TABLE public.servicios
    ADD COLUMN IF NOT EXISTS imagen_url_2 text;

ALTER TABLE public.servicios
    ADD COLUMN IF NOT EXISTS imagen_url_3 text;

ALTER TABLE public.servicios
    ADD COLUMN IF NOT EXISTS imagen_url_4 text;

ALTER TABLE public.servicios
    ADD COLUMN IF NOT EXISTS imagen_url_5 text;

-- ── 3. Backfill: conservar el texto visible en la tarjeta ────────────────────
UPDATE public.servicios
   SET descripcion_corta = descripcion
 WHERE descripcion_corta IS NULL
   AND descripcion IS NOT NULL;