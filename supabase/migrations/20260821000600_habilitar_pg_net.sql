-- =============================================================================
-- Migración: habilita `pg_net` para el envío push (hook BD → edge function).
-- -----------------------------------------------------------------------------
-- `notificar_solicitud_asignada_push` usa `net.http_post` para invocar la edge
-- function `send-push` cuando una solicitud es aceptada. `pg_net` no estaba
-- habilitado; se crea (idempotente) para que el hook funcione en cualquier
-- entorno. La extension vive en el schema `extensions`.
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;
