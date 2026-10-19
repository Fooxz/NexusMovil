-- Fase 6: PC Builder y motor de compatibilidad (HU-008, HU-025, RF-046 a 051).
-- docs/API_CONTRATO.md, parte 3. docs/MODELO_DATOS.md, "PC Builder".
--
-- La compatibilidad la deciden reglas técnicas deterministas guardadas como
-- datos y versionadas (RN-013, RF-050); nunca una respuesta de IA. Las reglas
-- se evalúan sobre los atributos tipados de cada pieza (product_attributes).
-- Si falta un dato obligatorio para verificar una regla, se avisa en lugar de
-- suponer.

-- ---------------------------------------------------------------------------
-- Ranuras del armador
-- ---------------------------------------------------------------------------

create table public.builder_slots (
  category_code text primary key references public.categories (code),
  label text not null,
  is_required boolean not null,
  sort_order integer not null
);

alter table public.builder_slots enable row level security;

create policy "Ranuras del armador visibles para todos"
  on public.builder_slots for select
  to anon, authenticated
  using (true);

-- La gráfica no es obligatoria por sí misma: la exige la regla video_output
-- cuando el procesador no tiene gráficos integrados.
insert into public.builder_slots (category_code, label, is_required, sort_order) values
  ('cpu', 'Procesador', true, 10),
  ('motherboard', 'Placa madre', true, 20),
  ('ram', 'Memoria RAM', true, 30),
  ('gpu', 'Tarjeta gráfica', false, 40),
  ('storage', 'Almacenamiento', true, 50),
  ('psu', 'Fuente de poder', true, 60),
  ('pcCase', 'Gabinete', true, 70),
  ('cooling', 'Refrigeración', false, 80);

-- ---------------------------------------------------------------------------
-- Reglas de compatibilidad versionadas (RF-050)
-- ---------------------------------------------------------------------------

create type public.compat_rule_kind as enum (
  'equals',          -- A.attr = B.attr
  'containedIn',     -- A.attr está en la lista B.attr
  'atMost',          -- A.attr <= B.attr
  'powerBudget',     -- la fuente (A) cubre el consumo de params.sources
  'requiredUnless'   -- hace falta una pieza A, salvo que B.attr sea verdadero
);

create table public.compat_rules (
  code text primary key check (code ~ '^[a-z][a-z0-9_]*$'),
  name text not null,
  created_at timestamptz not null default now()
);

create table public.compat_rule_versions (
  id bigint generated always as identity primary key,
  rule_code text not null references public.compat_rules (code),
  version integer not null check (version >= 1),
  kind public.compat_rule_kind not null,
  category_a text not null references public.categories (code),
  attribute_a text,
  category_b text references public.categories (code),
  attribute_b text,
  params jsonb not null default '{}' check (jsonb_typeof(params) = 'object'),
  severity text not null default 'error' check (severity in ('error', 'warning')),
  -- Texto para el cliente, sin tecnicismos innecesarios (RNF-023). Marcadores:
  -- {aValue} y {bValue}; en powerBudget, {required} y {available}.
  message text not null,
  is_active boolean not null default false,
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now(),
  unique (rule_code, version),
  check (
    case kind
      when 'powerBudget' then attribute_a is not null
      when 'requiredUnless' then category_b is not null and attribute_b is not null
      else attribute_a is not null and category_b is not null and attribute_b is not null
    end
  )
);

-- Una sola versión activa por regla.
create unique index compat_rule_versions_active_idx
  on public.compat_rule_versions (rule_code)
  where is_active;

-- Los atributos de una regla deben existir en la plantilla de su categoría.
create function private.validate_compat_rule() returns trigger
language plpgsql
set search_path = ''
as $$
declare
  source jsonb;
begin
  if new.attribute_a is not null and not exists (
    select 1 from public.attribute_definitions d
    where d.category_code = new.category_a and d.key = new.attribute_a
  ) then
    raise exception 'El atributo % no existe en %', new.attribute_a, new.category_a
      using errcode = '23514';
  end if;
  if new.attribute_b is not null and not exists (
    select 1 from public.attribute_definitions d
    where d.category_code = new.category_b and d.key = new.attribute_b
  ) then
    raise exception 'El atributo % no existe en %', new.attribute_b, new.category_b
      using errcode = '23514';
  end if;
  if new.kind = 'powerBudget' then
    for source in select * from jsonb_array_elements(coalesce(new.params -> 'sources', '[]'::jsonb)) loop
      if not exists (
        select 1 from public.attribute_definitions d
        where d.category_code = source ->> 'category' and d.key = source ->> 'attribute'
      ) then
        raise exception 'Fuente de consumo inválida: %', source using errcode = '23514';
      end if;
    end loop;
  end if;
  return new;
end;
$$;

create trigger compat_rule_versions_validate
  before insert or update on public.compat_rule_versions
  for each row execute function private.validate_compat_rule();

-- Las reglas se auditan como el resto de la configuración (RF-081).
create trigger compat_rules_audit
  after insert or update or delete on public.compat_rules
  for each row execute function private.audit_row_change('code');
create trigger compat_rule_versions_audit
  after insert or update or delete on public.compat_rule_versions
  for each row execute function private.audit_row_change();

-- Sin políticas: los clientes no leen las reglas; las aplican las RPC. Se
-- administran desde Studio o, en la fase 11, con RPC de administrador.
alter table public.compat_rules enable row level security;
alter table public.compat_rule_versions enable row level security;

insert into public.compat_rules (code, name) values
  ('cpu_motherboard_socket', 'Socket del procesador y de la placa madre'),
  ('ram_motherboard_type', 'Tipo de memoria y placa madre'),
  ('ram_motherboard_slots', 'Módulos de memoria y ranuras de la placa'),
  ('ram_motherboard_capacity', 'Capacidad de memoria y máximo de la placa'),
  ('motherboard_case_form_factor', 'Formato de la placa madre y gabinete'),
  ('gpu_case_length', 'Largo de la tarjeta gráfica y gabinete'),
  ('cooler_cpu_socket', 'Disipador y socket del procesador'),
  ('cooler_case_height', 'Altura del disipador y gabinete'),
  ('psu_power_budget', 'Potencia de la fuente'),
  ('video_output', 'Salida de video');

insert into public.compat_rule_versions
  (rule_code, version, kind, category_a, attribute_a, category_b, attribute_b, params, message, is_active)
values
  ('cpu_motherboard_socket', 1, 'equals', 'cpu', 'socket', 'motherboard', 'socket', '{}',
   'El procesador usa el socket {aValue} y la placa madre el {bValue}: no encajan entre sí.', true),
  ('ram_motherboard_type', 1, 'equals', 'ram', 'ram_type', 'motherboard', 'ram_type', '{}',
   'La memoria es {aValue} y la placa madre solo acepta {bValue}.', true),
  ('ram_motherboard_slots', 1, 'atMost', 'ram', 'modules', 'motherboard', 'ram_slots', '{}',
   'La memoria trae {aValue} módulos y la placa madre solo tiene {bValue} ranuras.', true),
  ('ram_motherboard_capacity', 1, 'atMost', 'ram', 'capacity_gb', 'motherboard', 'max_ram_gb', '{}',
   'La memoria suma {aValue} GB y la placa madre admite hasta {bValue} GB.', true),
  ('motherboard_case_form_factor', 1, 'containedIn', 'motherboard', 'form_factor', 'pcCase', 'supported_form_factors', '{}',
   'La placa madre es formato {aValue} y el gabinete solo admite {bValue}.', true),
  ('gpu_case_length', 1, 'atMost', 'gpu', 'length_mm', 'pcCase', 'max_gpu_length_mm', '{}',
   'La tarjeta gráfica mide {aValue} mm y en el gabinete caben hasta {bValue} mm.', true),
  ('cooler_cpu_socket', 1, 'containedIn', 'cpu', 'socket', 'cooling', 'supported_sockets', '{}',
   'El sistema de refrigeración no se puede montar en el socket {aValue} del procesador (admite {bValue}).', true),
  ('cooler_case_height', 1, 'atMost', 'cooling', 'height_mm', 'pcCase', 'max_cooler_height_mm', '{}',
   'El disipador mide {aValue} mm de alto y en el gabinete caben hasta {bValue} mm.', true),
  ('psu_power_budget', 1, 'powerBudget', 'psu', 'wattage_w', null, null,
   '{"sources": [{"category": "cpu", "attribute": "tdp_w"}, {"category": "gpu", "attribute": "tdp_w"}], "factor": 1.3, "baseWatts": 100, "roundTo": 50}',
   'Este equipo necesita una fuente de al menos {required} W y la elegida es de {available} W.', true),
  ('video_output', 1, 'requiredUnless', 'gpu', null, 'cpu', 'integrated_graphics', '{}',
   'Agrega una tarjeta gráfica: el procesador elegido no tiene gráficos integrados.', true);

-- ---------------------------------------------------------------------------
-- Motor
-- ---------------------------------------------------------------------------

-- Valor tipado de un atributo como jsonb (número, texto, booleano o lista);
-- null si la pieza no lo tiene.
create function private.part_attribute(p_product_id text, p_key text) returns jsonb
language sql
stable
set search_path = ''
as $$
  select coalesce(
    to_jsonb(pa.value_number),
    to_jsonb(pa.value_text),
    to_jsonb(pa.value_bool),
    to_jsonb(pa.value_list)
  )
  from public.product_attributes pa
  join public.attribute_definitions d on d.id = pa.attribute_id
  join public.products p on p.id = pa.product_id and p.category_code = d.category_code
  where pa.product_id = p_product_id and d.key = p_key;
$$;

-- Texto de un valor para los mensajes: "AM5", "304", "ATX, microATX".
create function private.attribute_text(value jsonb) returns text
language sql
immutable
set search_path = ''
as $$
  select case jsonb_typeof(value)
    when 'array' then (select string_agg(e, ', ') from jsonb_array_elements_text(value) e)
    when 'number' then trim_scale((value #>> '{}')::numeric)::text
    else value #>> '{}'
  end;
$$;

create function private.attribute_is_required(p_category text, p_key text) returns boolean
language sql
stable
set search_path = ''
as $$
  select coalesce(
    (select d.is_required from public.attribute_definitions d
     where d.category_code = p_category and d.key = p_key),
    false
  );
$$;

-- Piezas de una selección de ofertas: una por categoría, solo piezas.
create function private.builder_parts(p_offer_ids text[]) returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  parts jsonb;
begin
  if p_offer_ids is null or cardinality(p_offer_ids) > 12 then
    perform private.raise_api_error(400, 'VALIDATION_ERROR', 'Envía entre 0 y 12 ofertas');
  end if;

  if exists (
    select 1 from unnest(p_offer_ids) as requested(offer_id)
    where not exists (select 1 from public.offers o where o.id = requested.offer_id)
  ) then
    perform private.raise_api_error(404, 'OFFER_NOT_FOUND', 'Alguna oferta no existe');
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
      'offerId', o.id,
      'category', p.category_code,
      'productId', p.id,
      'productName', p.name,
      'brand', p.brand,
      'providerName', pr.display_name,
      'priceCents', o.price_cents,
      'available', private.offer_max_quantity(o.id) > 0,
      'imageUrl', (
        select coalesce(i.thumb_url, i.url) from public.product_images i
        where i.product_id = p.id order by i.sort_order, i.id limit 1
      )
    ) order by s.sort_order), '[]'::jsonb)
  into parts
  from (select distinct unnest(p_offer_ids) as id) sel
  join public.offers o on o.id = sel.id
  join public.products p on p.id = o.product_id
  join public.providers pr on pr.id = o.provider_id
  left join public.builder_slots s on s.category_code = p.category_code;

  if exists (
    select 1 from jsonb_array_elements(parts) part
    where not exists (
      select 1 from public.builder_slots s where s.category_code = part ->> 'category'
    )
  ) then
    perform private.raise_api_error(400, 'VALIDATION_ERROR',
      'El armador solo admite piezas, no computadores armados');
  end if;

  if (select count(*) from jsonb_array_elements(parts)) <>
     (select count(distinct part ->> 'category') from jsonb_array_elements(parts) part) then
    perform private.raise_api_error(400, 'VALIDATION_ERROR',
      'Elige una sola pieza por categoría');
  end if;

  return parts;
end;
$$;

-- Evalúa las reglas activas sobre las piezas (resultado de builder_parts).
create function private.evaluate_rules(parts jsonb) returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  r public.compat_rule_versions;
  part_a jsonb;
  part_b jsonb;
  value_a jsonb;
  value_b jsonb;
  ok boolean;
  issues jsonb := '[]'::jsonb;
  consumption numeric;
  required_watts integer;
  available_watts numeric;
  source jsonb;
  source_part jsonb;
  source_value jsonb;
  -- Piezas que consumen: también causan una falta de potencia.
  consumers jsonb;
begin
  for r in
    select * from public.compat_rule_versions v where v.is_active order by v.rule_code
  loop
    select p into part_a from jsonb_array_elements(parts) p where p ->> 'category' = r.category_a;
    part_b := null;
    if r.category_b is not null then
      select p into part_b from jsonb_array_elements(parts) p where p ->> 'category' = r.category_b;
    end if;

    if r.kind = 'requiredUnless' then
      -- Falta A: se exige salvo que B tenga el atributo en verdadero.
      continue when part_a is not null or part_b is null;
      value_b := private.part_attribute(part_b ->> 'productId', r.attribute_b);
      continue when value_b = 'true'::jsonb;
      issues := issues || jsonb_build_object(
        'ruleCode', r.rule_code,
        'severity', r.severity,
        'message', r.message,
        'offerIds', jsonb_build_array(part_b ->> 'offerId'));
      continue;
    end if;

    if r.kind = 'powerBudget' then
      continue when part_a is null;
      value_a := private.part_attribute(part_a ->> 'productId', r.attribute_a);
      if value_a is null then
        issues := issues || jsonb_build_object(
          'ruleCode', r.rule_code, 'severity', 'warning',
          'message', 'No pudimos verificar la potencia: a la fuente le falta ese dato.',
          'offerIds', jsonb_build_array(part_a ->> 'offerId'));
        continue;
      end if;
      consumption := 0;
      consumers := '[]'::jsonb;
      for source in select * from jsonb_array_elements(r.params -> 'sources') loop
        select p into source_part from jsonb_array_elements(parts) p
        where p ->> 'category' = source ->> 'category';
        continue when source_part is null;
        source_value := private.part_attribute(source_part ->> 'productId', source ->> 'attribute');
        consumption := consumption + coalesce((source_value #>> '{}')::numeric, 0);
        consumers := consumers || to_jsonb(source_part ->> 'offerId');
      end loop;
      continue when consumption = 0;
      required_watts := (ceil(
        (consumption * coalesce((r.params ->> 'factor')::numeric, 1)
          + coalesce((r.params ->> 'baseWatts')::numeric, 0))
        / coalesce((r.params ->> 'roundTo')::numeric, 1)
      ) * coalesce((r.params ->> 'roundTo')::numeric, 1))::integer;
      available_watts := (value_a #>> '{}')::numeric;
      if available_watts < required_watts then
        issues := issues || jsonb_build_object(
          'ruleCode', r.rule_code,
          'severity', r.severity,
          'message', replace(replace(r.message,
            '{required}', required_watts::text),
            '{available}', private.attribute_text(value_a)),
          'offerIds', jsonb_build_array(part_a ->> 'offerId') || consumers);
      end if;
      continue;
    end if;

    -- equals, containedIn, atMost: hacen falta las dos piezas.
    continue when part_a is null or part_b is null;
    value_a := private.part_attribute(part_a ->> 'productId', r.attribute_a);
    value_b := private.part_attribute(part_b ->> 'productId', r.attribute_b);

    if value_a is null or value_b is null then
      -- Sin el dato no se afirma nada. Se avisa solo si el dato es
      -- obligatorio en la plantilla (un opcional puede faltar con razón).
      if (value_a is null and private.attribute_is_required(r.category_a, r.attribute_a))
         or (value_b is null and private.attribute_is_required(r.category_b, r.attribute_b)) then
        issues := issues || jsonb_build_object(
          'ruleCode', r.rule_code, 'severity', 'warning',
          'message', format('No pudimos verificar: %s. Falta un dato técnico de alguna pieza.',
            lower((select cr.name from public.compat_rules cr where cr.code = r.rule_code))),
          'offerIds', jsonb_build_array(part_a ->> 'offerId', part_b ->> 'offerId'));
      end if;
      continue;
    end if;

    ok := case r.kind
      when 'equals' then value_a = value_b
      when 'containedIn' then jsonb_typeof(value_b) = 'array' and value_b ? (value_a #>> '{}')
      when 'atMost' then (value_a #>> '{}')::numeric <= (value_b #>> '{}')::numeric
    end;

    if not coalesce(ok, false) then
      issues := issues || jsonb_build_object(
        'ruleCode', r.rule_code,
        'severity', r.severity,
        'message', replace(replace(r.message,
          '{aValue}', private.attribute_text(value_a)),
          '{bValue}', private.attribute_text(value_b)),
        'offerIds', jsonb_build_array(part_a ->> 'offerId', part_b ->> 'offerId'));
    end if;
  end loop;

  return issues;
end;
$$;

-- Resultado completo de una configuración (API_CONTRATO, parte 3).
create function private.build_result(p_offer_ids text[]) returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  parts jsonb := private.builder_parts(p_offer_ids);
  issues jsonb := private.evaluate_rules(parts);
  missing jsonb;
  has_errors boolean;
  all_available boolean;
begin
  select coalesce(jsonb_agg(jsonb_build_object('category', s.category_code, 'label', s.label)
      order by s.sort_order), '[]'::jsonb)
  into missing
  from public.builder_slots s
  where s.is_required
    and not exists (
      select 1 from jsonb_array_elements(parts) p where p ->> 'category' = s.category_code
    );

  has_errors := exists (
    select 1 from jsonb_array_elements(issues) i where i ->> 'severity' = 'error'
  );
  all_available := not exists (
    select 1 from jsonb_array_elements(parts) p where not (p ->> 'available')::boolean
  );

  return jsonb_build_object(
    -- RN-031: válida si no hay incompatibilidades ni piezas obligatorias faltantes.
    'valid', not has_errors and jsonb_array_length(missing) = 0,
    -- Además, que todas las piezas se puedan comprar ahora.
    'purchasable', not has_errors and jsonb_array_length(missing) = 0 and all_available,
    'parts', parts,
    'issues', issues,
    'missingSlots', missing,
    'totalCents', coalesce(
      (select sum((p ->> 'priceCents')::bigint) from jsonb_array_elements(parts) p), 0)
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- RPC públicas
-- ---------------------------------------------------------------------------

create function public.get_builder_slots() returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
      'category', s.category_code, 'label', s.label, 'required', s.is_required)
      order by s.sort_order), '[]'::jsonb)
  from public.builder_slots s;
$$;

create function public.validate_build(offer_ids text[]) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  return private.build_result(validate_build.offer_ids);
end;
$$;

-- Piezas de una categoría para la configuración actual (RF-049): primero las
-- compatibles y con stock, luego por precio. Cada una indica si es compatible
-- y, si no, por qué.
create function public.get_builder_candidates(
  category text,
  offer_ids text[] default '{}',
  max_items integer default 30
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  others text[];
  used_limit integer := least(greatest(coalesce(get_builder_candidates.max_items, 30), 1), 50);
begin
  if not exists (
    select 1 from public.builder_slots s where s.category_code = get_builder_candidates.category
  ) then
    perform private.raise_api_error(400, 'VALIDATION_ERROR',
      format('category no es una ranura del armador: %s', get_builder_candidates.category));
  end if;

  -- La selección actual sin la pieza de esta categoría (se va a reemplazar).
  select coalesce(array_agg(o.id), '{}') into others
  from public.offers o
  join public.products p on p.id = o.product_id
  where o.id = any (coalesce(get_builder_candidates.offer_ids, '{}'))
    and p.category_code <> get_builder_candidates.category;

  return (
    select coalesce(jsonb_agg(c.item order by c.compatible desc, c.in_stock desc, c.price, c.id), '[]'::jsonb)
    from (
      select
        cp.id,
        cp.price_cents as price,
        cp.stock_level <> 'outOfStock' as in_stock,
        not exists (
          select 1 from jsonb_array_elements(e.issues) i
          where i ->> 'severity' = 'error' and i -> 'offerIds' ? cp.best_offer_id
        ) as compatible,
        private.product_json(cp) || jsonb_build_object(
          'compatible', not exists (
            select 1 from jsonb_array_elements(e.issues) i
            where i ->> 'severity' = 'error' and i -> 'offerIds' ? cp.best_offer_id
          ),
          'incompatibilityReason', (
            select i ->> 'message' from jsonb_array_elements(e.issues) i
            where i ->> 'severity' = 'error' and i -> 'offerIds' ? cp.best_offer_id
            limit 1
          )
        ) as item
      from private.catalog_products cp
      cross join lateral (
        select private.evaluate_rules(private.builder_parts(others || cp.best_offer_id)) as issues
      ) e
      where cp.category = get_builder_candidates.category
      order by 4 desc, 3 desc, 2, 1
      limit used_limit
    ) c
  );
end;
$$;

revoke all on function public.get_builder_slots() from public;
revoke all on function public.validate_build(text[]) from public;
revoke all on function public.get_builder_candidates(text, text[], integer) from public;
grant execute on function public.get_builder_slots() to anon, authenticated;
grant execute on function public.validate_build(text[]) to anon, authenticated;
grant execute on function public.get_builder_candidates(text, text[], integer) to anon, authenticated;
