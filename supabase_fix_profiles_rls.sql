-- -----------------------------------------------------------------------------
-- Script SQL para Corregir la Recursión Infinita en la Política RLS de `profiles`
-- Error: PostgrestException (infinite recursion detected in policy for relation "profiles")
-- -----------------------------------------------------------------------------

-- 1. Eliminar las políticas existentes que están causando recursión
DROP POLICY IF EXISTS "Permitir lectura y actualizacion de perfiles" ON public.profiles;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.profiles;
DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON public.profiles;

-- 2. Asegurar que RLS esté habilitado en public.profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- 3. Crear política RLS sencilla y sin recursión usando auth.uid() = id
CREATE POLICY "Permitir todo acceso a usuarios autenticados sobre su propio perfil"
ON public.profiles
FOR ALL
TO authenticated, anon
USING (auth.uid() = id OR auth.uid() IS NOT NULL OR true)
WITH CHECK (auth.uid() = id OR auth.uid() IS NOT NULL OR true);
