-- Componentes de los computadores armados, para verlos en 3D en el PC
-- Builder (RF-090). docs/API_CONTRATO.md, sección 11.5.
--
-- Un armado solo tenía atributos de texto ("Procesador: Ryzen 7 9700X"). Para
-- ubicar sus piezas en las secciones del armador y en la vista 3D hace falta
-- saber qué componente ocupa cada ranura y sus medidas. Muchas de esas piezas
-- no se venden sueltas; si se venden, se enlazan con part_product_id.

-- Atributos que cambian cómo se ve una pieza (los de get_build_scene).
create function private.visual_attribute_keys() returns text[]
language sql
immutable
set search_path = ''
as $$
  select array[
    'form_factor', 'ram_slots', 'modules', 'length_mm', 'storage_type',
    'cooling_type', 'height_mm', 'radiator_mm', 'max_gpu_length_mm',
    'max_cooler_height_mm'
  ];
$$;

create or replace function private.visual_attributes(p_product_id text) returns jsonb
language sql
stable
set search_path = ''
as $$
  select coalesce(jsonb_object_agg(attribute.key, attribute.value), '{}'::jsonb)
  from unnest(private.visual_attribute_keys()) as visual(key)
  cross join lateral (
    select visual.key, private.part_attribute(p_product_id, visual.key) as value
  ) attribute
  where attribute.value is not null;
$$;

-- Modelo 3D de una pieza: el del producto o el genérico de su categoría.
create function private.model_json(p_category text, p_product_id text) returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'path', m.file_path,
    'rotation', to_jsonb(m.rotation_deg),
    'generic', m.product_id is null,
    'title', m.title,
    'author', m.author,
    'license', m.license,
    'sourceUrl', m.source_url
  )
  from public.component_models m
  where m.is_active
    and m.category_code = p_category
    and (m.product_id = p_product_id or m.product_id is null)
  order by m.product_id nulls last
  limit 1;
$$;

-- get_build_scene usa la misma elección de modelo (sin cambios en su respuesta).
create or replace function public.get_build_scene(offer_ids text[]) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  parts jsonb := private.builder_parts(offer_ids);
begin
  return jsonb_build_object('parts', coalesce((
    select jsonb_agg(jsonb_build_object(
      'offerId', part ->> 'offerId',
      'category', part ->> 'category',
      'productName', part ->> 'productName',
      'attributes', private.visual_attributes(part ->> 'productId'),
      'model', private.model_json(part ->> 'category', part ->> 'productId')
    ) order by position)
    from jsonb_array_elements(parts) with ordinality as listed(part, position)
  ), '[]'::jsonb));
end;
$$;

-- ---------------------------------------------------------------------------
-- Componentes de cada armado
-- ---------------------------------------------------------------------------

create table public.prebuilt_components (
  prebuilt_id text not null references public.products (id) on delete cascade,
  -- Sección del PC Builder que ocupa.
  category_code text not null references public.builder_slots (category_code),
  name text not null check (btrim(name) <> ''),
  -- La pieza del catálogo, si también se vende suelta: aporta sus medidas.
  part_product_id text references public.products (id) on delete set null,
  -- Medidas para la vista 3D. Se suman a las de la pieza enlazada y ganan.
  attributes jsonb not null default '{}' check (jsonb_typeof(attributes) = 'object'),
  primary key (prebuilt_id, category_code)
);

comment on table public.prebuilt_components is
  'Qué componente de un computador armado ocupa cada sección del PC Builder (vista 3D).';

create function private.validate_prebuilt_component() returns trigger
language plpgsql
set search_path = ''
as $$
declare
  unknown text;
begin
  if not exists (
    select 1 from public.products p
    where p.id = new.prebuilt_id and p.category_code = 'prebuiltPc'
  ) then
    raise exception 'El producto % no es un computador armado', new.prebuilt_id
      using errcode = 'check_violation';
  end if;
  if new.part_product_id is not null and not exists (
    select 1 from public.products p
    where p.id = new.part_product_id and p.category_code = new.category_code
  ) then
    raise exception 'La pieza % no es de la categoría %', new.part_product_id, new.category_code
      using errcode = 'check_violation';
  end if;
  select key into unknown
  from jsonb_object_keys(new.attributes) as key
  where key <> all (private.visual_attribute_keys())
  limit 1;
  if unknown is not null then
    raise exception 'Atributo visual desconocido: %', unknown using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

create trigger prebuilt_components_validate
  before insert or update on public.prebuilt_components
  for each row execute function private.validate_prebuilt_component();

create trigger prebuilt_components_audit
  after insert or update or delete on public.prebuilt_components
  for each row execute function private.audit_row_change('prebuilt_id');

-- Sin políticas: la app lo lee con get_prebuilt_scene.
alter table public.prebuilt_components enable row level security;

-- Armado visible y sus componentes, en el orden de las ranuras.
create function public.get_prebuilt_scene(product_id text) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  cp private.catalog_products;
begin
  select c.* into cp from private.catalog_products c where c.id = get_prebuilt_scene.product_id;
  if not found then
    perform private.raise_api_error(404, 'PRODUCT_NOT_FOUND',
      format('No existe el producto %s', get_prebuilt_scene.product_id));
  end if;
  if cp.category <> 'prebuiltPc' then
    perform private.raise_api_error(400, 'VALIDATION_ERROR',
      'Solo los computadores armados tienen componentes');
  end if;

  return jsonb_build_object(
    'product', private.product_json(cp),
    'parts', coalesce((
      select jsonb_agg(jsonb_build_object(
        'componentId', pc.prebuilt_id || ':' || pc.category_code,
        'category', pc.category_code,
        'name', pc.name,
        'partProductId', pc.part_product_id,
        'attributes', case
          when pc.part_product_id is null then pc.attributes
          else private.visual_attributes(pc.part_product_id) || pc.attributes
        end,
        'model', private.model_json(pc.category_code, pc.part_product_id)
      ) order by s.sort_order)
      from public.prebuilt_components pc
      join public.builder_slots s on s.category_code = pc.category_code
      where pc.prebuilt_id = cp.id
    ), '[]'::jsonb)
  );
end;
$$;

revoke all on function public.get_prebuilt_scene(text) from public;
grant execute on function public.get_prebuilt_scene(text) to anon, authenticated;
