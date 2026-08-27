# Pruebas manuales — Face Map con productos/cantidades y cierre con evidencia mínima (E2E)

| | |
|---|---|
| **Fecha** | 2026-08-26 |
| **Versión** | 1.0 |
| **Entorno** | Local `flutter run -d web-server --web-port 8080` o desplegado en web.app |
| **Plan** | `docs/plans/2026-08-26_face_map_puntos_productos_cierre.md` |
| **Proyecto Supabase** | `hhyjremkguvphmjuaazp` |

## Cuentas

| Rol | Email | Clave |
|---|---|---|
| Especialista | (usuario especialista APROBADO) | (su clave) |
| Paciente | (usuario paciente) | (su clave) |

## Prerrequisitos

- Migración `20260826000100_face_map_puntos_producto_trazabilidad.sql`
  **aplicada al remoto** por el usuario desde el SQL Editor del Dashboard
  (NO `supabase db push`). Verifica que exista el índice
  `face_map_puntos_producto_id_idx` y la FK `face_map_puntos_producto_id_fkey`.
- Un especialista APROBADO + activo, un paciente con solicitud reservada y
  depósito pagado, cita aceptada y especialista en el domicilio (LLEGO) o en
  progreso (EN_PROCESO).
- Idealmente el paciente ya guardó su Face Map pre-tratamiento (para verificar
  que el especialista lo hereda).

## Checklist de aceptación

| # | Ítem | Resultado | Evidencia / observación |
|---|---|---|---|
| 1 | Al abrir la card "Face Map / Puntos de aplicación", si el paciente tiene Face Map (por tratamiento o fallback por servicio), los puntos aparecen pre-seleccionados | ✔ PASS | Control manual 2026-08-27 (abrir Face Map; marcar puntos) |
| 2 | Tocar un punto ya marcado abre el bottom sheet con "Elegir insumo" (dropdown de `state.productos`) y "Crear insumo" (form inline que inserta en `productos_aplicados`) | ✔ PASS | Control manual 2026-08-27 (asociar producto utilizado) |
| 3 | Puntos sin producto muestran badge naranja "sin producto"; con producto/cantidad muestran badge con cantidad + unidad (ej. "15 unidades") | ✔ PASS | Control manual 2026-08-27 |
| 4 | "Quitar punto" elimina el punto y su producto asociado; al guardar, los puntos sin producto NO persisten `cantidad`/`unidad` falsas | ✔ PASS | Control manual 2026-08-27 (editar/eliminar puntos con tratamiento abierto) |
| 5 | Al guardar, `face_map_puntos.producto_id` apunta al `productos_aplicados` elegido y `cantidad`/`unidad_medida`/`observaciones` quedan en la fila del punto (trazabilidad face_maps→puntos→productos_aplicados) | ✔ PASS | Control manual 2026-08-27 (cantidades diferentes por punto) |
| 6 | La card Face Map de `cita_detalle` muestra resumen "N puntos registrados con producto y cantidad" o "N puntos · M sin producto asignado" | ✔ PASS | Control manual 2026-08-27 |
| 7 | "Revisar y finalizar" navega a la pantalla de Revisión final (puntos con producto/cantidad, productos, fotos PRE/POST, evaluación, notas) | ✔ PASS | Control manual 2026-08-27 (revisar toda la información antes de cerrar) |
| 8 | Gate de cierre: si falta firma, o no hay ≥1 foto PRE, o ≥1 foto POST, o evaluación inicial, o face map sin puntos, o algún punto sin producto/cantidad>0 → alerta y NO cierra | ✔ PASS | Control manual 2026-08-27 (impide cerrar sin info obligatoria; foto POST; PRE/POST distinguidas) |
| 9 | Con todos los requisitos y saldo pagado (Stripe), "Confirmar cierre" pasa el tratamiento a `COMPLETADO` y la cita a `FINALIZADA`, con historial | ✔ PASS | Control manual 2026-08-27 (tratamiento cerrado conserva toda su evidencia) |
| 10 | Precisión del Face Map: al marcar puntos en distintos tamaños de pantalla/rotación, las coordenadas normalizadas X/Y se guardan con 3 decimales y los puntos se re-muestran en la misma posición relativa | ✔ PASS | Control manual 2026-08-27 (posición correcta al redimensionar pantalla) |

## Comandos de verificación

```powershell
flutter analyze
flutter test
```

## Estado

- `flutter analyze`: 0 issues.
- `flutter test`: 366/366 (incluye `face_map_geometry_test.dart` y
  `face_map_canvas_test.dart` multi-tamaño 320/400/768/1024).
- Migración `20260826000100` **aplicada al remoto por el usuario** (2026-08-26).
- **Control manual 2026-08-27: 10/10 ítems PASS** (12 controles manuales: abrir Face Map,
  marcar puntos, posición correcta, cantidades por punto, producto asociado, editar/eliminar
  puntos, coords al redimensionar, foto POST, PRE/POST distinguidas, bloqueo de cierre,
  revisión antes de cerrar, tratamiento cerrado conserva evidencia).