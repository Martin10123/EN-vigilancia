-- Un solo QR de caseta. Se pega una vez. El escaneo se une al turno abierto de quien lo lee.

alter table public.conjuntos
  add column qr_version integer not null default 1 check (qr_version > 0);

drop function if exists public.token_caseta(uuid);
drop function if exists private.token_caseta(uuid);

create or replace function private.token_caseta()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid := private.conjunto_unico();
  v_version integer;
  v_payload text;
begin
  if not private.es_admin() then
    raise exception 'Solo el administrador puede hacer esto.';
  end if;
  select qr_version into v_version from public.conjuntos where id = v_id;
  if v_id is null or v_version is null then
    raise exception 'No hay conjunto.';
  end if;
  v_payload := 'caseta|' || v_id::text || '|0|' || v_version::text;
  return v_payload || '.' || private.firmar_qr(v_payload);
end;
$$;

create or replace function public.token_caseta()
returns text
language sql
security invoker
set search_path = public
as $$ select private.token_caseta() $$;

create or replace function private.rotar_caseta()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not private.es_admin() then
    raise exception 'Solo el administrador puede hacer esto.';
  end if;
  update public.conjuntos
    set qr_version = qr_version + 1
    where id = private.conjunto_unico();
  if not found then
    raise exception 'No hay conjunto.';
  end if;
end;
$$;

create or replace function public.rotar_caseta()
returns void
language plpgsql
security invoker
set search_path = public
as $$ begin perform private.rotar_caseta(); end $$;

create or replace function private.registrar_evento(
  p_auth_user_id uuid,
  p_clase text,
  p_token text,
  p_lat double precision,
  p_lng double precision,
  p_path text,
  p_hash text,
  p_offline boolean,
  p_tipo text,
  p_descripcion text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_perfil public.perfiles;
  v_qr record;
  v_turno public.turnos;
  v_punto public.puntos_control;
  v_medida record;
  v_abierta record;
  v_ronda uuid;
  v_total integer;
  v_hechos integer;
  v_turno_id uuid;
  v_version integer;
begin
  select * into v_perfil from public.perfiles where auth_user_id = p_auth_user_id and activo;
  if not found then
    raise exception 'No hay un perfil activo para este usuario.';
  end if;
  if v_perfil.aceptado_en is null then
    raise exception 'Acepta el tratamiento de datos antes de registrar.';
  end if;
  if not exists (
    select 1 from public.perfil_roles where perfil_id = v_perfil.id and rol_id = 'vigilante'
  ) then
    raise exception 'Solo un vigilante registra turnos, rondas e incidentes.';
  end if;

  perform private.exigir_coordenadas(p_lat, p_lng);

  if p_clase = 'marcacion' then
    if p_tipo not in ('entrada', 'salida') then
      raise exception 'Indica si es entrada o salida.';
    end if;
    perform private.validar_foto(v_perfil.id, p_path, p_hash, true);
    select * into v_qr from private.leer_qr(p_token);
    if v_qr.tipo <> 'caseta' then
      raise exception 'Ese QR no es el de la caseta.';
    end if;
    if v_qr.ref is distinct from v_perfil.conjunto_id then
      raise exception 'Ese QR no es el de esta caseta.';
    end if;
    select qr_version into v_version from public.conjuntos where id = v_perfil.conjunto_id;
    if v_version is distinct from v_qr.version then
      raise exception 'Este QR ya no sirve. Pide el de la caseta al administrador.';
    end if;
    select * into v_turno
    from public.turnos
    where vigilante_id = v_perfil.id
      and conjunto_id = v_perfil.conjunto_id
      and estado <> 'cancelado'
      and now() >= inicio
      and now() < fin
    order by inicio
    limit 1;
    if not found then
      raise exception 'No tienes un turno abierto en este momento.';
    end if;
    select * into v_medida from private.medir(v_turno.conjunto_id, p_lat, p_lng);
    if not v_medida.aceptado then
      insert into public.alertas (conjunto_id, tipo, turno_id, detalle)
      values (
        v_turno.conjunto_id,
        'fuera_radio',
        v_turno.id,
        'Intento de ' || p_tipo || ' a ' || v_medida.metros || ' m. El radio permitido es ' || v_medida.radio_m || ' m.'
      );
      return jsonb_build_object(
        'ok', false,
        'error', 'Estás fuera del conjunto (' || v_medida.metros || ' m, radio ' || v_medida.radio_m || ' m).'
      );
    end if;
    if p_tipo = 'salida' and not exists (
      select 1 from public.marcaciones where turno_id = v_turno.id and tipo = 'entrada'
    ) then
      raise exception 'Marca la entrada antes de la salida.';
    end if;
    insert into public.marcaciones (
      turno_id, vigilante_id, tipo, dentro_radio, selfie_path, hash, lat, lng, offline
    ) values (
      v_turno.id, v_perfil.id, p_tipo, true, p_path, p_hash, p_lat, p_lng, coalesce(p_offline, false)
    );
    update public.turnos
      set estado = case when p_tipo = 'entrada' then 'en_curso' else 'cerrado' end
      where id = v_turno.id and estado <> 'cancelado';
    return jsonb_build_object('ok', true);

  elsif p_clase = 'escaneo' then
    select * into v_qr from private.leer_qr(p_token);
    if v_qr.tipo <> 'punto' then
      raise exception 'Ese QR no es de un punto de control.';
    end if;
    select * into v_punto from public.puntos_control
    where id = v_qr.ref and conjunto_id = v_perfil.conjunto_id and activo;
    if not found or v_punto.token_version <> v_qr.version then
      raise exception 'Este QR ya no sirve. Pide uno nuevo al administrador.';
    end if;
    select * into v_turno
    from public.turnos
    where vigilante_id = v_perfil.id
      and estado <> 'cancelado'
      and now() >= inicio
      and now() < fin
    order by inicio
    limit 1;
    if not found then
      raise exception 'No tienes un turno abierto en este momento.';
    end if;
    if not exists (select 1 from public.marcaciones where turno_id = v_turno.id and tipo = 'entrada') then
      raise exception 'Marca la entrada antes de la ronda.';
    end if;
    select * into v_abierta from private.ventana_abierta(v_turno.id);
    if not found then
      raise exception 'Ahora no hay una ronda abierta. Si volviste a tener datos tarde, esta ronda ya no se puede completar.';
    end if;
    perform private.validar_foto(v_perfil.id, p_path, p_hash, v_punto.exige_foto);
    select * into v_medida from private.medir(v_turno.conjunto_id, p_lat, p_lng);
    if not v_medida.aceptado then
      insert into public.alertas (conjunto_id, tipo, turno_id, detalle)
      values (
        v_turno.conjunto_id,
        'fuera_radio',
        v_turno.id,
        'Intento de ronda en ' || v_punto.nombre || ' a ' || v_medida.metros || ' m.'
      );
      return jsonb_build_object(
        'ok', false,
        'error', 'Estás fuera del conjunto (' || v_medida.metros || ' m, radio ' || v_medida.radio_m || ' m).'
      );
    end if;

    insert into public.rondas (turno_id, ventana_id)
    values (v_turno.id, v_abierta.ventana_id)
    on conflict (turno_id, ventana_id) do nothing;
    select id into v_ronda from public.rondas
    where turno_id = v_turno.id and ventana_id = v_abierta.ventana_id;

    if exists (select 1 from public.escaneos_punto where ronda_id = v_ronda and punto_id = v_punto.id) then
      raise exception 'Ese punto ya quedó registrado en esta ronda.';
    end if;

    insert into public.escaneos_punto (
      ronda_id, punto_id, vigilante_id, foto_path, hash, lat, lng, dentro_radio, offline
    ) values (
      v_ronda, v_punto.id, v_perfil.id, nullif(p_path, ''), nullif(p_hash, ''), p_lat, p_lng, true, coalesce(p_offline, false)
    );

    select count(*) into v_total from public.puntos_control
    where conjunto_id = v_turno.conjunto_id and activo;
    select count(*) into v_hechos from public.escaneos_punto where ronda_id = v_ronda;
    if v_hechos >= v_total and v_total > 0 then
      update public.rondas set estado = 'completa' where id = v_ronda;
    end if;
    return jsonb_build_object('ok', true, 'punto', v_punto.nombre);

  elsif p_clase = 'incidente' then
    if p_tipo not in ('novedad', 'dano', 'ingreso', 'emergencia', 'otro') then
      raise exception 'Elige un tipo de incidente.';
    end if;
    if char_length(trim(coalesce(p_descripcion, ''))) < 3 then
      raise exception 'Describe el incidente en al menos 3 caracteres.';
    end if;
    perform private.validar_foto(v_perfil.id, p_path, p_hash, true);
    select * into v_medida from private.medir(v_perfil.conjunto_id, p_lat, p_lng);
    if not v_medida.aceptado then
      insert into public.alertas (conjunto_id, tipo, detalle)
      values (
        v_perfil.conjunto_id,
        'fuera_radio',
        'Intento de incidente a ' || v_medida.metros || ' m. El radio permitido es ' || v_medida.radio_m || ' m.'
      );
      return jsonb_build_object(
        'ok', false,
        'error', 'Estás fuera del conjunto (' || v_medida.metros || ' m, radio ' || v_medida.radio_m || ' m).'
      );
    end if;
    select id into v_turno_id
    from public.turnos
    where vigilante_id = v_perfil.id and estado <> 'cancelado' and now() >= inicio and now() < fin
    order by inicio
    limit 1;
    insert into public.incidentes (
      conjunto_id, vigilante_id, turno_id, tipo, descripcion, foto_path, hash, offline
    ) values (
      v_perfil.conjunto_id,
      v_perfil.id,
      v_turno_id,
      p_tipo,
      trim(p_descripcion),
      p_path,
      p_hash,
      coalesce(p_offline, false)
    );
    return jsonb_build_object('ok', true);
  end if;

  raise exception 'No se reconoce el registro.';
exception
  when unique_violation then
    raise exception 'Ese registro ya existe.';
end;
$$;

grant execute on function private.token_caseta() to authenticated;
grant execute on function public.token_caseta() to authenticated;
grant execute on function private.rotar_caseta() to authenticated;
grant execute on function public.rotar_caseta() to authenticated;
