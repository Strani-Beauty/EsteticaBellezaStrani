-- -----------------------------------------------------------------------------
-- Script SQL para Habilitar y Crear Política RLS en la Tabla `roles` de Supabase
-- Permite lectura pública para el rol `anon` y `authenticated`
-- -----------------------------------------------------------------------------

-- 1. Asegurar que Row Level Security (RLS) esté habilitado en la tabla roles
ALTER TABLE public.roles ENABLE ROW LEVEL SECURITY;

-- 2. Eliminar la política previa si existía con ese nombre para evitar conflictos
DROP POLICY IF EXISTS "Permitir lectura publica de roles" ON public.roles;

-- 3. Crear política RLS para permitir SELECT a anon y authenticated
CREATE POLICY "Permitir lectura publica de roles"
ON public.roles
FOR SELECT
TO anon, authenticated
USING (true);
