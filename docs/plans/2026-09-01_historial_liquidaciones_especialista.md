# Plan: Historial de liquidaciones del especialista (Punto 13)

| | |
|---|---|
| **Fecha** | 2026-09-01 |
| **Estado** | APROBADO por el usuario (2026-09-01) |
| **Proyecto Supabase** | `hhyjremkguvphmjuaazp` |
| **Decisiones tomadas** | (1) Policies SELECT para el especialista dueño en `liquidaciones_especialistas` y `pagos_especialistas` (patrón `tratamiento_especialista_own`). (2) Pantalla nueva `mis_liquidaciones_screen.dart` con ruta `/specialist/liquidaciones` accesible desde el home del especialista. (3) El especialista SOLO lee (sin aprobar/pagar) y ve el comprobante con URL firmada. (4) Cubit nuevo `MisLiquidacionesCubit` (no reutiliza `AdminComisionesCubit`). |

## Contexto

De los 13 checkpoints del corte semanal de liquidaciones, 12 ya están aplicados y verificados. El **punto 13** ("El especialista puede consultar su historial de liquidaciones") no está implementado: no existe ninguna pantalla/cubit/usecase de liquidaciones para el rol Especialista, y `liquidaciones_especialistas` / `pagos_especialistas` solo tienen policies admin (`*_admin_all` de `20260822000100`) — el especialista dueño no puede leer sus propias liquidaciones por RLS.

## Actividades → implementación

### A. Migración `supabase/migrations/20260831000500_especialista_lee_sus_liquidaciones.sql`

- [x] A1. Policy `liquidaciones_especialistas_especialista_select` FOR SELECT TO authenticated
      USING `especialista_id = (SELECT id FROM public.especialistas WHERE usuario_id = auth.uid() LIMIT 1)`.
- [x] A2. Policy `pagos_especialistas_especialista_select` FOR SELECT TO authenticated
      USING `especialista_id = (SELECT id FROM public.especialistas WHERE usuario_id = auth.uid() LIMIT 1)`.
- [x] A3. Idempotente (DROP POLICY IF EXISTS). Aplicada al remoto (sim RLS OK).

### B. Capa de datos/dominio

- [x] B1. `admin_master_data_supabase_datasource.dart`: `fetchMisLiquidaciones(especialistaId)` y
      `fetchMisPagosEspecialistas(especialistaId)` — select embebido
      `'*, especialistas(usuario_id, profiles!especialistas_usuario_id_fkey(full_name))'`,
      `eq('especialista_id', id)`, orden desc, reutilizando `_liquidationFromJson`/parse de pago.
- [x] B2. `i_admin_master_data_repository.dart` + `admin_master_data_repository_impl.dart`:
      `getMisLiquidaciones(especialistaId)` y `getMisPagosEspecialistas(especialistaId)`
      → `Either<Failure, List<...>>` (patrón Right/Left + ServerFailure).
- [x] B3. `financiero_usecases.dart`: `GetMisLiquidaciones` y `GetMisPagosEspecialistas`
      (useclass con params `especialistaId`, patrón `UseCase<T, XParams>`).

### C. Cubit + DI

- [x] C1. `mis_liquidaciones_cubit.dart`: estados Initial/Loading/Loaded/Error; carga
      liquidaciones + pagos en paralelo; expone `firmarComprobante(path)`.
- [x] C2. `injection.dart`: registrar usecases + `MisLiquidacionesCubit` (inyectando por nombre).

### D. UI

- [x] D1. `mis_liquidaciones_screen.dart` (en `admin_master_data/presentation/screens/`):
      lista de liquidaciones con chip de estado coloreado, monto neto,
      período, método de pago del pago asociado y ver comprobante con URL firmada
      (reusar patrón visual de `admin_comisiones_screen.dart`).
- [x] D2. `app_routes.dart`: ruta `specialistLiquidaciones = '/specialist/liquidaciones'`
      (extra: especialistaId) con `BlocProvider<MisLiquidacionesCubit>.value`.
- [x] D3. `specialist_home_screen.dart`: tile `_MisLiquidacionesCard` →
      `context.push(AppRoutes.specialistLiquidaciones, extra: especialista.id)`.

### E. Verificación

- [x] E1. `flutter analyze` 0 issues + `flutter test` 366/366.
- [x] E2. Migración `20260831000500` aplicada al remoto (node pg): verificado con simulación
      RLS como especialista dueño (sub `90000000-...-000004`, especialista `c0000000-...-000002`)
      → ve su liquidación `e402f686` (PAGADA, monto_pagar 144.00) y su pago `ea2fa532`
      (Transferencia, 144.00, comprobante_url `e402f686-.../comprobante_1788179863780.jpg`).

## Notas

- El especialista NO puede cambiar estados ni registrar pagos: solo lectura (RLS SELECT-only).
- `firmarComprobante(path)` ya existe en el repositorio para URLs firmadas de storage.
- El comprobante está en bucket privado `comprobantes-pagos` (solo admin puede INSERT/UPDATE);
  el especialista podrá firmar/leer el objeto por la policy SELECT nueva + `firmarComprobante`.
- Patrón de errores `Either<Failure,T>` y cubits inyectando usecases por nombre.