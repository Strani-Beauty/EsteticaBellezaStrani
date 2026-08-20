-- =============================================================================
-- Limpieza del diagnóstico temporal (patrón: _diag_profiles → se elimina al
-- resolver el hallazgo). La función `_diag_solicitud_triggers` se usó para
-- inspeccionar los triggers sobre `solicitudes`/`historial_estados` y confirmar
-- el trigger huérfano `tr_log_solicitud_estado` (resuelto en
-- 20260820000200_remove_tr_log_solicitud_estado.sql). Se elimina para no dejar
-- superficie RPC expuesta a anon/authenticated.
-- =============================================================================
DROP FUNCTION IF EXISTS public._diag_solicitud_triggers();