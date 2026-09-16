# Plan — Botones de la vista de bienvenida iguales, sin texto cortado

Fecha: 2026-09-16
Estado: APROBADO por el usuario (m0555: "aprobado"). Sin commit.

## Objetivo

Los dos botones de acceso de la vista de bienvenida (Especialistas y Explorar
Servicios) deben verse **iguales: mismo tamaño y mismo diseño**, y el texto no
debe cortarse, sobre todo en vista celular. Hoy se renderizan en un `Row` de dos
`Expanded`; en celular cada botón queda ~146px y el texto salta de línea distinto
en cada uno → alturas diferentes y texto apretado.

Decisiones confirmadas (m0553):
- **Row en desktop, Column en móvil** (layout responsivo).
- **Sí, altura fija idéntica** (58px) para los dos botones.

## Cambios

### `lib/features/auth_users/presentation/screens/welcome_screen.dart`

1. **Layout responsivo de los botones** (`_buildContent`, ~142-164): envolver la
   sección en un `LayoutBuilder`:
   - `constraints.maxWidth >= 460` → `Row` con dos `Expanded` y `SizedBox(width: 12)`
     (escritorio, como hoy).
   - `< 460` → `Column` con `crossAxisAlignment: CrossAxisAlignment.stretch`, dos
     botones de ancho completo separados por `SizedBox(height: 12)` (móvil/tablet).

2. **Refactor de `_ActionButton`** (~318-413) para tamaño idéntico:
   - `AnimatedContainer` con `height: 58` (contenido centrado verticalmente por la
     `Row`). Ambos botones quedan exactamente del mismo alto.
   - Columna de texto `Flexible` → `Expanded` (con `crossAxisAlignment.start`):
     ícono y flecha en posiciones fijas e iguales (flecha al extremo derecho).
   - Label y subtítulo sin `maxLines`/`ellipsis` → nunca se cortan.
   - Padding pasa a `EdgeInsets.symmetric(horizontal: 18)`.
   - Se conservan: estilo secundario (blanco, borde gris, sombra, hover), iconos,
     flechas, `isPrimary`.

### Sin cambios
- Diseño/marca (GFS Didot), resto de la pantalla, otras vistas, pubspec, BD.

## Verificación

- [x] `flutter analyze` limpio.
- [x] `flutter test` (366 tests).
- [ ] Manual en `flutter run -d chrome`: modo celular (DevTools ~360px) → botones
      apilados a ancho completo, mismo tamaño, texto completo; escritorio → lado a
      lado iguales.

## Notas

- Sin commit (regla del proyecto: preguntar antes de commitear).