# Plan — Catálogo: 2 servicios por fila, descripción completa y precio "Desde $"

Fecha: 2026-09-15
Estado: APROBADO por el usuario (m0085). Sin commit.

## Objetivo

En la vista de catálogo de servicios (`/services`, `services_dashboard_screen.dart`):

1. **Dos servicios por fila en vista celular** (y tablet). Confirmado: aplicar en todos los
   tamaños (escritorio 3 columnas, tablet/celular 2) para consistencia.
2. **Descripción completa** visible, sin truncar (maxLines).
3. **Precio con prefijo "Desde $"** manteniendo el sufijo cuando aplica
   (`Desde $9.95 /unidad`, `Desde $145 /sesión`, `Desde $450`).

## Cambios

### `lib/features/catalog_services/presentation/screens/services_dashboard_screen.dart`

1. **`_buildCatalog`** (bloque `SliverLayoutBuilder`/`SliverGrid.builder` ~606-628):
   - Columnas por ancho: `crossAxisExtent >= 1000` → 3, resto → 2.
   - Reemplazar `SliverGrid` (alto fijo) por `SliverList.builder` de filas:
     agrupar `servicios` de a `columns` por fila (la última puede ir incompleta).
   - Cada item: `Padding(bottom: 18)` > `IntrinsicHeight` > `Row(crossAxisAlignment:
     stretch)` con un `Expanded` por tarjeta y `SizedBox(width: 18)` entre ellas.
   - Tarjetas de alto variable según contenido (necesario para descripción completa).
   - Estado vacío (`SliverFillRemaining`) se conserva.

2. **`_ServiceCard`**:
   - Descripción: quitar `maxLines: 2` y `TextOverflow.ellipsis` → texto completo.
   - Precio: envolver el `Text(_formatPrice(service))` en `Flexible` para que pueda
     fluir en tarjetas estrechas sin overflow (la duración se conserva en la Row).

3. **`_formatPrice`**: anteponer `'Desde '` al formato actual:
   `'Desde \$${service.precioBase}${suffix}'` (sufijo solo cuando no es precio fijo).

### Sin cambios
- Cubit, datasource, repositorio, rutas.
- No hay widget tests del catálogo → sin tests nuevos.

## Verificación

- [x] `flutter analyze` limpio.
- [x] `flutter test` (366 tests).
- [ ] Manual en `flutter run -d chrome`:
  - Celular (estrecho): 2 servicios por fila, descripción completa, precio "Desde $...".
  - Escritorio: 3 por fila con el mismo comportamiento.
  - Sin overflow ni tarjetas cortadas.

## Notas
- Sin commit (regla del proyecto: preguntar antes de commitear).