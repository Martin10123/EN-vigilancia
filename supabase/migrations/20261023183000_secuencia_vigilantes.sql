-- La secuencia acepta varios vigilantes. El primero hace dos días y dos noches.
-- Cada siguiente entra dos días después. Siempre queda uno de día y uno de noche.

drop function if exists public.generar_2x2(uuid, uuid, date);
drop function if exists private.generar_2x2(uuid, uuid, date);

create or replace function private.generar_secuencia(p_orden uuid[], p_desde date)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  i integer;
  k integer;
  v_n integer;
  v_ciclo integer;
  v_pos integer;
  v_fecha date;
  v_manana uuid;
  v_noche uuid;
  v_ini timestamptz;
  v_fin timestamptz;
  v_total integer := 0;
  v_conjunto uuid := private.conjunto_unico();
  v_viejos uuid[];
begin
  if not private.es_admin() then
    raise exception 'Solo el administrador puede hacer esto.';
  end if;
  if p_desde is null then
    raise exception 'Indica desde qué día arranca el turno.';
  end if;
  v_n := coalesce(array_length(p_orden, 1), 0);
  if v_n < 2 then
    raise exception 'La secuencia necesita al menos dos vigilantes.';
  end if;
  if exists (select 1 from unnest(p_orden) as id where id is null)
     or (select count(distinct id) from unnest(p_orden) as id) <> v_n then
    raise exception 'Cada vigilante va una sola vez en la secuencia.';
  end if;
  if (
    select count(*)
    from public.perfiles p
    join public.perfil_roles pr on pr.perfil_id = p.id
    where p.id = any (p_orden) and p.activo and pr.rol_id = 'vigilante'
  ) <> v_n then
    raise exception 'Elige vigilantes activos.';
  end if;

  v_ciclo := v_n * 2;

  select array_agg(t.id) into v_viejos
  from public.turnos t
  where t.vigilante_id = any (p_orden)
    and t.estado = 'programado'
    and t.fin > now()
    and not exists (select 1 from public.marcaciones m where m.turno_id = t.id)
    and not exists (select 1 from public.rondas r where r.turno_id = t.id)
    and not exists (select 1 from public.incidentes n where n.turno_id = t.id)
    and not exists (select 1 from public.ayudas y where y.turno_id = t.id);

  if v_viejos is not null then
    delete from public.alertas where turno_id = any (v_viejos);
    delete from public.turnos where id = any (v_viejos);
  end if;

  for i in 0..364 loop
    v_fecha := p_desde + i;
    v_manana := null;
    v_noche := null;
    for k in 1..v_n loop
      v_pos := mod(i - (2 * (k - 1)), v_ciclo);
      if v_pos < 0 then
        v_pos := v_pos + v_ciclo;
      end if;
      if v_pos < 2 then
        v_manana := p_orden[k];
      elsif v_pos < 4 then
        v_noche := p_orden[k];
      end if;
    end loop;
    if v_manana is null or v_noche is null or v_manana = v_noche then
      raise exception 'La secuencia no cubre ese día.';
    end if;

    v_ini := (v_fecha::timestamp + time '06:00') at time zone 'America/Bogota';
    v_fin := (v_fecha::timestamp + time '18:00') at time zone 'America/Bogota';
    if v_fin > now() and not exists (
      select 1 from public.turnos
      where vigilante_id = v_manana
        and estado <> 'cancelado'
        and inicio < v_fin
        and fin > v_ini
    ) then
      insert into public.turnos (conjunto_id, vigilante_id, inicio, fin)
      values (v_conjunto, v_manana, v_ini, v_fin);
      v_total := v_total + 1;
    end if;

    v_ini := (v_fecha::timestamp + time '18:00') at time zone 'America/Bogota';
    v_fin := ((v_fecha + 1)::timestamp + time '06:00') at time zone 'America/Bogota';
    if v_fin > now() and not exists (
      select 1 from public.turnos
      where vigilante_id = v_noche
        and estado <> 'cancelado'
        and inicio < v_fin
        and fin > v_ini
    ) then
      insert into public.turnos (conjunto_id, vigilante_id, inicio, fin)
      values (v_conjunto, v_noche, v_ini, v_fin);
      v_total := v_total + 1;
    end if;
  end loop;

  return v_total;
end;
$$;

create or replace function public.generar_secuencia(orden uuid[], desde date)
returns integer
language sql
security invoker
set search_path = public
as $$ select private.generar_secuencia(orden, desde) $$;

revoke all on function private.generar_secuencia(uuid[], date) from public, anon;
revoke all on function public.generar_secuencia(uuid[], date) from public, anon;
grant execute on function private.generar_secuencia(uuid[], date) to authenticated;
grant execute on function public.generar_secuencia(uuid[], date) to authenticated;
