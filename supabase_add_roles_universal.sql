-- -----------------------------------------------------------------------------
-- Script SQL universal e inofensivo para asegurar las columnas e insertar los roles
-- -----------------------------------------------------------------------------

-- 1. Agregar la columna `code` si no existía para evitar errores
ALTER TABLE public.roles ADD COLUMN IF NOT EXISTS code TEXT;
ALTER TABLE public.roles ADD COLUMN IF NOT EXISTS name TEXT;
ALTER TABLE public.roles ADD COLUMN IF NOT EXISTS activo BOOLEAN DEFAULT TRUE;

-- 2. Insertar los roles Paciente, Administrador y Especialista
INSERT INTO public.roles (code, name, activo)
VALUES 
  ('Paciente', 'Paciente', true),
  ('Administrador', 'Administrador', true),
  ('Especialista', 'Especialista', true)
ON CONFLICT DO NOTHING;
