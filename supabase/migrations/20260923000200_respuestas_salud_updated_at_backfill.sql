-- =============================================================================
-- MIGRACIÓN: `updated_at` en respuestas_salud + backfill de pregunta_texto.
-- -----------------------------------------------------------------------------
-- 1. Añade `updated_at` a `respuestas_salud` (retención ePHI/HIPAA de 7 años;
--    la última modificación permite auditar el ciclo de vida del expediente).
-- 2. Backfill idempotente de `pregunta_texto` desde el catálogo `preguntas`
--    para respuestas legacy guardadas sin el snapshot (ruta legacy
--    `saveHealthEvaluation` insertaba sin pregunta_texto).
-- Aplicar con `supabase db push` o desde el SQL Editor del dashboard.
-- Idempotente (ADD COLUMN IF NOT EXISTS / UPDATE condicionado).
-- =============================================================================

-- ── 1. updated_at ────────────────────────────────────────────────────────────
ALTER TABLE public.respuestas_salud
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ;

-- Recurso previo: las filas existentes quedan con updated_at = created_at.
UPDATE public.respuestas_salud
   SET updated_at = created_at
 WHERE updated_at IS NULL;

-- Mantener updated_at en cada UPDATE (patrón touch_* del proyecto).
CREATE OR REPLACE FUNCTION public.touch_respuesta_salud()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_touch_respuesta_salud ON public.respuestas_salud;
CREATE TRIGGER trg_touch_respuesta_salud
    BEFORE UPDATE ON public.respuestas_salud
    FOR EACH ROW EXECUTE FUNCTION public.touch_respuesta_salud();

-- ── 2. Backfill pregunta_texto desde preguntas ───────────────────────────────
UPDATE public.respuestas_salud rs
   SET pregunta_texto = p.pregunta
  FROM public.preguntas p
 WHERE rs.pregunta_id = p.id
   AND (rs.pregunta_texto IS NULL OR btrim(rs.pregunta_texto) = '');