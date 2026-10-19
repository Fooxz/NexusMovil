-- Fase 2: RPC públicas del catálogo (docs/API_CONTRATO.md, secciones 3 y 4).
--
--   GET /api/v1/products               -> rpc/get_products
--   GET /api/v1/products/{id}          -> rpc/get_product
--   GET /api/v1/products/{id}/related  -> rpc/get_related
--
-- Son SECURITY DEFINER: leen tablas sin políticas públicas y aplican aquí las
-- reglas de visibilidad. Solo devuelven productos con al menos una oferta
-- publicada de un proveedor activo (RF-015, RF-035, RN-022).

-- ---------------------------------------------------------------------------
-- Errores con el cuerpo del contrato: {"code": ..., "message": ...}
-- PostgREST usa "status" de detail como código HTTP.
-- ---------------------------------------------------------------------------

create function private.raise_api_error(status integer, code text, message text)
returns void
language plpgsql
stable  -- Solo lanza un error; permite llamarla desde las RPC stable.
set search_path = ''
as $$
begin
  raise sqlstate 'PGRST' using
    message = json_build_object(
      'code', code,
      'message', message,
      'details', null,
      'hint', null
    )::text,
    detail = json_build_object('status', status, 'headers', json_build_object())::text;
end;
$$;

-- ---------------------------------------------------------------------------
-- Vistas internas
-- ---------------------------------------------------------------------------

create view private.visible_offers as
select o.*, pr.display_name as provider_name
from public.offers o
join public.providers pr on pr.id = o.provider_id
where o.status = 'published'
  and pr.status = 'active';

-- Un producto del catálogo con su mejor oferta: la más barata con stock; si
-- ninguna tiene stock, la más barata. El nivel de stock es el mejor entre todas.
create view private.catalog_products as
select
  p.id,
  p.name,
  p.brand,
  c.family,
  p.category_code as category,
  c.name as category_name,
  c.search_terms,
  best.price_cents,
  best.old_price_cents,
  private.stock_level(agg.max_units) as stock_level,
  img.image_url,
  p.summary,
  p.quick_specs,
  p.specs
from public.products p
join public.categories c on c.code = p.category_code and c.is_active
join lateral (
  select o.price_cents, o.old_price_cents
  from private.visible_offers o
  where o.product_id = p.id
  order by (o.stock_units > 0) desc, o.price_cents, o.id
  limit 1
) best on true
cross join lateral (
  select max(o.stock_units) as max_units
  from private.visible_offers o
  where o.product_id = p.id
) agg
left join lateral (
  select coalesce(i.thumb_url, i.url) as image_url
  from public.product_images i
  where i.product_id = p.id
  order by i.sort_order, i.id
  limit 1
) img on true;

-- ---------------------------------------------------------------------------
-- Funciones auxiliares
-- ---------------------------------------------------------------------------

-- Búsqueda sin distinguir mayúsculas ni acentos.
create function private.normalize_search(value text) returns text
language sql
stable
set search_path = ''
as $$
  select lower(extensions.unaccent(trim(coalesce(value, ''))));
$$;

-- Patrón LIKE de "contiene", escapando los comodines que escriba el usuario.
create function private.search_pattern(value text) returns text
language sql
stable
set search_path = ''
as $$
  select case
    when private.normalize_search(value) = '' then null
    else '%' || replace(replace(replace(
      private.normalize_search(value), '\', '\\'), '%', '\%'), '_', '\_') || '%'
  end;
$$;

create function private.filtered_catalog(p_family text, p_category text, p_pattern text)
returns setof private.catalog_products
language sql
stable
set search_path = ''
as $$
  select cp.*
  from private.catalog_products cp
  where (p_family is null or cp.family::text = p_family)
    and (p_category is null or cp.category = p_category)
    and (
      p_pattern is null
      or private.normalize_search(cp.name) like p_pattern
      or private.normalize_search(cp.brand) like p_pattern
      or private.normalize_search(cp.category) like p_pattern
      or private.normalize_search(cp.category_name) like p_pattern
      or exists (
        select 1 from unnest(cp.search_terms) as term
        where private.normalize_search(term) like p_pattern
      )
    );
$$;

-- Objeto Product del contrato (sección 2).
create function private.product_json(
  cp private.catalog_products,
  offer_list jsonb default '[]'::jsonb
) returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'id', cp.id,
    'name', cp.name,
    'brand', cp.brand,
    'family', cp.family,
    'category', cp.category,
    'priceCents', cp.price_cents,
    'oldPriceCents', cp.old_price_cents,
    'stockLevel', cp.stock_level,
    'imageUrl', cp.image_url,
    'summary', cp.summary,
    'quickSpecs', to_jsonb(cp.quick_specs),
    'specs', cp.specs,
    'offers', offer_list
  );
$$;

-- ---------------------------------------------------------------------------
-- RPC públicas
-- ---------------------------------------------------------------------------

create function public.get_products(
  page integer default 0,
  page_size integer default 20,
  search text default null,
  family text default null,
  category text default null
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  used_size integer;
  pattern text;
  total_count bigint;
  items jsonb;
begin
  if get_products.page is null or get_products.page < 0 then
    perform private.raise_api_error(400, 'VALIDATION_ERROR', 'page no puede ser negativo');
  end if;
  if get_products.page_size is null or get_products.page_size < 1 then
    perform private.raise_api_error(400, 'VALIDATION_ERROR', 'page_size debe ser mayor que 0');
  end if;
  if get_products.family is not null
    and get_products.family not in ('prebuiltPc', 'part') then
    perform private.raise_api_error(400, 'VALIDATION_ERROR',
      format('family desconocida: %s', get_products.family));
  end if;
  if get_products.category is not null and not exists (
    select 1 from public.categories c
    where c.code = get_products.category and c.is_active
  ) then
    perform private.raise_api_error(400, 'VALIDATION_ERROR',
      format('category desconocida: %s', get_products.category));
  end if;

  used_size := least(get_products.page_size, 50);
  pattern := private.search_pattern(get_products.search);

  select count(*) into total_count
  from private.filtered_catalog(get_products.family, get_products.category, pattern);

  select coalesce(jsonb_agg(private.product_json(s.fc) order by (s.fc).name, (s.fc).id), '[]'::jsonb)
  into items
  from (
    select fc
    from private.filtered_catalog(get_products.family, get_products.category, pattern) fc
    order by fc.name, fc.id
    offset get_products.page::bigint * used_size
    limit used_size
  ) s;

  return jsonb_build_object(
    'items', items,
    'total', total_count,
    'page', get_products.page,
    'pageSize', used_size
  );
end;
$$;

create function public.get_product(id text) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  cp private.catalog_products;
  offer_list jsonb;
begin
  select c.* into cp
  from private.catalog_products c
  where c.id = get_product.id;

  if not found then
    perform private.raise_api_error(404, 'PRODUCT_NOT_FOUND',
      format('No existe el producto %s', get_product.id));
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
      'id', o.id,
      'providerId', o.provider_id,
      'providerName', o.provider_name,
      'priceCents', o.price_cents,
      'oldPriceCents', o.old_price_cents,
      'stockLevel', private.stock_level(o.stock_units)
    ) order by (o.stock_units > 0) desc, o.price_cents, o.id), '[]'::jsonb)
  into offer_list
  from private.visible_offers o
  where o.product_id = cp.id;

  return private.product_json(cp, offer_list);
end;
$$;

create function public.get_related(id text, max_items integer default 2)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  source_category text;
  used_limit integer := least(coalesce(get_related.max_items, 2), 10);
begin
  select c.category into source_category
  from private.catalog_products c
  where c.id = get_related.id;

  if not found then
    perform private.raise_api_error(404, 'PRODUCT_NOT_FOUND',
      format('No existe el producto %s', get_related.id));
  end if;

  if used_limit <= 0 then
    return '[]'::jsonb;
  end if;

  return (
    select coalesce(jsonb_agg(private.product_json(s.cp) order by s.rank, (s.cp).name, (s.cp).id), '[]'::jsonb)
    from (
      select cp, (cp.category <> source_category)::integer as rank
      from private.catalog_products cp
      where cp.id <> get_related.id
      order by (cp.category <> source_category), cp.name, cp.id
      limit used_limit
    ) s
  );
end;
$$;

-- Las RPC son la única puerta de lectura del catálogo para los clientes.
revoke all on function public.get_products(integer, integer, text, text, text) from public;
revoke all on function public.get_product(text) from public;
revoke all on function public.get_related(text, integer) from public;
grant execute on function public.get_products(integer, integer, text, text, text) to anon, authenticated;
grant execute on function public.get_product(text) to anon, authenticated;
grant execute on function public.get_related(text, integer) to anon, authenticated;
