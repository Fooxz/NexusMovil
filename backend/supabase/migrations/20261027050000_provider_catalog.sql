-- Publicaciones de las tiendas desde la app (API_CONTRATO, parte 8; HU-016,
-- HU-018, HU-019, RF-021 a RF-024, RF-029, RF-030).
--
-- - Una tienda publica sin aprobación del administrador: el producto queda en
--   el catálogo en cuanto pasa las validaciones automáticas (plantilla de
--   atributos, precio, stock, imágenes, duplicados y un límite diario).
-- - La ficha técnica (products) es compartida: si el producto ya existe, la
--   tienda solo crea su oferta sobre él, y así se comparan los precios.
-- - Quien registró la ficha puede editarla mientras sea la única tienda con
--   una oferta sobre ella (cualquier estado, también retirada). Después queda
--   fija para todos; las correcciones las hace el administrador por SQL.
-- - Cada tienda administra solo su oferta: precio, precio anterior, stock y
--   estado. Retirar es lógico (status = 'retired').
--
-- Todas las RPC exigen private.require_active_provider() y filtran por la
-- tienda de la cuenta; ninguna recibe el id de la tienda como parámetro. Las
-- tablas siguen sin políticas de escritura.

-- ---------------------------------------------------------------------------
-- Ficha: quién la registró y clave contra duplicados
-- ---------------------------------------------------------------------------

alter table public.products
  -- Tienda que registró la ficha. Null: catálogo base (seed, importación).
  add column created_by_provider_id text references public.providers (id) on delete set null;

create index products_created_by_idx on public.products (created_by_provider_id, created_at)
  where created_by_provider_id is not null;

-- Un producto por (categoría, marca, modelo) normalizados: "RTX 5070",
-- "rtx-5070" y "RTX5070" son el mismo modelo.
create unique index products_catalog_key_idx
  on public.products (category_code, private.name_key(brand), private.name_key(model))
  where model is not null;

insert into public.app_settings (key, value, description) values
  ('provider_daily_product_limit', '50',
   'Productos nuevos que una tienda puede registrar en 24 horas. Control automático: no hay moderación.'),
  ('product_max_images', '8', 'Imágenes por producto que registra una tienda.')
on conflict (key) do nothing;

-- ---------------------------------------------------------------------------
-- Imágenes: bucket público, cada tienda sube solo a su carpeta y no puede
-- reemplazar ni borrar lo subido (una ficha compartida no cambia de imagen).
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('product-images', 'product-images', true, 5242880,
  array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

-- ¿Puede la cuenta subir `object_name` (relativo al bucket)? Solo una tienda
-- que puede operar, a su carpeta y sin subcarpetas: "<tienda>/<archivo>".
-- La usa la política de Storage, que corre con el rol de quien sube.
create function public.can_upload_product_image(object_name text) returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  store public.providers;
begin
  select pr.* into store
  from public.providers pr
  join public.profiles p on p.id = pr.user_id
  where pr.user_id = auth.uid()
    and p.role = 'provider'
    and not p.must_change_password
    and pr.status = 'active';
  if store.id is null or not private.has_current_consents(auth.uid()) then
    return false;
  end if;
  return object_name ~ ('^' || store.id || '/[A-Za-z0-9][A-Za-z0-9._-]{0,120}$');
end;
$$;

create policy "Tiendas suben imágenes a su carpeta"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'product-images' and public.can_upload_product_image(name));

-- Sin políticas de lectura, actualización ni borrado: el bucket es público
-- para leer por URL y lo subido no se reemplaza ni se borra desde la app.

-- URL pública de un archivo del bucket. El origen sale del emisor del token
-- de la sesión (firmado por Auth), no de lo que envía la app.
create function private.product_image_url(object_name text) returns text
language sql
stable
set search_path = ''
as $$
  select regexp_replace(auth.jwt() ->> 'iss', '/auth/v1/?$', '')
    || '/storage/v1/object/public/product-images/' || object_name;
$$;

-- Ruta en el bucket de una URL de imagen, o null si no es del bucket.
create function private.product_image_path(url text) returns text
language sql
immutable
set search_path = ''
as $$
  select substring(url from '/storage/v1/object/public/product-images/(.+)$');
$$;

-- ---------------------------------------------------------------------------
-- Validaciones automáticas
-- ---------------------------------------------------------------------------

create function private.validation_error(field text, message text) returns void
language plpgsql
stable
set search_path = ''
as $$
begin
  perform private.raise_api_error_details(400, 'VALIDATION_ERROR', message,
    jsonb_build_object('field', field));
end;
$$;

-- Atributos contra la plantilla de la categoría (RN-032): obligatorios, tipo
-- y valores permitidos. `attributes` es {"clave": valor}.
create function private.validate_attributes(p_category text, attributes jsonb) returns void
language plpgsql
stable
set search_path = ''
as $$
declare
  def public.attribute_definitions;
  value jsonb;
  valid boolean;
  unknown text;
begin
  if attributes is null or jsonb_typeof(attributes) <> 'object' then
    perform private.validation_error('attributes', 'Los atributos técnicos deben ser un objeto {clave: valor}');
  end if;

  select string_agg(k, ', ' order by k) into unknown
  from jsonb_object_keys(attributes) k
  where not exists (
    select 1 from public.attribute_definitions d where d.category_code = p_category and d.key = k
  );
  if unknown is not null then
    perform private.validation_error('attributes', format('Atributos que no son de esta categoría: %s', unknown));
  end if;

  for def in
    select * from public.attribute_definitions d where d.category_code = p_category order by d.sort_order
  loop
    value := attributes -> def.key;
    if value is null or value = 'null'::jsonb then
      if def.is_required then
        perform private.validation_error('attributes.' || def.key,
          format('Falta el atributo obligatorio «%s»', def.label));
      end if;
      continue;
    end if;

    -- CASE anidado: cada conversión se evalúa solo si el tipo coincide.
    valid := case def.data_type
      when 'number' then
        case when jsonb_typeof(value) = 'number' then (value #>> '{}')::numeric >= 0 else false end
      when 'text' then
        case when jsonb_typeof(value) = 'string' then length(trim(value #>> '{}')) between 1 and 120 else false end
      when 'boolean' then jsonb_typeof(value) = 'boolean'
      when 'enum' then
        case when jsonb_typeof(value) = 'string' then (value #>> '{}') = any (def.allowed_values) else false end
      when 'enumList' then
        case when jsonb_typeof(value) = 'array' and jsonb_array_length(value) > 0 then
          not exists (
            select 1 from jsonb_array_elements(value) e
            where jsonb_typeof(e) <> 'string' or not ((e #>> '{}') = any (def.allowed_values))
          )
        else false end
    end;
    if not valid then
      perform private.validation_error('attributes.' || def.key,
        case when def.allowed_values is not null
          then format('«%s» debe ser uno de: %s', def.label, array_to_string(def.allowed_values, ', '))
          else format('Valor inválido para «%s»', def.label)
        end);
    end if;
  end loop;
end;
$$;

-- Imágenes: rutas del bucket que la cuenta subió a la carpeta de su tienda.
create function private.validate_images(p_provider text, images jsonb) returns void
language plpgsql
stable
set search_path = ''
as $$
declare
  max_images integer := private.numeric_setting('product_max_images', 8)::integer;
  path text;
begin
  if images is null or jsonb_typeof(images) <> 'array'
     or jsonb_array_length(images) not between 1 and max_images then
    perform private.validation_error('images', format('Agrega entre 1 y %s imágenes', max_images));
  end if;
  if (select count(distinct e) from jsonb_array_elements(images) e) <> jsonb_array_length(images) then
    perform private.validation_error('images', 'Hay imágenes repetidas');
  end if;
  if auth.jwt() ->> 'iss' is null then
    perform private.validation_error('images', 'La sesión no indica el origen de las imágenes');
  end if;

  for path in select e #>> '{}' from jsonb_array_elements(images) e loop
    if path is null or path !~ ('^' || p_provider || '/[A-Za-z0-9][A-Za-z0-9._-]{0,120}$')
       or not exists (
         select 1 from storage.objects o
         where o.bucket_id = 'product-images'
           and o.name = path
           and o.owner_id = auth.uid()::text
       ) then
      perform private.validation_error('images', 'Alguna imagen no es de tu tienda o no se terminó de subir');
    end if;
  end loop;
end;
$$;

-- Datos de la ficha. `p_category` es la categoría (no cambia al editar).
create function private.validate_product_input(p_category text, product jsonb, p_provider text) returns void
language plpgsql
stable
set search_path = ''
as $$
begin
  if product is null or jsonb_typeof(product) <> 'object' then
    perform private.validation_error('product', 'Faltan los datos del producto');
  end if;
  if p_category is null or not exists (
    select 1 from public.categories c where c.code = p_category and c.is_active
  ) then
    perform private.validation_error('category', 'Elige un tipo de pieza del catálogo');
  end if;
  if length(trim(coalesce(product ->> 'name', ''))) not between 3 and 160 then
    perform private.validation_error('name', 'El nombre debe tener de 3 a 160 caracteres');
  end if;
  if length(trim(coalesce(product ->> 'brand', ''))) not between 1 and 60 then
    perform private.validation_error('brand', 'La marca es obligatoria (hasta 60 caracteres)');
  end if;
  if length(trim(coalesce(product ->> 'model', ''))) not between 1 and 80
     or private.name_key(product ->> 'model') = '' then
    perform private.validation_error('model', 'El modelo es obligatorio (hasta 80 caracteres)');
  end if;
  if length(coalesce(product ->> 'summary', '')) > 200 then
    perform private.validation_error('summary', 'El resumen admite hasta 200 caracteres');
  end if;
  if product ? 'quickSpecs' and not (
    jsonb_typeof(product -> 'quickSpecs') = 'array'
    and jsonb_array_length(product -> 'quickSpecs') <= 8
    and not exists (
      select 1 from jsonb_array_elements(product -> 'quickSpecs') e
      where jsonb_typeof(e) <> 'string' or length(e #>> '{}') not between 1 and 30
    )
  ) then
    perform private.validation_error('quickSpecs', 'Hasta 8 etiquetas cortas de 1 a 30 caracteres');
  end if;
  if product ? 'specs' and not (
    jsonb_typeof(product -> 'specs') = 'array'
    and jsonb_array_length(product -> 'specs') <= 30
    and not exists (
      select 1 from jsonb_array_elements(product -> 'specs') e
      where jsonb_typeof(e) <> 'object'
        or length(coalesce(e ->> 'label', '')) not between 1 and 40
        or length(coalesce(e ->> 'value', '')) not between 1 and 120
    )
  ) then
    perform private.validation_error('specs', 'La ficha admite hasta 30 filas {label, value}');
  end if;

  perform private.validate_attributes(p_category, coalesce(product -> 'attributes', '{}'::jsonb));
  perform private.validate_images(p_provider, product -> 'images');
end;
$$;

-- Oferta: precio en centavos de COP múltiplo de 100, precio anterior mayor
-- (descuento), stock y estado. `status` admite draft, published o paused;
-- retirar tiene su propia RPC.
create function private.validate_offer_input(offer jsonb) returns void
language plpgsql
stable
set search_path = ''
as $$
begin
  if offer is null or jsonb_typeof(offer) <> 'object' then
    perform private.validation_error('offer', 'Faltan los datos de la oferta');
  end if;
  if not coalesce(case when jsonb_typeof(offer -> 'priceCents') = 'number' then
       (offer ->> 'priceCents')::numeric > 0 and (offer ->> 'priceCents')::numeric % 100 = 0
       and (offer ->> 'priceCents')::numeric <= 100000000000 end, false) then
    perform private.validation_error('priceCents', 'El precio debe ser mayor que 0 y en pesos enteros');
  end if;
  if offer -> 'oldPriceCents' is not null and offer -> 'oldPriceCents' <> 'null'::jsonb
     and not coalesce(case when jsonb_typeof(offer -> 'oldPriceCents') = 'number' then
       (offer ->> 'oldPriceCents')::numeric % 100 = 0
       and (offer ->> 'oldPriceCents')::numeric > (offer ->> 'priceCents')::numeric
       and (offer ->> 'oldPriceCents')::numeric <= 100000000000 end, false) then
    perform private.validation_error('oldPriceCents', 'El precio anterior debe ser mayor que el precio actual');
  end if;
  if not coalesce(case when jsonb_typeof(offer -> 'stockUnits') = 'number' then
       (offer ->> 'stockUnits')::numeric between 0 and 100000
       and (offer ->> 'stockUnits')::numeric = trunc((offer ->> 'stockUnits')::numeric) end, false) then
    perform private.validation_error('stockUnits', 'Las existencias deben ser un número entero de 0 a 100000');
  end if;
  if coalesce(offer ->> 'status', 'published') not in ('draft', 'published', 'paused') then
    perform private.validation_error('status', 'El estado debe ser borrador, publicada o pausada');
  end if;
  if offer ? 'externalSku' and offer -> 'externalSku' <> 'null'::jsonb
     and length(trim(coalesce(offer ->> 'externalSku', ''))) not between 1 and 64 then
    perform private.validation_error('externalSku', 'El código interno admite de 1 a 64 caracteres');
  end if;
end;
$$;

-- Duplicados: el mismo (categoría, marca, modelo) normalizado ya existe
-- (PRODUCT_EXISTS), o hay modelos parecidos de la misma marca, uno contenido
-- en el otro (POSSIBLE_DUPLICATE, se acepta con confirm_distinct).
create function private.check_duplicates(
  p_category text,
  product jsonb,
  current_id text,
  confirm_distinct boolean
) returns void
language plpgsql
stable
set search_path = ''
as $$
declare
  brand_key text := private.name_key(product ->> 'brand');
  model_key text := private.name_key(product ->> 'model');
  existing public.products;
  candidates jsonb;
begin
  select * into existing from public.products p
  where p.category_code = p_category
    and private.name_key(p.brand) = brand_key
    and private.name_key(p.model) = model_key
    and p.model is not null
    and p.id is distinct from current_id;
  if existing.id is not null then
    perform private.raise_api_error_details(409, 'PRODUCT_EXISTS',
      'Este producto ya está en el catálogo. Publica tu oferta sobre él.',
      jsonb_build_object('productId', existing.id, 'name', existing.name));
  end if;

  if coalesce(confirm_distinct, false) or length(model_key) < 4 then
    return;
  end if;
  select jsonb_agg(jsonb_build_object('productId', c.id, 'name', c.name, 'model', c.model) order by c.name)
  into candidates
  from (
    select p.id, p.name, p.model from public.products p
    where p.category_code = p_category
      and private.name_key(p.brand) = brand_key
      and p.model is not null
      and p.id is distinct from current_id
      and length(private.name_key(p.model)) >= 4
      and (position(private.name_key(p.model) in model_key) > 0
           or position(model_key in private.name_key(p.model)) > 0)
    order by p.name
    limit 5
  ) c;
  if candidates is not null then
    perform private.raise_api_error_details(409, 'POSSIBLE_DUPLICATE',
      'Puede que este producto ya esté en el catálogo. Revisa los parecidos o confirma que es otro.',
      jsonb_build_object('candidates', candidates));
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Escritura de la ficha y respuesta para la tienda
-- ---------------------------------------------------------------------------

-- Reemplaza datos, atributos e imágenes de la ficha (ya validados).
create function private.write_product_sheet(p_product_id text, p_category text, product jsonb) returns void
language plpgsql
set search_path = ''
as $$
begin
  update public.products p
  set name = trim(product ->> 'name'),
      brand = trim(product ->> 'brand'),
      model = trim(product ->> 'model'),
      summary = nullif(trim(coalesce(product ->> 'summary', '')), ''),
      quick_specs = coalesce(
        (select array_agg(trim(e #>> '{}') order by ord)
         from jsonb_array_elements(product -> 'quickSpecs') with ordinality as t(e, ord)), '{}'),
      specs = coalesce(product -> 'specs', '[]'::jsonb)
  where p.id = p_product_id;

  delete from public.product_attributes a where a.product_id = p_product_id;
  insert into public.product_attributes (product_id, attribute_id, value_number, value_text, value_bool, value_list)
  select p_product_id, d.id,
    case when d.data_type = 'number' then (a.value #>> '{}')::numeric end,
    case when d.data_type in ('text', 'enum') then trim(a.value #>> '{}') end,
    case when d.data_type = 'boolean' then (a.value #>> '{}')::boolean end,
    case when d.data_type = 'enumList' then array(select jsonb_array_elements_text(a.value)) end
  from jsonb_each(coalesce(product -> 'attributes', '{}'::jsonb)) a
  join public.attribute_definitions d on d.category_code = p_category and d.key = a.key
  where a.value <> 'null'::jsonb;

  delete from public.product_images i where i.product_id = p_product_id;
  insert into public.product_images (product_id, url, sort_order)
  select p_product_id, private.product_image_url(e #>> '{}'), (ord - 1)::integer
  from jsonb_array_elements(product -> 'images') with ordinality as t(e, ord);
end;
$$;

-- ¿Puede la tienda editar la ficha? Si la registró y ninguna otra tienda
-- tiene o tuvo una oferta sobre ella (las ofertas nunca se borran).
create function private.sheet_editable(p_product_id text, p_provider text) returns boolean
language sql
stable
set search_path = ''
as $$
  select coalesce((
    select p.created_by_provider_id = p_provider
      and not exists (
        select 1 from public.offers o where o.product_id = p.id and o.provider_id <> p_provider
      )
    from public.products p where p.id = p_product_id
  ), false);
$$;

create function private.attributes_json(p_product_id text) returns jsonb
language sql
stable
set search_path = ''
as $$
  select coalesce(jsonb_object_agg(d.key, case d.data_type
      when 'number' then to_jsonb(pa.value_number)
      when 'boolean' then to_jsonb(pa.value_bool)
      when 'enumList' then to_jsonb(pa.value_list)
      else to_jsonb(pa.value_text)
    end), '{}'::jsonb)
  from public.product_attributes pa
  join public.attribute_definitions d on d.id = pa.attribute_id
  where pa.product_id = p_product_id;
$$;

-- Oferta de la tienda en la lista "Mis publicaciones".
create function private.my_offer_json(o public.offers, p public.products, p_provider text) returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'offerId', o.id,
    'productId', p.id,
    'name', p.name,
    'brand', p.brand,
    'model', p.model,
    'category', p.category_code,
    'imageUrl', (
      select coalesce(i.thumb_url, i.url) from public.product_images i
      where i.product_id = p.id order by i.sort_order, i.id limit 1
    ),
    'priceCents', o.price_cents,
    'oldPriceCents', o.old_price_cents,
    -- Son de la tienda: a ella sí se le muestran las unidades.
    'stockUnits', o.stock_units,
    'stockLevel', private.stock_level(o.stock_units),
    'status', o.status,
    'externalSku', o.external_sku,
    'visible', o.status = 'published'
      and exists (select 1 from public.providers pr where pr.id = o.provider_id and pr.status = 'active'),
    'canEditSheet', private.sheet_editable(p.id, p_provider),
    'updatedAt', o.updated_at
  );
$$;

-- Detalle para editar: la oferta y la ficha completa.
create function private.my_offer_detail(p_product_id text, p_provider text) returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  o public.offers;
  p public.products;
begin
  select * into o from public.offers x where x.product_id = p_product_id and x.provider_id = p_provider;
  select * into p from public.products x where x.id = p_product_id;
  if o.id is null or p.id is null then
    perform private.raise_api_error(404, 'OFFER_NOT_FOUND', 'No tienes una oferta de ese producto');
  end if;

  return private.my_offer_json(o, p, p_provider) || jsonb_build_object(
    'summary', p.summary,
    'quickSpecs', to_jsonb(p.quick_specs),
    'specs', p.specs,
    'attributes', private.attributes_json(p.id),
    'images', coalesce((
      select jsonb_agg(jsonb_build_object('url', i.url, 'path', private.product_image_path(i.url))
        order by i.sort_order, i.id)
      from public.product_images i where i.product_id = p.id), '[]'::jsonb),
    'sellers', (
      select count(*) from public.offers x
      where x.product_id = p.id and x.status = 'published'
        and exists (select 1 from public.providers pr where pr.id = x.provider_id and pr.status = 'active')
    )
  );
end;
$$;

-- Inserta la oferta de la tienda (ya validada).
create function private.insert_offer(p_product_id text, p_provider text, offer jsonb) returns void
language plpgsql
set search_path = ''
as $$
begin
  insert into public.offers
    (product_id, provider_id, external_sku, price_cents, old_price_cents, stock_units, status, stock_synced_at)
  values (
    p_product_id,
    p_provider,
    coalesce(nullif(trim(offer ->> 'externalSku'), ''), p_product_id),
    (offer ->> 'priceCents')::bigint,
    nullif(offer ->> 'oldPriceCents', '')::bigint,
    (offer ->> 'stockUnits')::integer,
    coalesce(offer ->> 'status', 'published')::public.offer_status,
    now()
  );
exception when unique_violation then
  perform private.validation_error('externalSku', 'Ya usas ese código interno en otra oferta');
end;
$$;

-- ---------------------------------------------------------------------------
-- RPC de la tienda
-- ---------------------------------------------------------------------------

-- Busca fichas del catálogo, tengan o no ofertas visibles, para publicar una
-- oferta sobre un producto existente en vez de duplicarlo.
create function public.search_catalog_sheets(
  search text default null,
  category text default null,
  page integer default 0,
  page_size integer default 20
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  store_id text := private.require_active_provider();
  pattern text := private.search_pattern(search_catalog_sheets.search);
  used_size integer := least(greatest(coalesce(search_catalog_sheets.page_size, 20), 1), 50);
  total_count bigint;
  items jsonb;
begin
  if coalesce(search_catalog_sheets.page, 0) < 0 then
    perform private.raise_api_error(400, 'VALIDATION_ERROR', 'page no puede ser negativo');
  end if;
  perform private.validate_catalog_filters(null, search_catalog_sheets.category);

  select count(*) into total_count
  from public.products p
  join public.categories c on c.code = p.category_code and c.is_active
  where (search_catalog_sheets.category is null or p.category_code = search_catalog_sheets.category)
    and (pattern is null
      or private.normalize_search(p.name) like pattern
      or private.normalize_search(p.brand) like pattern
      or private.normalize_search(coalesce(p.model, '')) like pattern);

  select coalesce(jsonb_agg(jsonb_build_object(
      'productId', p.id,
      'name', p.name,
      'brand', p.brand,
      'model', p.model,
      'category', p.category_code,
      'imageUrl', (
        select coalesce(i.thumb_url, i.url) from public.product_images i
        where i.product_id = p.id order by i.sort_order, i.id limit 1
      ),
      'sellers', (select count(*) from private.visible_offers o where o.product_id = p.id),
      'myOffer', (
        select jsonb_build_object('offerId', o.id, 'status', o.status)
        from public.offers o where o.product_id = p.id and o.provider_id = store_id
      )
    ) order by m.name, m.id), '[]'::jsonb)
  into items
  from (
    select p.id, p.name
    from public.products p
    join public.categories c on c.code = p.category_code and c.is_active
    where (search_catalog_sheets.category is null or p.category_code = search_catalog_sheets.category)
      and (pattern is null
        or private.normalize_search(p.name) like pattern
        or private.normalize_search(p.brand) like pattern
        or private.normalize_search(coalesce(p.model, '')) like pattern)
    order by p.name, p.id
    offset coalesce(search_catalog_sheets.page, 0)::bigint * used_size
    limit used_size
  ) m
  join public.products p on p.id = m.id;

  return jsonb_build_object('items', items, 'total', total_count,
    'page', coalesce(search_catalog_sheets.page, 0), 'pageSize', used_size);
end;
$$;

-- "Mis publicaciones": las ofertas de la tienda. Sin `status`, todas menos
-- las retiradas.
create function public.get_my_offers(
  status text default null,
  search text default null,
  page integer default 0,
  page_size integer default 20
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  store_id text := private.require_active_provider();
  pattern text := private.search_pattern(get_my_offers.search);
  used_size integer := least(greatest(coalesce(get_my_offers.page_size, 20), 1), 50);
  total_count bigint;
  items jsonb;
begin
  if get_my_offers.status is not null
     and get_my_offers.status not in ('draft', 'published', 'paused', 'retired') then
    perform private.raise_api_error(400, 'VALIDATION_ERROR', 'status desconocido');
  end if;
  if coalesce(get_my_offers.page, 0) < 0 then
    perform private.raise_api_error(400, 'VALIDATION_ERROR', 'page no puede ser negativo');
  end if;

  select count(*) into total_count
  from public.offers o join public.products p on p.id = o.product_id
  where o.provider_id = store_id
    and (case when get_my_offers.status is null then o.status <> 'retired'
              else o.status::text = get_my_offers.status end)
    and (pattern is null or private.normalize_search(p.name) like pattern
         or private.normalize_search(p.brand) like pattern);

  select coalesce(jsonb_agg(private.my_offer_json(s.o, s.p, store_id) order by s.ord), '[]'::jsonb)
  into items
  from (
    select o, p, row_number() over (order by o.updated_at desc, o.id) as ord
    from public.offers o join public.products p on p.id = o.product_id
    where o.provider_id = store_id
      and (case when get_my_offers.status is null then o.status <> 'retired'
                else o.status::text = get_my_offers.status end)
      and (pattern is null or private.normalize_search(p.name) like pattern
           or private.normalize_search(p.brand) like pattern)
    order by o.updated_at desc, o.id
    offset coalesce(get_my_offers.page, 0)::bigint * used_size
    limit used_size
  ) s;

  return jsonb_build_object('items', items, 'total', total_count,
    'page', coalesce(get_my_offers.page, 0), 'pageSize', used_size);
end;
$$;

create function public.get_my_offer(product_id text) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  return private.my_offer_detail(get_my_offer.product_id, private.require_active_provider());
end;
$$;

-- Registra un producto nuevo con la oferta de la tienda. Se publica en
-- cuanto pasa las validaciones (sin aprobación del administrador).
create function public.create_my_product(
  product jsonb,
  offer jsonb,
  confirm_distinct boolean default false
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  store_id text := private.require_active_provider();
  v_category text := create_my_product.product ->> 'category';
  daily_limit integer := private.numeric_setting('provider_daily_product_limit', 50)::integer;
  new_id text;
begin
  if (
    select count(*) from public.products p
    where p.created_by_provider_id = store_id and p.created_at > now() - interval '24 hours'
  ) >= daily_limit then
    perform private.raise_api_error(429, 'RATE_LIMITED',
      format('Llegaste al límite de %s productos nuevos por día. Inténtalo mañana.', daily_limit));
  end if;

  perform private.validate_product_input(v_category, create_my_product.product, store_id);
  perform private.validate_offer_input(create_my_product.offer);
  perform private.check_duplicates(v_category, create_my_product.product, null, create_my_product.confirm_distinct);

  begin
    insert into public.products (name, brand, model, category_code, created_by_provider_id)
    values (trim(create_my_product.product ->> 'name'), trim(create_my_product.product ->> 'brand'),
      trim(create_my_product.product ->> 'model'), v_category, store_id)
    returning id into new_id;
  exception when unique_violation then
    -- Otra tienda registró el mismo modelo al mismo tiempo.
    perform private.check_duplicates(v_category, create_my_product.product, null, true);
    raise;
  end;

  perform private.write_product_sheet(new_id, v_category, create_my_product.product);
  perform private.insert_offer(new_id, store_id, create_my_product.offer);
  return private.my_offer_detail(new_id, store_id);
end;
$$;

-- Edita la ficha: solo quien la registró y mientras sea la única tienda con
-- una oferta sobre ella. La categoría no cambia.
create function public.update_my_product(product_id text, product jsonb) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  store_id text := private.require_active_provider();
  sheet public.products;
begin
  -- El bloqueo ordena esta edición con create_my_offer de otra tienda.
  select * into sheet from public.products p where p.id = update_my_product.product_id for update;
  if sheet.id is null or not exists (
    select 1 from public.offers o where o.product_id = sheet.id and o.provider_id = store_id
  ) then
    perform private.raise_api_error(404, 'OFFER_NOT_FOUND', 'No tienes una oferta de ese producto');
  end if;
  if sheet.created_by_provider_id is distinct from store_id then
    perform private.raise_api_error(403, 'PRODUCT_LOCKED',
      'Esta ficha es del catálogo compartido: solo puedes cambiar tu oferta');
  end if;
  if not private.sheet_editable(sheet.id, store_id) then
    perform private.raise_api_error(409, 'PRODUCT_SHARED',
      'Otras tiendas venden este producto: la ficha ya no se puede editar, solo tu oferta');
  end if;

  perform private.validate_product_input(sheet.category_code, update_my_product.product, store_id);
  perform private.check_duplicates(sheet.category_code, update_my_product.product, sheet.id, true);
  perform private.write_product_sheet(sheet.id, sheet.category_code, update_my_product.product);
  return private.my_offer_detail(sheet.id, store_id);
end;
$$;

-- Publica la oferta de la tienda sobre un producto que ya existe. Si la tenía
-- retirada, la reactiva (una oferta por tienda y producto).
create function public.create_my_offer(product_id text, offer jsonb) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  store_id text := private.require_active_provider();
  target public.products;
  existing public.offers;
begin
  select p.* into target
  from public.products p
  join public.categories c on c.code = p.category_code and c.is_active
  where p.id = create_my_offer.product_id
  for update of p;
  if target.id is null then
    perform private.raise_api_error(404, 'PRODUCT_NOT_FOUND', 'No existe ese producto en el catálogo');
  end if;
  perform private.validate_offer_input(create_my_offer.offer);

  select * into existing from public.offers o where o.product_id = target.id and o.provider_id = store_id;
  if existing.id is not null and existing.status <> 'retired' then
    perform private.raise_api_error_details(409, 'OFFER_EXISTS', 'Ya tienes una oferta de este producto',
      jsonb_build_object('offerId', existing.id));
  end if;

  if existing.id is not null then
    update public.offers o
    set price_cents = (create_my_offer.offer ->> 'priceCents')::bigint,
        old_price_cents = nullif(create_my_offer.offer ->> 'oldPriceCents', '')::bigint,
        stock_units = (create_my_offer.offer ->> 'stockUnits')::integer,
        status = coalesce(create_my_offer.offer ->> 'status', 'published')::public.offer_status,
        external_sku = coalesce(nullif(trim(create_my_offer.offer ->> 'externalSku'), ''), o.external_sku),
        stock_synced_at = now()
    where o.id = existing.id;
  else
    perform private.insert_offer(target.id, store_id, create_my_offer.offer);
  end if;
  return private.my_offer_detail(target.id, store_id);
end;
$$;

-- Precio, descuento, stock y estado de la oferta de la tienda.
create function public.update_my_offer(product_id text, offer jsonb) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  store_id text := private.require_active_provider();
  mine public.offers;
begin
  select * into mine from public.offers o
  where o.product_id = update_my_offer.product_id and o.provider_id = store_id
  for update;
  if mine.id is null then
    perform private.raise_api_error(404, 'OFFER_NOT_FOUND', 'No tienes una oferta de ese producto');
  end if;
  if mine.status = 'retired' then
    perform private.raise_api_error(409, 'OFFER_RETIRED', 'La oferta está retirada: vuelve a publicarla');
  end if;
  perform private.validate_offer_input(update_my_offer.offer);

  begin
    update public.offers o
    set price_cents = (update_my_offer.offer ->> 'priceCents')::bigint,
        old_price_cents = nullif(update_my_offer.offer ->> 'oldPriceCents', '')::bigint,
        stock_units = (update_my_offer.offer ->> 'stockUnits')::integer,
        status = coalesce(update_my_offer.offer ->> 'status', o.status::text)::public.offer_status,
        external_sku = coalesce(nullif(trim(update_my_offer.offer ->> 'externalSku'), ''), o.external_sku),
        stock_synced_at = case when o.stock_units is distinct from (update_my_offer.offer ->> 'stockUnits')::integer
                               then now() else o.stock_synced_at end
    where o.id = mine.id;
  exception when unique_violation then
    perform private.validation_error('externalSku', 'Ya usas ese código interno en otra oferta');
  end;
  return private.my_offer_detail(mine.product_id, store_id);
end;
$$;

-- Retira la oferta (lógico): sale del catálogo y queda en el historial de
-- órdenes. Se vuelve a publicar con create_my_offer.
create function public.retire_my_offer(product_id text) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  store_id text := private.require_active_provider();
begin
  update public.offers o set status = 'retired'
  where o.product_id = retire_my_offer.product_id and o.provider_id = store_id;
  if not found then
    perform private.raise_api_error(404, 'OFFER_NOT_FOUND', 'No tienes una oferta de ese producto');
  end if;
  return private.my_offer_detail(retire_my_offer.product_id, store_id);
end;
$$;

-- ---------------------------------------------------------------------------
-- Permisos: solo cuentas con sesión; cada RPC exige una tienda que pueda operar.
-- ---------------------------------------------------------------------------

revoke all on function public.can_upload_product_image(text) from public, anon;
revoke all on function public.search_catalog_sheets(text, text, integer, integer) from public, anon;
revoke all on function public.get_my_offers(text, text, integer, integer) from public, anon;
revoke all on function public.get_my_offer(text) from public, anon;
revoke all on function public.create_my_product(jsonb, jsonb, boolean) from public, anon;
revoke all on function public.update_my_product(text, jsonb) from public, anon;
revoke all on function public.create_my_offer(text, jsonb) from public, anon;
revoke all on function public.update_my_offer(text, jsonb) from public, anon;
revoke all on function public.retire_my_offer(text) from public, anon;

grant execute on function public.can_upload_product_image(text) to authenticated;
grant execute on function public.search_catalog_sheets(text, text, integer, integer) to authenticated;
grant execute on function public.get_my_offers(text, text, integer, integer) to authenticated;
grant execute on function public.get_my_offer(text) to authenticated;
grant execute on function public.create_my_product(jsonb, jsonb, boolean) to authenticated;
grant execute on function public.update_my_product(text, jsonb) to authenticated;
grant execute on function public.create_my_offer(text, jsonb) to authenticated;
grant execute on function public.update_my_offer(text, jsonb) to authenticated;
grant execute on function public.retire_my_offer(text) to authenticated;
