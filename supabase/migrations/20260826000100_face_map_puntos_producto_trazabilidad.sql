-- =============================================================================
-- MIGRACIÓN: Trazabilidad face_map_puntos → productos_aplicados (Act. 4/5/8).
-- -----------------------------------------------------------------------------
-- Cada punto del Face Map del especialista se asocia al producto aplicado
-- (`producto_id`), con su cantidad y unidad. `producto_id` ya existe como
-- columna nullable en `face_map_puntos` pero nunca se escribía y no tiene
-- constraint ni índice. Esta migración:
--   * agrega la FK hacia `productos_aplicados(id)` con ON DELETE SET NULL
--     (eliminar un insumo no bloquea ni borra los puntos que lo referencian)
--   * crea el índice para acelerar la trazabilidad y los joins de revisión
-- Idempotente (DO $$ + information_schema / CREATE INDEX IF NOT EXISTS).
-- Aplicar desde el SQL Editor del Dashboard (o `supabase db push`).
-- =============================================================================

-- ── 1. FK face_map_puntos.producto_id → productos_aplicados(id) ─────────────
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu
          ON kcu.constraint_name = tc.constraint_name
         AND kcu.table_schema = tc.table_schema
        WHERE tc.constraint_type = 'FOREIGN KEY'
          AND tc.table_schema = 'public'
          AND tc.table_name = 'face_map_puntos'
          AND kcu.column_name = 'producto_id'
    ) THEN
        ALTER TABLE public.face_map_puntos
            ADD CONSTRAINT face_map_puntos_producto_id_fkey
            FOREIGN KEY (producto_id)
            REFERENCES public.productos_aplicados (id)
            ON DELETE SET NULL;
    END IF;
END $$;

-- ── 2. Índice para trazabilidad y joins ─────────────────────────────────────
CREATE INDEX IF NOT EXISTS face_map_puntos_producto_id_idx
    ON public.face_map_puntos (producto_id);