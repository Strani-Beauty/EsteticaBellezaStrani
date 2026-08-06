-- Marketplace de citas: asignación de solicitudes "primer aviso gana" (tipo Uber).
-- El especialista acepta una solicitud pendiente de forma atómica: el primer
-- UPDATE con guarda de estado gana; los demás reciben aceptada=false.

-- ─────────────────────────────────────────────────────────────────────────────
-- RPC: aceptar_solicitud
--   - Cambia la solicitud a ACEPTADA solo si sigue en PUBLICADA/BUSCANDO_ESPECIALISTA
--     y no está expirada.
--   - Si el UPDATE afecta 1 fila, inserta la cita PROGRAMADA vinculada.
--   - Devuelve: { aceptada: bool, cita_id: uuid|null, motivo: 'ASIGNADA'|'EXPIRADA'|'NO_ENCONTRADA' }
-- ─────────────────────────────────────────────────────────────────────────────

create or replace function public.aceptar_solicitud(
  p_solicitud_id uuid,
  p_especialista_id uuid
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_estado   text;
  v_claim    int;
  v_cita_id  uuid;
begin
  select estado into v_estado
    from public.solicitudes
   where id = p_solicitud_id;

  if v_estado is null then
    return json_build_object('aceptada', false, 'cita_id', null, 'motivo', 'NO_ENCONTRADA');
  end if;

  if v_estado not in ('PUBLICADA', 'BUSCANDO_ESPECIALISTA') then
    return json_build_object('aceptada', false, 'cita_id', null, 'motivo', 'ASIGNADA');
  end if;

  -- Claim atómico: solo cambia si sigue publicada/buscando y no expirada.
  update public.solicitudes
     set estado     = 'ACEPTADA',
         updated_at = now()
   where id = p_solicitud_id
     and estado in ('PUBLICADA', 'BUSCANDO_ESPECIALISTA')
     and (fecha_expiracion is null or now() < fecha_expiracion);

  get diagnostics v_claim = row_count;

  if v_claim = 0 then
    -- Expiró o fue tomada entre la lectura y el update.
    return json_build_object('aceptada', false, 'cita_id', null, 'motivo', 'EXPIRADA');
  end if;

  insert into public.citas (solicitud_id, especialista_id, estado, fecha_aceptacion)
  values (p_solicitud_id, p_especialista_id, 'PROGRAMADA', now())
  returning id into v_cita_id;

  return json_build_object('aceptada', true, 'cita_id', v_cita_id, 'motivo', 'OK');
end;
$$;

grant execute on function public.aceptar_solicitud(uuid, uuid) to authenticated;
