# Plan — Configuración del Sistema: volver al listado tras guardar

Fecha: 2026-09-18
Estado: APROBADO por el usuario (m1698: "aprobado, ommit/push y despliegue"). Commit/push y deploy aprobados.

## Objetivo

Al guardar cualquier cambio en la vista Configuración del Sistema, la lista debe
permanecer visible con el nuevo valor. Hoy queda en **pantalla en blanco**.

## Causa raíz (diagnóstico)

`admin_configuracion_cubit.dart`:
1. `update()` guarda y emite `AdminConfiguracionSaved(...)`.
2. El `BlocConsumer.listener` de la pantalla muestra el snackbar y llama
   `clearSaved()`.
3. `clearSaved()` emite `AdminConfiguracionInitial`.
4. El `builder` solo renderiza `Loading`/`Error`/`Loaded`; con `Initial` (o
   `Saved`) cae en `return const SizedBox.shrink()` → pantalla en blanco, sin
   volver a `Loaded`.

## Cambios

### 1. `lib/features/admin_config/presentation/cubits/admin_configuracion_cubit.dart`
- Añadir `List<ConfigSistemaEntity> _items = const [];`, actualizada cuando
  `load()` tiene éxito.
- `update()`: al éxito, reemplazar el ítem en `_items` (nuevo
  `ConfigSistemaEntity` con el valor guardado) y emitir
  `AdminConfiguracionLoaded(_items)`; retornar `true`. El fallo sigue emitiendo
  `Error` y retornando `false`.
- Eliminar el estado `AdminConfiguracionSaved` y el método `clearSaved()`
  (quedan muertos).

### 2. `lib/features/admin_config/presentation/screens/admin_configuracion_screen.dart`
- `_editar`: tras `update(clave, valor)`, si `ok == true && mounted` mostrar el
  snackbar `'Clave "$clave" actualizada.'` directamente.
- Quitar del `listener` el branch de `AdminConfiguracionSaved`/`clearSaved()`;
  conservar el de `Error`.

Con esto el estado nunca sale de `Loaded` al guardar: la lista permanece visible
y el valor editado aparece actualizado al instante (sin recargar de red ni
pantalla en blanco).

## Verificación

- [x] `flutter analyze` limpio.
- [x] `flutter test` (370 tests; no hay tests del cubit de configuración).
- [ ] Manual: editar cualquier clave → Guardar → snackbar y listado visible con
      el nuevo valor.

## Notas

- Commit/push y despliegue en Firebase aprobados (m1698).
- Commit `496d028` pusheado (`c8781a0..496d028`) y deploy liberado en
  https://esteticaybellezastrani.web.app.