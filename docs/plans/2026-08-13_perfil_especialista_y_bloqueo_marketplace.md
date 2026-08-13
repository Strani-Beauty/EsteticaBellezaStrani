# Plan: Perfil de especialista (consulta/edición) + bloqueo de Marketplace para no-aprobados

**Fecha:** 2026-08-13
**Origen:** ítems 13 y 14 del checklist.
**Decisiones:** nueva `SpecialistProfileScreen` dedicada (reusa `SpecialistsCubit`); blindaje del Marketplace en cliente **y** BD (defensa en profundidad).

---

## Estado

- [x] Ítem 13 — `SpecialistProfileScreen` (consulta + edición)
- [x] Ítem 13 — ruta `/specialist/profile` + entrada role-aware
- [x] Ítem 14 — gate en `SpecialistMapScreen` (cliente)
- [x] Ítem 14 — migración SQL `obtener_solicitudes_publicadas_geo` solo APROBADO
- [x] Verificación (`flutter analyze`, `flutter test`)
- [x] Aplicar migración al remoto (`supabase db push` — confirmación usuario)
---

## Ítem 13 — Vista de perfil del especialista

- [ ] **13.1** Nueva pantalla `lib/features/specialists/presentation/screens/specialist_profile_screen.dart`.
  - Consulta: email, nombre, teléfono, dirección, tarifa, licencia, médico regente, especialidades y estado de verificación (+ `observacion`).
  - Edición (campos que le corresponden) vía `SpecialistsCubit`:
    - Personales: `guardarDatosPersonales` + `saveLocation` + `AuthCubit.refreshProfile`.
    - Profesionales: `actualizarDatosProfesionales` + `guardarEspecialidades` + `createMedicoRegente`.
  - Enlace "Corregir y reenviar" → `specialistDocuments` si estado `RECHAZADO`.

- [ ] **13.2** Router: añadir `AppRoutes.specialistProfile = '/specialist/profile'` con `BlocProvider<SpecialistsCubit>`.

- [ ] **13.3** Entrada:
  - `ProfileMenuButton` role-aware (especialista → `specialistProfile`, resto → `profile`).
  - Card "Editar mi información" en `SpecialistHomeScreen`.

## Ítem 14 — Bloqueo de Marketplace para no-aprobados

- [ ] **14.1** Cliente: en `SpecialistMapScreen`, cargar el especialista vía `SpecialistsCubit` y solo invocar `MarketplaceCubit.load` si está `APROBADO`; si no, mostrar vista de acceso restringido (sin llamar al RPC). Proveer `SpecialistsCubit` en la ruta del mapa.

- [ ] **14.2** BD: migración `supabase/migrations/20260813060000_obtener_solicitudes_geo_solo_aprobados.sql` que reemplaza `obtener_solicitudes_publicadas_geo` para devolver filas únicamente si `auth.uid()` corresponde a un especialista `APROBADO` y `activo`.

## Verificación

- [x] `flutter analyze` sin issues.
- [x] `flutter test` al verde (80/80).
- [x] `supabase db push` (pedir confirmación al usuario).