-- -----------------------------------------------------------------------------
-- Script SQL para agregar las columnas faltantes a la tabla `profiles` en Supabase
-- -----------------------------------------------------------------------------

-- 1. Agregar columna `address` (Dirección de Habitación)
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS address TEXT;

-- 2. Agregar columnas `latitude` y `longitude` (Coordenadas)
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION;

ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;

-- 3. Agregar columna `phone` (Teléfono de contacto)
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS phone TEXT;

-- 4. Agregar columna `activo` (Estado de activación según evaluación médica Qualify)
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS activo BOOLEAN DEFAULT FALSE;

-- 5. Agregar columnas opcionales de seguimiento de pago y evaluación
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS payment_completed BOOLEAN DEFAULT FALSE;

ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS evaluation_passed BOOLEAN DEFAULT FALSE;

ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
