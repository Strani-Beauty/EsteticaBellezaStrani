# Plan — Tipografía griega para el wordmark MERAKI SPA ONSITE

Fecha: 2026-09-15
Estado: APROBADO por el usuario (m0527: "aprobado"). Sin commit.

## Objetivo

El nombre MERAKI proviene del griego (μεράκι = hacer algo con alma, creatividad y
amor). Usar la fuente **GFS Didot** (Greek Font Society, basada en la tipografía
griega de Didot de 1805) para el wordmark y la marca visible, con glifos griegos
nativos, y añadir **μεράκι** como acento decorativo del logo.

Decisiones confirmadas (m0524):
- Fuente: **GFS Didot** (google_fonts 8.2.1 ya instalado → sin assets/pubspec).
- Añadir **μεράκι** en alfabeto griego al wordmark.
- Solo marca visible (wordmark, login, hero del catálogo); el resto sigue en Inter.

## Cambios

### 1. `welcome_screen.dart` — wordmark `_BrandLogo` (~285-302)
- `'MERAKI'`: `GoogleFonts.playfairDisplay(28, w700)` →
  `GoogleFonts.gfsDidot(fontSize: 32, letterSpacing: 3, height: 1.0, color: AppTheme.cDeepAccent)`.
- `'SPA ONSITE'`: se conserva `GoogleFonts.inter(8.5, w700, letterSpacing: 2.8, cMutedText)`.
- NUEVA línea bajo 'SPA ONSITE': `Text` con `μεράκι` en
  `GoogleFonts.gfsDidot(fontSize: 12, fontStyle: FontStyle.italic, color: AppTheme.cMutedText)`.

### 2. `login_screen.dart` — título (~268)
- `Text('Bienvenido/a a MERAKI spa onsite', titleMedium)` →
  `GoogleFonts.gfsDidot(fontSize: 17, color: AppTheme.cDarkText)`.

### 3. `services_dashboard_screen.dart` — slogan hero (~648-665)
- Style del `Text.rich` del hero: `GoogleFonts.playfairDisplay(isDesktop?34:26, w700)`
  → `GoogleFonts.gfsDidot(fontSize: isDesktop ? 34 : 26, fontWeight: FontWeight.w400,
  color: Colors.white, height: 1.2)`. Spans itálicos se conservan.

### Sin cambios
- AppTheme, resto de UI (Inter), pubspec, BD, tests.

## Verificación

- [x] `flutter analyze` limpio.
- [x] `flutter test` (366 tests).
- [ ] Manual en `flutter run -d chrome`: wordmark griego elegante con μεράκι
      visible en bienvenida; login y hero del catálogo en GFS Didot.

## Notas

- Sin commit (regla del proyecto: preguntar antes de commitear).