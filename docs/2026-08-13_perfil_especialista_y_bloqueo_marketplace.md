# Perfil del especialista (consulta/edición) y bloqueo del Marketplace para no-aprobados

**Fecha:** 2026-08-13
**Rama:** `main`
**Plan:** `docs/plans/2026-08-13_perfil_especialista_y_bloqueo_marketplace.md`

---

## 1. Contexto y motivo

Se implementaron dos ítems del checklist de especialistas:

- **Ítem 13** — Vista de perfil del especialista para consultar y actualizar la información que le corresponde.
- **Ítem 14** — Validar que un especialista **pendiente de verificación** pueda completar su información, pero **no** pueda visualizar ni recibir solicitudes del Marketplace.

### Resultado del diagnóstico

| Ítem | Estado previo | Acción |
|---|---|---|
| Perfil del especialista | `ProfileScreen` genérica (solo nombre/teléfono) y `SpecialistHomeScreen` (dashboard sin edición); el onboarding editaba pero solo cuando el perfil estaba incompleto | Nueva `SpecialistProfileScreen` dedicada que reusa el `SpecialistsCubit` |
| Bloqueo Marketplace | `aceptar_solicitud` ya validaba APROBADO (recibir), pero el RPC `obtener_solicitudes_publicadas_geo` no filtraba y `/specialist/map` era accesible por deep-link | Gate en cliente + migración SQL (defensa en profundidad) |

---

## 2. Cambios realizados

### 2.1 Ítem 13 — `SpecialistProfileScreen`

**Nueva pantalla** `lib/features/specialists/presentation/screens/specialist_profile_screen.dart`:
- **Consulta** (solo lectura): estado de verificación (badge + `observacion` si rechazado/bloqueado), email, nombre, teléfono, dirección, tarifa, licencia, médico regente y especialidades.
- **Edición** (campos que le corresponden), reusando `SpecialistsCubit`:
  - Personales → `guardarDatosPersonales` (profiles) + `saveLocation` (ubicaciones_especialista) + `AuthCubit.refreshProfile()`.
  - Profesionales → `actualizarDatosProfesionales` (licencia/médico regente) + `guardarEspecialidades` + `createMedicoRegente` (reusa `RegistrarMedicoRegenteDialog` y `EspecialidadesSelector`).
- Enlace "Corregir y reenviar" → `/specialist/documents` cuando el estado es `RECHAZADO`.

**Router** `lib/app/config/app_routes.dart`:
- Nueva ruta `AppRoutes.specialistProfile = '/specialist/profile'` con `BlocProvider<SpecialistsCubit>`.

**Entrada**:
- `ProfileMenuButton` ahora es role-aware: los especialistas van a su perfil ampliado, el resto a `/profile`.
- Card "Mi información" en `SpecialistHomeScreen`.

### 2.2 Ítem 14 — Bloqueo del Marketplace

**Cliente** `lib/features/marketplace_citas/presentation/screens/specialist_map_screen.dart`:
- La ruta del mapa ahora provee también `SpecialistsCubit` (MultiBlocProvider).
- La pantalla carga primero el especialista y solo invoca `MarketplaceCubit.load(...)` si `especialista.isApproved`. En caso contrario muestra `_AccesoRestringido` sin llamar al RPC.

**BD** `supabase/migrations/20260813060000_obtener_solicitudes_geo_solo_aprobados.sql`:
- `obtener_solicitudes_publicadas_geo` ahora devuelve filas únicamente si `auth.uid()` corresponde a un especialista `estado_verificacion = 'APROBADO'` y `activo = true`.

> La parte "pueda completar su información" ya funcionaba: `SpecialistHomeScreen` redirige al especialista incompleto a onboarding/documentos. Se conserva intacta.

---

## 3. Seguridad (defensa en profundidad)

- **Visualizar**: bloqueado en UI (`SpecialistMapScreen`) **y** en BD (RPC filtrado por APROBADO+activo).
- **Recibir**: `aceptar_solicitud` valida APROBADO+activo (migración `20260813020100`) y `fetchEspecialistasAprobados` filtra por APROBADO — un pendiente no aparece en el mapa ni puede aceptar.
- **Completar información**: el estado inicial sigue siendo `PENDIENTE`; el dueño solo puede INSERTar en PENDIENTE y autosolicitar revisión (triggers `trg_proteger_verificacion_especialista`).

---

## 4. Aplicación

Migración aplicada al remoto con `supabase db push`:

1. `20260813060000_obtener_solicitudes_geo_solo_aprobados.sql`

Verificación: `supabase migration list` muestra la migración como aplicada en Remote.

---

## 5. Verificación de código

- `flutter analyze` → sin issues.
- `flutter test` → 80/80.

---

## 6. Git

| | |
|---|---|
| Mensaje | `Perfil de especialista editable y bloqueo del Marketplace para no-aprobados` |
| Rama | `main` → pusheado a `origin/main` |

---

## 7. Verificación manual sugerida

1. **Perfil**: como especialista, en el home → "Mi información" (o icono de cuenta) → editar datos personales y profesionales → guardar. Verificar persistencia en `profiles` y `especialistas` (licencia, médico regente, especialidades, tarifa, dirección).
2. **Bloqueo**: con un especialista NO aprobado, abrir `/specialist/map` → debe verse "No tienes acceso al Marketplace" y no cargar solicitudes. Con uno APROBADO, el mapa carga con normalidad.
3. **BD**: como especialista pendiente, llamar a `obtener_solicitudes_publicadas_geo()` → debe devolver 0 filas.
