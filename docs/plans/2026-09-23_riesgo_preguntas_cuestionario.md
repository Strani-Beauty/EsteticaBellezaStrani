# Plan — Riesgo configurable al crear/editar preguntas + critico según gravedad

Fecha: 2026-09-23
Estado: APROBADO por el usuario (m2031/m2032). Sin commit.

## Objetivo

Al ingresar nuevas preguntas desde la App (admin → Cuestionario → Nueva pregunta), el
diálogo debe permitir definir el **riesgo** (detonante/patrón, etiqueta y si es crítico)
para que se persista en `preguntas.riesgo` con el formato sentinel que lee la RPC
(`{"detonante"|"patron", "etiqueta", "critico"}`). Además, las 15 preguntas creadas el
2026-09-23 (ids 23-37) deben quedar con `critico` correcto según gravedad médica.

Contexto verificado en BD (pooler): ids 23-37 ya tienen el sentinel con
`detonante:"SI"` + `etiqueta` (corregido antes); solo falta ajustar `critico`. Id 38
(TEXTO) sin riesgo (correcto). `opciones` en SI_NO queda `null` (correcto: el paciente
responde por toggle; opciones solo aplican a LISTA/MULTIPLE).

## Cambios

### 1. `_NuevaPreguntaDialog` (`admin_cuestionario_screen.dart:597-816`)
Añadir sección "Riesgo" (mismo estilo del contenedor de Opciones):
- `SwitchListTile` "Genera riesgo al responder" (default off).
- Si activo, según tipo:
  - `SI_NO`: detonante fijo `"SI"` (sin input).
  - `TEXTO`: campo Patrón (regex) → `patron`.
  - `LISTA`/`MULTIPLE`: campo "Valor que dispara" → `detonante`.
  - Campo **Etiqueta** (texto corto).
  - `SwitchListTile` "Es crítico" → `critico: true/false`.
- `onGuardar` pasa `Map<String,dynamic>?` de riesgo (o `null` si sin riesgo). El cubit
  `crearPregunta` y el datasource ya aceptan `riesgo`.

### 2. `_EditarPreguntaDialog` (`admin_cuestionario_screen.dart:822-1013`)
Misma sección para editar el riesgo: precargar desde `pregunta.riesgo` (switch activo si
existe, detonante/patrón, etiqueta, crítico); al guardar enviar el mapa.

### 3. BD (pooler, script node)
UPDATE de `preguntas.riesgo.critico` para ids 23-37:
- true: 24, 25, 26, 27, 28, 29, 31, 35.
- false: 23, 30, 32, 33, 34, 36, 37.

## Verificación

- [x] `flutter analyze` limpio.
- [x] `flutter test` (370).
- [x] Pooler: critico correcto en las 15 preguntas (8 true: 24,25,26,27,28,29,31,35; resto false; id 38 TEXTO sin riesgo).
- [ ] Manual: crear pregunta con riesgo → persiste; editar → cambia; expediente refleja.

## Notas

- Sin cambios de RLS/RPC/migración (solo UPDATE de datos por pooler). Sin commit.