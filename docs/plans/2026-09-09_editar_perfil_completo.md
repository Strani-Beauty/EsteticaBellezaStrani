# Plan: Edición completa del perfil del paciente ('Editar mi información')

**Fecha**: 2026-09-09
**Origen**: Reporte del usuario — "El botón de Editar mi información en vista Mi Perfil, no trae todos los datos del paciente. Debería editar todos los datos del paciente, inclusive, el avatar."

## Decisiones de alcance (aprobadas por el usuario)
1. **Campos a editar**: **Todos (recomendado)** = Avatar + nombre + teléfono + fecha de nacimiento + género + dirección con mapa (lat/lng). Set completo del onboarding del paciente.
2. **Por rol**: **Edición según rol (recomendado)** = el paciente edita todo (incl. avatar/fecha/género/dirección); admin solo nombre/teléfono/avatar.

## 1. Capa de datos — persistir `avatar_url` vía ruta limpia
- `i_auth_repository.dart`: añadir `String? avatarUrl` a `updateProfile`.
- `auth_repository_impl.dart`: mapear `if (avatarUrl != null) data['avatar_url'] = avatarUrl;`.
- `auth_cubit.dart` `updateProfile`: añadir parámetro `avatarUrl` y pasarlo al repo.
- `ProfileModel`/`ProfileEntity` ya soportan avatar_url/address/lat/lng. `AuthSupabaseDataSource.updateProfile` ya reenvía el map (acepta avatar_url) y sincroniza pacientes.

## 2. ProfileScreen — edición inline rica según rol
- Paciente (`profile.isPatient`): AvatarSelector + nombre + teléfono + fecha (showDatePicker) + género (dropdown) + dirección (geocode + modal de mapa) + Guardar.
- No-paciente (admin): AvatarSelector + nombre + teléfono.
- Carga previa (paciente): `sl<GetMiPaciente>()()` para fecha/género; prefill dirección/coordenadas/avatar desde `profile` (isValidMapCoordinate).
- Guardado paciente: `cubit.updateProfile(..., address, latitude, longitude, avatarUrl)` + `await sl<UpdateMiPaciente>()(fechaNacimiento, genero)` (fold ignorar).
- Guardado admin: `updateProfile` con fullName/phone/avatarUrl.
- En modo no-edición: mostrar campos de solo lectura (avatar/nombre/teléfono/correo y, si existe, dirección/fecha/género).
- Reutilizar `AvatarSelector`, `PatientMapPicker`, `map_config`, patrón geocode+modal de complete_profile_screen (sin flujo de pago).

## 3. NO tocar
- complete_profile_screen / supabase_service legacy (solo reutilizar widgets/patrones).
- specialist_profile_screen (ruta /specialist/profile, no se toca).

## Verificación
- `flutter analyze`, `flutter test` (366 green esperado).
- NO commitear sin OK explícito del usuario.

## Archivos a tocar
- i_auth_repository.dart, auth_repository_impl.dart, auth_cubit.dart.
- profile_screen.dart (edición completa).

## Checkpoints
- [x] Plan persistido
- [x] Capa de datos: avatarUrl en updateProfile (repo/impl/cubit)
- [x] ProfileScreen edición completa por rol
- [x] flutter analyze + test (No issues found / 366 tests passed)