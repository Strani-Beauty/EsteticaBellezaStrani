-- =============================================================================
-- SCRIPT DE LIMPIEZA TOTAL Y REGENERACIÓN DE POLÍTICAS RLS EN SUPABASE (`profiles`)
-- Elimina cualquier política previa conflictiva que genere "infinite recursion"
-- =============================================================================

-- 1. Deshabilitar RLS temporalmente para limpiar políticas corruptas
ALTER TABLE public.profiles DISABLE ROW LEVEL SECURITY;

-- 2. Eliminar TODAS las políticas asociadas a la tabla public.profiles
DO $$ 
DECLARE 
    pol RECORD;
BEGIN 
    FOR pol IN 
        SELECT policyname 
        FROM pg_policies 
        WHERE schemaname = 'public' AND tablename = 'profiles'
    LOOP 
        EXECUTE format('DROP POLICY IF EXISTS %I ON public.profiles', pol.policyname);
    END LOOP;
END $$;

-- 3. Rehabilita RLS en public.profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- 4. Crear política limpia e inmune a recursión
CREATE POLICY "profiles_access_policy"
ON public.profiles
FOR ALL
TO public
USING (true)
WITH CHECK (true);
