-- =============================================================================
-- MIGRACIÓN: Evaluación Médica Interna (se retira la marca Qualify/Telemedicina).
-- -----------------------------------------------------------------------------
-- A partir de ahora toda la validación médica es interna: el proveedor que se
-- registra en `validaciones_telemedicina.proveedor` es 'Medicina Interna'.
-- Esta migración normaliza los registros existentes (incluidos los de Qualify o
-- Telemedicina) para que la app muestre siempre la marca interna.
--
-- * No cambia el esquema ni las policies RLS (la columna `proveedor` ya existe).
-- * Idempotente (UPDATE condicionado).
-- Aplicar con `supabase db push` o desde el SQL Editor del dashboard.
-- =============================================================================

UPDATE public.validaciones_telemedicina
   SET proveedor = 'Medicina Interna',
       updated_at = now()
 WHERE proveedor IS NULL
    OR trim(proveedor) = ''
    OR proveedor ILIKE '%qualify%'
    OR proveedor ILIKE '%telemedicina%';
