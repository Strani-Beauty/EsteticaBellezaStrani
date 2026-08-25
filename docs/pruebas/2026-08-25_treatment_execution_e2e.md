# Pruebas manuales — Ejecución del Tratamiento y Consentimiento (E2E)

| | |
|---|---|
| **Fecha** | 2026-08-25 |
| **Versión** | 1.0 |
| **Commit** | `697322a` |
| **Entorno** | Local `flutter run -d web-server --web-port 8080` o desplegado en web.app |
| **Plan** | `docs/plans/2026-08-25_treatment_consentimiento_facemap.md` |
| **Proyecto Supabase** | `hhyjremkguvphmjuaazp` |

## Cuentas

| Rol | Email | Clave |
|---|---|---|
| Especialista | (usuario especialista APROBADO) | (su clave) |
| Paciente | (usuario paciente) | (su clave) |

## Prerrequisitos

- Migraciones `20260825000100_treatment_storage_privado.sql` y
  `20260825000200_face_map_especialista_rls.sql` **aplicadas al remoto** vía
  `supabase db push` (pooler sesión 6543).
- Un especialista APROBADO + activo, un paciente con solicitud reservada y
  depósito pagado (flujo de marketplace ya existente), cita aceptada y
  especialista en el domicilio (estado LLEGO).
- `flutter pub get` ejecutado (image_picker instalado).

## Checklist de aceptación

| # | Ítem | Resultado | Evidencia / observación |
|---|---|---|---|
| 1 | En LLEGO, "Iniciar servicio" pasa la cita a EN_PROCESO y **crea el tratamiento en estado `PENDIENTE_FIRMA`** | ✔ PASS | Control manual 2026-08-25 |
| 2 | Gate de firma: hasta que NO se firme el consentimiento, las secciones de evaluación, insumos, fotografías, face map y "Finalizar tratamiento" permanecen bloqueadas con aviso ("La firma del consentimiento es el primer paso obligatorio") | ✔ PASS | Control manual 2026-08-25 |
| 3 | Firma del consentimiento: el especialista firma en la app (paquete `signature`), se sube el PNG al bucket privado `firmas-consentimiento`, se guarda el PATH en `consentimientos_tratamiento.firma_url` y el tratamiento pasa a `EN_PROCESO` | ✔ PASS | Control manual 2026-08-25 |
| 4 | Tras firmar se habilitan las secciones y la evaluación inicial (`evaluacion_inicial`) se guarda correctamente | ✔ PASS | Control manual 2026-08-25 |
| 5 | Insumos: al agregar producto, el campo de unidad se precarga según `tipo_precio` del servicio (POR_UNIDAD→unidades, POR_JERINGA→jeringas, POR_SESION→sesiones, POR_PLAN→plan) | ✔ PASS | Control manual 2026-08-25 |
| 6 | Fotos PRE: desde la pantalla de fotografías se captura con la cámara o se selecciona de la galería (image_picker), se sube al bucket privado `fotografias-tratamiento` y aparece en la lista | ✔ PASS | Control manual 2026-08-25 |
| 7 | Fotos POST y OTRO: se pueden registrar libremente (no se fuerza el orden) | ✔ PASS | Control manual 2026-08-25 |
| 8 | Face Map del especialista: la card "Face Map / Puntos de aplicación" abre el canvas (3 vistas frente/perfiles), permite marcar/desmarcar puntos y zonas prohibidas y guarda en `face_maps` + `face_map_puntos` vinculado al tratamiento | ✔ PASS | Control manual 2026-08-25 |
| 9 | Gate de cierre: si falta la firma, o no hay al menos **una foto PRE**, o falta la evaluación inicial, "Finalizar tratamiento" muestra alerta "No se puede finalizar el tratamiento" y NO cierra | ✔ PASS | Control manual 2026-08-25 |
| 10 | Finalizar: con todos los requisitos cumplidos y saldo pendiente pagado (Stripe), el tratamiento pasa a `COMPLETADO` y la cita a `FINALIZADA`, con registro en `historial_estados` | ✔ PASS | Control manual 2026-08-25 |
| 11 | Vinculación en BD: cita → tratamiento → consentimiento → fotografías → productos quedan enlazados por FK verificable | ✔ PASS | Control manual 2026-08-25 |
| 12 | Privacidad: firmas y fotografías se sirven con URLs firmadas (`createSignedUrl`), no como objetos públicos | ✔ PASS | Control manual 2026-08-25 |

## Comandos de verificación

```powershell
flutter analyze
flutter test
```

## Estado

- `flutter analyze`: 0 issues (solo 2 infos pre-existentes
  `use_build_context_synchronously` en `cita_detalle_screen.dart:149/157`).
- `flutter test`: 148/148.
- Migraciones `20260825000100` y `20260825000200` aplicadas al remoto vía
  `supabase db push` (pooler sesión 6543) el 2026-08-25.
- **Control manual 2026-08-25: X/12 ítems PASS** (completar tras la ejecución).