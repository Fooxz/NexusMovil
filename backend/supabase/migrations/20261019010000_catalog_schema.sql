-- Fase 2: modelo del catálogo de NEXUS.
-- Familias y categorías, plantillas de atributos técnicos, productos,
-- proveedores y ofertas. Ver docs/MODELO_DATOS.md.
--
-- Acceso: todas las tablas tienen RLS. Solo categorías y plantillas son
-- legibles por los clientes; productos, ofertas y proveedores se consultan
-- por las RPC del contrato (migración catalog_rpc), que aplican las reglas de
-- visibilidad (RF-015, RN-022) y no exponen unidades ni datos fiscales.

create extension if not exists unaccent with schema extensions;

-- Esquema no expuesto por la API: vistas y funciones auxiliares.
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Tipos
-- ---------------------------------------------------------------------------

create type public.product_family as enum ('prebuiltPc', 'part');
create type public.attribute_data_type as enum ('number', 'text', 'boolean', 'enum', 'enumList');
create type public.provider_status as enum ('pending', 'active', 'suspended', 'rejected');
create type public.offer_status as enum ('draft', 'published', 'paused', 'retired');

-- ---------------------------------------------------------------------------
-- Utilidades
-- ---------------------------------------------------------------------------

create function private.set_updated_at() returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create table public.app_settings (
  key text primary key,
  value jsonb not null,
  description text,
  updated_at timestamptz not null default now()
);

insert into public.app_settings (key, value, description) values
  ('critical_stock_threshold', '5',
   'N de stockLevel "critical": de 1 a N unidades (API_CONTRATO, D3).');

create function private.critical_stock_threshold() returns integer
language sql
stable
set search_path = ''
as $$
  select coalesce(
    (select (s.value #>> '{}')::integer
     from public.app_settings s
     where s.key = 'critical_stock_threshold'),
    5
  );
$$;

-- Nivel de stock del contrato a partir de las unidades (API_CONTRATO, sección 2).
create function private.stock_level(units integer) returns text
language sql
stable
set search_path = ''
as $$
  select case
    when coalesce(units, 0) <= 0 then 'outOfStock'
    when units <= private.critical_stock_threshold() then 'critical'
    else 'stable'
  end;
$$;

-- ---------------------------------------------------------------------------
-- Categorías y plantillas de atributos (RF-012, RF-013, RNF-027)
-- ---------------------------------------------------------------------------

create table public.categories (
  code text primary key check (code ~ '^[a-z][A-Za-z0-9]*$'),
  family public.product_family not null,
  name text not null,
  search_terms text[] not null default '{}',
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  -- Mientras no se decida D8, los armados tienen una sola categoría.
  check ((family = 'prebuiltPc') = (code = 'prebuiltPc'))
);

create table public.attribute_definitions (
  id bigint generated always as identity primary key,
  category_code text not null references public.categories (code),
  key text not null check (key ~ '^[a-z][a-z0-9_]*$'),
  label text not null,
  data_type public.attribute_data_type not null,
  unit text,
  is_required boolean not null default false,
  allowed_values text[],
  sort_order integer not null default 0,
  unique (category_code, key),
  check (
    (data_type in ('enum', 'enumList'))
    = (allowed_values is not null and cardinality(allowed_values) > 0)
  )
);

-- ---------------------------------------------------------------------------
-- Productos
-- ---------------------------------------------------------------------------

create table public.products (
  id text primary key default gen_random_uuid()::text
    check (id ~ '^[a-z0-9][a-z0-9-]*$'),
  name text not null check (length(trim(name)) > 0),
  brand text not null check (length(trim(brand)) > 0),
  model text,
  category_code text not null references public.categories (code),
  summary text,
  quick_specs text[] not null default '{}',
  -- Ficha solo para mostrar: [{"label": "...", "value": "..."}].
  specs jsonb not null default '[]' check (jsonb_typeof(specs) = 'array'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index products_category_idx on public.products (category_code);

create trigger products_set_updated_at
  before update on public.products
  for each row execute function private.set_updated_at();

-- Atributos tipados (EAV): fuente de la búsqueda por atributos, el asistente y
-- el PC Builder. Un valor por fila, en la columna que corresponde a su tipo.
create table public.product_attributes (
  product_id text not null references public.products (id) on delete cascade,
  attribute_id bigint not null references public.attribute_definitions (id),
  value_number numeric,
  value_text text,
  value_bool boolean,
  value_list text[],
  primary key (product_id, attribute_id),
  check (num_nonnulls(value_number, value_text, value_bool, value_list) = 1)
);

create index product_attributes_attribute_idx
  on public.product_attributes (attribute_id);

-- RN-032: el atributo debe ser de la categoría del producto y el valor debe
-- respetar el tipo y los valores permitidos de su plantilla.
create function private.validate_product_attribute() returns trigger
language plpgsql
set search_path = ''
as $$
declare
  def public.attribute_definitions;
  product_category text;
begin
  select * into def
  from public.attribute_definitions d
  where d.id = new.attribute_id;

  select p.category_code into product_category
  from public.products p
  where p.id = new.product_id;

  if def.category_code is distinct from product_category then
    raise exception 'El atributo % no pertenece a la categoría %',
      def.key, product_category
      using errcode = '23514';
  end if;

  if not coalesce(case def.data_type
      when 'number' then new.value_number is not null
      when 'text' then new.value_text is not null
      when 'boolean' then new.value_bool is not null
      when 'enum' then new.value_text = any (def.allowed_values)
      when 'enumList' then cardinality(new.value_list) > 0
        and new.value_list <@ def.allowed_values
    end, false) then
    raise exception 'Valor inválido para el atributo % (tipo %)',
      def.key, def.data_type
      using errcode = '23514';
  end if;

  return new;
end;
$$;

create trigger product_attributes_validate
  before insert or update on public.product_attributes
  for each row execute function private.validate_product_attribute();

create table public.product_images (
  id bigint generated always as identity primary key,
  product_id text not null references public.products (id) on delete cascade,
  url text not null check (url ~ '^https?://'),
  thumb_url text check (thumb_url ~ '^https?://'),
  sort_order integer not null default 0
);

create index product_images_product_idx
  on public.product_images (product_id, sort_order);

-- ---------------------------------------------------------------------------
-- Proveedores y ofertas (RF-014, RN-001, RN-022)
-- ---------------------------------------------------------------------------

create table public.providers (
  id text primary key default gen_random_uuid()::text,
  legal_name text not null,
  display_name text not null,
  tax_id text not null unique,
  contact_email text not null,
  status public.provider_status not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger providers_set_updated_at
  before update on public.providers
  for each row execute function private.set_updated_at();

create table public.offers (
  id text primary key default gen_random_uuid()::text,
  product_id text not null references public.products (id),
  provider_id text not null references public.providers (id),
  -- Identificador del producto en el sistema del proveedor (RF-023).
  external_sku text not null check (length(trim(external_sku)) > 0),
  -- Centavos de COP, múltiplos de 100 (API_CONTRATO, sección 1).
  price_cents bigint not null check (price_cents > 0 and price_cents % 100 = 0),
  old_price_cents bigint check (
    old_price_cents is null
    or (old_price_cents > price_cents and old_price_cents % 100 = 0)
  ),
  stock_units integer not null default 0 check (stock_units >= 0),
  status public.offer_status not null default 'draft',
  stock_synced_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (provider_id, external_sku),
  unique (provider_id, product_id)
);

create index offers_published_product_idx
  on public.offers (product_id)
  where status = 'published';

create trigger offers_set_updated_at
  before update on public.offers
  for each row execute function private.set_updated_at();

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

alter table public.app_settings enable row level security;
alter table public.categories enable row level security;
alter table public.attribute_definitions enable row level security;
alter table public.products enable row level security;
alter table public.product_attributes enable row level security;
alter table public.product_images enable row level security;
alter table public.providers enable row level security;
alter table public.offers enable row level security;

create policy "Categorías activas visibles para todos"
  on public.categories for select
  to anon, authenticated
  using (is_active);

create policy "Plantillas de categorías activas visibles para todos"
  on public.attribute_definitions for select
  to anon, authenticated
  using (exists (
    select 1 from public.categories c
    where c.code = category_code and c.is_active
  ));

-- Sin políticas para app_settings, products, product_attributes,
-- product_images, providers ni offers: los clientes no las leen directamente.

-- ---------------------------------------------------------------------------
-- Datos de referencia: familias y tipos de pieza (S-10) con sus plantillas
-- ---------------------------------------------------------------------------

insert into public.categories (code, family, name, search_terms, sort_order) values
  ('prebuiltPc', 'prebuiltPc', 'Computador armado', array['pc', 'computador', 'equipo', 'armado', 'pc armado'], 0),
  ('cpu', 'part', 'Procesador', array['cpu', 'procesador'], 10),
  ('motherboard', 'part', 'Placa madre', array['motherboard', 'placa madre', 'placa base', 'board'], 20),
  ('ram', 'part', 'Memoria RAM', array['ram', 'memoria'], 30),
  ('gpu', 'part', 'Tarjeta gráfica', array['gpu', 'tarjeta grafica', 'tarjetas graficas', 'video'], 40),
  ('storage', 'part', 'Almacenamiento', array['storage', 'almacenamiento', 'disco', 'ssd'], 50),
  ('psu', 'part', 'Fuente de poder', array['psu', 'fuente', 'fuente de poder'], 60),
  ('pcCase', 'part', 'Gabinete', array['pccase', 'gabinete', 'case', 'chasis'], 70),
  ('cooling', 'part', 'Refrigeración', array['cooling', 'refrigeracion', 'disipador', 'enfriamiento'], 80);

insert into public.attribute_definitions
  (category_code, key, label, data_type, unit, is_required, allowed_values, sort_order)
values
  -- Computador armado
  ('prebuiltPc', 'cpu_model', 'Procesador', 'text', null, true, null, 10),
  ('prebuiltPc', 'cpu_cores', 'Núcleos del procesador', 'number', null, true, null, 20),
  ('prebuiltPc', 'ram_gb', 'Memoria RAM', 'number', 'GB', true, null, 30),
  ('prebuiltPc', 'ram_type', 'Tipo de memoria', 'enum', null, false, array['DDR4', 'DDR5'], 40),
  ('prebuiltPc', 'storage_gb', 'Almacenamiento', 'number', 'GB', true, null, 50),
  ('prebuiltPc', 'storage_type', 'Tipo de almacenamiento', 'enum', null, true, array['NVMe', 'SATA_SSD', 'HDD'], 60),
  ('prebuiltPc', 'gpu_model', 'Tarjeta gráfica', 'text', null, true, null, 70),
  ('prebuiltPc', 'gpu_vram_gb', 'Memoria de video', 'number', 'GB', false, null, 80),
  ('prebuiltPc', 'psu_w', 'Fuente de poder', 'number', 'W', false, null, 90),
  ('prebuiltPc', 'operating_system', 'Sistema operativo', 'text', null, false, null, 100),
  ('prebuiltPc', 'intended_uses', 'Usos declarados por el proveedor', 'enumList', null, false,
    array['gaming', 'office', 'design', 'programming', 'streaming', 'study'], 110),
  -- Procesador
  ('cpu', 'socket', 'Socket', 'enum', null, true, array['AM4', 'AM5', 'LGA1700', 'LGA1851'], 10),
  ('cpu', 'cores', 'Núcleos', 'number', null, true, null, 20),
  ('cpu', 'threads', 'Hilos', 'number', null, false, null, 30),
  ('cpu', 'base_clock_ghz', 'Frecuencia base', 'number', 'GHz', false, null, 40),
  ('cpu', 'boost_clock_ghz', 'Frecuencia turbo', 'number', 'GHz', false, null, 50),
  ('cpu', 'tdp_w', 'Consumo (TDP)', 'number', 'W', true, null, 60),
  ('cpu', 'integrated_graphics', 'Gráficos integrados', 'boolean', null, false, null, 70),
  -- Placa madre
  ('motherboard', 'socket', 'Socket', 'enum', null, true, array['AM4', 'AM5', 'LGA1700', 'LGA1851'], 10),
  ('motherboard', 'chipset', 'Chipset', 'text', null, true, null, 20),
  ('motherboard', 'form_factor', 'Formato', 'enum', null, true, array['EATX', 'ATX', 'microATX', 'miniITX'], 30),
  ('motherboard', 'ram_type', 'Tipo de memoria', 'enum', null, true, array['DDR4', 'DDR5'], 40),
  ('motherboard', 'ram_slots', 'Ranuras de memoria', 'number', null, true, null, 50),
  ('motherboard', 'max_ram_gb', 'Memoria máxima', 'number', 'GB', false, null, 60),
  ('motherboard', 'm2_slots', 'Ranuras M.2', 'number', null, false, null, 70),
  -- Memoria RAM
  ('ram', 'ram_type', 'Tipo de memoria', 'enum', null, true, array['DDR4', 'DDR5'], 10),
  ('ram', 'capacity_gb', 'Capacidad total del kit', 'number', 'GB', true, null, 20),
  ('ram', 'modules', 'Módulos', 'number', null, true, null, 30),
  ('ram', 'speed_mts', 'Velocidad', 'number', 'MT/s', true, null, 40),
  -- Tarjeta gráfica
  ('gpu', 'chipset', 'Chip gráfico', 'text', null, true, null, 10),
  ('gpu', 'vram_gb', 'Memoria de video', 'number', 'GB', true, null, 20),
  ('gpu', 'tdp_w', 'Consumo (TDP)', 'number', 'W', true, null, 30),
  ('gpu', 'length_mm', 'Largo', 'number', 'mm', true, null, 40),
  ('gpu', 'recommended_psu_w', 'Fuente recomendada', 'number', 'W', false, null, 50),
  -- Almacenamiento
  ('storage', 'storage_type', 'Tipo', 'enum', null, true, array['NVMe', 'SATA_SSD', 'HDD'], 10),
  ('storage', 'capacity_gb', 'Capacidad', 'number', 'GB', true, null, 20),
  ('storage', 'interface', 'Interfaz', 'enum', null, true, array['PCIe5', 'PCIe4', 'PCIe3', 'SATA'], 30),
  -- Fuente de poder
  ('psu', 'wattage_w', 'Potencia', 'number', 'W', true, null, 10),
  ('psu', 'efficiency', 'Certificación', 'enum', null, false,
    array['80PLUS', 'BRONZE', 'GOLD', 'PLATINUM', 'TITANIUM'], 20),
  ('psu', 'modularity', 'Modularidad', 'enum', null, false, array['full', 'semi', 'none'], 30),
  -- Gabinete
  ('pcCase', 'supported_form_factors', 'Formatos de placa admitidos', 'enumList', null, true,
    array['EATX', 'ATX', 'microATX', 'miniITX'], 10),
  ('pcCase', 'max_gpu_length_mm', 'Largo máximo de gráfica', 'number', 'mm', true, null, 20),
  ('pcCase', 'max_cooler_height_mm', 'Altura máxima de disipador', 'number', 'mm', false, null, 30),
  ('pcCase', 'radiator_support_mm', 'Radiadores admitidos', 'enumList', null, false,
    array['120', '240', '280', '360', '420'], 40),
  -- Refrigeración
  ('cooling', 'cooling_type', 'Tipo', 'enum', null, true, array['air', 'liquid'], 10),
  ('cooling', 'supported_sockets', 'Sockets admitidos', 'enumList', null, true,
    array['AM4', 'AM5', 'LGA1700', 'LGA1851'], 20),
  ('cooling', 'radiator_mm', 'Tamaño de radiador', 'number', 'mm', false, null, 30),
  ('cooling', 'height_mm', 'Altura', 'number', 'mm', false, null, 40),
  ('cooling', 'tdp_rating_w', 'Disipación máxima', 'number', 'W', false, null, 50);
