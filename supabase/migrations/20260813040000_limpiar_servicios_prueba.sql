-- =============================================================================
-- Migración: oculta servicios y categorías de prueba (seed viejo).
-- -----------------------------------------------------------------------------
-- Los servicios/categorías de prueba del seed anterior están referenciados por
-- solicitudes y citas de prueba (FK), por lo que se desactivan en vez de borrar
-- para no romper la integridad referencial. El catálogo ya filtra `activo=true`,
-- así que quedan fuera de la UI. Idempotente (UPDATE de un booleano).
-- =============================================================================

-- 1. Servicios de prueba → inactivos -------------------------------------------
UPDATE public.servicios
SET activo = false
WHERE lower(nombre) IN (
    lower('Ácido Hialurónico'),
    lower('Bioestimulador de Colágeno'),
    lower('Depilación Láser'),
    lower('Drenaje Linfático Manual'),
    lower('Estética y Belleza General'),
    lower('Lipólisis Alta Frecuencia'),
    lower('Lipólisis de Alta Frecuencia'),
    lower('Masaje Relajante Aromaterapia'),
    lower('Masaje Terapéutico Profundo'),
    lower('Microneedling'),
    lower('Peelings Médicos'),
    lower('Relleno con Ácido Hialurónico'),
    lower('Toxina Botulínica'),
    lower('Toxina Botulínica (Bótox)')
);

-- 2. Categorías de prueba → inactivas ------------------------------------------
UPDATE public.categorias_servicio
SET activo = false
WHERE lower(nombre) IN (
    lower('Neuromoduladores'),
    lower('Rellenos Dérmicos'),
    lower('Medicina Estética'),
    lower('Terapias IV'),
    lower('Control de Peso'),
    lower('Estética Facial'),
    lower('Estética Corporal'),
    lower('Bienestar')
);
