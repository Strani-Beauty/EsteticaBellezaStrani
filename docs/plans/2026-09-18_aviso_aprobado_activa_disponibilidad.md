# Plan — Aviso al especialista aprobado para activar disponibilidad (opciones A + D)

Fecha: 2026-09-18
Estado: APROBADO por el usuario (m1386: "aprobado commit/push"). Con commit/push.

## Objetivo

Avisar de forma visible al especialista que fue **aprobado por administración** y que
**ya puede activar su disponibilidad en el marketplace**. El aviso ya existe server-side
(trigger `trg_notificar_verificacion_aprobada` → notificación in-app `VERIFICACION_APROBADA`
+ push FCM "Tu expediente fue aprobado. Ya puedes activar tu disponibilidad y operar en el
marketplace."); el hueco es el lado cliente.

Decisiones del usuario (m1382): opciones **A + D**.

## Cambios

Archivo único: `lib/features/specialists/presentation/screens/specialist_home_screen.dart`.

### A. Banner CTA en el home
- En `_buildDashboard` (dentro de `if (especialista != null) ...[`), justo antes de la
  `DisponibilidadCard`:
  ```dart
  if (especialista.isApproved && !(state.disponibilidad?.isAvailable ?? false)) ...[
    _BannerActivarDisponibilidad(
      especialistaId: especialista.id,
      usuarioId: context.read<AuthCubit>().currentProfile?.id,
    ),
    const SizedBox(height: 16),
  ],
  ```
- Nuevo widget privado `_BannerActivarDisponibilidad` (params `especialistaId`, `usuarioId`):
  Card destacado (cBrandGreen claro) con icono `verified_rounded` + texto
  'Verificado por administración. Ya puedes activar tu disponibilidad para recibir citas
  en el marketplace' + FilledButton 'Activar disponibilidad' que llama
  `toggleDisponibilidad(especialistaId)` y `sl<PresenceService>().start(usuarioId)`
  (mismo patrón que el Switch de `disponibilidad_card.dart:46-53` con value=true).
- El banner desaparece solo cuando `disponibilidad.isAvailable` pasa a true.

### D. Pull-to-refresh también refresca la campana
- `RefreshIndicator.onRefresh`: `Future.wait([loadDashboard(usuarioId), sl<NotificationsCubit>().load(usuarioId)])`
  (hoy solo refresca loadDashboard).

### Import necesario
- `presence_service.dart` (`sl<PresenceService>`), si no está ya importado.

## Verificación

- [x] `flutter analyze` limpio.
- [x] `flutter test` (370 tests).
- [ ] Manual en `flutter run -d chrome`: `esp.aprobado@test.com` con disponibilidad OFF →
      banner visible; 'Activar disponibilidad' → switch ON + banner desaparece;
      pull-to-refresh → badge de notificaciones actualizado.

## Notas

- Sin cambios BD/RLS/triggers/cubits. Commit/push autorizado (m1386). Mensaje en español
  imperativo.