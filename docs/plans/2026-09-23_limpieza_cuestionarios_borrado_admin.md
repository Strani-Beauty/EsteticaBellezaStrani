# Plan — Limpieza de cuestionarios + borrado en admin (sin re-vincular servicios)

Fecha: 2026-09-23
Estado: APROBADO por el usuario (m2108: "si"). Sin commit.

## Objetivo

Limpiar los cuestionarios sobrantes de BD y agregar al admin la opción de **borrar
un cuestionario** (activo o no), sin re-vincular servicios ni decidir el modelo de
evaluación (pendiente del usuario final: ¿una sola evaluación de Medicina Interna
para todos los servicios, o un 2º cuestionario para servicios clave?).

## Contexto verificado en BD

| id | nombre | v | activo | evals | preguntas |
|---|---|---|---|---|---|
| 1 | Estética y Belleza General | 1 | sí | 7 | 0 |
| 3 | Evaluación Clínica General | 1 | sí | 0 | 18 |
| 4 | Cuestionario de Salud | 1 | no | 2 | 10 |
| 5 | Cuestionario de Salud | 2 | sí | 10 | 11 |
| 6 | Cuestionario de Salud | 3 | no | 0 | 11 |

- `servicio_cuestionarios`: 19 servicios → id 5; 1 servicio → id 3.
- FK a `cuestionarios`: `cuestionario_preguntas`, `evaluaciones_salud`,
  `servicio_cuestionarios`.
- `fetchCuestionarioActivo` (onboarding) = `.eq('activo',true).order('created_at',desc).limit(1)`.

## Cambios

### 1. Feature de borrado (admin)
- **Datasource** `patients_compliance_supabase_datasource.dart`:
  `eliminarCuestionario(int id)`:
  - Si `evaluaciones_salud` tiene filas del cuestionario → lanza Exception (ePHI,
    bloqueo). Motivo claro para el admin.
  - Si es el cuestionario activo → aviso (permitido con advertencia en la UI).
  - Borra en orden: `cuestionario_preguntas` (eq cuestionario_id) →
    `servicio_cuestionarios` (eq cuestionario_id) → `cuestionarios` (eq id).
    RLS admin ya cubre las 3 tablas (`cuestionario_admin_write`,
    `cuestionario_pregunta_admin_write`, `servicio_cuestionarios_admin_write`).
- **Dominio**: `i_patients_compliance_repository.dart` +
  `patients_compliance_repository_impl.dart`: `eliminarCuestionario(int)` →
  `Future<Either<Failure, void>>`.
- **Usecase** nuevo `domain/usecases/eliminar_cuestionario.dart`
  (`EliminarCuestionarioParams{cuestionarioId}`).
- **Cubit** `admin_cuestionario_cubit.dart`: `eliminarCuestionario(int id)` →
  fold → `AdminCuestionarioError(message)` (con motivo del bloqueo) o feedback
  'Cuestionario eliminado.' + `load()`.
- **Screen** `admin_cuestionario_screen.dart`: botón borrar por versión en el
  selector (icono `delete_outline_rounded`); confirmación con advertencia si es
  la versión activa; snackbar si tiene evaluaciones (bloqueado).
- **DI** `injection.dart`: registrar `EliminarCuestionario` y pasarlo al cubit.

### 2. Limpieza de datos (migración `supabase/migrations/20260923000300_limpieza_cuestionarios.sql`)
- Borrar físicamente id 6 (v3, 0 evaluaciones):
  `DELETE FROM public.cuestionario_preguntas WHERE cuestionario_id = 6;`
  `DELETE FROM public.cuestionarios WHERE id = 6;`
- Desactivar (`activo = false`): id 1, id 4 (tienen evaluaciones → no borrables),
  id 3 "Evaluación Clínica General" (queda como borrador inactivo hasta decidir).
- Resultado: único activo = Cuestionario de Salud v2 (id 5).
- Aplicar por pooler (CLI da 401 sin supabase login).

### 3. Riesgo latente
- Resuelto por la limpieza (solo 1 cuestionario activo). Sin cambios en el onboarding.

### Sin cambios
- `servicio_cuestionarios` (no re-vincular), flujo de reserva, RLS, `ValidarRequisitosServicio`.

## Verificación

- [x] `flutter analyze` limpio; `flutter test` (370 ALL PASSED).
- [x] Pooler: id 6 borrado, único activo id 5, vínculos intactos (19→id5, 1→id3).
      (Verificado: cuestionarios restantes id 1/3/4 inactivos, id 5 activo;
      id 6 eliminado.)
- [ ] Manual: borrar cuestionario con evaluaciones → bloqueado con motivo; borrar
      v3 → OK; desactivados ocultos del onboarding.

## Notas

- Sin commit (regla del proyecto: preguntar antes).
- Pendiente del usuario final (NO se resuelve aquí): modelo de evaluación
  (única vs 2º cuestionario por servicio).