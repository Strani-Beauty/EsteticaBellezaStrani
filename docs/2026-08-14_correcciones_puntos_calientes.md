# Correcciones de puntos calientes detectados en pruebas

- **Fecha**: 2026-08-14
- **Contexto**: los puntos calientes fueron identificados durante la elaboración de los planes de pruebas manuales (`docs/Pruebas manuales/`) mediante revisión de código. Este documento registra las correcciones aplicadas y el estado de los que quedan pendientes.

## Resumen

| Hotspot | Área | Estado |
|---|---|---|
| 1. Navegación rota al detalle de cita | treatment_execution | ✅ RESUELTO |
| 2. Ruta de fotografías inalcanzable | treatment_photos | ✅ RESUELTO |
| 3. Logout fantasma en ProfileScreen | auth_users | ✅ RESUELTO |
| 4. `_VerificationCard`: licencia perdida + onCreate('') | specialists | ✅ RESUELTO |
| 5. `solicitarVerificacion` sin await antes de go(home) | specialists | ⏳ Pendiente |
| 6. Qualify marca `payment_completed=true` sin pago | patients_compliance | ⏳ Pendiente |
| 7. Depósito-only deja solicitud en BORRADOR | payments_stripe | ⏳ Pendiente (decisión de negocio) |
| 8. `registerInitialPayment` no activa `profiles.activo` | payments_stripe | ⏳ Pendiente (decisión de diseño) |
| 9. `avanzar` traga errores (fold descarta failure) | treatment_execution | ⏳ Pendiente |
| 10. Eliminar foto no borra el archivo del bucket | treatment_photos | ⏳ Pendiente |
| 11. Deep-links con sesión de rol equivocado | auth / guards | ⏳ Pendiente (verificar) |
| 12. Desactivación remota fuerza logout | admin_users / guards | ⏳ Pendiente (verificar) |
| 13. PaymentSheet cancelado → flujo abortado | payments_stripe | ⏳ Pendiente (verificar) |
| 14. `version_documento` nunca incrementa | specialists | ⏳ Pendiente |
| 15. Concurrencia en `aceptar_solicitud` + fold | marketplace_citas | ⏳ Pendiente (verificado parcialmente) |

---

## ✅ Resueltos

### 1. Navegación rota al detalle de cita (Crítica)

**Bug**: `mis_citas_screen.dart` hacía `context.push(AppRoutes.misCitasDetalle, extra: cita.id)`. Como `AppRoutes.misCitasDetalle = '/specialist/mis-citas/:id'`, GoRouter consumía el segmento `:id` como placeholder al matchear la location literal → `pathParameters['id'] == ':id'` → `CitaDetalleScreen` llamaba `loadDetalle(citaId: ':id')` → "Cita :id no encontrada".

**Fix**:
- `lib/app/config/app_routes.dart`: nuevo helper `AppRoutes.misCitasDetalleDe(String citaId)`.
- `lib/features/treatment_execution/presentation/screens/mis_citas_screen.dart`: navega con `context.push(AppRoutes.misCitasDetalleDe(cita.id))`.

**Docs actualizados**: `09_treatment_execution.md` (TE-S-01), `11_flujos_integrados_e2e.md` (paso 1 de E2E-C).

### 2. Ruta de fotografías inalcanzable (Crítica)

**Bug**: la ruta `/tratamiento/:id/fotos` existía pero ningún código navegaba a ella (módulo funcional pero inaccesible).

**Fix**:
- `lib/app/config/app_routes.dart`: nuevo helper `AppRoutes.fotografiasTratamientoDe(String tratamientoId)`.
- `lib/features/treatment_execution/presentation/screens/cita_detalle_screen.dart`: tarjeta "Fotografías del tratamiento" en estado EN_PROCESO (donde existe el tratamiento) que navega a la ruta con el id real.

**Docs actualizados**: `10_treatment_photos.md` (TF-S-01 + encabezado/precondiciones), `11_flujos_integrados_e2e.md` (paso 12 de E2E-C), `00_indice_general.md`.

### 3. Logout fantasma en ProfileScreen (Crítica)

**Bug**: el botón de logout en modo no-edición solo mostraba el snackbar "La sesión se cerró." sin ejecutar `signOut`; la sesión seguía activa.

**Fix**:
- `lib/features/auth_users/presentation/screens/profile_screen.dart`: el onPressed ahora ejecuta `context.read<AuthCubit>().signOut()`. El `BlocListener` existente ya navegaba a `/login` al emitirse `AuthUnauthenticated`.

**Docs actualizados**: `01_auth_users.md` (AU-S-01).

### 4. `_VerificationCard`: licencia perdida + onCreate('') (Alta)

**Bug**: `_VerificationCard` (especialista sin perfil) creaba `TextEditingController()` inline en cada build (el texto se perdía en rebuilds) y el botón "Solicitar verificación" llamaba `onCreate('')` ignorando la licencia tecleada.

**Fix**:
- `lib/features/specialists/presentation/screens/specialist_home_screen.dart`: `_VerificationCard` convertido a `StatefulWidget` con controller persistente; el botón y `onSubmitted` usan `_enviar()` que envía la licencia tecleada y valida no-vacío (snackbar si está vacía). `_pedirVerificacion` usa `widget.especialista`.

**Docs actualizados**: `02_specialists.md` (SP-S-01, SP-S-02).

---

## ⏳ Pendientes

### 5. `solicitarVerificacion` sin await (Alta)
`specialist_documents_screen.dart::_continuar()` llama `cubit.solicitarVerificacion(...)` y acto seguido `context.go(home)` sin `await`; el home puede cargar el estado viejo (PENDIENTE en vez de EN_REVISION). Fix candidato: `await cubit.solicitarVerificacion(...)` antes de navegar (o recargar dashboard al volver).

### 6. Qualify marca `payment_completed=true` sin pago (Crítica — negocio)
`saveQualifyTestValidation(aprobado: true)` fija `profiles.activo/evaluation_passed/payment_completed = true` aunque el paciente haya pospuesto el pago de $30. Fix candidato: pasar el flag de pago real y solo marcar `payment_completed=true` si efectivamente pagó.

### 7. Depósito-only deja solicitud en BORRADOR (Alta — decisión de negocio)
`createServicePayment` con solo depósito crea solicitud `BORRADOR` (invisible en marketplace); no hay flujo claro para pagar el resto y publicarla. Requiere decisión de producto: ¿publicar igualmente, o añadir flujo "pagar saldo para publicar"?

### 8. `registerInitialPayment` no activa `profiles.activo` (Alta — decisión de diseño)
`registerInitialPayment` solo fija `payment_completed=true` + `pacientes.activo=true`; la activación del perfil depende de `saveQualifyTestValidation`. Verificar el guard entre pago y cuestionario (el paciente desactivado queda restringido a rutas permitidas).

### 9. `avanzar` traga errores (Alta)
`treatment_execution_cubit.dart::avanzar()` usa `fold((f) => emit(current.copyWith(trabajando: false)), ...)` descartando la failure sin feedback. Fix candidato: emitir error con mensaje o campo `feedback` como en MarketplaceCubit.

### 10. Eliminar foto no borra el archivo del bucket (Alta)
`eliminarFotografia(id)` se llama sin `pathEnStorage` desde la UI; el objeto en Storage queda huérfano. La entidad/model no exponen el path. Fix candidato: guardar `pathEnStorage` en la fila (columna nueva o derivar del `archivo_url`) y pasarlo al eliminar.

### 11. Deep-links con sesión de rol equivocado (verificar)
Los guards por rol redirigen, pero conviene probar cada combinación (paciente → `/admin`, `/specialist`, etc.). Cubierto por los casos AU-G-01..06.

### 12. Desactivación remota fuerza logout (verificar)
Guard `onDeactivated` fuerza `signOut` para especialistas/admins desactivados. Cubierto por AU-G-08/09 y AUU-E-01.

### 13. PaymentSheet cancelado → flujo abortado (verificar)
Cada consumidor de `procesarPagoStripe` debe abortar sin registros al devolver `null`. Cubierto por PS-V-01/PS-S-02.

### 14. `version_documento` nunca incrementa (Media)
Al re-subir un documento el `version_documento` queda en 1 siempre; se pierde trazabilidad de versiones. Fix candidato: calcular `max(version)+1` en el datasource.

### 15. Concurrencia en `aceptar_solicitud` + fold (verificar)
El fold de `aceptar` en `MarketplaceCubit` ya maneja la failure (emite `MarketplaceError`); el fold de `_refrescar` ignora errores (aceptable como refresh best-effort). La concurrencia "primer aviso gana" la decide el RPC del servidor. Pendiente de prueba real (MK-S-01).

---

## Verificación

Todos los fixes pasan:
- `flutter analyze` → sin issues.
- `flutter test` → 80/80 OK (los tests existentes son placeholders/widget tests).

Sin cambios de esquema de BD en esta tanda (los fixes 1-4 son solo Dart).
