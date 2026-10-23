-- El escaneo solo pasa a 100 m o menos de la caseta.

alter table public.conjuntos alter column radio_m set default 100;

update public.conjuntos
  set radio_m = 100, actualizado_en = now()
  where radio_m <> 100;

create or replace function private.estoy_cerca(p_lat double precision, p_lng double precision)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_conjunto uuid;
  v_medida record;
begin
  if private.perfil_actual() is null then
    raise exception 'No hay un perfil activo para este usuario.';
  end if;
  select conjunto_id into v_conjunto from public.perfiles where id = private.perfil_actual();
  perform private.exigir_coordenadas(p_lat, p_lng);
  select * into v_medida from private.medir(v_conjunto, p_lat, p_lng);
  return jsonb_build_object(
    'aceptado', v_medida.aceptado,
    'metros', v_medida.metros,
    'radio_m', v_medida.radio_m
  );
end;
$$;

create or replace function public.estoy_cerca(lat double precision, lng double precision)
returns jsonb
language sql
stable
security invoker
set search_path = public
as $$ select private.estoy_cerca(lat, lng) $$;

grant execute on function private.estoy_cerca(double precision, double precision) to authenticated;
grant execute on function public.estoy_cerca(double precision, double precision) to authenticated;
