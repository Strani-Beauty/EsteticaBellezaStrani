-- -----------------------------------------------------------------------------
-- Script SQL para insertar / actualizar los roles: Paciente y Administrador en `roles`
-- -----------------------------------------------------------------------------

-- 1. Insertar el rol "Paciente" si no existe
INSERT INTO public.roles (code, name, activo)
VALUES ('Paciente', 'Paciente', true)
ON CONFLICT (code) DO UPDATE 
SET name = 'Paciente', activo = true;

-- 2. Insertar el rol "Administrador" si no existe
INSERT INTO public.roles (code, name, activo)
VALUES ('Administrador', 'Administrador', true)
ON CONFLICT (code) DO UPDATE 
SET name = 'Administrador', activo = true;

-- 3. Insertar el rol "Especialista" si tampoco estuviese creado
INSERT INTO public.roles (code, name, activo)
VALUES ('Especialista', 'Especialista', true)
ON CONFLICT (code) DO UPDATE 
SET name = 'Especialista', activo = true;
