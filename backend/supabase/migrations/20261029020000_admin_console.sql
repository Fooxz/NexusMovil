-- Consola del administrador, entrega 1 (API_CONTRATO, parte 10): resumen
-- global, proveedores con métricas y control disciplinario, moderación
-- posterior del catálogo y supervisión de todos los pedidos (HU-022, HU-024,
-- HU-025, RF-011, RF-080).
--
-- - Proveedores: dos estados nuevos (bloqueado y desactivado). Suspender,
--   bloquear o desactivar exige el motivo, que queda en el historial
--   administrativo junto con advertencias, incidencias e incumplimientos.
-- - Moderación posterior: las tiendas siguen publicando sin aprobación. El
--   administrador revisa lo publicado (con alertas de calidad) y puede ocultar
--   una oferta pidiendo ajustes o rechazarla, siempre con motivo. La tienda ve
--   el motivo y, si la ocultaron, pide la revisión al corregirla.
-- - Pedidos: el administrador ve todos y puede intervenir el estado de una
--   sub-orden con una observación. Los reembolsos llegan en la entrega 2.
--
-- Todas las RPC de esta migración exigen private.require_admin().

alter type public.provider_status add value if not exists 'blocked';
alter type public.provider_status add value if not exists 'deactivated';

-- ---------------------------------------------------------------------------
-- Historial administrativo de proveedores
-- ---------------------------------------------------------------------------

create table public.provider_admin_notes (
  id bigint generated always as identity primary key,
  provider_id text not null references public.providers (id),
  -- note: observación; warning: advertencia; incident: incidencia recurrente;
  -- policy_violation: incumplimiento de políticas; status_change: cambio de
  -- estado (con from_status y to_status).
  kind text not null check (kind in ('note', 'warning', 'incident', 'policy_violation', 'status_change')),
  message text not null check (length(message) between 3 and 500),
  from_status text,
  to_status text,
  actor_id uuid references auth.users (id) on delete set null default auth.uid(),
  created_at timestamptz not null default now()
);

create index provider_admin_notes_idx on public.provider_admin_notes (provider_id, created_at desc);

create trigger provider_admin_notes_immutable
  before update or delete on public.provider_admin_notes
  for each row execute function private.prevent_change_except_actor_removal();

alter table public.provider_admin_notes enable row level security;
revoke all on public.provider_admin_notes from anon, authenticated;

-- ---------------------------------------------------------------------------
-- Moderación de ofertas
-- ---------------------------------------------------------------------------

alter table public.offers
  -- approved: visible si está publicada; hidden: oculta por NEXUS hasta que la
  -- tienda corrija; review: la tienda corrigió y pide revisión (sigue oculta);
  -- rejected: rechazada, no vuelve al catálogo.
  add column moderation_status text not null default 'approved'
    check (moderation_status in ('approved', 'hidden', 'review', 'rejected')),
  add column moderation_reason text check (moderation_reason is null or length(moderation_reason) <= 300),
  add column moderated_at timestamptz,
  add column moderated_by uuid references auth.users (id) on delete set null;

-- Mismas columnas que antes; ahora también exige la moderación aprobada.
create or replace view private.visible_offers as
select o.id, o.product_id, o.provider_id, o.external_sku, o.price_cents, o.old_price_cents,
  o.stock_units, o.status, o.stock_synced_at, o.created_at, o.updated_at,
  pr.display_name as provider_name
from public.offers o
join public.providers pr on pr.id = o.provider_id
where o.status = 'published'
  and pr.status = 'active'
  and o.moderation_status = 'approved';

-- La tienda ve si NEXUS ocultó o rechazó su oferta, y por qué.
create or replace function private.my_offer_json(o public.offers, p public.products, p_provider text)
returns jsonb
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
    'visible', o.status = 'published' and o.moderation_status = 'approved'
      and exists (select 1 from public.providers pr where pr.id = o.provider_id and pr.status::text = 'active'),
    'canEditSheet', private.sheet_editable(p.id, p_provider),
    'moderationStatus', o.moderation_status,
    'moderationReason', o.moderation_reason,
    'updatedAt', o.updated_at
  );
$$;

-- La tienda corrigió una oferta oculta y pide que la revisen.
create function public.request_my_offer_review(product_id text) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  store_id text := private.require_active_provider();
  mine public.offers;
begin
  select * into mine from public.offers o
  where o.product_id = request_my_offer_review.product_id and o.provider_id = store_id
  for update;
  if mine.id is null then
    perform private.raise_api_error(404, 'OFFER_NOT_FOUND', 'No tienes una oferta de ese producto');
  end if;
  if mine.moderation_status <> 'hidden' then
    perform private.raise_api_error(409, 'NOT_HIDDEN', 'Solo se pide revisión de una oferta oculta por NEXUS');
  end if;
  update public.offers o set moderation_status = 'review' where o.id = mine.id;
  return private.my_offer_detail(mine.product_id, store_id);
end;
$$;

-- Ofertas con sus alertas de calidad, para la moderación y el resumen:
-- incomplete (falta un atributo obligatorio: el PC Builder no puede validar
-- su compatibilidad), price_anomaly (menos de la mitad o más del doble de la
-- mediana de las ofertas del mismo producto) y duplicate (otro producto de la
-- misma categoría con el mismo nombre normalizado). Las fotos no son alerta:
-- el catálogo muestra el ícono de la categoría cuando faltan.
create view private.admin_offers as
with duplicated as (
  select p.category_code, private.name_key(p.name) as name_key
  from public.products p
  group by 1, 2
  having count(*) > 1
),
medians as (
  select o.product_id,
    percentile_cont(0.5) within group (order by o.price_cents) as median,
    count(*) as sellers
  from public.offers o
  where o.status = 'published'
  group by o.product_id
)
select
  o.id as offer_id,
  p.id as product_id,
  p.name as product_name,
  p.brand,
  p.model,
  p.category_code as category,
  o.provider_id,
  pr.display_name as provider_name,
  pr.status::text as provider_status,
  o.price_cents,
  o.old_price_cents,
  o.stock_units,
  o.status::text as status,
  o.moderation_status,
  o.moderation_reason,
  o.moderated_at,
  o.created_at,
  o.updated_at,
  (select coalesce(i.thumb_url, i.url) from public.product_images i
   where i.product_id = p.id order by i.sort_order, i.id limit 1) as image_url,
  array_remove(array[
    case when exists (
      select 1 from public.attribute_definitions d
      where d.category_code = p.category_code and d.is_required
        and not exists (
          select 1 from public.product_attributes a where a.product_id = p.id and a.attribute_id = d.id)
    ) then 'incomplete' end,
    case when m.sellers >= 2 and (o.price_cents < m.median * 0.5 or o.price_cents > m.median * 2)
      then 'price_anomaly' end,
    case when exists (
      select 1 from duplicated dup
      where dup.category_code = p.category_code and dup.name_key = private.name_key(p.name)
    ) then 'duplicate' end
  ], null) as flags
from public.offers o
join public.products p on p.id = o.product_id
join public.providers pr on pr.id = o.provider_id
left join medians m on m.product_id = o.product_id;

-- ---------------------------------------------------------------------------
-- Pedidos: observaciones del administrador
-- ---------------------------------------------------------------------------

create table public.order_admin_notes (
  id bigint generated always as identity primary key,
  order_id uuid not null references public.orders (id),
  sub_order_id uuid references public.sub_orders (id),
  message text not null check (length(message) between 3 and 500),
  actor_id uuid references auth.users (id) on delete set null default auth.uid(),
  created_at timestamptz not null default now()
);

create index order_admin_notes_idx on public.order_admin_notes (order_id, created_at);

create trigger order_admin_notes_immutable
  before update or delete on public.order_admin_notes
  for each row execute function private.prevent_change_except_actor_removal();

alter table public.order_admin_notes enable row level security;
revoke all on public.order_admin_notes from anon, authenticated;

-- Devuelve al stock las unidades de una sub-orden rechazada o cancelada
-- (menos las que ya faltaban al pagar). La usan la tienda y el administrador.
create function private.restock_sub_order(p_sub_order_id uuid, p_label text) returns void
language plpgsql
set search_path = ''
as $$
declare
  order_number text;
  item record;
begin
  select o.number into order_number
  from public.sub_orders s join public.orders o on o.id = s.order_id
  where s.id = p_sub_order_id;

  for item in
    select i.offer_id, sum(i.quantity - i.backordered_units)::integer as units
    from public.order_items i
    where i.sub_order_id = p_sub_order_id
    group by i.offer_id
    having sum(i.quantity - i.backordered_units) > 0
  loop
    perform private.set_stock_movement('cancellation', format('Pedido %s %s', order_number, p_label), p_sub_order_id);
    update public.offers o set stock_units = o.stock_units + item.units where o.id = item.offer_id;
  end loop;
  perform private.clear_stock_movement();
end;
$$;

-- Transiciones que puede hacer el administrador al intervenir: las de la
-- tienda, más cancelar un pedido en curso (incluso enviado, si se perdió) y
-- reportar o cerrar una incidencia con devolución.
create function private.admin_next_statuses(p_status text) returns text[]
language sql
immutable
set search_path = ''
as $$
  select case p_status
    when 'pending' then array['confirmed', 'rejected', 'cancelled', 'incident']
    when 'confirmed' then array['preparing', 'cancelled', 'incident']
    when 'preparing' then array['shipped', 'cancelled', 'incident']
    when 'shipped' then array['delivered', 'cancelled', 'incident']
    when 'delivered' then array['returned', 'incident']
    when 'incident' then array['confirmed', 'preparing', 'shipped', 'delivered', 'cancelled', 'returned']
    else array[]::text[]
  end;
$$;

-- ---------------------------------------------------------------------------
-- Resumen global
-- ---------------------------------------------------------------------------

create function public.admin_get_dashboard() returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  local_now timestamp := now() at time zone 'America/Bogota';
  day_start timestamptz := date_trunc('day', local_now) at time zone 'America/Bogota';
  week_start timestamptz := date_trunc('week', local_now) at time zone 'America/Bogota';
  month_start timestamptz := date_trunc('month', local_now) at time zone 'America/Bogota';
  series_start date := (local_now - interval '29 days')::date;
begin
  perform private.require_admin();

  return jsonb_build_object(
    -- Ventas: subtotal (IVA incluido) de las sub-órdenes no rechazadas ni
    -- canceladas. La comisión es el ingreso de NEXUS.
    'sales', (
      select jsonb_build_object(
        'totalCents', coalesce(sum(s.subtotal_cents), 0),
        'totalCommissionCents', coalesce(sum(s.commission_cents), 0),
        'todayCents', coalesce(sum(s.subtotal_cents) filter (where s.created_at >= day_start), 0),
        'yesterdayCents', coalesce(sum(s.subtotal_cents) filter (
          where s.created_at >= day_start - interval '1 day' and s.created_at < now() - interval '1 day'), 0),
        'weekCents', coalesce(sum(s.subtotal_cents) filter (where s.created_at >= week_start), 0),
        'previousWeekCents', coalesce(sum(s.subtotal_cents) filter (
          where s.created_at >= week_start - interval '7 days' and s.created_at < now() - interval '7 days'), 0),
        'monthCents', coalesce(sum(s.subtotal_cents) filter (where s.created_at >= month_start), 0),
        'previousMonthCents', coalesce(sum(s.subtotal_cents) filter (
          where s.created_at >= month_start - interval '1 month' and s.created_at < now() - interval '1 month'), 0),
        'monthCommissionCents', coalesce(sum(s.commission_cents) filter (where s.created_at >= month_start), 0),
        'monthProviderNetCents', coalesce(sum(s.provider_net_cents) filter (where s.created_at >= month_start), 0)
      )
      from public.sub_orders s
      where s.status not in ('rejected', 'cancelled')
    ),
    'orders', (
      select jsonb_build_object(
        'total', (select count(*) from public.orders),
        'inProgress', count(*) filter (where s.status in ('pending', 'confirmed', 'preparing', 'shipped')),
        'pending', count(*) filter (where s.status = 'pending'),
        'delivered', count(*) filter (where s.status = 'delivered'),
        'cancelled', count(*) filter (where s.status in ('rejected', 'cancelled')),
        'returned', count(*) filter (where s.status = 'returned'),
        'incident', count(*) filter (where s.status = 'incident'),
        'stale', count(*) filter (where s.status = 'pending' and s.created_at < now() - interval '48 hours')
      )
      from public.sub_orders s
    ),
    'users', jsonb_build_object(
      'customers', (select count(*) from public.profiles p where p.role = 'customer'),
      'activeCustomers', (
        select count(*) from public.profiles p join auth.users u on u.id = p.id
        where p.role = 'customer' and u.last_sign_in_at > now() - interval '30 days'),
      'newCustomers', (
        select count(*) from public.profiles p where p.role = 'customer' and p.created_at > now() - interval '30 days'),
      'providers', (
        select coalesce(jsonb_object_agg(x.status, x.n), '{}'::jsonb) from (
          select pr.status::text as status, count(*) as n from public.providers pr group by 1) x)
    ),
    'catalog', jsonb_build_object(
      'products', (select count(*) from public.products),
      'visibleProducts', (select count(*) from private.catalog_products),
      'outOfStockProducts', (select count(*) from private.catalog_products cp where cp.stock_level = 'outOfStock'),
      'offers', (select count(*) from public.offers),
      'hidden', (select count(*) from public.offers o where o.moderation_status = 'hidden'),
      'review', (select count(*) from public.offers o where o.moderation_status = 'review'),
      'rejected', (select count(*) from public.offers o where o.moderation_status = 'rejected'),
      'flagged', (
        select count(*) from private.admin_offers a
        where a.moderation_status = 'approved' and a.status = 'published' and cardinality(a.flags) > 0)
    ),
    'alerts', (
      select coalesce(jsonb_agg(jsonb_build_object('kind', x.kind, 'count', x.n)), '[]'::jsonb)
      from (
        select 'offers_review' as kind, (select count(*) from public.offers o where o.moderation_status = 'review') as n
        union all select 'orders_incident', (select count(*) from public.sub_orders s where s.status = 'incident')
        union all select 'orders_stale', (
          select count(*) from public.sub_orders s
          where s.status = 'pending' and s.created_at < now() - interval '48 hours')
        union all select 'providers_pending', (
          select count(*) from public.providers pr where pr.status::text = 'pending')
        union all select 'new_providers', (
          select count(*) from public.providers pr where pr.created_at > now() - interval '7 days')
        union all select 'payments_error', (
          select count(*) from public.payments p where p.status = 'error' and p.updated_at > now() - interval '30 days')
        union all select 'payment_events_unknown', (
          select count(*) from public.payment_events e
          where e.outcome = 'unknown_reference' and e.received_at > now() - interval '7 days')
        union all select 'assistant_unavailable', (
          select count(*) from public.assistant_interactions a
          where a.reply_type = 'unavailable' and a.created_at > now() - interval '24 hours')
      ) x
      where x.n > 0
    ),
    -- Últimos 30 días, por día de Colombia.
    'series', (
      select coalesce(jsonb_agg(jsonb_build_object(
          'date', d.day,
          'salesCents', coalesce(s.sales, 0),
          'commissionCents', coalesce(s.commission, 0),
          'orders', coalesce(s.orders, 0),
          'newCustomers', coalesce(c.n, 0),
          'newProviders', coalesce(pv.n, 0)
        ) order by d.day), '[]'::jsonb)
      from (select g::date as day from generate_series(series_start, local_now::date, interval '1 day') g) d
      left join (
        select (x.created_at at time zone 'America/Bogota')::date as day,
          sum(x.subtotal_cents) as sales, sum(x.commission_cents) as commission, count(distinct x.order_id) as orders
        from public.sub_orders x where x.status not in ('rejected', 'cancelled')
        group by 1
      ) s on s.day = d.day
      left join (
        select (p.created_at at time zone 'America/Bogota')::date as day, count(*) as n
        from public.profiles p where p.role = 'customer' group by 1
      ) c on c.day = d.day
      left join (
        select (pr.created_at at time zone 'America/Bogota')::date as day, count(*) as n
        from public.providers pr group by 1
      ) pv on pv.day = d.day
    ),
    'topCategories', (
      select coalesce(jsonb_agg(jsonb_build_object(
          'category', x.category_code, 'name', x.name, 'salesCents', x.sales, 'units', x.units)
          order by x.sales desc), '[]'::jsonb)
      from (
        select p.category_code, c.name, sum(i.line_total_cents) as sales, sum(i.quantity) as units
        from public.order_items i
        join public.sub_orders s on s.id = i.sub_order_id
        join public.products p on p.id = i.product_id
        join public.categories c on c.code = p.category_code
        where s.status not in ('rejected', 'cancelled') and s.created_at > now() - interval '30 days'
        group by 1, 2
        order by 4 desc
        limit 6
      ) x
    )
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Proveedores
-- ---------------------------------------------------------------------------

-- Desempeño de una tienda: ventas de los últimos 30 días, pedidos y tasas
-- sobre los pedidos cerrados (entregados, rechazados, cancelados o devueltos).
create function private.admin_provider_metrics(p_provider_id text) returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'sales30dCents', coalesce(sum(s.subtotal_cents) filter (
      where s.created_at > now() - interval '30 days' and s.status not in ('rejected', 'cancelled')), 0),
    'commission30dCents', coalesce(sum(s.commission_cents) filter (
      where s.created_at > now() - interval '30 days' and s.status not in ('rejected', 'cancelled')), 0),
    'orders', count(*),
    'openOrders', count(*) filter (where s.status in ('pending', 'confirmed', 'preparing', 'shipped', 'incident')),
    'incidents', count(*) filter (where s.status = 'incident'),
    'deliveredRate', case when count(*) filter (where s.status in ('delivered', 'rejected', 'cancelled', 'returned')) = 0
      then null
      else round(count(*) filter (where s.status = 'delivered')::numeric
        / count(*) filter (where s.status in ('delivered', 'rejected', 'cancelled', 'returned')), 3) end,
    'cancelRate', case when count(*) filter (where s.status in ('delivered', 'rejected', 'cancelled', 'returned')) = 0
      then null
      else round(count(*) filter (where s.status in ('rejected', 'cancelled'))::numeric
        / count(*) filter (where s.status in ('delivered', 'rejected', 'cancelled', 'returned')), 3) end,
    'warnings', (select count(*) from public.provider_admin_notes n
                 where n.provider_id = p_provider_id and n.kind in ('warning', 'incident', 'policy_violation'))
  )
  from public.sub_orders s
  where s.provider_id = p_provider_id;
$$;

-- Lista de tiendas con su desempeño. `sort`: name, sales (ventas de 30
-- días), performance (tasa de entrega) o recent (las más nuevas).
create function public.admin_list_providers(
  search text default null,
  status text default null,
  sort text default 'name'
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  pattern text := private.search_pattern(admin_list_providers.search);
  used_sort text := coalesce(admin_list_providers.sort, 'name');
begin
  perform private.require_admin();
  if used_sort not in ('name', 'sales', 'performance', 'recent') then
    perform private.raise_api_error(400, 'VALIDATION_ERROR', format('sort desconocido: %s', used_sort));
  end if;
  if admin_list_providers.status is not null and admin_list_providers.status not in
     ('pending', 'active', 'suspended', 'blocked', 'deactivated', 'rejected') then
    perform private.raise_api_error(400, 'VALIDATION_ERROR', 'status desconocido');
  end if;

  return (
    select coalesce(jsonb_agg(x.item order by
        case when used_sort = 'sales' then -(x.metrics ->> 'sales30dCents')::numeric end,
        case when used_sort = 'performance' then -coalesce((x.metrics ->> 'deliveredRate')::numeric, -1) end,
        case when used_sort = 'recent' then -extract(epoch from x.created_at) end,
        lower(x.display_name), x.id), '[]'::jsonb)
    from (
      select pr.id, pr.display_name, pr.created_at, m.metrics,
        private.admin_provider_json(pr) || jsonb_build_object('metrics', m.metrics) as item
      from public.providers pr
      cross join lateral (select private.admin_provider_metrics(pr.id) as metrics) m
      where (admin_list_providers.status is null or pr.status::text = admin_list_providers.status)
        and (pattern is null
          or private.normalize_search(pr.display_name) like pattern
          or private.normalize_search(pr.legal_name) like pattern
          or pr.tax_id like pattern)
    ) x
  );
end;
$$;

-- Ficha completa de una tienda para supervisarla: datos, desempeño,
-- inventario, pedidos por estado, últimos pedidos e historial administrativo.
create function public.admin_get_provider_overview(id text) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  store public.providers;
begin
  perform private.require_admin();
  select * into store from public.providers pr where pr.id = admin_get_provider_overview.id;
  if not found then
    perform private.raise_api_error(404, 'PROVIDER_NOT_FOUND', 'No existe esa tienda');
  end if;

  return private.admin_provider_json(store) || jsonb_build_object(
    'metrics', private.admin_provider_metrics(store.id),
    'inventory', (
      select jsonb_build_object(
        'published', count(*) filter (where o.status = 'published'),
        'lowStock', count(*) filter (where o.status = 'published' and o.stock_units > 0 and o.stock_units <= o.min_stock),
        'outOfStock', count(*) filter (where o.status = 'published' and o.stock_units = 0),
        'hidden', count(*) filter (where o.moderation_status in ('hidden', 'review')),
        'rejected', count(*) filter (where o.moderation_status = 'rejected'))
      from public.offers o where o.provider_id = store.id
    ),
    'ordersByStatus', (
      select coalesce(jsonb_object_agg(x.status, x.n), '{}'::jsonb)
      from (select s.status, count(*) as n from public.sub_orders s where s.provider_id = store.id group by 1) x
    ),
    'recentOrders', coalesce((
      select jsonb_agg(private.admin_sub_order_json(x.s) order by x.created_at desc)
      from (select s, s.created_at from public.sub_orders s where s.provider_id = store.id
            order by s.created_at desc limit 5) x), '[]'::jsonb),
    'notes', coalesce((
      select jsonb_agg(jsonb_build_object(
          'id', n.id, 'kind', n.kind, 'message', n.message,
          'fromStatus', n.from_status, 'toStatus', n.to_status,
          'actorName', (select p.full_name from public.profiles p where p.id = n.actor_id),
          'createdAt', n.created_at) order by n.created_at desc, n.id desc)
      from public.provider_admin_notes n where n.provider_id = store.id), '[]'::jsonb)
  );
end;
$$;

-- Cambia el estado de una tienda (RF-011). Activa, suspendida (temporal),
-- bloqueada (por incumplimiento) o desactivada (dejó de operar). Salvo para
-- habilitarla, exige el motivo. En los tres casos sus ofertas salen del
-- catálogo y la cuenta no puede operar (PROVIDER_NOT_ACTIVE).
drop function public.admin_set_provider_status(text, text);

create function public.admin_set_provider_status(id text, status text, reason text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  store public.providers;
  previous text;
  used_reason text := nullif(trim(coalesce(admin_set_provider_status.reason, '')), '');
begin
  perform private.require_admin();
  if admin_set_provider_status.status is null
     or admin_set_provider_status.status not in ('active', 'suspended', 'blocked', 'deactivated') then
    perform private.raise_api_error(400, 'VALIDATION_ERROR',
      'status debe ser "active", "suspended", "blocked" o "deactivated"');
  end if;
  if admin_set_provider_status.status <> 'active' and (used_reason is null or length(used_reason) < 3) then
    perform private.validation_error('reason', 'Escribe el motivo (al menos 3 caracteres)');
  end if;
  if length(used_reason) > 500 then
    perform private.validation_error('reason', 'El motivo admite hasta 500 caracteres');
  end if;

  select pr.status::text into previous from public.providers pr where pr.id = admin_set_provider_status.id for update;
  if previous is null then
    perform private.raise_api_error(404, 'PROVIDER_NOT_FOUND', 'No existe esa tienda');
  end if;
  if previous = admin_set_provider_status.status then
    perform private.raise_api_error(409, 'SAME_STATUS', 'La tienda ya está en ese estado');
  end if;

  update public.providers pr
  set status = admin_set_provider_status.status::public.provider_status
  where pr.id = admin_set_provider_status.id
  returning * into store;

  insert into public.provider_admin_notes (provider_id, kind, message, from_status, to_status)
  values (store.id, 'status_change', coalesce(used_reason, 'Tienda habilitada'), previous, admin_set_provider_status.status);

  return private.admin_provider_json(store);
end;
$$;

-- Advertencias, incidencias recurrentes, incumplimientos y observaciones.
create function public.admin_add_provider_note(id text, kind text, message text) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  used_message text := trim(coalesce(admin_add_provider_note.message, ''));
begin
  perform private.require_admin();
  if not exists (select 1 from public.providers pr where pr.id = admin_add_provider_note.id) then
    perform private.raise_api_error(404, 'PROVIDER_NOT_FOUND', 'No existe esa tienda');
  end if;
  if admin_add_provider_note.kind is null
     or admin_add_provider_note.kind not in ('note', 'warning', 'incident', 'policy_violation') then
    perform private.validation_error('kind', 'El tipo debe ser observación, advertencia, incidencia o incumplimiento');
  end if;
  if length(used_message) not between 3 and 500 then
    perform private.validation_error('message', 'Escribe el detalle (de 3 a 500 caracteres)');
  end if;
  insert into public.provider_admin_notes (provider_id, kind, message)
  values (admin_add_provider_note.id, admin_add_provider_note.kind, used_message);
  return public.admin_get_provider_overview(admin_add_provider_note.id);
end;
$$;

-- ---------------------------------------------------------------------------
-- Catálogo global y moderación
-- ---------------------------------------------------------------------------

create function private.admin_offer_json(a private.admin_offers) returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'offerId', a.offer_id,
    'productId', a.product_id,
    'productName', a.product_name,
    'brand', a.brand,
    'model', a.model,
    'category', a.category,
    'providerId', a.provider_id,
    'providerName', a.provider_name,
    'providerStatus', a.provider_status,
    'priceCents', a.price_cents,
    'oldPriceCents', a.old_price_cents,
    'stockUnits', a.stock_units,
    'status', a.status,
    'moderationStatus', a.moderation_status,
    'moderationReason', a.moderation_reason,
    'moderatedAt', a.moderated_at,
    'imageUrl', a.image_url,
    'flags', to_jsonb(a.flags),
    'visible', a.status = 'published' and a.moderation_status = 'approved' and a.provider_status = 'active',
    'updatedAt', a.updated_at
  );
$$;

-- Todas las ofertas, con filtros. `moderation`: approved, hidden, review o
-- rejected. `flag`: incomplete, price_anomaly, duplicate o any
-- (cualquier alerta).
create function public.admin_list_offers(
  search text default null,
  provider text default null,
  category text default null,
  brand text default null,
  moderation text default null,
  flag text default null,
  page integer default 0,
  page_size integer default 20
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  pattern text := private.search_pattern(admin_list_offers.search);
  used_size integer := least(greatest(coalesce(admin_list_offers.page_size, 20), 1), 50);
  total_count bigint;
  items jsonb;
  counts jsonb;
begin
  perform private.require_admin();
  if admin_list_offers.moderation is not null
     and admin_list_offers.moderation not in ('approved', 'hidden', 'review', 'rejected') then
    perform private.raise_api_error(400, 'VALIDATION_ERROR', 'moderation desconocido');
  end if;
  if admin_list_offers.flag is not null
     and admin_list_offers.flag not in ('incomplete', 'price_anomaly', 'duplicate', 'any') then
    perform private.raise_api_error(400, 'VALIDATION_ERROR', 'flag desconocido');
  end if;
  if coalesce(admin_list_offers.page, 0) < 0 then
    perform private.raise_api_error(400, 'VALIDATION_ERROR', 'page no puede ser negativo');
  end if;

  -- `filtered` aplica la búsqueda y los filtros de tienda, categoría y marca
  -- (de ahí salen los contadores); `matched`, además, la moderación y la alerta.
  with filtered as (
    select a as offer, a.offer_id, a.moderation_status, a.flags, a.updated_at
    from private.admin_offers a
    where (admin_list_offers.provider is null or a.provider_id = admin_list_offers.provider)
      and (admin_list_offers.category is null or a.category = admin_list_offers.category)
      and (admin_list_offers.brand is null or lower(a.brand) = lower(trim(admin_list_offers.brand)))
      and (pattern is null
        or private.normalize_search(a.product_name) like pattern
        or private.normalize_search(a.brand) like pattern
        or private.normalize_search(a.provider_name) like pattern)
  ),
  matched as (
    -- Primero las que piden revisión y las que tienen más alertas.
    select f.offer, row_number() over (order by
        f.moderation_status = 'review' desc, cardinality(f.flags) desc, f.updated_at desc, f.offer_id) as ord
    from filtered f
    where (admin_list_offers.moderation is null or f.moderation_status = admin_list_offers.moderation)
      and (admin_list_offers.flag is null
        or (admin_list_offers.flag = 'any' and cardinality(f.flags) > 0)
        or admin_list_offers.flag = any (f.flags))
  )
  select
    (select jsonb_build_object(
        'all', count(*),
        'approved', count(*) filter (where f.moderation_status = 'approved'),
        'hidden', count(*) filter (where f.moderation_status = 'hidden'),
        'review', count(*) filter (where f.moderation_status = 'review'),
        'rejected', count(*) filter (where f.moderation_status = 'rejected'),
        'flagged', count(*) filter (where cardinality(f.flags) > 0))
     from filtered f),
    (select count(*) from matched),
    (select coalesce(jsonb_agg(private.admin_offer_json(m.offer) order by m.ord), '[]'::jsonb)
     from matched m
     where m.ord > coalesce(admin_list_offers.page, 0)::bigint * used_size
       and m.ord <= (coalesce(admin_list_offers.page, 0)::bigint + 1) * used_size)
  into counts, total_count, items;

  return jsonb_build_object('items', items, 'total', total_count, 'counts', counts,
    'page', coalesce(admin_list_offers.page, 0), 'pageSize', used_size);
end;
$$;

-- Detalle de una oferta para moderarla: la ficha completa (atributos
-- tipados e imágenes) y las otras tiendas que venden el producto.
create function public.admin_get_offer(offer_id text) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  row_data private.admin_offers;
begin
  perform private.require_admin();
  select * into row_data from private.admin_offers a where a.offer_id = admin_get_offer.offer_id;
  if row_data.offer_id is null then
    perform private.raise_api_error(404, 'OFFER_NOT_FOUND', 'No existe esa oferta');
  end if;

  return private.admin_offer_json(row_data) || jsonb_build_object(
    'summary', (select p.summary from public.products p where p.id = row_data.product_id),
    'createdByProviderId', (select p.created_by_provider_id from public.products p where p.id = row_data.product_id),
    'attributes', private.attributes_json(row_data.product_id),
    'images', coalesce((
      select jsonb_agg(i.url order by i.sort_order, i.id) from public.product_images i
      where i.product_id = row_data.product_id), '[]'::jsonb),
    'otherOffers', coalesce((
      select jsonb_agg(jsonb_build_object(
          'offerId', a.offer_id, 'providerName', a.provider_name, 'priceCents', a.price_cents,
          'stockUnits', a.stock_units, 'status', a.status, 'moderationStatus', a.moderation_status)
          order by a.price_cents)
      from private.admin_offers a
      where a.product_id = row_data.product_id and a.offer_id <> row_data.offer_id), '[]'::jsonb)
  );
end;
$$;

-- Aprueba (o restaura), oculta pidiendo ajustes o rechaza una oferta.
-- Ocultar y rechazar exigen el motivo, que ve la tienda.
create function public.admin_moderate_offer(offer_id text, action text, reason text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  admin_id uuid := private.require_admin();
  used_reason text := nullif(trim(coalesce(admin_moderate_offer.reason, '')), '');
  next_status text;
begin
  next_status := case admin_moderate_offer.action
    when 'approve' then 'approved'
    when 'hide' then 'hidden'
    when 'reject' then 'rejected'
  end;
  if next_status is null then
    perform private.raise_api_error(400, 'VALIDATION_ERROR', 'action debe ser "approve", "hide" o "reject"');
  end if;
  if next_status <> 'approved' and (used_reason is null or length(used_reason) not between 3 and 300) then
    perform private.validation_error('reason', 'Escribe el motivo para la tienda (de 3 a 300 caracteres)');
  end if;

  update public.offers o
  set moderation_status = next_status,
      moderation_reason = case when next_status = 'approved' then null else used_reason end,
      moderated_at = now(),
      moderated_by = admin_id
  where o.id = admin_moderate_offer.offer_id;
  if not found then
    perform private.raise_api_error(404, 'OFFER_NOT_FOUND', 'No existe esa oferta');
  end if;
  return public.admin_get_offer(admin_moderate_offer.offer_id);
end;
$$;

-- Corrige la ficha compartida de un producto: nombre, marca, modelo,
-- resumen, categoría y atributos (contra la plantilla de la categoría). La
-- ficha para mostrar llega armada desde la app. Las imágenes no cambian.
create function public.admin_update_product(product_id text, product jsonb) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_product public.products;
  v_category text := coalesce(admin_update_product.product ->> 'category', '');
begin
  perform private.require_admin();
  select * into current_product from public.products p where p.id = admin_update_product.product_id for update;
  if current_product.id is null then
    perform private.raise_api_error(404, 'PRODUCT_NOT_FOUND', 'No existe ese producto');
  end if;
  if admin_update_product.product is null or jsonb_typeof(admin_update_product.product) <> 'object' then
    perform private.validation_error('product', 'Faltan los datos del producto');
  end if;
  if not exists (select 1 from public.categories c where c.code = v_category and c.is_active) then
    perform private.validation_error('category', 'Elige un tipo de pieza del catálogo');
  end if;
  if length(trim(coalesce(admin_update_product.product ->> 'name', ''))) not between 3 and 160 then
    perform private.validation_error('name', 'El nombre debe tener de 3 a 160 caracteres');
  end if;
  if length(trim(coalesce(admin_update_product.product ->> 'brand', ''))) not between 1 and 60 then
    perform private.validation_error('brand', 'La marca es obligatoria (hasta 60 caracteres)');
  end if;
  if length(trim(coalesce(admin_update_product.product ->> 'model', ''))) not between 1 and 80 then
    perform private.validation_error('model', 'El modelo es obligatorio (hasta 80 caracteres)');
  end if;
  perform private.validate_attributes(v_category, coalesce(admin_update_product.product -> 'attributes', '{}'::jsonb));
  perform private.check_duplicates(v_category, admin_update_product.product, current_product.id, true);

  -- Los atributos son de la categoría: se reemplazan antes de cambiarla.
  delete from public.product_attributes a where a.product_id = current_product.id;
  update public.products p
  set name = trim(admin_update_product.product ->> 'name'),
      brand = trim(admin_update_product.product ->> 'brand'),
      model = trim(admin_update_product.product ->> 'model'),
      summary = nullif(trim(coalesce(admin_update_product.product ->> 'summary', '')), ''),
      category_code = v_category,
      quick_specs = coalesce(
        (select array_agg(trim(e #>> '{}') order by ord)
         from jsonb_array_elements(admin_update_product.product -> 'quickSpecs') with ordinality as t(e, ord)),
        p.quick_specs),
      specs = coalesce(admin_update_product.product -> 'specs', p.specs)
  where p.id = current_product.id;
  insert into public.product_attributes (product_id, attribute_id, value_number, value_text, value_bool, value_list)
  select current_product.id, d.id,
    case when d.data_type = 'number' then (a.value #>> '{}')::numeric end,
    case when d.data_type in ('text', 'enum') then trim(a.value #>> '{}') end,
    case when d.data_type = 'boolean' then (a.value #>> '{}')::boolean end,
    case when d.data_type = 'enumList' then array(select jsonb_array_elements_text(a.value)) end
  from jsonb_each(coalesce(admin_update_product.product -> 'attributes', '{}'::jsonb)) a
  join public.attribute_definitions d on d.category_code = v_category and d.key = a.key
  where a.value <> 'null'::jsonb;

  return jsonb_build_object('productId', current_product.id,
    'offers', coalesce((select jsonb_agg(private.admin_offer_json(a)) from private.admin_offers a
                        where a.product_id = current_product.id), '[]'::jsonb));
end;
$$;

-- ---------------------------------------------------------------------------
-- Pedidos globales
-- ---------------------------------------------------------------------------

create function private.admin_sub_order_json(s public.sub_orders) returns jsonb
language sql
stable
set search_path = ''
as $$
  select private.vendor_order_json(s) || jsonb_build_object(
    'orderId', s.order_id,
    'providerId', s.provider_id,
    'providerName', s.provider_name,
    'customerEmail', o.contact ->> 'email',
    'paymentMethod', p.payment_method_type
  )
  from public.orders o
  join public.payments p on p.id = o.payment_id
  where o.id = s.order_id;
$$;

-- Todas las sub-órdenes. `search`: número de pedido, cliente (nombre o
-- correo) o tienda. Fechas `from_date` y `to_date` de Colombia, inclusivas.
create function public.admin_list_orders(
  search text default null,
  provider text default null,
  status text default null,
  from_date date default null,
  to_date date default null,
  page integer default 0,
  page_size integer default 20
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  pattern text := private.search_pattern(admin_list_orders.search);
  used_size integer := least(greatest(coalesce(admin_list_orders.page_size, 20), 1), 50);
  total_count bigint;
  items jsonb;
begin
  perform private.require_admin();
  if admin_list_orders.status is not null and admin_list_orders.status not in
     ('pending', 'confirmed', 'preparing', 'shipped', 'delivered', 'rejected', 'cancelled', 'returned', 'incident') then
    perform private.raise_api_error(400, 'VALIDATION_ERROR', 'status desconocido');
  end if;
  if coalesce(admin_list_orders.page, 0) < 0 then
    perform private.raise_api_error(400, 'VALIDATION_ERROR', 'page no puede ser negativo');
  end if;

  select count(*) into total_count
  from public.sub_orders s join public.orders o on o.id = s.order_id
  where (admin_list_orders.provider is null or s.provider_id = admin_list_orders.provider)
    and (admin_list_orders.status is null or s.status = admin_list_orders.status)
    and (admin_list_orders.from_date is null
      or (s.created_at at time zone 'America/Bogota')::date >= admin_list_orders.from_date)
    and (admin_list_orders.to_date is null
      or (s.created_at at time zone 'America/Bogota')::date <= admin_list_orders.to_date)
    and (pattern is null
      or private.normalize_search(o.number) like pattern
      or private.normalize_search(o.contact ->> 'fullName') like pattern
      or private.normalize_search(o.contact ->> 'email') like pattern
      or private.normalize_search(s.provider_name) like pattern);

  select coalesce(jsonb_agg(private.admin_sub_order_json(x.s) order by x.ord), '[]'::jsonb) into items
  from (
    select s, row_number() over (order by s.created_at desc, s.id) as ord
    from public.sub_orders s join public.orders o on o.id = s.order_id
    where (admin_list_orders.provider is null or s.provider_id = admin_list_orders.provider)
      and (admin_list_orders.status is null or s.status = admin_list_orders.status)
      and (admin_list_orders.from_date is null
        or (s.created_at at time zone 'America/Bogota')::date >= admin_list_orders.from_date)
      and (admin_list_orders.to_date is null
        or (s.created_at at time zone 'America/Bogota')::date <= admin_list_orders.to_date)
      and (pattern is null
        or private.normalize_search(o.number) like pattern
        or private.normalize_search(o.contact ->> 'fullName') like pattern
        or private.normalize_search(o.contact ->> 'email') like pattern
        or private.normalize_search(s.provider_name) like pattern)
    order by s.created_at desc, s.id
    offset coalesce(admin_list_orders.page, 0)::bigint * used_size
    limit used_size
  ) x;

  return jsonb_build_object('items', items, 'total', total_count,
    'page', coalesce(admin_list_orders.page, 0), 'pageSize', used_size);
end;
$$;

-- El pedido completo: pago, entrega, cliente, cada sub-orden con su detalle
-- y estados a los que el administrador la puede llevar, y las observaciones.
create function public.admin_get_order(id uuid) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  ord public.orders;
  pay public.payments;
begin
  perform private.require_admin();
  select * into ord from public.orders o where o.id = admin_get_order.id;
  if ord.id is null then
    perform private.raise_api_error(404, 'ORDER_NOT_FOUND', 'No existe ese pedido');
  end if;
  select * into pay from public.payments p where p.id = ord.payment_id;

  return jsonb_build_object(
    'id', ord.id,
    'number', ord.number,
    'createdAt', ord.created_at,
    'totalCents', ord.total_cents,
    'contact', ord.contact,
    'shippingAddress', ord.shipping_address,
    'payment', jsonb_build_object(
      'reference', pay.reference,
      'status', pay.status,
      'amountCents', pay.amount_cents,
      'method', pay.payment_method_type,
      'transactionId', pay.gateway_transaction_id,
      'approvedAt', pay.approved_at),
    'subOrders', coalesce((
      select jsonb_agg(private.vendor_order_detail(s.id) || jsonb_build_object(
          'providerId', s.provider_id,
          'providerName', s.provider_name,
          'adminNextStatuses', to_jsonb(private.admin_next_statuses(s.status)))
        order by s.provider_name, s.id)
      from public.sub_orders s where s.order_id = ord.id), '[]'::jsonb),
    'notes', coalesce((
      select jsonb_agg(jsonb_build_object(
          'id', n.id, 'subOrderId', n.sub_order_id, 'message', n.message,
          'actorName', (select p.full_name from public.profiles p where p.id = n.actor_id),
          'createdAt', n.created_at) order by n.created_at, n.id)
      from public.order_admin_notes n where n.order_id = ord.id), '[]'::jsonb)
  );
end;
$$;

create function public.admin_add_order_note(id uuid, message text, sub_order_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  used_message text := trim(coalesce(admin_add_order_note.message, ''));
begin
  perform private.require_admin();
  if not exists (select 1 from public.orders o where o.id = admin_add_order_note.id) then
    perform private.raise_api_error(404, 'ORDER_NOT_FOUND', 'No existe ese pedido');
  end if;
  if admin_add_order_note.sub_order_id is not null and not exists (
    select 1 from public.sub_orders s
    where s.id = admin_add_order_note.sub_order_id and s.order_id = admin_add_order_note.id
  ) then
    perform private.validation_error('subOrderId', 'La sub-orden no es de ese pedido');
  end if;
  if length(used_message) not between 3 and 500 then
    perform private.validation_error('message', 'Escribe la observación (de 3 a 500 caracteres)');
  end if;
  insert into public.order_admin_notes (order_id, sub_order_id, message)
  values (admin_add_order_note.id, admin_add_order_note.sub_order_id, used_message);
  return public.admin_get_order(admin_add_order_note.id);
end;
$$;

-- Intervención del administrador en una sub-orden. Siempre con la
-- observación, que queda en el historial del pedido. Cancelar o rechazar
-- devuelve las unidades al stock; el reembolso llega en la entrega 2.
create function public.admin_update_sub_order_status(
  id uuid,
  status text,
  note text,
  carrier text default null,
  tracking_number text default null
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_order public.sub_orders;
  used_note text := nullif(trim(coalesce(admin_update_sub_order_status.note, '')), '');
  used_carrier text := nullif(trim(coalesce(admin_update_sub_order_status.carrier, '')), '');
  used_tracking text := nullif(trim(coalesce(admin_update_sub_order_status.tracking_number, '')), '');
begin
  perform private.require_admin();
  select * into current_order from public.sub_orders s where s.id = admin_update_sub_order_status.id for update;
  if current_order.id is null then
    perform private.raise_api_error(404, 'ORDER_NOT_FOUND', 'No existe ese pedido');
  end if;
  if admin_update_sub_order_status.status is null or not (
    admin_update_sub_order_status.status = any (private.admin_next_statuses(current_order.status))
  ) then
    perform private.raise_api_error_details(409, 'INVALID_TRANSITION',
      'El pedido no puede pasar a ese estado desde el actual',
      jsonb_build_object('from', current_order.status, 'to', admin_update_sub_order_status.status,
        'allowed', to_jsonb(private.admin_next_statuses(current_order.status))));
  end if;
  if used_note is null or length(used_note) not between 3 and 300 then
    perform private.validation_error('note', 'Escribe la observación (de 3 a 300 caracteres)');
  end if;
  if admin_update_sub_order_status.status = 'shipped' and (used_carrier is null or used_tracking is null) then
    perform private.validation_error('trackingNumber', 'Escribe la transportadora y el número de guía');
  end if;

  update public.sub_orders s
  set status = admin_update_sub_order_status.status,
      status_note = used_note,
      status_changed_at = now(),
      carrier = case when admin_update_sub_order_status.status = 'shipped' then used_carrier else s.carrier end,
      tracking_number = case when admin_update_sub_order_status.status = 'shipped' then used_tracking else s.tracking_number end,
      shipped_at = case when admin_update_sub_order_status.status = 'shipped' then now() else s.shipped_at end,
      delivered_at = case when admin_update_sub_order_status.status = 'delivered' then now() else s.delivered_at end
  where s.id = current_order.id;

  insert into public.sub_order_status_history (sub_order_id, from_status, to_status, note)
  values (current_order.id, current_order.status, admin_update_sub_order_status.status,
    'NEXUS: ' || used_note);

  if admin_update_sub_order_status.status in ('rejected', 'cancelled') then
    perform private.restock_sub_order(current_order.id,
      case admin_update_sub_order_status.status when 'rejected' then 'rechazado por NEXUS' else 'cancelado por NEXUS' end);
  end if;

  return public.admin_get_order(current_order.order_id);
end;
$$;

-- ---------------------------------------------------------------------------
-- Permisos
-- ---------------------------------------------------------------------------

revoke all on function public.request_my_offer_review(text) from public, anon;
revoke all on function public.admin_get_dashboard() from public, anon;
revoke all on function public.admin_list_providers(text, text, text) from public, anon;
revoke all on function public.admin_get_provider_overview(text) from public, anon;
revoke all on function public.admin_set_provider_status(text, text, text) from public, anon;
revoke all on function public.admin_add_provider_note(text, text, text) from public, anon;
revoke all on function public.admin_list_offers(text, text, text, text, text, text, integer, integer) from public, anon;
revoke all on function public.admin_get_offer(text) from public, anon;
revoke all on function public.admin_moderate_offer(text, text, text) from public, anon;
revoke all on function public.admin_update_product(text, jsonb) from public, anon;
revoke all on function public.admin_list_orders(text, text, text, date, date, integer, integer) from public, anon;
revoke all on function public.admin_get_order(uuid) from public, anon;
revoke all on function public.admin_add_order_note(uuid, text, uuid) from public, anon;
revoke all on function public.admin_update_sub_order_status(uuid, text, text, text, text) from public, anon;

grant execute on function public.request_my_offer_review(text) to authenticated;
grant execute on function public.admin_get_dashboard() to authenticated;
grant execute on function public.admin_list_providers(text, text, text) to authenticated;
grant execute on function public.admin_get_provider_overview(text) to authenticated;
grant execute on function public.admin_set_provider_status(text, text, text) to authenticated;
grant execute on function public.admin_add_provider_note(text, text, text) to authenticated;
grant execute on function public.admin_list_offers(text, text, text, text, text, text, integer, integer) to authenticated;
grant execute on function public.admin_get_offer(text) to authenticated;
grant execute on function public.admin_moderate_offer(text, text, text) to authenticated;
grant execute on function public.admin_update_product(text, jsonb) to authenticated;
grant execute on function public.admin_list_orders(text, text, text, date, date, integer, integer) to authenticated;
grant execute on function public.admin_get_order(uuid) to authenticated;
grant execute on function public.admin_add_order_note(uuid, text, uuid) to authenticated;
grant execute on function public.admin_update_sub_order_status(uuid, text, text, text, text) to authenticated;
