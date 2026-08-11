-- =============================================================================
-- Migración: Tabla `dispositivos_usuario` (tokens FCM) + RLS.
-- -----------------------------------------------------------------------------
-- Registra los dispositivos asociados a cada usuario para preparar el envío de
-- notificaciones push. La tabla ya existía en la BD real (creada fuera de las
-- migraciones del repo); esta migración la normaliza de forma idempotente y le
-- añade RLS para que cada usuario administre solo sus propios dispositivos y el
-- administrador pueda consultarlos.
-- Columnas alineadas al esquema real (schema OpenAPI / PostgREST):
--   id, usuario_id, token_fcm, plataforma, modelo_dispositivo, activo,
--   created_at, updated_at.
-- Idempotente: CREATE TABLE IF NOT EXISTS + DROP POLICY IF EXISTS + trigger.
-- =============================================================================

-- 1. Tabla (si ya existe, no toca el esquema) --------------------------------
CREATE TABLE IF NOT EXISTS public.dispositivos_usuario (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id          UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    token_fcm           TEXT NOT NULL,
    plataforma          TEXT,
    modelo_dispositivo  TEXT,
    activo              BOOLEAN DEFAULT TRUE,
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT dispositivos_usuario_token_fcm_unique UNIQUE (token_fcm)
);

ALTER TABLE public.dispositivos_usuario
    ADD COLUMN IF NOT EXISTS usuario_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE;
ALTER TABLE public.dispositivos_usuario
    ADD COLUMN IF NOT EXISTS token_fcm TEXT;
ALTER TABLE public.dispositivos_usuario
    ADD COLUMN IF NOT EXISTS plataforma TEXT;
ALTER TABLE public.dispositivos_usuario
    ADD COLUMN IF NOT EXISTS modelo_dispositivo TEXT;
ALTER TABLE public.dispositivos_usuario
    ADD COLUMN IF NOT EXISTS activo BOOLEAN DEFAULT TRUE;
ALTER TABLE public.dispositivos_usuario
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE public.dispositivos_usuario
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- 2. Trigger: mantener `updated_at` ------------------------------------------
CREATE OR REPLACE FUNCTION public.touch_dispositivo_usuario()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_touch_dispositivo_usuario ON public.dispositivos_usuario;
CREATE TRIGGER trg_touch_dispositivo_usuario
    BEFORE UPDATE ON public.dispositivos_usuario
    FOR EACH ROW EXECUTE FUNCTION public.touch_dispositivo_usuario();

-- 3. RLS: cada usuario solo sus propios dispositivos --------------------------
ALTER TABLE public.dispositivos_usuario ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "dispositivo_own_access" ON public.dispositivos_usuario;
CREATE POLICY "dispositivo_own_access"
    ON public.dispositivos_usuario
    FOR ALL TO authenticated
    USING (auth.uid() = usuario_id)
    WITH CHECK (auth.uid() = usuario_id);

-- El administrador puede consultar los dispositivos de todos los usuarios -----
DROP POLICY IF EXISTS "dispositivo_admin_select" ON public.dispositivos_usuario;
CREATE POLICY "dispositivo_admin_select"
    ON public.dispositivos_usuario
    FOR SELECT TO authenticated
    USING (public.is_administrador());