-- =============================================================================
-- MIGRACIÓN: Dashboard interactivo de ventas (admin) — RPCs agregadores.
-- -----------------------------------------------------------------------------
-- RPCs SECURITY DEFINER con chequeo `is_administrador()` (patrón
-- `admin_resumen_kpis`). Todos filtran por período `p_desde`/`p_hasta`
-- (timestamptz) para el selector del dashboard:
--   1. dashboard_ventas_resumen            → json con KPIs financieros.
--   2. dashboard_ventas_por_servicio       → ventas agregadas por servicio.
--   3. dashboard_ventas_por_especialista   → ventas agregadas por especialista.
--   4. dashboard_ventas_serie              → serie temporal (día/semana/mes).
-- Además se crean índices que faltaban para las consultas del dashboard
-- (deuda de rendimiento detectada en la auditoría).
-- Aplicar con `supabase db push` o desde el SQL Editor del dashboard.
-- Idempotente (CREATE OR REPLACE FUNCTION / CREATE INDEX IF NOT EXISTS).
-- =============================================================================

-- ── 0. Helper de comisión (porcentaje configurado) ─────────────────────────
-- Se reutiliza `configuracion_sistema.clave='comision_porcentaje'` (default 20).

-- ── 1. Resumen financiero por período ───────────────────────────────────────
CREATE OR REPLACE FUNCTION public.dashboard_ventas_resumen(
    p_desde timestamptz,
    p_hasta timestamptz
)
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_monto_recibido     numeric;
    v_monto_pagado       numeric;
    v_comision_pct       numeric;
    v_neto_especialistas numeric;
    v_citas_realizadas   bigint;
    v_servicios_aplicados bigint;
    v_solicitudes        bigint;
    v_usuarios_activos   bigint;
BEGIN
    IF NOT public.is_administrador() THEN
        RETURN json_build_object('error', 'NO_AUTORIZADO');
    END IF;

    -- Montos efectivamente cobrados (transacciones APROBADO) en el período.
    SELECT COALESCE(sum(t.monto), 0)
      INTO v_monto_recibido
      FROM public.transacciones t
     WHERE t.estado = 'APROBADO'
       AND t.fecha_transaccion >= p_desde
       AND t.fecha_transaccion <= p_hasta;

    -- Pagos efectivamente realizados a especialistas en el período.
    SELECT COALESCE(sum(pe.monto_pagado), 0)
      INTO v_monto_pagado
      FROM public.pagos_especialistas pe
     WHERE pe.fecha_pago >= p_desde
       AND pe.fecha_pago <= p_hasta;

    -- Porcentaje de comisión configurado.
    SELECT COALESCE(
        (SELECT valor::numeric FROM public.configuracion_sistema
          WHERE clave = 'comision_porcentaje'),
        20
    ) INTO v_comision_pct;

    -- Neto para especialistas: suma del neto de citas FINALIZADA y pagadas
    -- (monto_total - comisión) en el período.
    SELECT COALESCE(sum(
               round(p.monto_total - round(p.monto_total * v_comision_pct / 100, 2), 2)
           ), 0)
      INTO v_neto_especialistas
      FROM public.citas c
      JOIN public.solicitudes s ON s.id = c.solicitud_id
      JOIN public.pagos p       ON p.solicitud_id = s.id
     WHERE c.estado = 'FINALIZADA'
       AND c.fecha_finalizacion >= p_desde
       AND c.fecha_finalizacion <= p_hasta
       AND p.estado = 'PAGADO'
       AND p.saldo_pendiente <= 0;

    -- Citas realizadas en el período.
    SELECT count(*)
      INTO v_citas_realizadas
      FROM public.citas c
     WHERE c.estado = 'FINALIZADA'
       AND c.fecha_finalizacion >= p_desde
       AND c.fecha_finalizacion <= p_hasta;

    -- Líneas de servicios aplicados (solicitud_detalles de citas FINALIZADA).
    SELECT count(*)
      INTO v_servicios_aplicados
      FROM public.citas c
      JOIN public.solicitudes s      ON s.id = c.solicitud_id
      JOIN public.solicitud_detalles sd ON sd.solicitud_id = s.id
     WHERE c.estado = 'FINALIZADA'
       AND c.fecha_finalizacion >= p_desde
       AND c.fecha_finalizacion <= p_hasta;

    -- Solicitudes creadas en el período.
    SELECT count(*)
      INTO v_solicitudes
      FROM public.solicitudes
     WHERE fecha_solicitud >= p_desde
       AND fecha_solicitud <= p_hasta;

    -- Usuarios activos.
    SELECT count(*)
      INTO v_usuarios_activos
      FROM public.profiles
     WHERE activo = TRUE;

    RETURN json_build_object(
        'montos_recibidos',      round(v_monto_recibido, 2),
        'montos_pagados',        round(v_monto_pagado, 2),
        'comision_porcentaje',   v_comision_pct,
        'neto_especialistas',    round(v_neto_especialistas, 2),
        'citas_realizadas',      v_citas_realizadas,
        'servicios_aplicados',   v_servicios_aplicados,
        'solicitudes',           v_solicitudes,
        'usuarios_activos',      v_usuarios_activos
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.dashboard_ventas_resumen(timestamptz, timestamptz)
    TO authenticated;

-- ── 2. Ventas por servicio ──────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.dashboard_ventas_por_servicio(
    p_desde timestamptz,
    p_hasta timestamptz
)
RETURNS TABLE (
    servicio_id      uuid,
    servicio_nombre  text,
    cantidad         bigint,
    monto_total      numeric,
    monto_comision   numeric
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT sv.id,
           sv.nombre,
           sum(sd.cantidad) AS cantidad,
           round(sum(sd.precio_unitario * sd.cantidad), 2) AS monto_total,
           round(sum(sd.precio_unitario * sd.cantidad) *
                 COALESCE((SELECT valor::numeric FROM public.configuracion_sistema
                            WHERE clave = 'comision_porcentaje'), 20) / 100, 2) AS monto_comision
      FROM public.solicitud_detalles sd
      JOIN public.solicitudes s  ON s.id = sd.solicitud_id
      JOIN public.citas c        ON c.solicitud_id = s.id
      JOIN public.servicios sv   ON sv.id = sd.servicio_id
     WHERE c.estado = 'FINALIZADA'
       AND c.fecha_finalizacion >= p_desde
       AND c.fecha_finalizacion <= p_hasta
       AND public.is_administrador()
     GROUP BY sv.id, sv.nombre
     ORDER BY monto_total DESC;
$$;

GRANT EXECUTE ON FUNCTION public.dashboard_ventas_por_servicio(timestamptz, timestamptz)
    TO authenticated;

-- ── 3. Ventas por especialista ──────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.dashboard_ventas_por_especialista(
    p_desde timestamptz,
    p_hasta timestamptz
)
RETURNS TABLE (
    especialista_id      uuid,
    especialista_nombre  text,
    citas                bigint,
    servicios            bigint,
    monto_total          numeric,
    monto_comision       numeric,
    monto_especialista   numeric
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT e.id,
           pf.full_name AS especialista_nombre,
           count(DISTINCT c.id) AS citas,
           count(sd.id) AS servicios,
           round(sum(p.monto_total), 2) AS monto_total,
           round(sum(p.monto_total) *
                 COALESCE((SELECT valor::numeric FROM public.configuracion_sistema
                            WHERE clave = 'comision_porcentaje'), 20) / 100, 2) AS monto_comision,
           round(sum(p.monto_total) -
                 sum(p.monto_total) *
                 COALESCE((SELECT valor::numeric FROM public.configuracion_sistema
                            WHERE clave = 'comision_porcentaje'), 20) / 100, 2) AS monto_especialista
      FROM public.citas c
      JOIN public.especialistas e  ON e.id = c.especialista_id
      JOIN public.profiles pf      ON pf.id = e.usuario_id
      JOIN public.solicitudes s    ON s.id = c.solicitud_id
      JOIN public.pagos p          ON p.solicitud_id = s.id
      JOIN public.solicitud_detalles sd ON sd.solicitud_id = s.id
     WHERE c.estado = 'FINALIZADA'
       AND c.fecha_finalizacion >= p_desde
       AND c.fecha_finalizacion <= p_hasta
       AND p.estado = 'PAGADO'
       AND p.saldo_pendiente <= 0
       AND public.is_administrador()
     GROUP BY e.id, pf.full_name
     ORDER BY monto_total DESC;
$$;

GRANT EXECUTE ON FUNCTION public.dashboard_ventas_por_especialista(timestamptz, timestamptz)
    TO authenticated;

-- ── 4. Serie temporal (día / semana / mes) ─────────────────────────────────
CREATE OR REPLACE FUNCTION public.dashboard_ventas_serie(
    p_desde timestamptz,
    p_hasta timestamptz,
    p_agrupacion text DEFAULT 'day'
)
RETURNS TABLE (
    periodo          date,
    monto_recibido   numeric,
    monto_pagado     numeric,
    citas            bigint
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    WITH recibidos AS (
        SELECT CASE p_agrupacion
                    WHEN 'week'  THEN date_trunc('week', t.fecha_transaccion)::date
                    WHEN 'month' THEN date_trunc('month', t.fecha_transaccion)::date
                    ELSE t.fecha_transaccion::date
               END AS periodo,
               sum(t.monto) AS monto
          FROM public.transacciones t
         WHERE t.estado = 'APROBADO'
           AND t.fecha_transaccion >= p_desde
           AND t.fecha_transaccion <= p_hasta
         GROUP BY 1
    ),
    pagados AS (
        SELECT CASE p_agrupacion
                    WHEN 'week'  THEN date_trunc('week', pe.fecha_pago)::date
                    WHEN 'month' THEN date_trunc('month', pe.fecha_pago)::date
                    ELSE pe.fecha_pago::date
               END AS periodo,
               sum(pe.monto_pagado) AS monto
          FROM public.pagos_especialistas pe
         WHERE pe.fecha_pago >= p_desde
           AND pe.fecha_pago <= p_hasta
         GROUP BY 1
    ),
    citas AS (
        SELECT CASE p_agrupacion
                    WHEN 'week'  THEN date_trunc('week', c.fecha_finalizacion)::date
                    WHEN 'month' THEN date_trunc('month', c.fecha_finalizacion)::date
                    ELSE c.fecha_finalizacion::date
               END AS periodo,
               count(*) AS n
          FROM public.citas c
         WHERE c.estado = 'FINALIZADA'
           AND c.fecha_finalizacion >= p_desde
           AND c.fecha_finalizacion <= p_hasta
         GROUP BY 1
    )
    SELECT COALESCE(r.periodo, pg.periodo, ci.periodo) AS periodo,
           COALESCE(r.monto, 0)   AS monto_recibido,
           COALESCE(pg.monto, 0)  AS monto_pagado,
           COALESCE(ci.n, 0)      AS citas
      FROM recibidos r
      FULL JOIN pagados pg ON pg.periodo = r.periodo
      FULL JOIN citas ci   ON ci.periodo = COALESCE(r.periodo, pg.periodo)
     WHERE public.is_administrador()
     ORDER BY 1;
$$;

GRANT EXECUTE ON FUNCTION public.dashboard_ventas_serie(timestamptz, timestamptz, text)
    TO authenticated;

-- ── 5. Índices de rendimiento para las consultas del dashboard ─────────────
CREATE INDEX IF NOT EXISTS idx_pagos_solicitud_id
    ON public.pagos(solicitud_id);

CREATE INDEX IF NOT EXISTS idx_transacciones_fecha
    ON public.transacciones(fecha_transaccion);

CREATE INDEX IF NOT EXISTS idx_transacciones_estado
    ON public.transacciones(estado);

CREATE INDEX IF NOT EXISTS idx_citas_estado_fecha_finalizacion
    ON public.citas(estado, fecha_finalizacion);

CREATE INDEX IF NOT EXISTS idx_liquidaciones_especialista_id
    ON public.liquidaciones_especialistas(especialista_id);

CREATE INDEX IF NOT EXISTS idx_liquidacion_detalles_cita_id
    ON public.liquidacion_detalles(cita_id);

CREATE INDEX IF NOT EXISTS idx_comisiones_cita_id
    ON public.comisiones(cita_id);