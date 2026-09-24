-- =============================================================================
-- Migración: permiso `admin.entrevistas` + cierre de deuda de seguridad.
-- -----------------------------------------------------------------------------
-- 1) Alta idempotente del permiso `admin.entrevistas` y otorgamiento explícito
--    al rol Administrador. El grant masivo de 20260901000200 usa
--    `p.codigo LIKE 'admin.%'` en un INSERT ... SELECT de una sola pasada, por
--    lo que un permiso sembrado en una migración POSTERIOR no se auto-otorga.
-- 2) Cierre del hueco: `registrar_validacion_telemedicina` es SECURITY DEFINER
--    y resuelve el paciente con auth.uid() SIN validar rol → cualquier
--    authenticated podía autodictaminarse (APROBADA + profiles.evaluation_passed).
--    El dictamen ahora se emite solo vía el RPC admin
--    `emitir_dictamen_entrevista` (Fase 2). Se revoca el EXECUTE.
-- Idempotente. Aplicar en orden ascendente.
-- =============================================================================

-- ── 1. Permiso admin.entrevistas ────────────────────────────────────────────
INSERT INTO public.permisos (codigo, nombre, modulo, descripcion)
VALUES (
    'admin.entrevistas',
    'Entrevistas médicas',
    'admin',
    'Agendar entrevistas médicas F2F, coordinar la videollamada, emitir el dictamen del examen médico total y gestionar consentimiento/grabación'
)
ON CONFLICT (codigo) DO UPDATE SET
    nombre = EXCLUDED.nombre,
    modulo = EXCLUDED.modulo,
    descripcion = EXCLUDED.descripcion;

-- Otorga el permiso al rol Administrador (super-rol) si aún no lo tiene.
INSERT INTO public.rol_permisos (rol_id, permiso_id)
SELECT r.id, p.id
  FROM public.roles r
  JOIN public.permisos p ON p.codigo = 'admin.entrevistas'
 WHERE r.name = 'Administrador'
   AND NOT EXISTS (
       SELECT 1 FROM public.rol_permisos rp
        WHERE rp.rol_id = r.id AND rp.permiso_id = p.id
   );

-- ── 2. Revocar el autodictamen por el paciente ──────────────────────────────
-- Firma vigente: registrar_validacion_telemedicina(boolean, text, text).
REVOKE EXECUTE ON FUNCTION public.registrar_validacion_telemedicina(boolean, text, text)
    FROM anon, authenticated, PUBLIC;
