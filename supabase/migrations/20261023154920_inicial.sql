-- Control de vigilancia del conjunto.
-- La hora oficial, el radio, la firma del QR y el cierre de evidencias viven aquí.
-- No se guarda un recorrido: cada evento trae una sola lectura de ubicación.

create schema if not exists private;

revoke all on schema private from public;
grant usage on schema private to anon, authenticated, service_role;

create extension if not exists pgcrypto with schema extensions;

create table public.roles (
  id text primary key,
  nombre text not null
);

insert into public.roles (id, nombre) values
  ('administrador', 'Administrador'),
  ('vigilante', 'Vigilante'),
  ('residente', 'Residente');

create table public.conjuntos (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  lat double precision,
  lng double precision,
  radio_m integer not null default 150 check (radio_m between 30 and 1000),
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  check (
    (lat is null and lng is null)
    or (lat between -90 and 90 and lng between -180 and 180)
  )
);

create table public.perfiles (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid not null unique references auth.users (id) on delete cascade,
  conjunto_id uuid not null references public.conjuntos (id),
  nombre text not null,
  telefono text,
  activo boolean not null default true,
  aceptado_en timestamptz,
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now()
);

create table public.perfil_roles (
  perfil_id uuid not null references public.perfiles (id) on delete cascade,
  rol_id text not null references public.roles (id),
  primary key (perfil_id, rol_id)
);

create table public.invitaciones (
  id uuid primary key default gen_random_uuid(),
  email text not null,
  creada_por uuid references public.perfiles (id) on delete set null,
  usada boolean not null default false,
  creado_en timestamptz not null default now()
);

create table public.turnos (
  id uuid primary key default gen_random_uuid(),
  conjunto_id uuid not null references public.conjuntos (id),
  vigilante_id uuid not null references public.perfiles (id),
  inicio timestamptz not null,
  fin timestamptz not null,
  estado text not null default 'programado' check (estado in ('programado', 'en_curso', 'cerrado', 'cancelado')),
  creado_en timestamptz not null default now(),
  check (fin > inicio)
);

create table public.puntos_control (
  id uuid primary key default gen_random_uuid(),
  conjunto_id uuid not null references public.conjuntos (id),
  nombre text not null,
  orden integer not null default 1,
  exige_foto boolean not null default false,
  activo boolean not null default true,
  token_version integer not null default 1 check (token_version > 0),
  unique (conjunto_id, nombre)
);

create table public.ventanas_ronda (
  id uuid primary key default gen_random_uuid(),
  conjunto_id uuid not null references public.conjuntos (id),
  nombre text not null,
  hora_inicio time not null,
  hora_fin time not null,
  orden integer not null default 1,
  check (hora_inicio <> hora_fin)
);

create table public.rondas (
  id uuid primary key default gen_random_uuid(),
  turno_id uuid not null references public.turnos (id),
  ventana_id uuid not null references public.ventanas_ronda (id),
  estado text not null default 'pendiente' check (estado in ('pendiente', 'completa', 'incompleta')),
  unique (turno_id, ventana_id)
);

create table public.marcaciones (
  id uuid primary key default gen_random_uuid(),
  turno_id uuid not null references public.turnos (id),
  vigilante_id uuid not null references public.perfiles (id),
  tipo text not null check (tipo in ('entrada', 'salida')),
  dentro_radio boolean not null,
  selfie_path text not null,
  hash text not null,
  lat double precision not null,
  lng double precision not null,
  offline boolean not null default false,
  capturado_en timestamptz not null default now(),
  sincronizado_en timestamptz not null default now(),
  unique (turno_id, tipo)
);

create table public.escaneos_punto (
  id uuid primary key default gen_random_uuid(),
  ronda_id uuid not null references public.rondas (id),
  punto_id uuid not null references public.puntos_control (id),
  vigilante_id uuid not null references public.perfiles (id),
  foto_path text,
  hash text,
  lat double precision not null,
  lng double precision not null,
  dentro_radio boolean not null,
  offline boolean not null default false,
  capturado_en timestamptz not null default now(),
  sincronizado_en timestamptz not null default now(),
  unique (ronda_id, punto_id)
);

create table public.incidentes (
  id uuid primary key default gen_random_uuid(),
  conjunto_id uuid not null references public.conjuntos (id),
  vigilante_id uuid not null references public.perfiles (id),
  turno_id uuid references public.turnos (id),
  tipo text not null check (tipo in ('novedad', 'dano', 'ingreso', 'emergencia', 'otro')),
  descripcion text not null check (char_length(descripcion) between 3 and 1000),
  foto_path text not null,
  hash text not null,
  offline boolean not null default false,
  capturado_en timestamptz not null default now(),
  sincronizado_en timestamptz not null default now()
);

create table public.alertas (
  id uuid primary key default gen_random_uuid(),
  conjunto_id uuid not null references public.conjuntos (id),
  tipo text not null check (tipo in ('sin_entrada', 'ronda_incompleta', 'fuera_radio')),
  turno_id uuid references public.turnos (id),
  ventana_id uuid references public.ventanas_ronda (id),
  detalle text not null,
  leida boolean not null default false,
  creada_en timestamptz not null default now()
);

create table public.ayudas (
  id uuid primary key default gen_random_uuid(),
  residente_id uuid not null references public.perfiles (id),
  vigilante_id uuid not null references public.perfiles (id),
  turno_id uuid references public.turnos (id),
  canal text not null check (canal in ('llamada', 'mensaje')),
  creado_en timestamptz not null default now()
);

create unique index alertas_sin_entrada_idx on public.alertas (turno_id) where tipo = 'sin_entrada';
create unique index alertas_ronda_idx on public.alertas (turno_id, ventana_id) where tipo = 'ronda_incompleta';
create index turnos_vigilante_idx on public.turnos (vigilante_id, inicio);
create index invitaciones_email_idx on public.invitaciones (lower(email)) where usada = false;

create table private.secretos (
  clave text primary key,
  valor text not null
);

insert into private.secretos (clave, valor)
values ('qr', encode(extensions.gen_random_bytes(32), 'hex'));

revoke all on table private.secretos from public, anon, authenticated;

insert into public.conjuntos (nombre, radio_m)
values ('Conjunto residencial', 150);

insert into public.ventanas_ronda (conjunto_id, nombre, hora_inicio, hora_fin, orden)
select id, 'Primera ronda', '20:00', '22:00', 1 from public.conjuntos
union all
select id, 'Segunda ronda', '02:00', '04:00', 2 from public.conjuntos;

create or replace function private.perfil_actual()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select id from public.perfiles where auth_user_id = auth.uid() and activo
$$;

create or replace function private.es_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.perfiles p
    join public.perfil_roles pr on pr.perfil_id = p.id
    where p.auth_user_id = auth.uid()
      and p.activo
      and pr.rol_id = 'administrador'
  );
$$;

create or replace function private.tiene_rol(rol text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.perfiles p
    join public.perfil_roles pr on pr.perfil_id = p.id
    where p.auth_user_id = auth.uid()
      and p.activo
      and pr.rol_id = tiene_rol.rol
  );
$$;

create or replace function private.hay_administrador()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.perfil_roles where rol_id = 'administrador');
$$;

create or replace function private.conjunto_unico()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select id from public.conjuntos order by creado_en limit 1
$$;

create or replace function private.ruta_propia(p_ruta text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select p_ruta is not null
    and p_ruta !~ '\.\.'
    and lower(split_part(p_ruta, '/', 1)) = private.perfil_actual()::text;
$$;

create or replace function private.firmar_qr(p_payload text)
returns text
language sql
stable
security definer
set search_path = public, extensions
as $$
  select encode(
    extensions.hmac(
      convert_to(p_payload, 'utf8'),
      convert_to((select valor from private.secretos where clave = 'qr'), 'utf8'),
      'sha256'
    ),
    'hex'
  );
$$;

create or replace function private.leer_qr(p_token text)
returns table (tipo text, ref uuid, exp bigint, version integer)
language plpgsql
stable
security definer
set search_path = public, extensions
as $$
declare
  v_payload text;
  v_firma text;
  v_partes text[];
begin
  if p_token is null or position('.' in p_token) = 0 or split_part(p_token, '.', 3) <> '' then
    raise exception 'QR inválido.';
  end if;
  v_payload := split_part(p_token, '.', 1);
  v_firma := split_part(p_token, '.', 2);
  if v_firma is distinct from private.firmar_qr(v_payload) or length(v_firma) <> 64 then
    raise exception 'QR inválido.';
  end if;
  v_partes := string_to_array(v_payload, '|');
  if cardinality(v_partes) <> 4 or v_partes[1] not in ('caseta', 'punto') then
    raise exception 'QR inválido.';
  end if;
  tipo := v_partes[1];
  ref := v_partes[2]::uuid;
  exp := v_partes[3]::bigint;
  version := v_partes[4]::integer;
  return next;
exception
  when invalid_text_representation then
    raise exception 'QR inválido.';
end;
$$;

create or replace function private.ocurre_en_turno(p_inicio timestamptz, p_fin timestamptz, p_hora time)
returns timestamptz
language plpgsql
stable
set search_path = public
as $$
declare
  dia date;
  candidato timestamptz;
begin
  if p_inicio is null or p_fin is null or p_hora is null then
    return null;
  end if;
  dia := (p_inicio at time zone 'America/Bogota')::date;
  while dia <= (p_fin at time zone 'America/Bogota')::date loop
    candidato := (dia::timestamp + p_hora) at time zone 'America/Bogota';
    if candidato >= p_inicio and candidato < p_fin then
      return candidato;
    end if;
    dia := dia + 1;
    if dia > (p_inicio at time zone 'America/Bogota')::date + 3 then
      exit;
    end if;
  end loop;
  return null;
end;
$$;

create or replace function private.ventana_en_turno(
  p_inicio timestamptz,
  p_fin timestamptz,
  p_hora_ini time,
  p_hora_fin time
)
returns table (abre timestamptz, cierra timestamptz)
language plpgsql
stable
set search_path = public
as $$
declare
  v_abre timestamptz;
  v_cierra timestamptz;
begin
  v_abre := private.ocurre_en_turno(p_inicio, p_fin, p_hora_ini);
  if v_abre is null then
    return;
  end if;
  if p_hora_fin > p_hora_ini then
    v_cierra := (((v_abre at time zone 'America/Bogota')::date)::timestamp + p_hora_fin) at time zone 'America/Bogota';
  else
    v_cierra := ((((v_abre at time zone 'America/Bogota')::date + 1))::timestamp + p_hora_fin) at time zone 'America/Bogota';
  end if;
  if v_cierra > p_fin then
    v_cierra := p_fin;
  end if;
  if v_cierra <= v_abre then
    return;
  end if;
  abre := v_abre;
  cierra := v_cierra;
  return next;
end;
$$;

create or replace function private.ventana_abierta(p_turno uuid)
returns table (ventana_id uuid, nombre text, abre timestamptz, cierra timestamptz)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_turno public.turnos;
  v_ventana public.ventanas_ronda;
  v_abre timestamptz;
  v_cierra timestamptz;
begin
  select * into v_turno from public.turnos where id = p_turno;
  if not found then
    return;
  end if;
  for v_ventana in
    select * from public.ventanas_ronda where conjunto_id = v_turno.conjunto_id order by orden
  loop
    select w.abre, w.cierra into v_abre, v_cierra
    from private.ventana_en_turno(v_turno.inicio, v_turno.fin, v_ventana.hora_inicio, v_ventana.hora_fin) w;
    if v_abre is not null and now() >= v_abre and now() < v_cierra then
      ventana_id := v_ventana.id;
      nombre := v_ventana.nombre;
      abre := v_abre;
      cierra := v_cierra;
      return next;
      return;
    end if;
  end loop;
end;
$$;

create or replace function private.exigir_coordenadas(p_lat double precision, p_lng double precision)
returns void
language plpgsql
immutable
as $$
begin
  if p_lat is null or p_lng is null or p_lat < -90 or p_lat > 90 or p_lng < -180 or p_lng > 180 then
    raise exception 'Se necesita la ubicación de este momento. No se guarda un recorrido.';
  end if;
end;
$$;

create or replace function private.medir(p_conjunto uuid, p_lat double precision, p_lng double precision)
returns table (metros numeric, radio_m integer, aceptado boolean)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_lat double precision;
  v_lng double precision;
  v_radio integer;
  v_metros numeric;
begin
  select c.lat, c.lng, c.radio_m into v_lat, v_lng, v_radio
  from public.conjuntos c
  where c.id = p_conjunto;
  if v_lat is null or v_lng is null then
    raise exception 'El administrador todavía no guardó la ubicación del conjunto.';
  end if;
  v_metros := 6371000 * 2 * asin(least(1::numeric, sqrt(
    power(sin(radians(p_lat - v_lat) / 2), 2)
    + cos(radians(v_lat)) * cos(radians(p_lat)) * power(sin(radians(p_lng - v_lng) / 2), 2)
  )::numeric));
  metros := round(v_metros);
  radio_m := v_radio;
  aceptado := v_metros <= v_radio;
  return next;
end;
$$;

create or replace function private.validar_foto(p_perfil uuid, p_path text, p_hash text, p_obligatoria boolean)
returns void
language plpgsql
immutable
as $$
begin
  if not p_obligatoria and nullif(p_path, '') is null and nullif(p_hash, '') is null then
    return;
  end if;
  if nullif(p_path, '') is null or nullif(p_hash, '') is null then
    raise exception 'La foto tiene que llegar completa.';
  end if;
  if p_path !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.jpg$' then
    raise exception 'La foto no tiene una ruta válida.';
  end if;
  if split_part(p_path, '/', 1)::uuid <> p_perfil then
    raise exception 'La foto no corresponde a este usuario.';
  end if;
  if p_hash !~ '^[0-9a-f]{64}$' then
    raise exception 'La foto no trae un hash válido.';
  end if;
end;
$$;

create or replace function private.proteger_perfil()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.auth_user_id is distinct from old.auth_user_id or new.conjunto_id is distinct from old.conjunto_id then
    raise exception 'No puedes cambiar la cuenta ni el conjunto.';
  end if;
  if not private.es_admin() and new.activo is distinct from old.activo then
    raise exception 'No puedes cambiar tu estado.';
  end if;
  return new;
end;
$$;

create trigger perfiles_proteger
  before update on public.perfiles
  for each row execute function private.proteger_perfil();

create or replace function private.bloquear_evidencia()
returns trigger
language plpgsql
as $$
begin
  raise exception 'Este registro no se puede modificar.';
end;
$$;

create trigger marcaciones_bloquear
  before update or delete on public.marcaciones
  for each row execute function private.bloquear_evidencia();

create trigger escaneos_bloquear
  before update or delete on public.escaneos_punto
  for each row execute function private.bloquear_evidencia();

create trigger incidentes_bloquear
  before update or delete on public.incidentes
  for each row execute function private.bloquear_evidencia();

create or replace function private.proteger_alerta()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not private.es_admin() then
    raise exception 'Solo el administrador revisa las alertas.';
  end if;
  if new.tipo is distinct from old.tipo
    or new.turno_id is distinct from old.turno_id
    or new.ventana_id is distinct from old.ventana_id
    or new.detalle is distinct from old.detalle
    or new.conjunto_id is distinct from old.conjunto_id
    or new.creada_en is distinct from old.creada_en then
    raise exception 'Solo se puede marcar la alerta como leída.';
  end if;
  return new;
end;
$$;

create trigger alertas_proteger
  before update on public.alertas
  for each row execute function private.proteger_alerta();

create or replace function private.alta_perfil()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  nuevo uuid;
  hay_admin boolean;
  conjunto uuid;
begin
  select private.hay_administrador() into hay_admin;
  if hay_admin and not exists (
    select 1 from public.invitaciones
    where lower(email) = lower(new.email) and usada = false
  ) then
    raise exception 'El registro está cerrado. Pide al administrador que cree tu usuario.';
  end if;

  conjunto := private.conjunto_unico();
  insert into public.perfiles (auth_user_id, conjunto_id, nombre)
  values (
    new.id,
    conjunto,
    coalesce(nullif(new.raw_user_meta_data ->> 'nombre', ''), split_part(new.email, '@', 1))
  )
  returning id into nuevo;

  if hay_admin then
    update public.invitaciones
      set usada = true
      where lower(email) = lower(new.email) and usada = false;
    insert into public.perfil_roles (perfil_id, rol_id) values (nuevo, 'vigilante');
  else
    insert into public.perfil_roles (perfil_id, rol_id) values (nuevo, 'administrador');
  end if;
  return new;
end;
$$;

create trigger alta_perfil_al_crear_usuario
  after insert on auth.users
  for each row execute function private.alta_perfil();

create or replace function private.aceptar_datos()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_perfil uuid := private.perfil_actual();
begin
  if v_perfil is null then
    raise exception 'No hay un perfil activo para este usuario.';
  end if;
  update public.perfiles
    set aceptado_en = coalesce(aceptado_en, now()), actualizado_en = now()
    where id = v_perfil;
end;
$$;

create or replace function private.actualizar_mi_perfil(p_nombre text, p_telefono text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_perfil uuid := private.perfil_actual();
begin
  if v_perfil is null then
    raise exception 'No hay un perfil activo para este usuario.';
  end if;
  if char_length(trim(p_nombre)) < 3 then
    raise exception 'El nombre necesita al menos 3 caracteres.';
  end if;
  update public.perfiles
    set nombre = trim(p_nombre),
        telefono = nullif(trim(p_telefono), ''),
        actualizado_en = now()
    where id = v_perfil;
end;
$$;

create or replace function private.datos_conjunto()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_fila public.conjuntos;
begin
  if private.perfil_actual() is null then
    raise exception 'No hay un perfil activo para este usuario.';
  end if;
  select * into v_fila from public.conjuntos order by creado_en limit 1;
  return jsonb_build_object(
    'id', v_fila.id,
    'nombre', v_fila.nombre,
    'radio_m', v_fila.radio_m,
    'lat', case when private.es_admin() then v_fila.lat end,
    'lng', case when private.es_admin() then v_fila.lng end
  );
end;
$$;

create or replace function private.guardar_conjunto(p_nombre text, p_lat double precision, p_lng double precision, p_radio integer)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not private.es_admin() then
    raise exception 'Solo el administrador puede hacer esto.';
  end if;
  if char_length(trim(p_nombre)) < 3 then
    raise exception 'El nombre del conjunto es muy corto.';
  end if;
  if p_radio is null or p_radio < 30 or p_radio > 1000 then
    raise exception 'El radio debe estar entre 30 y 1000 metros.';
  end if;
  if p_lat is null or p_lng is null or p_lat < -90 or p_lat > 90 or p_lng < -180 or p_lng > 180 then
    raise exception 'Indica la latitud y la longitud de la caseta.';
  end if;
  update public.conjuntos
    set nombre = trim(p_nombre), lat = p_lat, lng = p_lng, radio_m = p_radio, actualizado_en = now()
    where id = private.conjunto_unico();
end;
$$;

create or replace function private.guardar_acceso(p_perfil uuid, p_roles text[], p_activo boolean, p_telefono text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not private.es_admin() then
    raise exception 'Solo el administrador puede hacer esto.';
  end if;
  if p_roles is null or cardinality(p_roles) = 0 then
    raise exception 'Asigna al menos un rol.';
  end if;
  if exists (
    select 1 from unnest(p_roles) rol
    where rol not in ('administrador', 'vigilante', 'residente')
  ) then
    raise exception 'Hay un rol que no existe.';
  end if;
  if not exists (select 1 from public.perfiles where id = p_perfil) then
    raise exception 'No se encontró el usuario.';
  end if;

  update public.perfiles
    set activo = p_activo,
        telefono = nullif(trim(p_telefono), ''),
        actualizado_en = now()
    where id = p_perfil;
  delete from public.perfil_roles where perfil_id = p_perfil;
  insert into public.perfil_roles (perfil_id, rol_id)
  select p_perfil, rol from unnest(p_roles) rol;

  if (
    select count(*)
    from public.perfiles p
    join public.perfil_roles pr on pr.perfil_id = p.id
    where pr.rol_id = 'administrador' and p.activo
  ) < 1 then
    raise exception 'Tiene que quedar al menos un administrador activo.';
  end if;
end;
$$;

create or replace function private.crear_turno(p_vigilante uuid, p_inicio timestamptz, p_fin timestamptz)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  nuevo uuid;
begin
  if not private.es_admin() then
    raise exception 'Solo el administrador puede hacer esto.';
  end if;
  if p_fin <= p_inicio then
    raise exception 'La salida del turno tiene que ser después de la entrada.';
  end if;
  if p_fin - p_inicio < interval '1 hour' or p_fin - p_inicio > interval '14 hours' then
    raise exception 'El turno debe durar entre 1 y 14 horas.';
  end if;
  if not exists (
    select 1
    from public.perfiles p
    join public.perfil_roles pr on pr.perfil_id = p.id
    where p.id = p_vigilante and p.activo and pr.rol_id = 'vigilante'
  ) then
    raise exception 'Elige un vigilante activo.';
  end if;
  if exists (
    select 1 from public.turnos
    where vigilante_id = p_vigilante
      and estado <> 'cancelado'
      and inicio < p_fin
      and fin > p_inicio
  ) then
    raise exception 'Ese vigilante ya tiene un turno en ese horario.';
  end if;

  insert into public.turnos (conjunto_id, vigilante_id, inicio, fin)
  values (private.conjunto_unico(), p_vigilante, p_inicio, p_fin)
  returning id into nuevo;
  return nuevo;
end;
$$;

create or replace function private.cancelar_turno(p_turno uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not private.es_admin() then
    raise exception 'Solo el administrador puede hacer esto.';
  end if;
  update public.turnos
    set estado = 'cancelado'
    where id = p_turno and estado = 'programado';
  if not found then
    raise exception 'Solo se puede cancelar un turno que todavía no empezó.';
  end if;
end;
$$;

create or replace function private.guardar_punto(p_punto uuid, p_nombre text, p_orden integer, p_exige boolean)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  nuevo uuid;
begin
  if not private.es_admin() then
    raise exception 'Solo el administrador puede hacer esto.';
  end if;
  if char_length(trim(p_nombre)) < 2 then
    raise exception 'El punto necesita un nombre.';
  end if;
  if p_punto is null then
    insert into public.puntos_control (conjunto_id, nombre, orden, exige_foto)
    values (private.conjunto_unico(), trim(p_nombre), coalesce(p_orden, 1), coalesce(p_exige, false))
    returning id into nuevo;
    return nuevo;
  end if;
  update public.puntos_control
    set nombre = trim(p_nombre), orden = coalesce(p_orden, orden), exige_foto = coalesce(p_exige, exige_foto)
    where id = p_punto and conjunto_id = private.conjunto_unico()
    returning id into nuevo;
  if nuevo is null then
    raise exception 'No se encontró el punto.';
  end if;
  return nuevo;
end;
$$;

create or replace function private.desactivar_punto(p_punto uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not private.es_admin() then
    raise exception 'Solo el administrador puede hacer esto.';
  end if;
  update public.puntos_control
    set activo = false
    where id = p_punto and conjunto_id = private.conjunto_unico();
end;
$$;

create or replace function private.rotar_punto(p_punto uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not private.es_admin() then
    raise exception 'Solo el administrador puede hacer esto.';
  end if;
  update public.puntos_control
    set token_version = token_version + 1
    where id = p_punto and conjunto_id = private.conjunto_unico() and activo;
  if not found then
    raise exception 'No se encontró el punto.';
  end if;
end;
$$;

create or replace function private.guardar_ventana(
  p_ventana uuid,
  p_nombre text,
  p_hora_inicio time,
  p_hora_fin time,
  p_orden integer
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  nuevo uuid;
begin
  if not private.es_admin() then
    raise exception 'Solo el administrador puede hacer esto.';
  end if;
  if char_length(trim(p_nombre)) < 2 or p_hora_inicio is null or p_hora_fin is null or p_hora_inicio = p_hora_fin then
    raise exception 'Completa el nombre y dos horas distintas.';
  end if;
  if p_ventana is null then
    insert into public.ventanas_ronda (conjunto_id, nombre, hora_inicio, hora_fin, orden)
    values (private.conjunto_unico(), trim(p_nombre), p_hora_inicio, p_hora_fin, coalesce(p_orden, 1))
    returning id into nuevo;
    return nuevo;
  end if;
  update public.ventanas_ronda
    set nombre = trim(p_nombre), hora_inicio = p_hora_inicio, hora_fin = p_hora_fin, orden = coalesce(p_orden, orden)
    where id = p_ventana and conjunto_id = private.conjunto_unico()
    returning id into nuevo;
  if nuevo is null then
    raise exception 'No se encontró la ventana.';
  end if;
  return nuevo;
end;
$$;

create or replace function private.borrar_ventana(p_ventana uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not private.es_admin() then
    raise exception 'Solo el administrador puede hacer esto.';
  end if;
  if exists (select 1 from public.rondas where ventana_id = p_ventana) then
    raise exception 'Esa ventana ya tiene rondas registradas.';
  end if;
  delete from public.alertas where ventana_id = p_ventana and tipo = 'ronda_incompleta';
  delete from public.ventanas_ronda
    where id = p_ventana and conjunto_id = private.conjunto_unico();
end;
$$;

create or replace function private.token_caseta(p_turno uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_fin timestamptz;
  v_payload text;
begin
  if not private.es_admin() then
    raise exception 'Solo el administrador puede hacer esto.';
  end if;
  select fin into v_fin from public.turnos
  where id = p_turno and conjunto_id = private.conjunto_unico() and estado <> 'cancelado';
  if v_fin is null then
    raise exception 'No se encontró el turno.';
  end if;
  v_payload := 'caseta|' || p_turno::text || '|' || floor(extract(epoch from v_fin))::bigint::text || '|0';
  return v_payload || '.' || private.firmar_qr(v_payload);
end;
$$;

create or replace function private.token_punto(p_punto uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_version integer;
  v_payload text;
begin
  if not private.es_admin() then
    raise exception 'Solo el administrador puede hacer esto.';
  end if;
  select token_version into v_version
  from public.puntos_control
  where id = p_punto and conjunto_id = private.conjunto_unico() and activo;
  if v_version is null then
    raise exception 'No se encontró el punto.';
  end if;
  v_payload := 'punto|' || p_punto::text || '|0|' || v_version::text;
  return v_payload || '.' || private.firmar_qr(v_payload);
end;
$$;

create or replace function private.estado_ronda(p_turno uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_perfil uuid := private.perfil_actual();
  v_turno public.turnos;
  v_abierta record;
  v_ronda uuid;
begin
  if v_perfil is null or not private.tiene_rol('vigilante') then
    raise exception 'Solo un vigilante consulta la ronda.';
  end if;
  select * into v_turno from public.turnos
  where id = p_turno and vigilante_id = v_perfil and estado <> 'cancelado';
  if not found then
    raise exception 'Ese turno no es tuyo.';
  end if;
  if not exists (select 1 from public.marcaciones where turno_id = v_turno.id and tipo = 'entrada') then
    return jsonb_build_object('fuera', true, 'mensaje', 'Marca la entrada antes de la ronda.');
  end if;
  if exists (select 1 from public.marcaciones where turno_id = v_turno.id and tipo = 'salida') then
    return jsonb_build_object('fuera', true, 'mensaje', 'Este turno ya tiene salida.');
  end if;

  select * into v_abierta from private.ventana_abierta(v_turno.id);
  if not found then
    return jsonb_build_object('fuera', true, 'mensaje', 'Ahora no hay una ronda abierta. Revisa las ventanas del turno.');
  end if;

  select id into v_ronda from public.rondas
  where turno_id = v_turno.id and ventana_id = v_abierta.ventana_id;

  return jsonb_build_object(
    'fuera', false,
    'turno_id', v_turno.id,
    'ventana', jsonb_build_object(
      'id', v_abierta.ventana_id,
      'nombre', v_abierta.nombre
    ),
    'puntos', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', p.id,
          'nombre', p.nombre,
          'orden', p.orden,
          'exige_foto', p.exige_foto,
          'escaneado', exists (
            select 1 from public.escaneos_punto e
            where e.ronda_id = v_ronda and e.punto_id = p.id
          )
        )
        order by p.orden
      )
      from public.puntos_control p
      where p.conjunto_id = v_turno.conjunto_id and p.activo
    ), '[]'::jsonb)
  );
end;
$$;

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
    select * into v_turno from public.turnos
    where id = v_qr.ref and vigilante_id = v_perfil.id and estado <> 'cancelado';
    if not found then
      raise exception 'Ese QR no corresponde a tu turno.';
    end if;
    if abs(extract(epoch from v_turno.fin) - v_qr.exp) > 2 then
      raise exception 'Ese QR de la caseta ya no sirve. Imprime el del turno vigente.';
    end if;
    if now() < v_turno.inicio then
      raise exception 'El turno todavía no empieza.';
    end if;
    if now() >= v_turno.fin then
      raise exception 'El turno ya terminó. Si estabas sin datos, esta marcación no se puede verificar.';
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

create or replace function private.revisar_alertas()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_turno public.turnos;
  v_ventana public.ventanas_ronda;
  v_abre timestamptz;
  v_cierra timestamptz;
  v_total integer;
  v_hechos integer;
  v_ronda uuid;
begin
  if not private.es_admin() then
    raise exception 'Solo el administrador revisa las alertas.';
  end if;

  insert into public.alertas (conjunto_id, tipo, turno_id, detalle)
  select t.conjunto_id, 'sin_entrada', t.id, 'No marcó entrada pasados 15 minutos del inicio del turno.'
  from public.turnos t
  where t.estado <> 'cancelado'
    and now() > t.inicio + interval '15 minutes'
    and now() < t.fin
    and not exists (
      select 1 from public.marcaciones m where m.turno_id = t.id and m.tipo = 'entrada'
    )
  on conflict (turno_id) where tipo = 'sin_entrada' do nothing;

  for v_turno in
    select * from public.turnos
    where estado <> 'cancelado'
      and inicio < now()
      and fin > now() - interval '2 days'
  loop
    for v_ventana in
      select * from public.ventanas_ronda where conjunto_id = v_turno.conjunto_id order by orden
    loop
      select w.abre, w.cierra into v_abre, v_cierra
      from private.ventana_en_turno(v_turno.inicio, v_turno.fin, v_ventana.hora_inicio, v_ventana.hora_fin) w;
      if v_cierra is null or now() < v_cierra then
        continue;
      end if;
      select count(*) into v_total from public.puntos_control
      where conjunto_id = v_turno.conjunto_id and activo;
      select id into v_ronda from public.rondas
      where turno_id = v_turno.id and ventana_id = v_ventana.id;
      select count(*) into v_hechos from public.escaneos_punto where ronda_id = v_ronda;
      if v_total > 0 and (v_ronda is null or v_hechos < v_total) then
        if v_ronda is not null then
          update public.rondas set estado = 'incompleta' where id = v_ronda and estado = 'pendiente';
        end if;
        insert into public.alertas (conjunto_id, tipo, turno_id, ventana_id, detalle)
        values (
          v_turno.conjunto_id,
          'ronda_incompleta',
          v_turno.id,
          v_ventana.id,
          'La ronda "' || v_ventana.nombre || '" no se completó en su ventana.'
        )
        on conflict (turno_id, ventana_id) where tipo = 'ronda_incompleta' do nothing;
      end if;
    end loop;
  end loop;
end;
$$;

create or replace function private.marcar_alerta_leida(p_alerta uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not private.es_admin() then
    raise exception 'Solo el administrador revisa las alertas.';
  end if;
  update public.alertas set leida = true where id = p_alerta;
end;
$$;

create or replace function private.vigilantes_en_turno()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if private.perfil_actual() is null then
    raise exception 'No hay un perfil activo para este usuario.';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'turno_id', t.id,
      'vigilante_id', p.id,
      'nombre', p.nombre,
      'telefono', p.telefono,
      'en_puesto', exists (
        select 1 from public.marcaciones m
        where m.turno_id = t.id and m.tipo = 'entrada'
      ) and not exists (
        select 1 from public.marcaciones m
        where m.turno_id = t.id and m.tipo = 'salida'
      )
    ) order by p.nombre)
    from public.turnos t
    join public.perfiles p on p.id = t.vigilante_id
    where t.estado <> 'cancelado'
      and p.activo
      and now() >= t.inicio
      and now() < t.fin
  ), '[]'::jsonb);
end;
$$;

create or replace function private.registrar_ayuda(p_vigilante uuid, p_canal text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_residente uuid := private.perfil_actual();
  v_telefono text;
  v_nombre text;
  v_turno uuid;
begin
  if v_residente is null or not private.tiene_rol('residente') then
    raise exception 'Solo un residente usa el botón de ayuda.';
  end if;
  if (select aceptado_en from public.perfiles where id = v_residente) is null then
    raise exception 'Acepta el tratamiento de datos antes de pedir ayuda.';
  end if;
  if p_canal not in ('llamada', 'mensaje') then
    raise exception 'Elige llamada o mensaje.';
  end if;
  select p.telefono, p.nombre, t.id
    into v_telefono, v_nombre, v_turno
  from public.turnos t
  join public.perfiles p on p.id = t.vigilante_id
  where t.vigilante_id = p_vigilante
    and t.estado <> 'cancelado'
    and now() >= t.inicio
    and now() < t.fin
    and p.activo
  limit 1;
  if v_turno is null then
    raise exception 'Ese vigilante no está de turno.';
  end if;
  if nullif(v_telefono, '') is null then
    raise exception 'Ese vigilante no tiene teléfono cargado.';
  end if;
  insert into public.ayudas (residente_id, vigilante_id, turno_id, canal)
  values (v_residente, p_vigilante, v_turno, p_canal);
  return jsonb_build_object('nombre', v_nombre, 'telefono', v_telefono);
end;
$$;

-- La vista la ejecuta el dueño para poder mostrar el teléfono solo a quien corresponde.
create or replace view public.perfiles_directorio
with (security_invoker = false, security_barrier = true) as
select
  p.id,
  p.nombre,
  p.activo,
  p.conjunto_id,
  case when p.id = private.perfil_actual() or private.es_admin() then p.telefono end as telefono,
  case when p.id = private.perfil_actual() or private.es_admin() then p.aceptado_en end as aceptado_en
from public.perfiles p
where private.es_admin() or p.id = private.perfil_actual();

alter table public.roles enable row level security;
alter table public.conjuntos enable row level security;
alter table public.perfiles enable row level security;
alter table public.perfil_roles enable row level security;
alter table public.invitaciones enable row level security;
alter table public.turnos enable row level security;
alter table public.puntos_control enable row level security;
alter table public.ventanas_ronda enable row level security;
alter table public.rondas enable row level security;
alter table public.marcaciones enable row level security;
alter table public.escaneos_punto enable row level security;
alter table public.incidentes enable row level security;
alter table public.alertas enable row level security;
alter table public.ayudas enable row level security;

create policy roles_lectura on public.roles for select to authenticated using (true);
create policy conjuntos_lectura on public.conjuntos for select to authenticated using (true);
create policy puntos_lectura on public.puntos_control for select to authenticated using (true);
create policy ventanas_lectura on public.ventanas_ronda for select to authenticated using (true);

create policy perfiles_lectura on public.perfiles
  for select to authenticated
  using (id = private.perfil_actual() or private.es_admin());

create policy perfil_roles_lectura on public.perfil_roles
  for select to authenticated
  using (perfil_id = private.perfil_actual() or private.es_admin());

create policy turnos_lectura on public.turnos
  for select to authenticated
  using (vigilante_id = private.perfil_actual() or private.es_admin());

create policy rondas_lectura on public.rondas
  for select to authenticated
  using (
    private.es_admin()
    or exists (
      select 1 from public.turnos t
      where t.id = rondas.turno_id and t.vigilante_id = private.perfil_actual()
    )
  );

create policy marcaciones_lectura on public.marcaciones
  for select to authenticated
  using (vigilante_id = private.perfil_actual() or private.es_admin());

create policy escaneos_lectura on public.escaneos_punto
  for select to authenticated
  using (vigilante_id = private.perfil_actual() or private.es_admin());

create policy incidentes_lectura on public.incidentes
  for select to authenticated
  using (vigilante_id = private.perfil_actual() or private.es_admin());

create policy alertas_lectura on public.alertas
  for select to authenticated
  using (private.es_admin());

create policy alertas_leida on public.alertas
  for update to authenticated
  using (private.es_admin())
  with check (private.es_admin());

create policy ayudas_lectura on public.ayudas
  for select to authenticated
  using (residente_id = private.perfil_actual() or private.es_admin());

insert into storage.buckets (id, name, public)
values ('evidencias', 'evidencias', false)
on conflict (id) do nothing;

create policy evidencias_leer on storage.objects
  for select to authenticated
  using (
    bucket_id = 'evidencias'
    and (private.es_admin() or private.ruta_propia(name))
  );

create or replace function public.hay_administrador()
returns boolean language sql stable security invoker set search_path = public
as $$ select private.hay_administrador() $$;

create or replace function public.aceptar_datos()
returns void language plpgsql security invoker set search_path = public
as $$ begin perform private.aceptar_datos(); end $$;

create or replace function public.actualizar_mi_perfil(nombre text, telefono text)
returns void language plpgsql security invoker set search_path = public
as $$ begin perform private.actualizar_mi_perfil(nombre, telefono); end $$;

create or replace function public.datos_conjunto()
returns jsonb language sql stable security invoker set search_path = public
as $$ select private.datos_conjunto() $$;

create or replace function public.guardar_conjunto(nombre text, lat double precision, lng double precision, radio_m integer)
returns void language plpgsql security invoker set search_path = public
as $$ begin perform private.guardar_conjunto(nombre, lat, lng, radio_m); end $$;

create or replace function public.guardar_acceso(perfil_id uuid, roles text[], activo boolean, telefono text)
returns void language plpgsql security invoker set search_path = public
as $$ begin perform private.guardar_acceso(perfil_id, roles, activo, telefono); end $$;

create or replace function public.crear_turno(vigilante_id uuid, inicio timestamptz, fin timestamptz)
returns uuid language sql security invoker set search_path = public
as $$ select private.crear_turno(vigilante_id, inicio, fin) $$;

create or replace function public.cancelar_turno(turno_id uuid)
returns void language plpgsql security invoker set search_path = public
as $$ begin perform private.cancelar_turno(turno_id); end $$;

create or replace function public.guardar_punto(punto_id uuid, nombre text, orden integer, exige_foto boolean)
returns uuid language sql security invoker set search_path = public
as $$ select private.guardar_punto(punto_id, nombre, orden, exige_foto) $$;

create or replace function public.desactivar_punto(punto_id uuid)
returns void language plpgsql security invoker set search_path = public
as $$ begin perform private.desactivar_punto(punto_id); end $$;

create or replace function public.rotar_punto(punto_id uuid)
returns void language plpgsql security invoker set search_path = public
as $$ begin perform private.rotar_punto(punto_id); end $$;

create or replace function public.guardar_ventana(ventana_id uuid, nombre text, hora_inicio time, hora_fin time, orden integer)
returns uuid language sql security invoker set search_path = public
as $$ select private.guardar_ventana(ventana_id, nombre, hora_inicio, hora_fin, orden) $$;

create or replace function public.borrar_ventana(ventana_id uuid)
returns void language plpgsql security invoker set search_path = public
as $$ begin perform private.borrar_ventana(ventana_id); end $$;

create or replace function public.token_caseta(turno_id uuid)
returns text language sql security invoker set search_path = public
as $$ select private.token_caseta(turno_id) $$;

create or replace function public.token_punto(punto_id uuid)
returns text language sql security invoker set search_path = public
as $$ select private.token_punto(punto_id) $$;

create or replace function public.estado_ronda(turno_id uuid)
returns jsonb language sql security invoker set search_path = public
as $$ select private.estado_ronda(turno_id) $$;

create or replace function public.registrar_evento(
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
returns jsonb language sql security invoker set search_path = public
as $$
  select private.registrar_evento(
    p_auth_user_id, p_clase, p_token, p_lat, p_lng, p_path, p_hash, p_offline, p_tipo, p_descripcion
  )
$$;

create or replace function public.revisar_alertas()
returns void language plpgsql security invoker set search_path = public
as $$ begin perform private.revisar_alertas(); end $$;

create or replace function public.marcar_alerta_leida(alerta_id uuid)
returns void language plpgsql security invoker set search_path = public
as $$ begin perform private.marcar_alerta_leida(alerta_id); end $$;

create or replace function public.vigilantes_en_turno()
returns jsonb language sql stable security invoker set search_path = public
as $$ select private.vigilantes_en_turno() $$;

create or replace function public.registrar_ayuda(vigilante_id uuid, canal text)
returns jsonb language sql security invoker set search_path = public
as $$ select private.registrar_ayuda(vigilante_id, canal) $$;

revoke all on all functions in schema private from public, anon, authenticated;
revoke all on all functions in schema public from public, anon, authenticated;

grant execute on function private.hay_administrador() to anon, authenticated;
grant execute on function public.hay_administrador() to anon, authenticated;

grant execute on function private.perfil_actual() to authenticated;
grant execute on function private.es_admin() to authenticated;
grant execute on function private.tiene_rol(text) to authenticated;
grant execute on function private.ruta_propia(text) to authenticated;
grant execute on function private.aceptar_datos() to authenticated;
grant execute on function private.actualizar_mi_perfil(text, text) to authenticated;
grant execute on function private.datos_conjunto() to authenticated;
grant execute on function private.guardar_conjunto(text, double precision, double precision, integer) to authenticated;
grant execute on function private.guardar_acceso(uuid, text[], boolean, text) to authenticated;
grant execute on function private.crear_turno(uuid, timestamptz, timestamptz) to authenticated;
grant execute on function private.cancelar_turno(uuid) to authenticated;
grant execute on function private.guardar_punto(uuid, text, integer, boolean) to authenticated;
grant execute on function private.desactivar_punto(uuid) to authenticated;
grant execute on function private.rotar_punto(uuid) to authenticated;
grant execute on function private.guardar_ventana(uuid, text, time, time, integer) to authenticated;
grant execute on function private.borrar_ventana(uuid) to authenticated;
grant execute on function private.token_caseta(uuid) to authenticated;
grant execute on function private.token_punto(uuid) to authenticated;
grant execute on function private.estado_ronda(uuid) to authenticated;
grant execute on function private.revisar_alertas() to authenticated;
grant execute on function private.marcar_alerta_leida(uuid) to authenticated;
grant execute on function private.vigilantes_en_turno() to authenticated;
grant execute on function private.registrar_ayuda(uuid, text) to authenticated;
grant execute on function private.alta_perfil() to supabase_auth_admin, service_role;
grant execute on function private.registrar_evento(uuid, text, text, double precision, double precision, text, text, boolean, text, text) to service_role;

grant execute on function public.aceptar_datos() to authenticated;
grant execute on function public.actualizar_mi_perfil(text, text) to authenticated;
grant execute on function public.datos_conjunto() to authenticated;
grant execute on function public.guardar_conjunto(text, double precision, double precision, integer) to authenticated;
grant execute on function public.guardar_acceso(uuid, text[], boolean, text) to authenticated;
grant execute on function public.crear_turno(uuid, timestamptz, timestamptz) to authenticated;
grant execute on function public.cancelar_turno(uuid) to authenticated;
grant execute on function public.guardar_punto(uuid, text, integer, boolean) to authenticated;
grant execute on function public.desactivar_punto(uuid) to authenticated;
grant execute on function public.rotar_punto(uuid) to authenticated;
grant execute on function public.guardar_ventana(uuid, text, time, time, integer) to authenticated;
grant execute on function public.borrar_ventana(uuid) to authenticated;
grant execute on function public.token_caseta(uuid) to authenticated;
grant execute on function public.token_punto(uuid) to authenticated;
grant execute on function public.estado_ronda(uuid) to authenticated;
grant execute on function public.registrar_evento(uuid, text, text, double precision, double precision, text, text, boolean, text, text) to service_role;
grant execute on function public.revisar_alertas() to authenticated;
grant execute on function public.marcar_alerta_leida(uuid) to authenticated;
grant execute on function public.vigilantes_en_turno() to authenticated;
grant execute on function public.registrar_ayuda(uuid, text) to authenticated;

revoke all on all tables in schema public from anon, authenticated;
grant select on table public.roles to authenticated;
grant select (id, nombre, radio_m) on table public.conjuntos to authenticated;
grant select (id, auth_user_id, conjunto_id, nombre, activo, aceptado_en, creado_en, actualizado_en) on table public.perfiles to authenticated;
grant select on table public.perfil_roles to authenticated;
grant select on table public.turnos to authenticated;
grant select on table public.puntos_control to authenticated;
grant select on table public.ventanas_ronda to authenticated;
grant select on table public.rondas to authenticated;
grant select on table public.marcaciones to authenticated;
grant select on table public.escaneos_punto to authenticated;
grant select on table public.incidentes to authenticated;
grant select on table public.alertas to authenticated;
grant update (leida) on table public.alertas to authenticated;
grant select on table public.ayudas to authenticated;
grant select on public.perfiles_directorio to authenticated;

revoke all on table public.invitaciones from anon, authenticated;
grant all on table public.invitaciones to service_role;
