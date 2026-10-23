-- Los turnos programados pueden tener alerta de entrada. Hay que quitarla antes de rearmar el 2x2.

create or replace function private.generar_2x2(p_dia uuid, p_noche uuid, p_desde date)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  i integer;
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
  if p_dia is null or p_noche is null or p_dia = p_noche then
    raise exception 'Elige dos vigilantes distintos.';
  end if;
  if p_desde is null then
    raise exception 'Indica desde qué día arranca el turno.';
  end if;
  if (
    select count(*)
    from public.perfiles p
    join public.perfil_roles pr on pr.perfil_id = p.id
    where p.id in (p_dia, p_noche) and p.activo and pr.rol_id = 'vigilante'
  ) <> 2 then
    raise exception 'Elige dos vigilantes activos.';
  end if;

  select array_agg(t.id) into v_viejos
  from public.turnos t
  where t.vigilante_id in (p_dia, p_noche)
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
    if (i % 4) < 2 then
      v_manana := p_dia;
      v_noche := p_noche;
    else
      v_manana := p_noche;
      v_noche := p_dia;
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
