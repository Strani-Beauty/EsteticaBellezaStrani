-- =============================================================================
-- Migración temporal de diagnóstico (se elimina al resolver el bloqueo).
-- Lista los triggers sobre `solicitudes` y `historial_estados`, su función
-- (definición completa) y las policies de RLS de `historial_estados`.
-- =============================================================================
CREATE OR REPLACE FUNCTION public._diag_solicitud_triggers()
RETURNS TABLE (
    trigger_name  TEXT,
    table_name    TEXT,
    timing        TEXT,
    event         TEXT,
    function_name TEXT,
    function_def  TEXT
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT t.tgname::text,
           t.tgrelid::regclass::text,
           t.tgtype::int::bit(6)::text,
           e.event::text,
           p.proname::text,
           pg_get_functiondef(p.oid)
    FROM pg_trigger t
    JOIN pg_proc p ON p.oid = t.tgfoid
    CROSS JOIN LATERAL (
        SELECT 'INSERT' AS event WHERE t.tgtype & 4 = 4
        UNION ALL
        SELECT 'UPDATE' WHERE t.tgtype & 2 = 2
        UNION ALL
        SELECT 'DELETE' WHERE t.tgtype & 8 = 8
    ) e
    WHERE t.tgrelid IN ('public.solicitudes'::regclass, 'public.historial_estados'::regclass)
      AND NOT t.tgisinternal
    ORDER BY t.tgrelid::regclass::text, t.tgname;
END;
$$;

REVOKE ALL ON FUNCTION public._diag_solicitud_triggers() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public._diag_solicitud_triggers() TO anon, authenticated;