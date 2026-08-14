-- =============================================================================
-- Migración: corrige FK de `especialistas.medico_regente_id`.
-- -----------------------------------------------------------------------------
-- En la BD viva la columna quedó con una FK errónea creada a mano
-- (`especialistas_medico_regente_id_fkey` -> profiles(id)), además de la
-- correcta `fk_especialistas_medico_regente` -> medicos_regentes(id) que añade
-- la migración 20260811000100. Esa FK errónea rompe el alta de especialista
-- (la app escribe el id de medicos_regentes) y el seed de pruebas.
-- Idempotente: elimina cualquier FK sobre `medico_regente_id` que apunte a
-- `profiles`.
-- =============================================================================

DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN
        SELECT c.conname
        FROM pg_constraint c
        JOIN pg_class t      ON t.oid = c.conrelid
        JOIN pg_class rt     ON rt.oid = c.confrelid
        JOIN pg_attribute a  ON a.attrelid = t.oid AND a.attnum = c.conkey[1]
        WHERE t.relname   = 'especialistas'
          AND rt.relname  = 'profiles'
          AND a.attname   = 'medico_regente_id'
          AND c.contype   = 'f'
    LOOP
        EXECUTE format('ALTER TABLE public.especialistas DROP CONSTRAINT %I', r.conname);
    END LOOP;
END $$;
