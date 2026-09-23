# Plan — Advertencia modal ePHI/HIPAA al acceder al expediente de salud

Fecha: 2026-09-23
Estado: APROBADO por el usuario (m2059: "aprobado"). Sin commit.

## Objetivo

Al abrir o seleccionar la opción "Expedientes de salud" (y en cada punto de
acceso al ePHI), mostrar una **ventana modal de advertencia** de los riesgos
legales bajo las normas ePHI/HIPAA, con botones **Continuar / Declinar**.

Alcance aprobado (m2057): la advertencia aparece en **todos los accesos**:
1. Tile 'Expedientes de Salud' del panel admin.
2. Botón `folder_shared_rounded` por fila en Gestión de Pacientes.
3. Tap sobre un paciente en el listado del expediente (buscador).

## Cambios

### 1. Nuevo `lib/features/patients_compliance/presentation/widgets/advertencia_expediente_dialog.dart`
- Función `Future<bool> confirmarAccesoExpediente(BuildContext context)` que muestra
  un `AlertDialog`:
  - Título: **'Aviso de confidencialidad (ePHI/HIPAA)'** con icono `gpp_maybe_rounded`
    en `AppTheme.cGoldAccent`.
  - Texto legal: la información es Información Electrónica Protegida de Salud (ePHI)
    regulada por HIPAA; el acceso queda registrado en la auditoría del sistema; está
    prohibida su divulgación sin autorización; el uso indebido acarrea responsabilidad legal.
  - `barrierDismissible: false`.
  - Botones: `TextButton` 'Declinar' (cError) → `pop(false)`; `FilledButton` 'Continuar'
    (cDeepAccent) → `pop(true)`.
  - Retorna `true` si Continuar, `false` si Declinar.

### 2. Enlazar en los 3 puntos de acceso (patrón `if (await confirmarAccesoExpediente(context))`)
- `admin_dashboard_screen.dart` (tile 'Expedientes de Salud', l.178-185): `onTap`
  → `() async { if (await confirmarAccesoExpediente(context)) context.go(AppRoutes.adminExpedienteSalud); }`.
- `admin_pacientes_screen.dart` (botón por fila, l.133-141): ídem → push detalle con `extra: paciente`.
- `admin_expediente_salud_screen.dart` (tap ListTile paciente, l.135-138): ídem → push detalle.

## Verificación

- [x] `flutter analyze` limpio; `flutter test` (370).
- [ ] Manual: en los 3 accesos aparece el modal; 'Continuar' navega; 'Declinar' cierra sin
      navegar; la auditoría `EXPEDIENTE_SALUD_VISTO` se registra solo al Continuar (en el detalle).

## Notas

- Sin cambios en BD/RLS. El PDF/expediente no se modifica.
- Sin commit (regla del proyecto: preguntar antes).