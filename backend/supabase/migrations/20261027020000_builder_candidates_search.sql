-- Candidatos del PC Builder con búsqueda, precio máximo, orden y páginas
-- (API_CONTRATO v0.12, sección 11.3).
--
-- Con un catálogo grande (cientos de piezas por tipo), las 30 primeras por
-- precio no alcanzan: el cliente no podía llegar a una gráfica de gama alta y
-- el asistente solo veía las más baratas. Ahora se filtra antes de evaluar las
-- reglas, y se pide la página siguiente si hace falta.

drop function public.get_builder_candidates(text, text[], integer);

create function public.get_builder_candidates(
  category text,
  offer_ids text[] default '{}',
  max_items integer default 30,
  search text default null,
  max_price_cents bigint default null,
  sort text default 'priceAsc',
  page integer default 0
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  others text[];
  used_limit integer := least(greatest(coalesce(get_builder_candidates.max_items, 30), 1), 50);
  used_sort text := coalesce(get_builder_candidates.sort, 'priceAsc');
  pattern text := private.search_pattern(get_builder_candidates.search);
begin
  if not exists (
    select 1 from public.builder_slots s where s.category_code = get_builder_candidates.category
  ) then
    perform private.raise_api_error(400, 'VALIDATION_ERROR',
      format('category no es una ranura del armador: %s', get_builder_candidates.category));
  end if;
  if used_sort not in ('priceAsc', 'priceDesc') then
    perform private.raise_api_error(400, 'VALIDATION_ERROR', format('sort desconocido: %s', used_sort));
  end if;
  if coalesce(get_builder_candidates.page, 0) < 0 then
    perform private.raise_api_error(400, 'VALIDATION_ERROR', 'page no puede ser negativo');
  end if;
  if get_builder_candidates.max_price_cents < 0 then
    perform private.raise_api_error(400, 'VALIDATION_ERROR', 'max_price_cents no puede ser negativo');
  end if;

  -- La selección actual sin la pieza de esta categoría (se va a reemplazar).
  select coalesce(array_agg(o.id), '{}') into others
  from public.offers o
  join public.products p on p.id = o.product_id
  where o.id = any (coalesce(get_builder_candidates.offer_ids, '{}'))
    and p.category_code <> get_builder_candidates.category;

  return (
    select coalesce(jsonb_agg(c.item order by c.compatible desc, c.in_stock desc, c.sort_price, c.id), '[]'::jsonb)
    from (
      select
        cp.id,
        case when used_sort = 'priceDesc' then -cp.price_cents else cp.price_cents end as sort_price,
        cp.stock_level <> 'outOfStock' as in_stock,
        e.reason is null as compatible,
        private.product_json(cp) || jsonb_build_object(
          'compatible', e.reason is null,
          'incompatibilityReason', e.reason
        ) as item
      from private.filtered_catalog(
        null, get_builder_candidates.category, pattern, null, null, get_builder_candidates.max_price_cents
      ) cp
      cross join lateral (
        select (
          select i ->> 'message'
          from jsonb_array_elements(private.evaluate_rules(private.builder_parts(others || cp.best_offer_id))) i
          where i ->> 'severity' = 'error' and i -> 'offerIds' ? cp.best_offer_id
          limit 1
        ) as reason
      ) e
      order by 4 desc, 3 desc, 2, 1
      limit used_limit
      offset used_limit * coalesce(get_builder_candidates.page, 0)
    ) c
  );
end;
$$;

revoke all on function public.get_builder_candidates(text, text[], integer, text, bigint, text, integer) from public;
grant execute on function public.get_builder_candidates(text, text[], integer, text, bigint, text, integer)
  to anon, authenticated;
