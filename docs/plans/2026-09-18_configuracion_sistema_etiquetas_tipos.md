# Plan — Configuración del Sistema: etiquetas legibles, stepper INTEGER y selector de monedas

Fecha: 2026-09-18
Estado: APROBADO por el usuario (m1673: "si"). Sin commit.

## Objetivo

Mejorar la vista admin **Configuración del Sistema** (`admin_configuracion_screen.dart`):

1. Mostrar una **etiqueta legible** del parámetro en vez del nombre de la clave
   (p.ej. `tiempo_expiracion_sol` → "Tiempo de expiración de la solicitud").
2. Los ítems **INTEGER** se editan con un **Input Number** (stepper `-` / `+`).
3. La clave **moneda** usa un listado de las principales monedas del mundo.

Decisiones confirmadas (m1671, tool question):
- Stepper **solo para tipo_dato INTEGER** (NUMERIC conserva campo numérico editable).
- Claves secretas (`anon_key`, `edge_function_base_url`) se **ocultan de la lista**.
- Booleanos se editan en **diálogo con dropdown** true/false (no switch directo).

## Cambios (archivo único `lib/features/admin_config/presentation/screens/admin_configuracion_screen.dart`)

### 1. Ocultar secretos
- `_ConfigTile.build` (o el `ListView.builder`) no renderiza las claves
  `anon_key` y `edge_function_base_url`.

### 2. Etiquetas legibles
- Mapa estático `_etiquetaConfig(String clave)` con el nombre descriptivo de cada
  clave real (ver lista en BD), p.ej.:
  - `tiempo_expiracion_sol` → 'Tiempo de expiración de la solicitud'
  - `tiempo_expiracion_solicitud` → 'Tiempo de expiración de la solicitud sin aceptar'
  - `radio_busqueda_km` → 'Radio máximo de búsqueda (km)'
  - `dias_validez_qualify` → 'Días de validez del dictamen médico' (sin la marca Qualify)
  - `moneda_principal` → 'Moneda principal del sistema'
- `_ConfigTile`: título = etiqueta legible (w600); subtítulo =
  `'$valor · $tipoDato'` + descripción si existe; clave técnica en texto pequeño
  cMutedText (fontSize 10) como referencia secundaria.

### 3. Diálogo de edición según tipo (`_editar`)
- **INTEGER** → stepper: Row con IconButton `-`, TextFormField numérico centrado
  (controlador), IconButton `+`; min 0; validación `int.tryParse` + `>= 0`.
- **NUMERIC** → TextFormField `TextInputType.numberWithOptions(decimal: true)`,
  validación `double.tryParse` (como hoy).
- **BOOLEAN** → `DropdownButtonFormField<String>` con opciones `true`/`false`.
- **MONEDA** (clave `moneda_principal`) → `DropdownButtonFormField<String>` con las
  principales monedas ISO 4217: USD, EUR, MXN, COP, VES, ARS, BRL, PEN, CLP, CAD,
  GBP, CRC, GTQ, PYG, UYU, BOB.
- **STRING** (resto) → TextFormField normal (como hoy).
- Ajustar `_validarValor` para INTEGER (`int.tryParse`).

### Sin cambios
BD/RLS (sin columna nueva de tipo 'MONEDA'; se detecta por clave), cubit,
datasource (guarda `update(clave, valor)` como texto), resto de la app.

## Verificación

- [x] `flutter analyze` limpio.
- [x] `flutter test` (370 tests).
- [ ] Manual en `flutter run -d chrome`: panel admin → Configuración del Sistema →
      20 claves con etiquetas legibles; `moneda_principal` con dropdown de monedas;
      `tiempo_expiracion_*` con stepper +/-; booleanos con dropdown true/false;
      `anon_key`/`edge_function_base_url` ausentes.

## Notas

- Sin commit (regla del proyecto: preguntar antes).