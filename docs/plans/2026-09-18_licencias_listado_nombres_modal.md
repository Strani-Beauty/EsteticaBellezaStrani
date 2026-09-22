# Plan — Verificación de licencias: listado de nombres + tarjeta completa en modal

Fecha: 2026-09-18
Estado: APROBADO por el usuario (m1647: "si"). Sin commit.

## Objetivo

En la vista del administrador "Verificación de licencias", cada pestaña debe
mostrar **solo un listado de los nombres** de los especialistas con el **icono de
editar a la derecha**. Al pulsar la fila (o el icono) se abre un **diálogo modal**
con la **tarjeta completa** para aprobar/verificar/editar los datos.

Decisiones confirmadas (m1642):
1. Apertura de la tarjeta completa: **diálogo modal**.
2. El icono de editar abre lo mismo que la fila (la tarjeta completa).

## Cambios

Archivo único: `lib/features/admin_config/presentation/screens/admin_licencias_screen.dart`.

1. **Nuevo widget compacto `_EspecialistaFila`** (StatelessWidget, params
   `especialista` + `VoidCallback onTap`): tarjeta blanca radiusLg con contorno
   `cDeepAccent` alpha 0.35 y `elevation: 1`; `InkWell` → `Row[ Expanded(Text(nombre
   o email o 'Especialista {usuarioId}', w600)), IconButton edit_rounded 18
   cDeepAccent ]`. Fila e icono llaman `onTap`.

2. **Método `_abrirDetalle(BuildContext, EspecialistaEntity)`** en
   `_VerificacionDeLicencias`: `showDialog` con `Dialog(radiusLg, insetPadding h16
   v20)` → `ConstrainedBox(maxWidth 560, maxHeight 85% pantalla)` →
   `SingleChildScrollView` → reutiliza `_EspecialistaCard` con los mismos params
   (`medicosRegentes`, `documentos[id]`, `contrato`, `numeroEspecialidades`).
   Callbacks envueltos para **cerrar el modal antes de ejecutar la acción**
   (Aprobar/Rechazar/Bloquear/Editar → `Navigator.pop(dialogCtx)` + callback);
   `onRevisarDocumento` se pasa directo (sus sub-diálogos viven en el navigator raíz).

3. **Reemplazar el render en las listas**:
   - `_listaEspecialistas`: `_EspecialistaCard` → `_EspecialistaFila(..., onTap: () =>
     _abrirDetalle(context, e))`. Se conservan el contador y el empty-state.
   - `_listaVerificados`: igual para especialistas; la sección **Médicos Regentes**
     al final se conserva intacta (decisión previa).

### Sin cambios
`_EspecialistaCard`, `_ExpedienteChecklist`, `_DocumentosBloque`/`_DocumentoFila`,
`_MedicoRegenteCard`, `_MotivoDialog`, `_Badge`, `_ErrorView`,
`_EditarEspecialistaDialog`, cubit, BD/RLS.

## Verificación

- [x] `flutter analyze` limpio.
- [x] `flutter test` (370 tests, ALL PASSED).
- [ ] Manual en `flutter run -d chrome` (admin@test.com): cada pestaña muestra solo
      nombres + icono editar; al pulsar fila o icono se abre el modal con la tarjeta
      completa; al aprobar/rechazar/bloquear/editar se cierra el modal y la lista se
      actualiza; Médicos Regentes siguen al final de Verificados.

## Notas

- Sin commit (regla del proyecto: preguntar antes).