-- Fase 3: filtros por marca y precio, orden (RF-033, D5) y lista de marcas.
-- docs/API_CONTRATO.md v0.4, secciones 3.1 y 3.5.

drop function public.get_products(integer, integer, text, text, text);
drop function private.filtered_catalog(text, text, text);

-- Validación común de family y category (VALIDATION_ERROR del contrato).
create function private.validate_catalog_filters(p_family text, p_category text)
returns void
language plpgsql
stable
set search_path = ''
as $$
begin
  if p_family is not null and p_family not in ('prebuiltPc', 'part') then
    perform private.raise_api_error(400, 'VALIDATION_ERROR',
      format('family desconocida: %s', p_family));
  end if;
  if p_category is not null and not exists (
    select 1 from public.categories c
    where c.code = p_category and c.is_active
  ) then
    perform private.raise_api_error(400, 'VALIDATION_ERROR',
      format('category desconocida: %s', p_category));
  end if;
end;
$$;

create function private.filtered_catalog(
  p_family text,
  p_category text,
  p_pattern text,
  p_brand text default null,
  p_min_price_cents bigint default null,
  p_max_price_cents bigint default null
) returns setof private.catalog_products
language sql
stable
set search_path = ''
as $$
  select cp.*
  from private.catalog_products cp
  where (p_family is null or cp.family::text = p_family)
    and (p_category is null or cp.category = p_category)
    and (p_brand is null or lower(cp.brand) = lower(trim(p_brand)))
    and (p_min_price_cents is null or cp.price_cents >= p_min_price_cents)
    and (p_max_price_cents is null or cp.price_cents <= p_max_price_cents)
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

create function public.get_products(
  page integer default 0,
  page_size integer default 20,
  search text default null,
  family text default null,
  category text default null,
  brand text default null,
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
  used_sort text := coalesce(get_products.sort, 'relevance');
  used_brand text := nullif(trim(get_products.brand), '');
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
  perform private.validate_catalog_filters(get_products.family, get_products.category);
  if used_sort not in ('relevance', 'priceAsc', 'priceDesc') then
    perform private.raise_api_error(400, 'VALIDATION_ERROR',
      format('sort desconocido: %s', used_sort));
  end if;
  if get_products.min_price_cents < 0 or get_products.max_price_cents < 0 then
    perform private.raise_api_error(400, 'VALIDATION_ERROR', 'los precios no pueden ser negativos');
  end if;
  if get_products.min_price_cents > get_products.max_price_cents then
    perform private.raise_api_error(400, 'VALIDATION_ERROR',
      'min_price_cents no puede ser mayor que max_price_cents');
  end if;

  used_size := least(get_products.page_size, 50);
  pattern := private.search_pattern(get_products.search);

  select count(*) into total_count
  from private.filtered_catalog(
    get_products.family, get_products.category, pattern,
    used_brand, get_products.min_price_cents, get_products.max_price_cents);

  -- "relevance" ordena por nombre mientras no exista un puntaje de búsqueda.
  -- El id desempata para que el orden sea estable entre páginas.
  select coalesce(jsonb_agg(private.product_json(s.fc) order by s.position), '[]'::jsonb)
  into items
  from (
    select
      fc,
      row_number() over (
        order by
          case when used_sort = 'priceAsc' then fc.price_cents end asc,
          case when used_sort = 'priceDesc' then fc.price_cents end desc,
          fc.name,
          fc.id
      ) as position
    from private.filtered_catalog(
      get_products.family, get_products.category, pattern,
      used_brand, get_products.min_price_cents, get_products.max_price_cents) fc
    order by position
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

-- Marcas con productos visibles, para el filtro de marca.
create function public.get_catalog_brands(
  family text default null,
  category text default null
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform private.validate_catalog_filters(get_catalog_brands.family, get_catalog_brands.category);

  return (
    select coalesce(jsonb_agg(b.brand order by lower(b.brand), b.brand), '[]'::jsonb)
    from (
      select distinct fc.brand
      from private.filtered_catalog(get_catalog_brands.family, get_catalog_brands.category, null) fc
    ) b
  );
end;
$$;

revoke all on function public.get_products(integer, integer, text, text, text, text, bigint, bigint, text) from public;
revoke all on function public.get_catalog_brands(text, text) from public;
grant execute on function public.get_products(integer, integer, text, text, text, text, bigint, bigint, text) to anon, authenticated;
grant execute on function public.get_catalog_brands(text, text) to anon, authenticated;
