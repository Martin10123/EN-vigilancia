create table public.bitacora (
  id uuid primary key default gen_random_uuid(),
  creado_en timestamptz not null default now(),
  perfil_id uuid references public.perfiles (id),
  nivel text not null default 'error' check (nivel in ('error', 'aviso')),
  origen text not null check (char_length(origen) between 1 and 40),
  mensaje text not null check (char_length(mensaje) between 1 and 500),
  ruta text,
  detalle text
);

create index bitacora_creado_idx on public.bitacora (creado_en desc);

alter table public.bitacora enable row level security;

create policy bitacora_insertar on public.bitacora
  for insert to authenticated
  with check (perfil_id is null or perfil_id = private.perfil_actual());

create policy bitacora_lectura on public.bitacora
  for select to authenticated
  using (private.es_admin());

grant select, insert on public.bitacora to authenticated;
grant all on public.bitacora to service_role;
