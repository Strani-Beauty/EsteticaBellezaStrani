-- =============================================================================
-- Migración temporal de diagnóstico v2 (se elimina en la corrección).
-- Lista las policies reales sobre profiles.
-- =============================================================================
DROP FUNCTION IF EXISTS public._diag_profiles();

CREATE FUNCTION public._diag_profiles()
RETURNS TABLE (
    policy_name   TEXT,
    cmd           TEXT,
    roles         TEXT,
    qual          TEXT,
    with_check    TEXT
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT p.policyname::text, p.cmd::text, array_to_string(p.roles, ', '),
           p.qual::text, p.with_check::text
    FROM pg_policies p
    WHERE p.schemaname = 'public' AND p.tablename = 'profiles'
    ORDER BY p.policyname;
END;
$$;

REVOKE ALL ON FUNCTION public._diag_profiles() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public._diag_profiles() TO anon, authenticated;
