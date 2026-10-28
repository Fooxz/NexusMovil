-- Catálogo por oferta (API_CONTRATO, parte 6): una tarjeta por cada tienda que
-- vende un producto, con su precio, su descuento y su stock, aunque el
-- nombre, la marca y el modelo sean iguales. La ficha técnica sigue siendo
-- una sola (products) y cada tienda es dueña de su oferta (offers).
--
--   GET /api/v1/offers            -> rpc/get_offers
--   GET /api/v1/catalog/providers -> rpc/get_catalog_providers (filtro por tienda)
--
-- No cambia nada existente: get_products, get_product y get_related siguen
-- sirviendo al detalle (comparación entre tiendas), al PC Builder y al
-- asistente. Mismas reglas de visibilidad que el resto del catálogo: solo
-- ofertas publicadas de tiendas activas, en categorías activas (RF-015,
-- RN-022, private.visible_offers).

-- Una fila por oferta visible. `offer_count` es cuántas tiendas venden el
-- producto, para "Comparar N tiendas"; se calcula antes de cualquier filtro.
create view private.catalog_offers as
select
  o.id as offer_id,
  p.id as product_id,
  p.name,
  p.brand,
  p.category_code as category,
  c.name as category_name,
  c.search_terms,
  o.provider_id,
  o.provider_name,
  o.price_cents,
  o.old_price_cents,
  private.stock_level(o.stock_units) as stock_level,
  img.image_url,
  p.summary,
  p.quick_specs,
  count(*) over (partition by p.id) as offer_count
from private.visible_offers o
join public.products p on p.id = o.product_id
join public.categories c on c.code = p.category_code and c.is_active
left join lateral (
  select coalesce(i.thumb_url, i.url) as image_url
  from public.product_images i
  where i.product_id = p.id
  order by i.sort_order, i.id
  limit 1
) img on true;

create function private.filtered_offers(
  p_category text,
  p_pattern text,
  p_brand text default null,
  p_provider text default null,
  p_min_price_cents bigint default null,
  p_max_price_cents bigint default null
) returns setof private.catalog_offers
language sql
stable
set search_path = ''
as $$
  select co.*
  from private.catalog_offers co
  where (p_category is null or co.category = p_category)
    and (p_brand is null or lower(co.brand) = lower(trim(p_brand)))
    and (p_provider is null or co.provider_id = p_provider)
    and (p_min_price_cents is null or co.price_cents >= p_min_price_cents)
    and (p_max_price_cents is null or co.price_cents <= p_max_price_cents)
    and (
      p_pattern is null
      or private.normalize_search(co.name) like p_pattern
      or private.normalize_search(co.brand) like p_pattern
      or private.normalize_search(co.category) like p_pattern
      or private.normalize_search(co.category_name) like p_pattern
      or private.normalize_search(co.provider_name) like p_pattern
      or exists (
        select 1 from unnest(co.search_terms) as term
        where private.normalize_search(term) like p_pattern
      )
    );
$$;

create function private.offer_json(co private.catalog_offers) returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'offerId', co.offer_id,
    'productId', co.product_id,
    'name', co.name,
    'brand', co.brand,
    'category', co.category,
    'providerId', co.provider_id,
    'providerName', co.provider_name,
    'priceCents', co.price_cents,
    'oldPriceCents', co.old_price_cents,
    'stockLevel', co.stock_level,
    'imageUrl', co.image_url,
    'summary', co.summary,
    'quickSpecs', to_jsonb(co.quick_specs),
    'offerCount', co.offer_count
  );
$$;

-- Catálogo principal. "relevance" ordena por nombre (mientras no haya un
-- puntaje de búsqueda) y deja juntas las ofertas del mismo producto: primero
-- las que tienen stock y después por precio. El id de la oferta desempata
-- para que el orden sea estable entre páginas.
create function public.get_offers(
  page integer default 0,
  page_size integer default 20,
  search text default null,
  category text default null,
  brand text default null,
  provider text default null,
  min_price_cents bigint default null,
  max_price_cents bigint default null,
  sort text default 'relevance'
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  used_size integer;
  used_sort text := coalesce(get_offers.sort, 'relevance');
  used_brand text := nullif(trim(get_offers.brand), '');
  used_provider text := nullif(trim(get_offers.provider), '');
  pattern text;
  total_count bigint;
  items jsonb;
begin
  if get_offers.page is null or get_offers.page < 0 then
    perform private.raise_api_error(400, 'VALIDATION_ERROR', 'page no puede ser negativo');
  end if;
  if get_offers.page_size is null or get_offers.page_size < 1 then
    perform private.raise_api_error(400, 'VALIDATION_ERROR', 'page_size debe ser mayor que 0');
  end if;
  perform private.validate_catalog_filters(null, get_offers.category);
  if used_sort not in ('relevance', 'priceAsc', 'priceDesc') then
    perform private.raise_api_error(400, 'VALIDATION_ERROR',
      format('sort desconocido: %s', used_sort));
  end if;
  if get_offers.min_price_cents < 0 or get_offers.max_price_cents < 0 then
    perform private.raise_api_error(400, 'VALIDATION_ERROR', 'los precios no pueden ser negativos');
  end if;
  if get_offers.min_price_cents > get_offers.max_price_cents then
    perform private.raise_api_error(400, 'VALIDATION_ERROR',
      'min_price_cents no puede ser mayor que max_price_cents');
  end if;
  if used_provider is not null
     and not exists (select 1 from public.providers pr where pr.id = used_provider) then
    perform private.raise_api_error(400, 'VALIDATION_ERROR',
      format('provider desconocido: %s', used_provider));
  end if;

  used_size := least(get_offers.page_size, 50);
  pattern := private.search_pattern(get_offers.search);

  select count(*) into total_count
  from private.filtered_offers(get_offers.category, pattern, used_brand, used_provider,
    get_offers.min_price_cents, get_offers.max_price_cents);

  select coalesce(jsonb_agg(private.offer_json(s.fo) order by s.position), '[]'::jsonb)
  into items
  from (
    select
      fo,
      row_number() over (
        order by
          case when used_sort = 'priceAsc' then fo.price_cents end asc,
          case when used_sort = 'priceDesc' then fo.price_cents end desc,
          fo.name,
          fo.product_id,
          fo.stock_level = 'outOfStock',
          fo.price_cents,
          fo.offer_id
      ) as position
    from private.filtered_offers(get_offers.category, pattern, used_brand, used_provider,
      get_offers.min_price_cents, get_offers.max_price_cents) fo
    order by position
    offset get_offers.page::bigint * used_size
    limit used_size
  ) s;

  return jsonb_build_object(
    'items', items,
    'total', total_count,
    'page', get_offers.page,
    'pageSize', used_size
  );
end;
$$;

-- Tiendas con ofertas visibles, para el filtro por tienda. Se filtra por id:
-- dos tiendas distintas pueden tener el mismo nombre visible.
create function public.get_catalog_providers(category text default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform private.validate_catalog_filters(null, get_catalog_providers.category);

  return (
    select coalesce(jsonb_agg(jsonb_build_object(
        'id', s.provider_id,
        'displayName', s.provider_name,
        'offerCount', s.offers
      ) order by lower(s.provider_name), s.provider_id), '[]'::jsonb)
    from (
      select co.provider_id, co.provider_name, count(*) as offers
      from private.filtered_offers(get_catalog_providers.category, null) co
      group by co.provider_id, co.provider_name
    ) s
  );
end;
$$;

-- Públicas como el resto del catálogo (se recorre sin cuenta).
revoke all on function public.get_offers(integer, integer, text, text, text, text, bigint, bigint, text) from public;
revoke all on function public.get_catalog_providers(text) from public;
grant execute on function public.get_offers(integer, integer, text, text, text, text, bigint, bigint, text)
  to anon, authenticated;
grant execute on function public.get_catalog_providers(text) to anon, authenticated;
