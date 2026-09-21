-- =============================================================================
-- MIGRACIÓN: Índice sobre `dispositivos_usuario.usuario_id`.
-- -----------------------------------------------------------------------------
-- Los RPCs de notificación push (`notificar_usuario_push` en 20260821000100,
-- 20260824000100 y 20260901000300) filtran por `usuario_id` + `activo` +
-- `token_fcm IS NOT NULL` para agregar tokens. Sin índice, esa agregación
-- escanea toda la tabla por usuario. Se añade un índice B-tree (idempotente).
-- Sin cambios de RLS.
-- Aplicar con `supabase db push` o desde el SQL Editor del dashboard.
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_dispositivos_usuario_usuario_id
    ON public.dispositivos_usuario(usuario_id);