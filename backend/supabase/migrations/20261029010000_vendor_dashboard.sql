-- Panel de la tienda, fase 1 (API_CONTRATO, parte 9): resumen del negocio,
-- inventario con movimientos y pedidos con su flujo de estados (HU-018,
-- HU-020, HU-021, RF-063, RF-066, RF-069, RN-029).
--
-- - Inventario: cada cambio de stock queda en `inventory_movements` (entrada,
--   salida, ajuste, venta o devolución al stock por un pedido cancelado), con
--   fecha, usuario, motivo y cantidad. Lo registra un trigger sobre offers, así
--   que ningún camino (RPC de la tienda, checkout, SQL del administrador) se
--   lo salta. Cada oferta tiene un stock mínimo para las alertas.
-- - Pedidos: la tienda opera su sub-orden: Nuevo -> Confirmado -> Preparando
--   -> Enviado -> Entregado, con Rechazado, Cancelado, Devuelto y Con
--   incidencia. Cada cambio queda en `sub_order_status_history` (RN-029).
--   Rechazar o cancelar devuelve las unidades al stock.
-- - Resumen: ventas, pedidos, inventario y dinero de la tienda en una RPC.
--
-- Todas las RPC exigen private.require_active_provider() y filtran por la
-- tienda de la cuenta: ninguna recibe el id de la tienda.

-- ---------------------------------------------------------------------------
-- Inventario
-- ---------------------------------------------------------------------------

alter table public.offers
  add column min_stock integer not null default 5 check (min_stock between 0 and 100000);

create table public.inventory_movements (
  id bigint generated always as identity primary key,
  offer_id text not null references public.offers (id),
  provider_id text not null references public.providers (id),
  -- entry: entrada; exit: salida; adjustment: ajuste (conteo, corrección o
  -- edición de la publicación); sale: venta; cancellation: devolución al
  -- stock por un pedido rechazado o cancelado.
  kind text not null check (kind in ('entry', 'exit', 'adjustment', 'sale', 'cancellation')),
  quantity_delta integer not null,
  stock_before integer not null,
  stock_after integer not null,
  reason text check (reason is null or length(reason) <= 200),
  sub_order_id uuid references public.sub_orders (id),
  actor_id uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  check (stock_after = stock_before + quantity_delta)
);

create index inventory_movements_offer_idx on public.inventory_movements (offer_id, created_at desc);
create index inventory_movements_provider_idx on public.inventory_movements (provider_id, created_at desc);

-- Historiales de solo inserción. La única excepción es la que hace la base al
-- borrar una cuenta: el `actor_id` queda nulo (on delete set null) y el resto
-- del registro no cambia.
create function private.prevent_change_except_actor_removal() returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' and new.actor_id is null
     and to_jsonb(new) - 'actor_id' = to_jsonb(old) - 'actor_id' then
    return new;
  end if;
  raise exception '% no admite cambios: es un registro de la operación', tg_table_name
    using errcode = '42501';
end;
$$;

create trigger inventory_movements_immutable
  before update or delete on public.inventory_movements
  for each row execute function private.prevent_change_except_actor_removal();

alter table public.inventory_movements enable row level security;
revoke all on public.inventory_movements from anon, authenticated;

-- Motivo del próximo cambio de stock en esta transacción. Lo ponen las RPC y
-- el checkout antes de tocar offers.stock_units; el trigger lo lee. Sin
-- motivo, el cambio es un ajuste.
create function private.set_stock_movement(p_kind text, p_reason text, p_sub_order_id uuid)
returns void
language sql
set search_path = ''
as $$
  select set_config('nexus.stock_movement',
    json_build_object('kind', p_kind, 'reason', p_reason, 'subOrderId', p_sub_order_id)::text, true);
$$;

create function private.clear_stock_movement() returns void
language sql
set search_path = ''
as $$
  select set_config('nexus.stock_movement', '', true);
$$;

create function private.record_stock_movement() returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  context jsonb := nullif(current_setting('nexus.stock_movement', true), '')::jsonb;
  before_units integer := case when tg_op = 'INSERT' then 0 else old.stock_units end;
begin
  if new.stock_units is not distinct from before_units then
    return null;
  end if;
  insert into public.inventory_movements
    (offer_id, provider_id, kind, quantity_delta, stock_before, stock_after, reason, sub_order_id, actor_id)
  values (
    new.id,
    new.provider_id,
    coalesce(context ->> 'kind', case when tg_op = 'INSERT' then 'entry' else 'adjustment' end),
    new.stock_units - before_units,
    before_units,
    new.stock_units,
    coalesce(context ->> 'reason', case when tg_op = 'INSERT' then 'Stock inicial' end),
    (context ->> 'subOrderId')::uuid,
    auth.uid()
  );
  return null;
end;
$$;

create trigger offers_stock_movement
  after insert or update of stock_units on public.offers
  for each row execute function private.record_stock_movement();

-- Punto de partida del historial para las ofertas que ya existían.
insert into public.inventory_movements
  (offer_id, provider_id, kind, quantity_delta, stock_before, stock_after, reason)
select o.id, o.provider_id, 'entry', o.stock_units, 0, o.stock_units, 'Inventario inicial'
from public.offers o
where o.stock_units > 0;

-- El checkout descuenta el stock al aprobarse el pago: igual que antes, ahora
-- con el motivo "venta" y la sub-orden en el historial de inventario.
create or replace function private.create_order(p_payment_id uuid) returns uuid
language plpgsql
set search_path = ''
as $$
declare
  pay public.payments;
  new_order_id uuid;
  current_sub_order_id uuid;
  vat numeric := private.numeric_setting('vat_rate', 0.19);
  provider record;
  item record;
  commission record;
  stock_before integer;
  line_total bigint;
  tax_base bigint;
  commission_amount bigint;
  order_number text;
begin
  select * into pay from public.payments where id = p_payment_id;

  insert into public.orders (user_id, payment_id, total_cents, shipping_address, contact)
  values (pay.user_id, pay.id, pay.amount_cents, pay.shipping_address, pay.contact)
  returning id, number into new_order_id, order_number;

  for provider in
    select e ->> 'providerId' as id, min(e ->> 'providerName') as name, min(t.ord) as first
    from jsonb_array_elements(pay.items) with ordinality as t(e, ord)
    group by e ->> 'providerId'
    order by first
  loop
    insert into public.sub_orders (order_id, provider_id, provider_name)
    values (new_order_id, provider.id, provider.name)
    returning id into current_sub_order_id;

    -- Lo aprueba la pasarela, no una persona: sin autor.
    insert into public.sub_order_status_history (sub_order_id, from_status, to_status, note, actor_id)
    values (current_sub_order_id, null, 'pending', 'Pago aprobado', null);

    for item in
      select e ->> 'offerId' as offer_id,
             e ->> 'productId' as product_id,
             e ->> 'productName' as product_name,
             e ->> 'brand' as brand,
             (e ->> 'quantity')::integer as quantity,
             (e ->> 'unitPriceCents')::bigint as unit_price_cents
      from jsonb_array_elements(pay.items) with ordinality as t(e, ord)
      where e ->> 'providerId' = provider.id
      order by t.ord
    loop
      -- Descuenta lo vendido hasta la siguiente sincronización del proveedor
      -- (RF-066). Si otra compra se llevó las unidades mientras este cliente
      -- pagaba, la diferencia queda registrada en backordered_units.
      select o.stock_units into stock_before
      from public.offers o
      where o.id = item.offer_id
      for update;

      perform private.set_stock_movement('sale', format('Pedido %s', order_number), current_sub_order_id);
      update public.offers
      set stock_units = greatest(stock_units - item.quantity, 0)
      where id = item.offer_id;

      line_total := item.unit_price_cents * item.quantity;
      tax_base := round(line_total / (1 + vat), -2)::bigint;
      select * into commission from private.commission_for(provider.id, item.product_id, now());
      commission_amount := round(tax_base * commission.rate, -2)::bigint;

      insert into public.order_items (
        sub_order_id, offer_id, product_id, product_name, brand, quantity,
        unit_price_cents, line_total_cents, vat_rate, tax_base_cents,
        commission_rate, commission_rule_id, commission_cents, provider_net_cents,
        backordered_units
      ) values (
        current_sub_order_id, item.offer_id, item.product_id, item.product_name,
        item.brand, item.quantity, item.unit_price_cents, line_total, vat, tax_base,
        commission.rate, commission.rule_id, commission_amount, line_total - commission_amount,
        greatest(item.quantity - coalesce(stock_before, 0), 0)
      );
    end loop;

    update public.sub_orders s
    set subtotal_cents = t.subtotal,
        tax_base_cents = t.tax_base,
        commission_cents = t.commission,
        provider_net_cents = t.net
    from (
      select sum(i.line_total_cents) as subtotal,
             sum(i.tax_base_cents) as tax_base,
             sum(i.commission_cents) as commission,
             sum(i.provider_net_cents) as net
      from public.order_items i
      where i.sub_order_id = current_sub_order_id
    ) t
    where s.id = current_sub_order_id;
  end loop;
  perform private.clear_stock_movement();

  -- Lo comprado sale del carrito; lo demás se queda.
  delete from public.cart_items c
  where c.user_id = pay.user_id
    and c.offer_id in (select e ->> 'offerId' from jsonb_array_elements(pay.items) e);

  return new_order_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Pedidos: estados de la sub-orden
-- ---------------------------------------------------------------------------

alter table public.sub_orders drop constraint sub_orders_status_check;
alter table public.sub_orders
  add constraint sub_orders_status_check check (status in (
    'pending',    -- Nuevo: pagado, esperando que la tienda lo acepte
    'confirmed',  -- Confirmado: la tienda tiene las unidades
    'preparing',  -- Preparando
    'shipped',    -- Enviado, con transportadora y guía
    'delivered',  -- Entregado
    'rejected',   -- Rechazado por la tienda antes de confirmarlo
    'cancelled',  -- Cancelado después de confirmarlo
    'returned',   -- Devuelto por el cliente después de la entrega
    'incident'    -- Con incidencia: se detuvo por un problema
  )),
  add column carrier text check (carrier is null or length(carrier) between 2 and 60),
  add column tracking_number text check (tracking_number is null or length(tracking_number) between 3 and 60),
  add column status_note text check (status_note is null or length(status_note) <= 300),
  add column status_changed_at timestamptz not null default now(),
  add column shipped_at timestamptz,
  add column delivered_at timestamptz;

create index sub_orders_provider_status_idx on public.sub_orders (provider_id, status, created_at desc);

create table public.sub_order_status_history (
  id bigint generated always as identity primary key,
  sub_order_id uuid not null references public.sub_orders (id),
  from_status text,
  to_status text not null,
  note text,
  actor_id uuid references auth.users (id) on delete set null default auth.uid(),
  created_at timestamptz not null default now()
);

create index sub_order_status_history_idx on public.sub_order_status_history (sub_order_id, created_at);

create trigger sub_order_status_history_immutable
  before update or delete on public.sub_order_status_history
  for each row execute function private.prevent_change_except_actor_removal();

alter table public.sub_order_status_history enable row level security;
revoke all on public.sub_order_status_history from anon, authenticated;

-- Historial de las sub-órdenes que ya existían.
insert into public.sub_order_status_history (sub_order_id, from_status, to_status, note, created_at)
select s.id, null, s.status, 'Pago aprobado', s.created_at
from public.sub_orders s;

-- Transiciones válidas (RN-029). Con incidencia se retoma donde haga falta o
-- se cancela. Rechazado, cancelado y devuelto son finales.
create function private.sub_order_next_statuses(p_status text) returns text[]
language sql
immutable
set search_path = ''
as $$
  select case p_status
    when 'pending' then array['confirmed', 'rejected']
    when 'confirmed' then array['preparing', 'cancelled', 'incident']
    when 'preparing' then array['shipped', 'cancelled', 'incident']
    when 'shipped' then array['delivered', 'incident']
    when 'delivered' then array['returned', 'incident']
    when 'incident' then array['confirmed', 'preparing', 'shipped', 'delivered', 'cancelled']
    else array[]::text[]
  end;
$$;

-- Unidades vendidas que todavía no salieron de la tienda (pedido pagado, sin
-- enviar): ya se descontaron del stock y están comprometidas.
create function private.reserved_units(p_offer_id text) returns integer
language sql
stable
set search_path = ''
as $$
  select coalesce(sum(i.quantity - i.backordered_units), 0)::integer
  from public.order_items i
  join public.sub_orders s on s.id = i.sub_order_id
  where i.offer_id = p_offer_id
    and s.status in ('pending', 'confirmed', 'preparing', 'incident');
$$;

create function private.sold_units(p_offer_id text) returns integer
language sql
stable
set search_path = ''
as $$
  select coalesce(sum(i.quantity), 0)::integer
  from public.order_items i
  join public.sub_orders s on s.id = i.sub_order_id
  where i.offer_id = p_offer_id
    and s.status not in ('rejected', 'cancelled');
$$;

create function private.vendor_order_json(s public.sub_orders) returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'id', s.id,
    'orderNumber', o.number,
    'createdAt', s.created_at,
    'status', s.status,
    'statusChangedAt', s.status_changed_at,
    'units', (select coalesce(sum(i.quantity), 0) from public.order_items i where i.sub_order_id = s.id),
    'subtotalCents', s.subtotal_cents,
    'commissionCents', s.commission_cents,
    'netCents', s.provider_net_cents,
    'customerName', o.contact ->> 'fullName',
    'city', o.shipping_address ->> 'city',
    'department', o.shipping_address ->> 'department',
    'carrier', s.carrier,
    'trackingNumber', s.tracking_number,
    'hasBackorders', exists (
      select 1 from public.order_items i where i.sub_order_id = s.id and i.backordered_units > 0
    )
  )
  from public.orders o
  where o.id = s.order_id;
$$;

-- Detalle del pedido para la tienda: lo que necesita para despachar y
-- facturar (dirección, contacto y documento del cliente), sus ítems con la
-- comisión y el historial de estados.
create function private.vendor_order_detail(p_sub_order_id uuid) returns jsonb
language sql
stable
set search_path = ''
as $$
  select private.vendor_order_json(s) || jsonb_build_object(
    'statusNote', s.status_note,
    'shippedAt', s.shipped_at,
    'deliveredAt', s.delivered_at,
    'shippingAddress', o.shipping_address,
    'contact', o.contact,
    'nextStatuses', to_jsonb(private.sub_order_next_statuses(s.status)),
    'items', coalesce((
      select jsonb_agg(jsonb_build_object(
          'offerId', i.offer_id,
          'productId', i.product_id,
          'productName', i.product_name,
          'brand', i.brand,
          'quantity', i.quantity,
          'unitPriceCents', i.unit_price_cents,
          'lineTotalCents', i.line_total_cents,
          'commissionCents', i.commission_cents,
          'netCents', i.provider_net_cents,
          'backorderedUnits', i.backordered_units
        ) order by i.product_name, i.id)
      from public.order_items i where i.sub_order_id = s.id), '[]'::jsonb),
    'history', coalesce((
      select jsonb_agg(jsonb_build_object(
          'fromStatus', h.from_status,
          'toStatus', h.to_status,
          'note', h.note,
          'actorName', (select p.full_name from public.profiles p where p.id = h.actor_id),
          'createdAt', h.created_at
        ) order by h.created_at, h.id)
      from public.sub_order_status_history h where h.sub_order_id = s.id), '[]'::jsonb)
  )
  from public.sub_orders s
  join public.orders o on o.id = s.order_id
  where s.id = p_sub_order_id;
$$;

create function public.get_my_orders(
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
  pattern text := private.search_pattern(get_my_orders.search);
  used_size integer := least(greatest(coalesce(get_my_orders.page_size, 20), 1), 50);
  total_count bigint;
  items jsonb;
begin
  if get_my_orders.status is not null and get_my_orders.status not in
     ('pending', 'confirmed', 'preparing', 'shipped', 'delivered', 'rejected', 'cancelled', 'returned', 'incident') then
    perform private.raise_api_error(400, 'VALIDATION_ERROR', 'status desconocido');
  end if;
  if coalesce(get_my_orders.page, 0) < 0 then
    perform private.raise_api_error(400, 'VALIDATION_ERROR', 'page no puede ser negativo');
  end if;

  select count(*) into total_count
  from public.sub_orders s join public.orders o on o.id = s.order_id
  where s.provider_id = store_id
    and (get_my_orders.status is null or s.status = get_my_orders.status)
    and (pattern is null or private.normalize_search(o.number) like pattern
         or private.normalize_search(o.contact ->> 'fullName') like pattern);

  select coalesce(jsonb_agg(private.vendor_order_json(x.s) order by x.ord), '[]'::jsonb) into items
  from (
    select s, row_number() over (order by s.created_at desc, s.id) as ord
    from public.sub_orders s join public.orders o on o.id = s.order_id
    where s.provider_id = store_id
      and (get_my_orders.status is null or s.status = get_my_orders.status)
      and (pattern is null or private.normalize_search(o.number) like pattern
           or private.normalize_search(o.contact ->> 'fullName') like pattern)
    order by s.created_at desc, s.id
    offset coalesce(get_my_orders.page, 0)::bigint * used_size
    limit used_size
  ) x;

  return jsonb_build_object('items', items, 'total', total_count,
    'page', coalesce(get_my_orders.page, 0), 'pageSize', used_size);
end;
$$;

create function public.get_my_order(id uuid) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  store_id text := private.require_active_provider();
begin
  if not exists (
    select 1 from public.sub_orders s where s.id = get_my_order.id and s.provider_id = store_id
  ) then
    perform private.raise_api_error(404, 'ORDER_NOT_FOUND', 'No tienes ese pedido');
  end if;
  return private.vendor_order_detail(get_my_order.id);
end;
$$;

-- Cambia el estado del pedido de la tienda (RF-063). Rechazar, cancelar,
-- devolver y reportar una incidencia exigen el motivo; enviar exige la
-- transportadora y la guía (RF-069). Rechazar o cancelar devuelve al stock
-- las unidades que se habían descontado.
create function public.update_my_order_status(
  id uuid,
  status text,
  note text default null,
  carrier text default null,
  tracking_number text default null
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  store_id text := private.require_active_provider();
  current_order public.sub_orders;
  used_note text := nullif(trim(coalesce(update_my_order_status.note, '')), '');
  used_carrier text := nullif(trim(coalesce(update_my_order_status.carrier, '')), '');
  used_tracking text := nullif(trim(coalesce(update_my_order_status.tracking_number, '')), '');
  order_number text;
  item record;
begin
  select * into current_order from public.sub_orders s
  where s.id = update_my_order_status.id and s.provider_id = store_id
  for update;
  if current_order.id is null then
    perform private.raise_api_error(404, 'ORDER_NOT_FOUND', 'No tienes ese pedido');
  end if;

  if update_my_order_status.status is null
     or not (update_my_order_status.status = any (private.sub_order_next_statuses(current_order.status))) then
    perform private.raise_api_error_details(409, 'INVALID_TRANSITION',
      'El pedido no puede pasar a ese estado desde el actual',
      jsonb_build_object('from', current_order.status, 'to', update_my_order_status.status,
        'allowed', to_jsonb(private.sub_order_next_statuses(current_order.status))));
  end if;

  if update_my_order_status.status in ('rejected', 'cancelled', 'returned', 'incident')
     and (used_note is null or length(used_note) not between 3 and 300) then
    perform private.validation_error('note', 'Escribe el motivo (de 3 a 300 caracteres)');
  end if;
  if used_note is not null and length(used_note) > 300 then
    perform private.validation_error('note', 'La nota admite hasta 300 caracteres');
  end if;
  if update_my_order_status.status = 'shipped' then
    if used_carrier is null or length(used_carrier) not between 2 and 60 then
      perform private.validation_error('carrier', 'Escribe la transportadora');
    end if;
    if used_tracking is null or length(used_tracking) not between 3 and 60 then
      perform private.validation_error('trackingNumber', 'Escribe el número de guía');
    end if;
  end if;

  update public.sub_orders s
  set status = update_my_order_status.status,
      status_note = used_note,
      status_changed_at = now(),
      carrier = case when update_my_order_status.status = 'shipped' then used_carrier else s.carrier end,
      tracking_number = case when update_my_order_status.status = 'shipped' then used_tracking else s.tracking_number end,
      shipped_at = case when update_my_order_status.status = 'shipped' then now() else s.shipped_at end,
      delivered_at = case when update_my_order_status.status = 'delivered' then now() else s.delivered_at end
  where s.id = current_order.id;

  insert into public.sub_order_status_history (sub_order_id, from_status, to_status, note)
  values (current_order.id, current_order.status, update_my_order_status.status, used_note);

  -- Las unidades vuelven al stock: se habían descontado al aprobarse el pago
  -- (menos las que ya faltaban entonces).
  if update_my_order_status.status in ('rejected', 'cancelled') then
    select o.number into order_number from public.orders o where o.id = current_order.order_id;
    for item in
      select i.offer_id, sum(i.quantity - i.backordered_units)::integer as units
      from public.order_items i
      where i.sub_order_id = current_order.id
      group by i.offer_id
      having sum(i.quantity - i.backordered_units) > 0
    loop
      perform private.set_stock_movement('cancellation',
        format('Pedido %s %s', order_number,
          case update_my_order_status.status when 'rejected' then 'rechazado' else 'cancelado' end),
        current_order.id);
      update public.offers o set stock_units = o.stock_units + item.units where o.id = item.offer_id;
    end loop;
    perform private.clear_stock_movement();
  end if;

  return private.vendor_order_detail(current_order.id);
end;
$$;

-- ---------------------------------------------------------------------------
-- Inventario de la tienda
-- ---------------------------------------------------------------------------

create function private.inventory_item_json(o public.offers) returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'offerId', o.id,
    'productId', p.id,
    'name', p.name,
    'brand', p.brand,
    'category', p.category_code,
    'imageUrl', (
      select coalesce(i.thumb_url, i.url) from public.product_images i
      where i.product_id = p.id order by i.sort_order, i.id limit 1
    ),
    'status', o.status,
    'externalSku', o.external_sku,
    'stockUnits', o.stock_units,
    'minStock', o.min_stock,
    'reservedUnits', private.reserved_units(o.id),
    'soldUnits', private.sold_units(o.id),
    'alert', case
      when o.stock_units = 0 then 'out'
      when o.stock_units <= o.min_stock then 'low'
    end,
    'updatedAt', o.updated_at
  )
  from public.products p
  where p.id = o.product_id;
$$;

-- Existencias de las ofertas de la tienda (sin las retiradas). `alert`:
-- "low" (stock bajo: 1 a min_stock unidades) u "out" (agotadas).
create function public.get_my_inventory(
  alert text default null,
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
  pattern text := private.search_pattern(get_my_inventory.search);
  used_size integer := least(greatest(coalesce(get_my_inventory.page_size, 20), 1), 50);
  total_count bigint;
  items jsonb;
  counts jsonb;
begin
  if get_my_inventory.alert is not null and get_my_inventory.alert not in ('low', 'out') then
    perform private.raise_api_error(400, 'VALIDATION_ERROR', 'alert debe ser "low" u "out"');
  end if;
  if coalesce(get_my_inventory.page, 0) < 0 then
    perform private.raise_api_error(400, 'VALIDATION_ERROR', 'page no puede ser negativo');
  end if;

  select jsonb_build_object(
      'all', count(*),
      'low', count(*) filter (where o.stock_units > 0 and o.stock_units <= o.min_stock),
      'out', count(*) filter (where o.stock_units = 0))
  into counts
  from public.offers o
  where o.provider_id = store_id and o.status <> 'retired';

  select count(*) into total_count
  from public.offers o join public.products p on p.id = o.product_id
  where o.provider_id = store_id and o.status <> 'retired'
    and (get_my_inventory.alert is null
      or (get_my_inventory.alert = 'out' and o.stock_units = 0)
      or (get_my_inventory.alert = 'low' and o.stock_units > 0 and o.stock_units <= o.min_stock))
    and (pattern is null or private.normalize_search(p.name) like pattern
         or private.normalize_search(o.external_sku) like pattern);

  select coalesce(jsonb_agg(private.inventory_item_json(x.o) order by x.ord), '[]'::jsonb) into items
  from (
    select o, row_number() over (order by o.stock_units - o.min_stock, p.name, o.id) as ord
    from public.offers o join public.products p on p.id = o.product_id
    where o.provider_id = store_id and o.status <> 'retired'
      and (get_my_inventory.alert is null
        or (get_my_inventory.alert = 'out' and o.stock_units = 0)
        or (get_my_inventory.alert = 'low' and o.stock_units > 0 and o.stock_units <= o.min_stock))
      and (pattern is null or private.normalize_search(p.name) like pattern
           or private.normalize_search(o.external_sku) like pattern)
    order by o.stock_units - o.min_stock, p.name, o.id
    offset coalesce(get_my_inventory.page, 0)::bigint * used_size
    limit used_size
  ) x;

  return jsonb_build_object('items', items, 'total', total_count, 'counts', counts,
    'page', coalesce(get_my_inventory.page, 0), 'pageSize', used_size);
end;
$$;

-- Movimiento manual: entrada (+), salida (-) o ajuste al conteo real. El
-- motivo es obligatorio: queda en el historial.
create function public.adjust_my_stock(
  product_id text,
  kind text,
  quantity integer,
  reason text
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  store_id text := private.require_active_provider();
  mine public.offers;
  used_reason text := nullif(trim(coalesce(adjust_my_stock.reason, '')), '');
  new_units integer;
begin
  select * into mine from public.offers o
  where o.product_id = adjust_my_stock.product_id and o.provider_id = store_id
  for update;
  if mine.id is null then
    perform private.raise_api_error(404, 'OFFER_NOT_FOUND', 'No tienes una oferta de ese producto');
  end if;
  if adjust_my_stock.kind is null or adjust_my_stock.kind not in ('entry', 'exit', 'adjustment') then
    perform private.validation_error('kind', 'El movimiento debe ser entrada, salida o ajuste');
  end if;
  if used_reason is null or length(used_reason) not between 3 and 200 then
    perform private.validation_error('reason', 'Escribe el motivo (de 3 a 200 caracteres)');
  end if;
  if adjust_my_stock.quantity is null or adjust_my_stock.quantity < 0 or adjust_my_stock.quantity > 100000
     or (adjust_my_stock.kind <> 'adjustment' and adjust_my_stock.quantity = 0) then
    perform private.validation_error('quantity', 'La cantidad debe ser un número entero de 1 a 100000');
  end if;

  new_units := case adjust_my_stock.kind
    when 'entry' then mine.stock_units + adjust_my_stock.quantity
    when 'exit' then mine.stock_units - adjust_my_stock.quantity
    else adjust_my_stock.quantity
  end;
  if new_units < 0 then
    perform private.validation_error('quantity',
      format('Solo hay %s unidades: no puedes sacar %s', mine.stock_units, adjust_my_stock.quantity));
  end if;
  if new_units > 100000 then
    perform private.validation_error('quantity', 'Las existencias no pueden pasar de 100000');
  end if;
  if new_units = mine.stock_units then
    perform private.validation_error('quantity', 'El stock ya es ese: no hay nada que ajustar');
  end if;

  perform private.set_stock_movement(adjust_my_stock.kind, used_reason, null);
  update public.offers o
  set stock_units = new_units, stock_synced_at = now()
  where o.id = mine.id
  returning * into mine;
  perform private.clear_stock_movement();

  return private.inventory_item_json(mine);
end;
$$;

create function public.set_my_min_stock(product_id text, min_stock integer) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  store_id text := private.require_active_provider();
  mine public.offers;
begin
  if set_my_min_stock.min_stock is null or set_my_min_stock.min_stock not between 0 and 100000 then
    perform private.validation_error('minStock', 'El stock mínimo debe ser un número entero de 0 a 100000');
  end if;
  update public.offers o set min_stock = set_my_min_stock.min_stock
  where o.product_id = set_my_min_stock.product_id and o.provider_id = store_id
  returning * into mine;
  if mine.id is null then
    perform private.raise_api_error(404, 'OFFER_NOT_FOUND', 'No tienes una oferta de ese producto');
  end if;
  return private.inventory_item_json(mine);
end;
$$;

-- Historial de movimientos de la tienda, de un producto o de todos.
create function public.get_my_stock_movements(
  product_id text default null,
  page integer default 0,
  page_size integer default 30
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  store_id text := private.require_active_provider();
  used_size integer := least(greatest(coalesce(get_my_stock_movements.page_size, 30), 1), 100);
  total_count bigint;
  items jsonb;
begin
  if coalesce(get_my_stock_movements.page, 0) < 0 then
    perform private.raise_api_error(400, 'VALIDATION_ERROR', 'page no puede ser negativo');
  end if;

  select count(*) into total_count
  from public.inventory_movements m join public.offers o on o.id = m.offer_id
  where m.provider_id = store_id
    and (get_my_stock_movements.product_id is null or o.product_id = get_my_stock_movements.product_id);

  select coalesce(jsonb_agg(x.item order by x.created_at desc, x.id desc), '[]'::jsonb) into items
  from (
    select m.id, m.created_at, jsonb_build_object(
        'id', m.id,
        'productId', o.product_id,
        'productName', p.name,
        'kind', m.kind,
        'quantityDelta', m.quantity_delta,
        'stockBefore', m.stock_before,
        'stockAfter', m.stock_after,
        'reason', m.reason,
        'orderNumber', (select ord.number from public.sub_orders s join public.orders ord on ord.id = s.order_id
                        where s.id = m.sub_order_id),
        'actorName', (select pr.full_name from public.profiles pr where pr.id = m.actor_id),
        'createdAt', m.created_at
      ) as item
    from public.inventory_movements m
    join public.offers o on o.id = m.offer_id
    join public.products p on p.id = o.product_id
    where m.provider_id = store_id
      and (get_my_stock_movements.product_id is null or o.product_id = get_my_stock_movements.product_id)
    order by m.created_at desc, m.id desc
    offset coalesce(get_my_stock_movements.page, 0)::bigint * used_size
    limit used_size
  ) x;

  return jsonb_build_object('items', items, 'total', total_count,
    'page', coalesce(get_my_stock_movements.page, 0), 'pageSize', used_size);
end;
$$;

-- La edición de una publicación también cambia el stock: queda como ajuste
-- con ese motivo.
create or replace function public.update_my_offer(product_id text, offer jsonb) returns jsonb
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

  perform private.set_stock_movement('adjustment', 'Edición de la publicación', null);
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
  perform private.clear_stock_movement();
  return private.my_offer_detail(mine.product_id, store_id);
end;
$$;

-- ---------------------------------------------------------------------------
-- Resumen del negocio
-- ---------------------------------------------------------------------------

-- Ventas, pedidos, inventario y dinero de la tienda. Los periodos son los de
-- Colombia (America/Bogota). El crecimiento compara con el periodo anterior
-- hasta el mismo momento: hoy contra ayer a esta hora, la semana en curso
-- contra la anterior al mismo día y hora, y el mes contra el anterior.
-- Las ventas cuentan los pedidos pagados que no se rechazaron ni cancelaron.
create function public.get_my_dashboard() returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  store_id text := private.require_active_provider();
  local_now timestamp := now() at time zone 'America/Bogota';
  day_start timestamptz := date_trunc('day', local_now) at time zone 'America/Bogota';
  week_start timestamptz := date_trunc('week', local_now) at time zone 'America/Bogota';
  month_start timestamptz := date_trunc('month', local_now) at time zone 'America/Bogota';
begin
  return jsonb_build_object(
    'sales', (
      select jsonb_build_object(
        'todayCents', coalesce(sum(s.subtotal_cents) filter (where s.created_at >= day_start), 0),
        'yesterdayCents', coalesce(sum(s.subtotal_cents) filter (
          where s.created_at >= day_start - interval '1 day' and s.created_at < now() - interval '1 day'), 0),
        'weekCents', coalesce(sum(s.subtotal_cents) filter (where s.created_at >= week_start), 0),
        'previousWeekCents', coalesce(sum(s.subtotal_cents) filter (
          where s.created_at >= week_start - interval '7 days' and s.created_at < now() - interval '7 days'), 0),
        'monthCents', coalesce(sum(s.subtotal_cents) filter (where s.created_at >= month_start), 0),
        'previousMonthCents', coalesce(sum(s.subtotal_cents) filter (
          where s.created_at >= month_start - interval '1 month' and s.created_at < now() - interval '1 month'), 0)
      )
      from public.sub_orders s
      where s.provider_id = store_id and s.status not in ('rejected', 'cancelled')
    ),
    'orders', (
      select jsonb_build_object(
        'pending', count(*) filter (where s.status = 'pending'),
        'confirmed', count(*) filter (where s.status = 'confirmed'),
        'preparing', count(*) filter (where s.status = 'preparing'),
        'shipped', count(*) filter (where s.status = 'shipped'),
        'delivered', count(*) filter (where s.status = 'delivered'),
        'cancelled', count(*) filter (where s.status in ('rejected', 'cancelled')),
        'returned', count(*) filter (where s.status = 'returned'),
        'incident', count(*) filter (where s.status = 'incident')
      )
      from public.sub_orders s where s.provider_id = store_id
    ),
    'inventory', (
      select jsonb_build_object(
        'active', count(*) filter (where o.status = 'published'),
        'outOfStock', count(*) filter (where o.status = 'published' and o.stock_units = 0),
        'lowStock', count(*) filter (where o.status = 'published' and o.stock_units > 0
                                       and o.stock_units <= o.min_stock)
      )
      from public.offers o where o.provider_id = store_id
    ),
    'lowStockItems', coalesce((
      select jsonb_agg(x.item order by x.gap, x.name)
      from (
        select private.inventory_item_json(o) as item, o.stock_units - o.min_stock as gap, p.name
        from public.offers o join public.products p on p.id = o.product_id
        where o.provider_id = store_id and o.status = 'published' and o.stock_units <= o.min_stock
        order by o.stock_units - o.min_stock, p.name
        limit 5
      ) x), '[]'::jsonb),
    -- Del mes en curso. Sin liquidaciones todavía (fase 2): lo pendiente de
    -- pago es el neto de todos los pedidos no rechazados ni cancelados.
    'finance', (
      select jsonb_build_object(
        'grossCents', coalesce(sum(s.subtotal_cents) filter (where s.created_at >= month_start), 0),
        'commissionCents', coalesce(sum(s.commission_cents) filter (where s.created_at >= month_start), 0),
        'netCents', coalesce(sum(s.provider_net_cents) filter (where s.created_at >= month_start), 0),
        'pendingPayoutCents', coalesce(sum(s.provider_net_cents) filter (where s.status <> 'returned'), 0)
      )
      from public.sub_orders s
      where s.provider_id = store_id and s.status not in ('rejected', 'cancelled')
    ),
    'recentOrders', coalesce((
      select jsonb_agg(private.vendor_order_json(x.s) order by x.created_at desc)
      from (
        select s, s.created_at from public.sub_orders s
        where s.provider_id = store_id
        order by s.created_at desc
        limit 5
      ) x), '[]'::jsonb)
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Permisos
-- ---------------------------------------------------------------------------

revoke all on function public.get_my_orders(text, text, integer, integer) from public, anon;
revoke all on function public.get_my_order(uuid) from public, anon;
revoke all on function public.update_my_order_status(uuid, text, text, text, text) from public, anon;
revoke all on function public.get_my_inventory(text, text, integer, integer) from public, anon;
revoke all on function public.adjust_my_stock(text, text, integer, text) from public, anon;
revoke all on function public.set_my_min_stock(text, integer) from public, anon;
revoke all on function public.get_my_stock_movements(text, integer, integer) from public, anon;
revoke all on function public.get_my_dashboard() from public, anon;

grant execute on function public.get_my_orders(text, text, integer, integer) to authenticated;
grant execute on function public.get_my_order(uuid) to authenticated;
grant execute on function public.update_my_order_status(uuid, text, text, text, text) to authenticated;
grant execute on function public.get_my_inventory(text, text, integer, integer) to authenticated;
grant execute on function public.adjust_my_stock(text, text, integer, text) to authenticated;
grant execute on function public.set_my_min_stock(text, integer) to authenticated;
grant execute on function public.get_my_stock_movements(text, integer, integer) to authenticated;
grant execute on function public.get_my_dashboard() to authenticated;
