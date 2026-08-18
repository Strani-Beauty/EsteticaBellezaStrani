-- =============================================================================
-- Migración: integridad referencial de `ubicaciones_especialista`.
-- -----------------------------------------------------------------------------
-- La tabla se creó a mano en el dashboard SIN foreign key hacia
-- `especialistas`, por lo que PostgREST no la resuelve como relación embebida
-- (`PGRST200 Could not find a relationship`) y el mapa del especialista
-- (`fetchEspecialistasAprobados`) falla.
-- Idempotente: solo crea el constraint si no existe y elimina huérfanos previos.
-- =============================================================================

-- Limpia filas huérfanas que impedirían crear la FK.
DELETE FROM public.ubicaciones_especialista ue
WHERE NOT EXISTS (
    SELECT 1 FROM public.especialistas e WHERE e.id = ue.especialista_id
);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'ubicaciones_especialista_especialista_id_fkey'
          AND conrelid = 'public.ubicaciones_especialista'::regclass
    ) THEN
        ALTER TABLE public.ubicaciones_especialista
            ADD CONSTRAINT ubicaciones_especialista_especialista_id_fkey
            FOREIGN KEY (especialista_id)
            REFERENCES public.especialistas(id)
            ON DELETE CASCADE;
    END IF;
END $$;