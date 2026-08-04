-- =============================================================================
-- Migración: Configuración segura y conexión Flutter ↔ Supabase
-- (aplicar con `supabase db push` o desde el SQL Editor del dashboard)
-- =============================================================================

-- 1. Columnas de `profiles` (idempotente) ------------------------------------
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS address TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'Paciente';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS role_id BIGINT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS activo BOOLEAN DEFAULT FALSE;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS payment_completed BOOLEAN DEFAULT FALSE;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS evaluation_passed BOOLEAN DEFAULT FALSE;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS avatar_url TEXT;

-- 2. Tabla `roles`: columnas y semilla ----------------------------------------
ALTER TABLE public.roles ADD COLUMN IF NOT EXISTS code TEXT;
ALTER TABLE public.roles ADD COLUMN IF NOT EXISTS name TEXT;
ALTER TABLE public.roles ADD COLUMN IF NOT EXISTS activo BOOLEAN DEFAULT TRUE;

INSERT INTO public.roles (code, name, activo)
VALUES ('Paciente', 'Paciente', true),
       ('Especialista', 'Especialista', true),
       ('Administrador', 'Administrador', true)
ON CONFLICT DO NOTHING;

-- 3. RLS: `roles` — lectura pública ------------------------------------------
ALTER TABLE public.roles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Permitir lectura publica de roles" ON public.roles;
CREATE POLICY "Permitir lectura publica de roles"
ON public.roles FOR SELECT TO anon, authenticated USING (true);

-- 4. RLS: `profiles` — cada usuario solo su propio perfil --------------------
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Elimina TODAS las políticas previas (incluidas las abiertas USING(true))
DO $$
DECLARE pol RECORD;
BEGIN
    FOR pol IN
        SELECT policyname FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'profiles'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON public.profiles', pol.policyname);
    END LOOP;
END $$;

-- Un usuario autenticado solo lee/edita su propio perfil.
CREATE POLICY "own_profile_access"
ON public.profiles
FOR ALL TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- 5. Tabla `pacientes`: constraint única canónica en `usuario_id` ------------
ALTER TABLE public.pacientes ADD COLUMN IF NOT EXISTS usuario_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE;
ALTER TABLE public.pacientes ADD COLUMN IF NOT EXISTS activo BOOLEAN DEFAULT FALSE;
ALTER TABLE public.pacientes ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE public.pacientes ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- 6. RLS: `pacientes` — cada usuario solo su propio registro -----------------
ALTER TABLE public.pacientes ENABLE ROW LEVEL SECURITY;

DO $$
DECLARE pol RECORD;
BEGIN
    FOR pol IN
        SELECT policyname FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'pacientes'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON public.pacientes', pol.policyname);
    END LOOP;
END $$;

CREATE POLICY "own_paciente_access"
ON public.pacientes
FOR ALL TO authenticated
USING (auth.uid() = usuario_id)
WITH CHECK (auth.uid() = usuario_id);

-- 7. Trigger: crear perfil + paciente al registrarse en auth.users -----------
-- Centraliza la creación de perfil/paciente en la BD (elimina fallbacks del cliente).
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_role      TEXT;
    v_role_id   BIGINT;
BEGIN
    v_role := COALESCE(NULLIF(TRIM(new.raw_user_meta_data ->> 'role'), ''), 'Paciente');
    v_role := CASE WHEN lower(v_role) IN ('paciente', 'cliente') THEN 'Paciente'
                   WHEN lower(v_role) IN ('especialista')        THEN 'Especialista'
                   WHEN lower(v_role) IN ('administrador', 'admin') THEN 'Administrador'
                   ELSE 'Paciente'
              END;

    -- Restricción de negocio: el registro abierto NO permite Administradores.
    IF v_role = 'Administrador' THEN
        RAISE EXCEPTION 'El registro de Administradores no está habilitado. Provisiona la cuenta por el dashboard.';
    END IF;

    SELECT id INTO v_role_id FROM public.roles WHERE name = v_role LIMIT 1;

    INSERT INTO public.profiles (id, email, full_name, role, role_id, activo, payment_completed, evaluation_passed)
    VALUES (new.id,
            new.email,
            COALESCE(new.raw_user_meta_data ->> 'full_name', ''),
            v_role,
            v_role_id,
            false, false, false)
    ON CONFLICT (id) DO NOTHING;

    IF v_role = 'Paciente' THEN
        INSERT INTO public.pacientes (usuario_id, activo, created_at, updated_at)
        VALUES (new.id, false, NOW(), NOW())
        ON CONFLICT (usuario_id) DO NOTHING;
    END IF;

    RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
