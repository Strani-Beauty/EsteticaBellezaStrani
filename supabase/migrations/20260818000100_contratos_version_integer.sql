-- =============================================================================
-- Migración: normaliza `contratos.version_contrato` a INTEGER.
-- -----------------------------------------------------------------------------
-- La columna nació como texto/varchar, pero toda la app (y el dominio) la
-- trata como número entero (`ContratoModel.versionContrato`, payload de
-- `firmarContrato`, versión mostrada en la UI). PostgREST devuelve strings,
-- lo que rompía el parseo del modelo al firmar el primer contrato.
-- Idempotente: solo altera si la columna sigue siendo de tipo texto.
-- =============================================================================

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
          FROM information_schema.columns
         WHERE table_schema = 'public'
           AND table_name = 'contratos'
           AND column_name = 'version_contrato'
           AND data_type IN ('text', 'character varying', 'character')
    ) THEN
        ALTER TABLE public.contratos
            ALTER COLUMN version_contrato TYPE integer
            USING CASE
                WHEN version_contrato ~ '^[0-9]+$' THEN version_contrato::integer
                ELSE 1
            END;
    END IF;
END $$;
