# Plan: Verificación E2E del compliance del especialista (12 ítems)

| | |
|---|---|
| **Fecha** | 2026-08-18 |
| **Estado** | APROBADO por el usuario (2026-08-18) |
| **Origen** | Checklist de aceptación del compliance del especialista (12 ítems) |
| **Proyecto Supabase** | `hhyjremkguvphmjuaazp` |

## Decisiones (confirmadas por el usuario)

- **Especialista nuevo**: se **registra una cuenta nueva en la app** (SignUp como Especialista) para probar el flujo desde cero.
- **Resultados**: se anotan en `docs/pruebas/2026-08-18_compliance_e2e.md` (checklist ítem por ítem con ✅/❌/observación).
- **Contra-pruebas SQL**: sí, **solo consultas** (SELECT + UPDATE controlados) en el SQL Editor de Supabase, para validar triggers/RLS.

## Entorno

- La app se corre **localmente** (`flutter run -d chrome`): lo desplegado en https://esteticaybellezastrani.web.app NO tiene los cambios de hoy (`8e51419`).
- BD remota compartida.
- Cuentas: `admin@strani.com` / `Test1234!`, `especialista1@test.com` / `Test1234!` (aprobado) + cuenta nueva registrada en la app.
- Precondición: ≥1 médico regente ACTIVO en BD.

## Ítems a verificar

1. El especialista puede cargar sus documentos.
2. Los archivos quedan almacenados de forma privada.
3. Cada documento tiene su propio estado.
4. El administrador puede revisar cada documento.
5. El administrador puede aprobarlo o rechazarlo.
6. Al rechazarlo puede indicar el motivo.
7. El especialista recibe la notificación correspondiente.
8. Puede reemplazar únicamente el documento rechazado.
9. Los documentos aprobados permanecen aprobados.
10. El especialista no puede acceder al Marketplace mientras tenga requisitos pendientes.
11. Una vez aprobado y con el contrato correspondiente, puede pasar a estado Verificado.
12. Un especialista verificado puede activar su disponibilidad para comenzar a recibir solicitudes.

## Fases

- **A (ítems 1-3)**: onboarding de la cuenta nueva → subir IDENTIFICACION, LICENCIA y formación (DIPLOMA o CERTIFICACION) → tiles con estado individual → bucket `documentos-especialistas` privado.
- **B (ítems 4-6)**: admin → `/admin` → aprobar IDENTIFICACION, rechazar LICENCIA con motivo.
- **C (ítem 7)**: especialista ve la notificación de rechazo (campanita con badge + motivo + versión); marcar leída. ✅ Verificado en app: badge `1` en la campana, pantalla Notificaciones con "Documento rechazado" y motivo, al leerla la campana se actualiza. Fixes UX aplicados: botón "Reintentar" con ancho adaptable (ya no se corta), motivo del rechazo en caja resaltada en el tile, campanita agregada al AppBar de la pantalla de Documentos.
- **D (ítems 8-9)**: IDENTIFICACION queda "Aprobado" (no re-subible); LICENCIA "Rechazado" con "Reintentar" → re-subida con `version_documento=2`; aprobados permanecen.
- **E (ítem 10)**: con requisitos pendientes, sin tarjeta mapa/citas en el home, toggle de disponibilidad bloqueado, ruta del mapa → "Acceso restringido".
- **F (ítem 11)**: ✅ aprobar LICENCIA, firmar contrato, checklist del expediente en verde → admin aprueba → **Verificado**. Contra-prueba SQL: trigger bloquea APROBADO con expediente incompleto (negativa con julio12; positiva con expediente completo). Bug fijo: `contratos.version_contrato` (string→int, migración `20260818000100`).
- **G (ítem 12)**: ✅ toggle habilitado → activar → `especialistas.disponible=true` + fila en `disponibilidad_especialista` → tarjeta mapa/citas aparece → mapa carga solicitudes → aceptó solicitud de María González → cita PROGRAMADA. Bug fijo: FK `ubicaciones_especialista` (migración `20260818000200`) + select con hint de FK y ordenado en cliente.

## Hallazgo esperado a confirmar

- `tiposSubiblesDocumentos` (`documentos_requeridos.dart`) excluye solo los tipos APROBADOS: el diálogo "Subir" del home podría ofrecer tipos PENDIENTE que el trigger de BD bloquea (error en snackbar). Confirmar en ítem 8 y, si aplica, corregir el helper (excluir también PENDIENTE).

## Cierre

- Registrar resultados en `docs/pruebas/2026-08-18_compliance_e2e.md`.
- Si hay hallazgos: proponer fix, aplicar y re-verificar.
- Commit del doc de pruebas (preguntar antes de commitear).
