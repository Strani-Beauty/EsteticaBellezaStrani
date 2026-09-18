# Plan — Pestañas en Verificación de licencias + opción de edición

Fecha: 2026-09-18
Estado: APROBADO por el usuario (m1242: "aprobado"). Sin commit.

## Objetivo

La vista del administrador 'Verificación de Licencias'
(`admin_licencias_screen.dart`) muestra todos los especialistas en una sola
lista. Se separa en **4 pestañas** con su listado filtrado y se agrega una
**opción de edición** por especialista (licencia, médico regente, disponible,
activo, observación).

Decisiones confirmadas (m1231):
1. Mapeo de pestañas: **Nuevos**=PENDIENTE, **Pendientes**=EN_REVISION,
   **Verificados**=APROBADO, **Rechazados**=RECHAZADO+BLOQUEADO.
2. Opción de edición: botón/ícono 'Editar' por especialista que abre un diálogo
   para cambiar datos (licencia, disponible, activo, observación, etc.).
   Aprobar/Rechazar/Bloquear y documentos se conservan en la tarjeta.
3. Médicos Regentes se mantienen al final de la pestaña 'Verificados'.

## Cambios

### 1. `lib/features/specialists/presentation/cubits/specialists_cubit.dart`
Nuevo método público `editarEspecialista`:
- Firma: `Future<void> editarEspecialista({required String especialistaId,
  String? numeroLicencia, String? medicoRegenteId, bool? disponible, bool?
  activo, String? observacion, bool limpiarObservacion = false})`.
- Usa `_updateEspecialista(UpdateEspecialistaParams(id, numeroLicencia,
  medicoRegenteId, disponible, activo, observacion, limpiarObservacion))`
  (patrón de `updateVerificacion`); en fold ok emite
  `current.copyWith(especialistas: [...])` preservando `nombreUsuario`/
  `emailUsuario`; en error → `SpecialistsError`.
- El usecase `UpdateEspecialistaParams` ya soporta todos los campos.

### 2. `lib/features/admin_config/presentation/screens/admin_licencias_screen.dart`
- `_VerificacionDeLicencias`: envolver en `DefaultTabController(length: 4)` +
  `TabBar` (pestañas Nuevos/Pendientes/Verificados/Rechazados con contadores) +
  `TabBarView`. Cada pestaña filtra `especialistas` por estado y reutiliza
  `_EspecialistaCard`. Se conserva `RefreshIndicator` (recarga todas).
- **Icono 'Editar'** (edit_rounded) en el header de cada `_EspecialistaCard`
  → abre `_EditarEspecialistaDialog` (nuevo widget privado):
  - `numeroLicencia` (TextFormField), `medicoRegenteId` (Dropdown desde
    `medicosRegentes`), `disponible` (Switch — deshabilitado si el especialista
    NO está APROBADO o inactivo, por el trigger `proteger_verificacion_especialista`),
    `activo` (Switch), `observacion` (TextFormField; si el admin la vacía →
    `limpiarObservacion: true`).
  - Al guardar: `cubit.editarEspecialista(...)`.
- Las acciones Aprobar/Rechazar/Bloquear, documentos y checklist de expediente
  se conservan intactos en la tarjeta.

### Sin cambios
Data layer (datasource/repository/usecase), RLS, triggers.

## Verificación

- [x] `flutter analyze` limpio.
- [x] `flutter test` (366 tests).
- [ ] Manual en `flutter run -d chrome`: admin → Verificación de Licencias →
      4 pestañas con contadores y listados filtrados; editar licencia/médico
      regente/disponible/activo/observación; disponibles deshabilitados si no
      está aprobado.

## Notas

- Sin commit (regla del proyecto: preguntar antes).