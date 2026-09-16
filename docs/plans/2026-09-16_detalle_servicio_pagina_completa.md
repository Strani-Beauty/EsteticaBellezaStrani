# Plan — Vista a página completa del detalle de servicio (antes del pago $30)

Fecha: 2026-09-16
Estado: APROBADO por el usuario (m0684: "si"). Sin commit.

## Objetivo

Al tocar un servicio en el catálogo con **sesión iniciada (paciente registrado)**,
mostrar una pantalla a página completa con el detalle del servicio **antes** del
flujo de pago/reserva. Layout (escritorio): imagen principal arriba-derecha,
descripción completa a la izquierda, hasta 4 imágenes relacionadas
(`imagen_url_2.._5`, placeholders si vacías) abajo-derecha, e invitación a
reservar al final con advertencia de $30 solo si el servicio lo requiere
(`requiere_telemedicina`).

Decisiones confirmadas (m0682):
1. Solo pacientes registrados (anónimos siguen yendo al login de paciente).
2. Botón "Reservar" → continúa el flujo actual (gate RN-020 → FaceMap → requisitos → resumen).
3. Galería: mostrar siempre 4 placeholders aunque estén vacías.
4. Celular: apilado vertical (imagen → datos → descripción → galería → CTA).

## Cambios

### 1. Nuevo `lib/features/catalog_services/presentation/widgets/service_image_hero.dart`
Helpers compartidos (extraídos de `services_dashboard_screen.dart`):
- `String servicioSlug(String nombre)` (antes `_slugify`).
- `IconData iconoServicio(ServicioEntity)` (antes `_iconForServicio`).
- `String formatPrecioServicio(ServicioEntity)` (antes `_formatPrice`, prefijo 'Desde $').
- Widget `ServiceImageHero` (imagen principal: `imagenUrl` → `Image.network` con
  fallback; si no, asset `service_<slug>`; si no, gradiente + ícono).
- Placeholder de galería reutilizable (cPastelPurple + `photo_library_rounded`).

### 2. Nuevo `lib/features/catalog_services/presentation/screens/service_detail_screen.dart`
- `ServiceDetailScreen extends StatelessWidget` con `ServicioEntity service`.
- AppBar con back + título 'Detalle del Servicio'.
- Body responsive (`LayoutBuilder`):
  - Escritorio (≥900): dos columnas (izquierda: nombre/precio/duración/chip/
    descripción completa; derecha: imagen principal arriba + galería abajo).
  - Celular: apilado vertical.
- Galería de 4 slots: `service.imagenesAdicionales[i]` → `Image.network` con
  `errorBuilder` → placeholder.
- CTA final: botón 'Reservar este servicio' → `Navigator.pop(context, 'reservar')`.
  Si `service.requiereTelemedicina` → advertencia $30 / Evaluación Médica Interna.

### 3. `lib/app/config/app_routes.dart`
- Nueva constante `serviceDetail = '/service-detail'` + `GoRoute` con
  `ServiceDetailScreen(service: state.extra as ServicioEntity?)`.
- Ruta privada por defecto (route guard redirige a welcome sin sesión).

### 4. `lib/features/catalog_services/presentation/screens/services_dashboard_screen.dart`
- `_onServiceSelected`: para `profile != null`, primero
  `await context.push(AppRoutes.serviceDetail, extra: service)`; solo si
  `result == 'reservar'` continúa con gate RN-020 → FaceMap → requisitos → resumen.
- `_ServiceCard`: usar helpers/widgets compartidos; eliminar los privados
  `_slugify`, `_iconForServicio`, `_formatPrice`, `_buildHeroFallback`, `_ServiceHeroImage`.

## Verificación

- [x] `flutter analyze` limpio.
- [x] `flutter test` (366 tests).
- [ ] Manual en `flutter run -d chrome`: anónimo → login; registrado → detalle
      (desktop: imagen arriba-derecha, descripción completa izquierda, galería
      placeholders abajo-derecha; celular: apilado); Reservar con advertencia $30
      solo si `requiere_telemedicina`; al reservar continúa RN-020/FaceMap/resumen.

## Notas

- Sin cambios de BD, cubits, datasources ni RLS. Sin commit (regla del proyecto).