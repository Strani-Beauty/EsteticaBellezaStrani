-- =============================================================================
-- MIGRACIÓN: Simulación de llegada del especialista (pruebas).
-- -----------------------------------------------------------------------------
-- Permite al especialista "llegar al domicilio" usando las coordenadas del
-- domicilio del paciente (ya cargadas en la cita) en lugar del GPS real,
-- para pruebas con datos de otro país (p.ej. en Venezuela con citas en USA).
-- Clave `simular_llegada` en `configuracion_sistema` (BOOLEAN). En producción
-- debe quedar en 'false' para exigir GPS real.
-- Idempotente: ON CONFLICT (clave) DO UPDATE.
-- =============================================================================

INSERT INTO public.configuracion_sistema
    (id, clave, valor, tipo_dato, descripcion, activo, updated_at)
VALUES
    (gen_random_uuid(), 'simular_llegada', 'true', 'BOOLEAN',
     'Simula la llegada del especialista usando las coordenadas del domicilio (pruebas)', true, now())
ON CONFLICT (clave) DO UPDATE
    SET valor = EXCLUDED.valor,
        descripcion = EXCLUDED.descripcion,
        tipo_dato = EXCLUDED.tipo_dato,
        updated_at = now();