-- =============================================================================
-- Migración: FKs faltantes para Datos Maestros del admin.
-- -----------------------------------------------------------------------------
-- PostgREST necesita FKs para los select embebidos. Faltaban:
--   * rol_permisos.rol_id → roles.id        (roles(...rol_permisos(...)))
--   * liquidaciones_especialistas.especialista_id → especialistas.id
--   * pagos_especialistas.especialista_id   → especialistas.id
-- Idempotente (DO $$ con chequeo en pg_constraint).
-- =============================================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'fk_rol_permisos_rol'
    ) THEN
        ALTER TABLE public.rol_permisos
            ADD CONSTRAINT fk_rol_permisos_rol
            FOREIGN KEY (rol_id) REFERENCES public.roles(id) ON DELETE CASCADE;
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'fk_liquidaciones_especialista'
    ) THEN
        ALTER TABLE public.liquidaciones_especialistas
            ADD CONSTRAINT fk_liquidaciones_especialista
            FOREIGN KEY (especialista_id) REFERENCES public.especialistas(id)
            ON DELETE CASCADE;
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'fk_pagos_especialistas_especialista'
    ) THEN
        ALTER TABLE public.pagos_especialistas
            ADD CONSTRAINT fk_pagos_especialistas_especialista
            FOREIGN KEY (especialista_id) REFERENCES public.especialistas(id)
            ON DELETE CASCADE;
    END IF;
END $$;