-- =============================================================================
-- MIGRACIÓN: Adelanto porcentual configurable para el pago de servicios.
-- -----------------------------------------------------------------------------
-- Al seleccionar un servicio del catálogo el paciente puede pagar un adelanto
-- del total (porcentaje configurable) o el servicio completo. Se agrega la clave
-- `adelanto_porcentaje` a configuracion_sistema (default 50%). La cuota inicial
-- de $30 (`deposito_reserva`, telemedicina/medicina interna) NO se modifica.
-- Idempotente: ON CONFLICT (clave).
-- =============================================================================

INSERT INTO public.configuracion_sistema
    (id, clave, valor, tipo_dato, descripcion, activo, updated_at)
VALUES
    (gen_random_uuid(), 'adelanto_porcentaje', '50', 'NUMERIC',
     'Porcentaje de adelanto del total del servicio (%)', true, now())
ON CONFLICT (clave) DO UPDATE
    SET valor = EXCLUDED.valor,
        updated_at = now();