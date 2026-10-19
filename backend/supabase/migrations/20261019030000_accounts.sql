-- Fase 4: cuentas de cliente (HU-001, HU-002, HU-003).
-- Documentos legales versionados, perfil, consentimientos y direcciones.
-- Ver docs/MODELO_DATOS.md, sección "Cuentas".
--
-- La cuenta la crea Supabase Auth. El trigger private.handle_new_user crea el
-- perfil y registra la aceptación de los documentos vigentes; si falta
-- alguna, la cuenta no se crea (RF-007, RN-033).

-- ---------------------------------------------------------------------------
-- Documentos legales (términos y política de datos)
-- ---------------------------------------------------------------------------

create table public.legal_documents (
  code text not null check (code in ('terms', 'privacy')),
  version text not null check (version ~ '^[0-9]+(\.[0-9]+)*$'),
  title text not null,
  content text not null,
  published_at timestamptz not null default now(),
  is_current boolean not null default false,
  primary key (code, version)
);

-- Una sola versión vigente por documento.
create unique index legal_documents_current_idx
  on public.legal_documents (code)
  where is_current;

alter table public.legal_documents enable row level security;

-- Se leen antes de crear la cuenta, así que son públicos.
create policy "Documentos legales vigentes visibles para todos"
  on public.legal_documents for select
  to anon, authenticated
  using (is_current);

-- Borradores: el texto definitivo depende de la jurisdicción (RNF-008, RNF-035).
insert into public.legal_documents (code, version, title, content, is_current) values
  ('terms', '1.0', 'Términos y condiciones',
   'BORRADOR PENDIENTE DE REVISIÓN LEGAL.' || E'\n\n' ||
   'NEXUS es un intermediario entre clientes y proveedores de computadores armados y piezas. '
   || 'Cada proveedor fija el precio, vende y despacha sus productos. '
   || 'Las recomendaciones del asistente son informativas y la decisión de compra es tuya.',
   true),
  ('privacy', '1.0', 'Política de tratamiento de datos personales',
   'BORRADOR PENDIENTE DE REVISIÓN LEGAL.' || E'\n\n' ||
   'Usamos tu nombre, correo, teléfono y direcciones para gestionar tu cuenta, tus compras y sus entregas. '
   || 'Puedes consultar, corregir o pedir la eliminación de tus datos.',
   true);

-- ---------------------------------------------------------------------------
-- Perfil
-- ---------------------------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text not null check (length(trim(full_name)) between 2 and 120),
  phone text check (phone ~ '^\+?[0-9]{7,15}$'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function private.set_updated_at();

alter table public.profiles enable row level security;

create policy "Cada usuario ve su perfil"
  on public.profiles for select
  to authenticated
  using (id = (select auth.uid()));

create policy "Cada usuario edita su perfil"
  on public.profiles for update
  to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- El perfil lo crea el trigger de alta y se borra con la cuenta.
revoke insert, delete on public.profiles from anon, authenticated;

-- ---------------------------------------------------------------------------
-- Consentimientos (RF-007)
-- ---------------------------------------------------------------------------

create table public.user_consents (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  document_code text not null,
  document_version text not null,
  accepted_at timestamptz not null default now(),
  foreign key (document_code, document_version)
    references public.legal_documents (code, version),
  unique (user_id, document_code, document_version)
);

alter table public.user_consents enable row level security;

create policy "Cada usuario ve sus consentimientos"
  on public.user_consents for select
  to authenticated
  using (user_id = (select auth.uid()));

-- Constancia: los clientes no los crean, cambian ni borran directamente.
revoke insert, update, delete on public.user_consents from anon, authenticated;

-- ---------------------------------------------------------------------------
-- Alta de usuario
-- ---------------------------------------------------------------------------

-- Lee de raw_user_meta_data (lo envía la app en signUp):
--   full_name: text
--   accepted_documents: [{"code": "terms", "version": "1.0"}, ...]
create function private.handle_new_user() returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  accepted jsonb := coalesce(new.raw_user_meta_data -> 'accepted_documents', '[]'::jsonb);
  missing text;
begin
  if jsonb_typeof(accepted) <> 'array' then
    accepted := '[]'::jsonb;
  end if;

  select string_agg(d.code, ', ' order by d.code) into missing
  from public.legal_documents d
  where d.is_current
    and not exists (
      select 1 from jsonb_array_elements(accepted) a
      where a ->> 'code' = d.code and a ->> 'version' = d.version
    );

  if missing is not null then
    raise exception 'CONSENT_REQUIRED: faltan por aceptar %', missing
      using errcode = '23514';
  end if;

  insert into public.profiles (id, full_name)
  values (new.id, trim(coalesce(new.raw_user_meta_data ->> 'full_name', '')));

  insert into public.user_consents (user_id, document_code, document_version)
  select new.id, d.code, d.version
  from public.legal_documents d
  where d.is_current;

  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_new_user();

-- ---------------------------------------------------------------------------
-- Direcciones de entrega (RF-004). Supuesto: Colombia (S-02).
-- ---------------------------------------------------------------------------

create table public.addresses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  label text not null check (length(trim(label)) between 1 and 40),
  recipient_name text not null check (length(trim(recipient_name)) between 2 and 120),
  phone text not null check (phone ~ '^\+?[0-9]{7,15}$'),
  department text not null check (length(trim(department)) between 2 and 60),
  city text not null check (length(trim(city)) between 2 and 80),
  address_line text not null check (length(trim(address_line)) between 5 and 200),
  details text check (details is null or length(details) <= 200),
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index addresses_user_idx on public.addresses (user_id, created_at);

-- Como máximo una dirección predeterminada por usuario.
create unique index addresses_one_default_idx
  on public.addresses (user_id)
  where is_default;

create trigger addresses_set_updated_at
  before update on public.addresses
  for each row execute function private.set_updated_at();

-- La primera dirección es la predeterminada; marcar otra desmarca la anterior.
create function private.addresses_keep_single_default() returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.is_default then
    update public.addresses a
    set is_default = false
    where a.user_id = new.user_id and a.id <> new.id and a.is_default;
  elsif tg_op = 'INSERT' and not exists (
    select 1 from public.addresses a where a.user_id = new.user_id
  ) then
    new.is_default := true;
  end if;
  return new;
end;
$$;

create trigger addresses_single_default
  before insert or update of is_default on public.addresses
  for each row execute function private.addresses_keep_single_default();

-- Al borrar la predeterminada, pasa a serlo la más reciente que quede.
create function private.addresses_promote_default() returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.is_default then
    update public.addresses a
    set is_default = true
    where a.id = (
      select b.id from public.addresses b
      where b.user_id = old.user_id
      order by b.created_at desc, b.id
      limit 1
    );
  end if;
  return null;
end;
$$;

create trigger addresses_promote_default
  after delete on public.addresses
  for each row execute function private.addresses_promote_default();

alter table public.addresses enable row level security;

create policy "Cada usuario gestiona sus direcciones"
  on public.addresses for all
  to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
