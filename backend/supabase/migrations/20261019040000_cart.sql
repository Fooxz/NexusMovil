-- Fase 5: carrito (HU-009, RF-053, RF-054, RN-028).
-- docs/API_CONTRATO.md v0.5: `bestOfferId` en Product y parte 2 (carrito).
--
-- Una línea del carrito es una OFERTA (producto + proveedor): cada proveedor
-- fija su precio y despacha por separado (RN-001, S-06).
-- Las cantidades se validan aquí contra el stock: el cliente nunca recibe las
-- unidades, solo el máximo comprable por línea (D7).

-- ---------------------------------------------------------------------------
-- Mejor oferta en el catálogo: su id, para agregarla al carrito desde la
-- tarjeta. Se agrega al final de la vista (CREATE OR REPLACE lo exige).
-- ---------------------------------------------------------------------------

create or replace view private.catalog_products as
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
  p.specs,
  best.id as best_offer_id
from public.products p
join public.categories c on c.code = p.category_code and c.is_active
join lateral (
  select o.id, o.price_cents, o.old_price_cents
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

create or replace function private.product_json(
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
    'bestOfferId', cp.best_offer_id,
    'imageUrl', cp.image_url,
    'summary', cp.summary,
    'quickSpecs', to_jsonb(cp.quick_specs),
    'specs', cp.specs,
    'offers', offer_list
  );
$$;

-- ---------------------------------------------------------------------------
-- Tabla del carrito del usuario con sesión
-- ---------------------------------------------------------------------------

insert into public.app_settings (key, value, description) values
  ('cart_max_quantity_per_item', '10',
   'Máximo de unidades de una misma oferta en el carrito (API_CONTRATO, parte 2).');

create table public.cart_items (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  offer_id text not null references public.offers (id) on delete cascade,
  quantity integer not null check (quantity between 1 and 99),
  added_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, offer_id)
);

create trigger cart_items_set_updated_at
  before update on public.cart_items
  for each row execute function private.set_updated_at();

alter table public.cart_items enable row level security;

create policy "Cada usuario ve su carrito"
  on public.cart_items for select
  to authenticated
  using (user_id = (select auth.uid()));

-- Los cambios pasan por las RPC, que validan el stock.
revoke insert, update, delete on public.cart_items from anon, authenticated;

-- ---------------------------------------------------------------------------
-- Funciones auxiliares
-- ---------------------------------------------------------------------------

create function private.cart_max_quantity_per_item() returns integer
language sql
stable
set search_path = ''
as $$
  select coalesce(
    (select (s.value #>> '{}')::integer
     from public.app_settings s
     where s.key = 'cart_max_quantity_per_item'),
    10
  );
$$;

-- Cuántas unidades de la oferta se pueden comprar: 0 si no está publicada,
-- su proveedor no está activo o no tiene stock (RN-022, RN-028).
create function private.offer_max_quantity(p_offer_id text) returns integer
language sql
stable
set search_path = ''
as $$
  select coalesce(
    (select least(o.stock_units, private.cart_max_quantity_per_item())
     from private.visible_offers o
     where o.id = p_offer_id),
    0
  );
$$;

create function private.require_user() returns uuid
language plpgsql
stable
set search_path = ''
as $$
begin
  if auth.uid() is null then
    perform private.raise_api_error(401, 'AUTH_REQUIRED', 'Inicia sesión para usar tu carrito');
  end if;
  return auth.uid();
end;
$$;

-- Valida que la oferta exista y admita la cantidad pedida.
create function private.check_cart_quantity(p_offer_id text, p_quantity integer)
returns void
language plpgsql
stable
set search_path = ''
as $$
declare
  max_quantity integer;
begin
  if p_quantity is null or p_quantity < 1 then
    perform private.raise_api_error(400, 'VALIDATION_ERROR', 'quantity debe ser al menos 1');
  end if;
  if not exists (select 1 from public.offers o where o.id = p_offer_id) then
    perform private.raise_api_error(404, 'OFFER_NOT_FOUND',
      format('No existe la oferta %s', p_offer_id));
  end if;

  max_quantity := private.offer_max_quantity(p_offer_id);
  if max_quantity = 0 then
    perform private.raise_api_error(409, 'OUT_OF_STOCK', 'La oferta no está disponible');
  end if;
  if p_quantity > max_quantity then
    -- PostgREST exige que "details" sea texto: va el JSON serializado.
    raise sqlstate 'PGRST' using
      message = json_build_object(
        'code', 'QUANTITY_UNAVAILABLE',
        'message', format('Solo puedes llevar %s unidades', max_quantity),
        'details', json_build_object('maxQuantity', max_quantity)::text,
        'hint', null
      )::text,
      detail = json_build_object('status', 409, 'headers', json_build_object())::text;
  end if;
end;
$$;

-- Vista de líneas a partir de [{"offerId": ..., "quantity": ...}], en el
-- mismo orden. Las ofertas que ya no existen se omiten; las que no se pueden
-- comprar se devuelven con available = false.
create function private.cart_lines(entries jsonb) returns jsonb
language sql
stable
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
      'offerId', o.id,
      'quantity', e.quantity,
      'maxQuantity', private.offer_max_quantity(o.id),
      'available', private.offer_max_quantity(o.id) > 0,
      'priceCents', o.price_cents,
      'oldPriceCents', o.old_price_cents,
      'stockLevel', case
        when private.offer_max_quantity(o.id) = 0 then 'outOfStock'
        else private.stock_level(o.stock_units)
      end,
      'providerId', pr.id,
      'providerName', pr.display_name,
      'productId', p.id,
      'productName', p.name,
      'brand', p.brand,
      'category', p.category_code,
      'imageUrl', (
        select coalesce(i.thumb_url, i.url)
        from public.product_images i
        where i.product_id = p.id
        order by i.sort_order, i.id
        limit 1
      )
    ) order by e.ord), '[]'::jsonb)
  from (
    select
      item ->> 'offerId' as offer_id,
      greatest(coalesce((item ->> 'quantity')::integer, 1), 1) as quantity,
      ord
    from jsonb_array_elements(coalesce(entries, '[]'::jsonb)) with ordinality as t(item, ord)
  ) e
  join public.offers o on o.id = e.offer_id
  join public.providers pr on pr.id = o.provider_id
  join public.products p on p.id = o.product_id;
$$;

create function private.saved_cart(p_user_id uuid) returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object('items', private.cart_lines(coalesce(
    (select jsonb_agg(
        jsonb_build_object('offerId', c.offer_id, 'quantity', c.quantity)
        order by c.added_at, c.offer_id)
     from public.cart_items c
     where c.user_id = p_user_id),
    '[]'::jsonb)));
$$;

-- ---------------------------------------------------------------------------
-- RPC públicas
-- ---------------------------------------------------------------------------

-- Carrito sin sesión: el cliente guarda las líneas y pide su vista vigente.
create function public.preview_cart(items jsonb) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if items is null or jsonb_typeof(items) <> 'array' then
    perform private.raise_api_error(400, 'VALIDATION_ERROR', 'items debe ser una lista');
  end if;
  if jsonb_array_length(items) > 50 then
    perform private.raise_api_error(400, 'VALIDATION_ERROR', 'Máximo 50 líneas');
  end if;
  return jsonb_build_object('items', private.cart_lines(items));
end;
$$;

create function public.get_cart() returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  return private.saved_cart(private.require_user());
end;
$$;

-- Suma unidades a una línea (la crea si no existe).
create function public.add_cart_item(offer_id text, quantity integer default 1)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := private.require_user();
  current_quantity integer;
begin
  select c.quantity into current_quantity
  from public.cart_items c
  where c.user_id = current_user_id and c.offer_id = add_cart_item.offer_id;

  perform private.check_cart_quantity(
    add_cart_item.offer_id, coalesce(current_quantity, 0) + add_cart_item.quantity);

  insert into public.cart_items (user_id, offer_id, quantity)
  values (current_user_id, add_cart_item.offer_id, add_cart_item.quantity)
  on conflict on constraint cart_items_pkey
  do update set quantity = public.cart_items.quantity + excluded.quantity;

  return private.saved_cart(current_user_id);
end;
$$;

-- Fija la cantidad de una línea.
create function public.set_cart_item(offer_id text, quantity integer)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := private.require_user();
begin
  perform private.check_cart_quantity(set_cart_item.offer_id, set_cart_item.quantity);

  insert into public.cart_items (user_id, offer_id, quantity)
  values (current_user_id, set_cart_item.offer_id, set_cart_item.quantity)
  on conflict on constraint cart_items_pkey
  do update set quantity = excluded.quantity;

  return private.saved_cart(current_user_id);
end;
$$;

create function public.remove_cart_item(offer_id text) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := private.require_user();
begin
  delete from public.cart_items c
  where c.user_id = current_user_id and c.offer_id = remove_cart_item.offer_id;
  return private.saved_cart(current_user_id);
end;
$$;

create function public.clear_cart() returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := private.require_user();
begin
  delete from public.cart_items c where c.user_id = current_user_id;
  return private.saved_cart(current_user_id);
end;
$$;

-- Al iniciar sesión: suma el carrito de invitado al guardado. Cada línea queda
-- limitada al máximo disponible; las ofertas no disponibles se descartan.
create function public.merge_cart(items jsonb) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := private.require_user();
  entry record;
  max_quantity integer;
begin
  if items is null or jsonb_typeof(items) <> 'array' then
    perform private.raise_api_error(400, 'VALIDATION_ERROR', 'items debe ser una lista');
  end if;

  for entry in
    select t.item ->> 'offerId' as offer_id,
           greatest(coalesce((t.item ->> 'quantity')::integer, 1), 1) as quantity
    from jsonb_array_elements(items) as t(item)
  loop
    max_quantity := private.offer_max_quantity(entry.offer_id);
    continue when max_quantity = 0;

    insert into public.cart_items (user_id, offer_id, quantity)
    values (current_user_id, entry.offer_id, least(entry.quantity, max_quantity))
    on conflict on constraint cart_items_pkey
    do update set quantity = least(public.cart_items.quantity + excluded.quantity, max_quantity);
  end loop;

  return private.saved_cart(current_user_id);
end;
$$;

revoke all on function public.preview_cart(jsonb) from public;
revoke all on function public.get_cart() from public;
revoke all on function public.add_cart_item(text, integer) from public;
revoke all on function public.set_cart_item(text, integer) from public;
revoke all on function public.remove_cart_item(text) from public;
revoke all on function public.clear_cart() from public;
revoke all on function public.merge_cart(jsonb) from public;

grant execute on function public.preview_cart(jsonb) to anon, authenticated;
grant execute on function public.get_cart() to authenticated;
grant execute on function public.add_cart_item(text, integer) to authenticated;
grant execute on function public.set_cart_item(text, integer) to authenticated;
grant execute on function public.remove_cart_item(text) to authenticated;
grant execute on function public.clear_cart() to authenticated;
grant execute on function public.merge_cart(jsonb) to authenticated;
