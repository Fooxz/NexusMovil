-- Fase 6.1: modelos 3D para el visor del PC Builder (RF-090).
-- docs/API_CONTRATO.md, parte 3 (get_build_scene). backend/MODELOS_3D.md.
--
-- Los archivos .glb viven en el bucket público `component-models` de
-- Storage (config.toml). Esta tabla dice qué archivo usa cada pieza: uno del
-- producto exacto o, si no hay, el genérico de su categoría. Sin ninguno, la
-- app genera la pieza con su forma y medidas típicas.

create table public.component_models (
  id bigint generated always as identity primary key,
  category_code text not null references public.builder_slots (category_code),
  -- Nulo para el modelo genérico de la categoría.
  product_id text references public.products (id) on delete cascade,
  -- Ruta dentro del bucket, por ejemplo generic/gpu.glb.
  file_path text not null check (file_path ~ '^[a-z0-9][a-z0-9/_.-]*\.glb$'),
  -- Grados (X, Y, Z) que dejan el modelo en la orientación de su categoría.
  rotation_deg numeric[] not null default '{0,0,0}'
    check (cardinality(rotation_deg) = 3 and array_position(rotation_deg, null) is null),
  title text not null check (btrim(title) <> ''),
  author text not null check (btrim(author) <> ''),
  -- 'propia': hecho o comprado por NEXUS con derecho de uso.
  license text not null check (license in ('CC0-1.0', 'CC-BY-3.0', 'CC-BY-4.0', 'propia')),
  source_url text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid default auth.uid(),
  -- CC BY exige dar crédito con un enlace a la obra.
  constraint component_models_attribution check (license not like 'CC-BY-%' or source_url is not null)
);

comment on table public.component_models is
  'Modelo 3D (.glb en Storage) de un producto o, sin producto, genérico de su categoría.';

-- Un solo modelo activo por producto y uno genérico por categoría.
create unique index component_models_one_active
  on public.component_models (category_code, coalesce(product_id, ''))
  where is_active;

create function private.validate_component_model() returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.product_id is not null and not exists (
    select 1 from public.products p
    where p.id = new.product_id and p.category_code = new.category_code
  ) then
    raise exception 'El producto % no es de la categoría %', new.product_id, new.category_code
      using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

create trigger component_models_validate
  before insert or update on public.component_models
  for each row execute function private.validate_component_model();

create trigger component_models_audit
  after insert or update or delete on public.component_models
  for each row execute function private.audit_row_change();

-- Sin políticas: la app lee los modelos solo con get_build_scene.
alter table public.component_models enable row level security;

-- ---------------------------------------------------------------------------
-- Escena para el visor
-- ---------------------------------------------------------------------------

-- Atributos que cambian cómo se ve una pieza (formato, largo, altura...).
create function private.visual_attributes(p_product_id text) returns jsonb
language sql
stable
set search_path = ''
as $$
  select coalesce(jsonb_object_agg(attribute.key, attribute.value), '{}'::jsonb)
  from unnest(array[
    'form_factor', 'ram_slots', 'modules', 'length_mm', 'storage_type',
    'cooling_type', 'height_mm', 'radiator_mm', 'max_gpu_length_mm',
    'max_cooler_height_mm'
  ]) as visual(key)
  cross join lateral (
    select visual.key, private.part_attribute(p_product_id, visual.key) as value
  ) attribute
  where attribute.value is not null;
$$;

-- Las mismas validaciones de entrada que validate_build (builder_parts).
create function public.get_build_scene(offer_ids text[]) returns jsonb
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
      'model', (
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
          and m.category_code = part ->> 'category'
          and (m.product_id = part ->> 'productId' or m.product_id is null)
        order by m.product_id nulls last
        limit 1
      )
    ) order by position)
    from jsonb_array_elements(parts) with ordinality as listed(part, position)
  ), '[]'::jsonb));
end;
$$;

revoke all on function public.get_build_scene(text[]) from public;
grant execute on function public.get_build_scene(text[]) to anon, authenticated;
