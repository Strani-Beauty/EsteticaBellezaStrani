-- =============================================================================
-- Migración: RPC `registrar_medico_regente` para alta de regentes por especialista.
-- -----------------------------------------------------------------------------
--   * El endurecimiento 20260907 restringió el SELECT de `medicos_regentes` a
--     solo administradores (policy `medicos_regentes_admin_select`), pero la
--     policy de INSERT sigue permitiendo al especialista crear regentes en
--     estado PENDIENTE/activo=false (WITH CHECK).
--   * El app hacía `insert(...).select()` (RETURNING): PostgREST exige una
--     policy SELECT sobre la fila insertada → el especialista recibía 42501
--     "new row violates row-level security policy".
--   * Solución: función SECURITY DEFINER que inserta y devuelve SOLO los campos
--     públicos (id, nombre, numero_licencia, estado, activo, fechas) sin
--     teléfono/correo, manteniendo el diseño de contacto admin-only.
-- Idempotente (CREATE OR REPLACE / REVOKE no-op). Aplicar con `supabase db push`.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.registrar_medico_regente(
    p_nombre TEXT,
    p_numero_licencia TEXT DEFAULT NULL,
    p_telefono TEXT DEFAULT NULL,
    p_correo TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_id UUID;
    v_created_at TIMESTAMPTZ := now();
BEGIN
    -- Insert con estado/activo fijos; el alta queda pendiente de validación
    -- por un administrador antes de poder asociarlo a un especialista.
    INSERT INTO public.medicos_regentes (
        nombre,
        numero_licencia,
        telefono,
        correo,
        estado,
        activo,
        created_at,
        updated_at
    ) VALUES (
        p_nombre,
        p_numero_licencia,
        p_telefono,
        p_correo,
        'PENDIENTE',
        FALSE,
        v_created_at,
        v_created_at
    )
    RETURNING id INTO v_id;

    RETURN jsonb_build_object(
        'id', v_id,
        'nombre', p_nombre,
        'numero_licencia', p_numero_licencia,
        'estado', 'PENDIENTE',
        'activo', FALSE,
        'created_at', v_created_at,
        'updated_at', v_created_at
    );
END;
$$;

-- Solo los clientes autenticados (especialistas y administradores) pueden invocarla.
REVOKE EXECUTE ON FUNCTION public.registrar_medico_regente(TEXT, TEXT, TEXT, TEXT)
    FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.registrar_medico_regente(TEXT, TEXT, TEXT, TEXT)
    TO authenticated;