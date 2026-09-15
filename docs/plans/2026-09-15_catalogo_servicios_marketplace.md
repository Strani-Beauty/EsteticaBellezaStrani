# Plan — Catálogo de servicios estilo marketplace

Fecha: 2026-09-15
Estado: APROBADO por el usuario (m0052: "1. No 2. si" → sin buscador, implementar). Sin commit.

## Objetivo

Rediseñar la vista del catálogo de servicios al paciente (`/services`) como una vista de
inicio de marketplace:

- Imagen principal con slogan (hero) → `assets/images/Imagen_cat.jpg` (1024x1024, 178 KB, confirmada).
- Slogan: `Donde la ciencia encuentra tu belleza` (playfair, 2 líneas, mismo estilo de bienvenida).
- **Sin buscador** (decisión del usuario) y **sin carrito**.
- Categorías de servicios deslizables horizontalmente (se conserva el mecanismo actual).
- Cuadrícula de servicios: cada uno con foto arriba, descripción corta, precio.
- Arriba a la derecha: botón **"Iniciar sesión"** cuando el visitante NO está logueado.
- Los iconos **Mis Solicitudes, Estado de Salud, Mi perfil** (y logout) solo aparecen cuando
  el paciente está logueado.

## Cambios

### `lib/features/catalog_services/presentation/screens/services_dashboard_screen.dart`

1. **Auth**: reemplazar el legacy `SupabaseService.currentUser` (import línea 9, usos en
   `_loadFlowStatus` ~66-71 y `_onServiceSelected` ~91-96) por
   `context.watch<AuthCubit>().currentProfile` (`currentProfile?.id`). Eliminar el import legacy.
2. **AppBar condicional**:
   - `isLogged = profile != null`.
   - Logueado → se conservan los 4 iconos (Mis Solicitudes, Estado de Salud, Mi Perfil, Logout).
   - Anónimo → sin esos iconos; `actions` con `FilledButton` "Iniciar sesión" → `context.go(AppRoutes.login)`.
   - Título: logueado `Bienvenido/a, $name`; anónimo solo `Catálogo de Servicios`.
3. **Body** → `CustomScrollView` (dentro del `BlocConsumer<CatalogCubit>`) con slivers:
   1. `_CatalogHero` (nuevo): `Image.asset('assets/images/Imagen_cat.jpg')` + gradiente + slogan.
   2. `_buildStatusBanner()` solo si `isLogged`.
   3. `_buildCategoryChips` (se conserva).
   4. `SliverGrid` con `_ServiceCard` rediseñada.
   - Estados de carga/error/empty y overlay de `loadingServicios` se conservan.
4. **`_ServiceCard` rediseñada**: imagen arriba (`AspectRatio`), luego nombre (2 líneas),
   descripción corta (2 líneas), precio; chip de categoría + duración como meta.
   Se reutilizan `_buildHero`, `_ServiceHeroImage`, `_slugify`, `_iconForServicio`, `_formatPrice`.
5. **Flujo preservado**: `_onServiceSelected` (gate RN-020/022, face map, requisitos de salud,
   resumen), modales y `didPopNext`.

### Sin cambios en cubit/datasource/repositorio
- No hay buscador → no se toca `CatalogCubit`.
- Rutas: `/services` sigue pública; botón "Iniciar sesión" usa `/login`.

## Verificación

- [x] `flutter analyze` limpio.
- [x] `flutter test` (366 tests pasan; no hay widget tests del catálogo).
- [ ] Manual en `flutter run -d chrome`:
  - Anónimo: hero con Imagen_cat.jpg + slogan, categorías deslizables, grid con foto/desc/precio,
    botón "Iniciar sesión" arriba a la derecha, SIN iconos de paciente ni banner RN-020.
  - Logueado (paciente): iconos Mis Solicitudes / Estado de Salud / Perfil / Logout visibles,
    banner RN-020, saludo `Bienvenido/a, $name`, flujo de selección de servicio intacto.

## Notas
- Sin commit (regla del proyecto: preguntar antes de commitear).