-- -----------------------------------------------------------------------------
-- Script SQL para insertar los roles Paciente, Administrador y Especialista
-- adaptado a la estructura estándar de la tabla `roles` (usando `id` y `name`)
-- -----------------------------------------------------------------------------

-- Opción A: Si la tabla roles usa la columna `id` (texto/uuid) o `name` / `nombre`

-- 1. Si usa la columna `id` y `name`:
INSERT INTO public.roles (id, name, activo)
VALUES 
  ('Paciente', 'Paciente', true),
  ('Administrador', 'Administrador', true),
  ('Especialista', 'Especialista', true)
ON CONFLICT DO NOTHING;

-- Opción B: Si la tabla roles utiliza `nombre` en lugar de `name`:
-- INSERT INTO public.roles (id, nombre, activo)
-- VALUES 
--   ('Paciente', 'Paciente', true),
--   ('Administrador', 'Administrador', true),
--   ('Especialista', 'Especialista', true)
-- ON CONFLICT DO NOTHING;
