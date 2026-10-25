-- Fase 8: checkout, pagos y comisión (HU-010, HU-011, HU-026; RF-055 a
-- RF-061, RF-066, RF-071 a RF-075; RN-002, RN-005, RN-025, RN-026).
-- docs/API_CONTRATO.md v0.10, parte 5.
--
-- Flujo:
-- 1. `start_checkout` revalida el carrito (RF-055) y guarda un intento de pago
--    (`payments`) con la foto de las líneas, la dirección y el contacto.
-- 2. La Edge Function `checkout` firma ese intento y lo envía a Wompi.
-- 3. Wompi avisa el resultado a `payment-webhook`, o la app lo consulta con
--    `checkout`. Las dos llaman a `apply_payment_event`, que es idempotente
--    (RNF-020): la orden se crea solo con el pago aprobado (RN-025), una sola
--    vez, y ahí se descuenta el stock (RF-066) y se calcula la comisión.
--
-- Precios: el catálogo trae el precio final con IVA del 19 % incluido
-- (RN-001, RN-006). La comisión se calcula sobre el valor sin IVA y se
-- descuenta de lo que recibe el proveedor; el cliente paga el precio
-- publicado (RN-002).

-- ---------------------------------------------------------------------------
-- Parámetros del negocio
-- ---------------------------------------------------------------------------

insert into public.app_settings (key, value, description) values
  ('vat_rate', '0.19',
   'IVA incluido en los precios del catálogo. La comisión se calcula sobre el valor sin IVA.'),
  ('default_commission_rate', '0.10',
   'SUPUESTO S-07, pendiente del negocio: comisión cuando el proveedor y el producto no tienen regla vigente.'),
  ('commission_rate_max', '0.30',
   'SUPUESTO RN-024, pendiente del negocio: comisión máxima que admite una regla.'),
  ('checkout_expiration_minutes', '60',
   'Minutos que tiene el cliente para pagar un intento en la pasarela.'),
  ('checkout_attempts_per_window', '10',
   'Intentos de pago por usuario cada 10 minutos.');

create function private.numeric_setting(p_key text, p_fallback numeric) returns numeric
language sql
stable
set search_path = ''
as $$
  select coalesce(
    (select (s.value #>> '{}')::numeric from public.app_settings s where s.key = p_key),
    p_fallback
  );
$$;

-- Registros contables: no se modifican ni se borran (RN-026, RNF-032).
create function private.prevent_change() returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception '% no admite cambios: es un registro de la operación', tg_table_name
    using errcode = '42501';
end;
$$;

-- ---------------------------------------------------------------------------
-- Comisiones (HU-023, RF-071 a RF-073)
-- ---------------------------------------------------------------------------

-- Una regla es del proveedor (product_id nulo) o de un producto suyo, con
-- vigencia. Prevalece la del producto (S-05). Las reglas no se editan para
-- cambiar el porcentaje: se cierra la vigencia de la anterior y se crea otra,
-- así las órdenes viejas conservan su regla.
create table public.commission_rules (
  id uuid primary key default gen_random_uuid(),
  provider_id text not null references public.providers (id),
  product_id text references public.products (id),
  rate numeric(5, 4) not null check (rate >= 0 and rate < 1),
  valid_from timestamptz not null default now(),
  valid_to timestamptz,
  note text check (note is null or length(note) <= 300),
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now(),
  check (valid_to is null or valid_to > valid_from)
);

create index commission_rules_lookup_idx
  on public.commission_rules (provider_id, product_id, valid_from desc);

-- Rango permitido (RN-024) y sin vigencias superpuestas para el mismo
-- proveedor y producto, para que siempre haya una sola regla aplicable.
create function private.check_commission_rule() returns trigger
language plpgsql
set search_path = ''
as $$
declare
  max_rate numeric := private.numeric_setting('commission_rate_max', 0.30);
begin
  if new.rate > max_rate then
    raise exception 'La comisión % supera el máximo permitido (%)', new.rate, max_rate
      using errcode = '23514';
  end if;
  if exists (
    select 1
    from public.commission_rules r
    where r.id <> new.id
      and r.provider_id = new.provider_id
      and r.product_id is not distinct from new.product_id
      and tstzrange(r.valid_from, r.valid_to) && tstzrange(new.valid_from, new.valid_to)
  ) then
    raise exception 'Ya hay una comisión vigente para ese proveedor y producto en esas fechas'
      using errcode = '23P01';
  end if;
  return new;
end;
$$;

create trigger commission_rules_check
  before insert or update on public.commission_rules
  for each row execute function private.check_commission_rule();

create trigger commission_rules_audit
  after insert or update or delete on public.commission_rules
  for each row execute function private.audit_row_change();

alter table public.commission_rules enable row level security;
revoke all on public.commission_rules from anon, authenticated;

-- Comisión aplicable a un producto de un proveedor en un momento: la del
-- producto, si no la del proveedor, si no la general (RF-073, S-05).
create function private.commission_for(
  p_provider_id text,
  p_product_id text,
  p_at timestamptz,
  out rate numeric,
  out rule_id uuid
)
language plpgsql
stable
set search_path = ''
as $$
begin
  select r.rate, r.id into rate, rule_id
  from public.commission_rules r
  where r.provider_id = p_provider_id
    and (r.product_id is null or r.product_id = p_product_id)
    and r.valid_from <= p_at
    and (r.valid_to is null or r.valid_to > p_at)
  order by (r.product_id is not null) desc, r.valid_from desc
  limit 1;

  if not found then
    rate := private.numeric_setting('default_commission_rate', 0.10);
    rule_id := null;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Pagos (RF-057 a RF-059)
-- ---------------------------------------------------------------------------

-- Un intento de pago con la foto de lo que se va a comprar. `items` guarda
-- [{offerId, productId, providerId, providerName, productName, brand,
-- quantity, unitPriceCents}] con el precio revalidado al iniciar el pago.
create table public.payments (
  id uuid primary key default gen_random_uuid(),
  reference text not null unique check (reference ~ '^NX-[0-9]{8}-[0-9A-F]{10}$'),
  user_id uuid references auth.users (id) on delete set null,
  -- pending: esperando el pago; approved: pagado (tiene orden);
  -- declined, voided, error: la pasarela no cobró;
  -- abandoned: el cliente empezó otro intento sin pagar este.
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'declined', 'voided', 'error', 'abandoned')),
  amount_cents bigint not null check (amount_cents > 0 and amount_cents % 100 = 0),
  currency text not null default 'COP' check (currency = 'COP'),
  gateway text not null default 'wompi' check (gateway = 'wompi'),
  gateway_transaction_id text,
  payment_method_type text,
  status_message text,
  items jsonb not null check (jsonb_typeof(items) = 'array' and jsonb_array_length(items) > 0),
  shipping_address jsonb not null,
  contact jsonb not null,
  expires_at timestamptz not null,
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index payments_user_idx on public.payments (user_id, created_at desc);

create trigger payments_set_updated_at
  before update on public.payments
  for each row execute function private.set_updated_at();

create trigger payments_audit
  after insert or update or delete on public.payments
  for each row execute function private.audit_row_change();

create trigger payments_no_delete
  before delete on public.payments
  for each row execute function private.prevent_change();

alter table public.payments enable row level security;
revoke all on public.payments from anon, authenticated;

-- Cada aviso de la pasarela (webhook) y cada consulta, con lo que se hizo.
-- Sirve para la conciliación (RF-079) y para explicar un estado.
create table public.payment_events (
  id bigint generated always as identity primary key,
  payment_id uuid references public.payments (id),
  reference text not null,
  source text not null check (source in ('webhook', 'status_check')),
  transaction_id text,
  status text,
  amount_cents bigint,
  currency text,
  -- order_created, status_updated, duplicate, stale, amount_mismatch,
  -- unknown_reference.
  outcome text not null,
  payload jsonb,
  received_at timestamptz not null default now()
);

create index payment_events_reference_idx on public.payment_events (reference, received_at);

create trigger payment_events_immutable
  before update or delete on public.payment_events
  for each row execute function private.prevent_change();

alter table public.payment_events enable row level security;
revoke all on public.payment_events from anon, authenticated;

-- ---------------------------------------------------------------------------
-- Órdenes (RF-060, RF-061, RN-026)
-- ---------------------------------------------------------------------------

create sequence public.order_number_seq;

create table public.orders (
  id uuid primary key default gen_random_uuid(),
  number text not null unique
    default ('NX-' || lpad(nextval('public.order_number_seq')::text, 6, '0')),
  user_id uuid references auth.users (id) on delete set null,
  payment_id uuid not null unique references public.payments (id),
  -- La fase 9 agrega los demás estados y sus transiciones (RN-029).
  status text not null default 'paid' check (status in ('paid')),
  total_cents bigint not null check (total_cents > 0),
  shipping_address jsonb not null,
  contact jsonb not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index orders_user_idx on public.orders (user_id, created_at desc);

-- Una sub-orden por proveedor (S-06): cada uno confirma y despacha lo suyo.
create table public.sub_orders (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders (id),
  provider_id text not null references public.providers (id),
  provider_name text not null,
  -- pending: esperando que el proveedor confirme. La fase 9 agrega el resto.
  status text not null default 'pending' check (status in ('pending')),
  subtotal_cents bigint not null default 0,
  tax_base_cents bigint not null default 0,
  commission_cents bigint not null default 0,
  provider_net_cents bigint not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (order_id, provider_id),
  check (provider_net_cents = subtotal_cents - commission_cents)
);

-- Cada ítem conserva el precio, la cantidad y la comisión del momento de la
-- compra (RN-026, RF-075): base sin IVA, porcentaje, regla, comisión y neto.
create table public.order_items (
  id uuid primary key default gen_random_uuid(),
  sub_order_id uuid not null references public.sub_orders (id),
  offer_id text not null references public.offers (id),
  product_id text not null references public.products (id),
  product_name text not null,
  brand text not null,
  quantity integer not null check (quantity > 0),
  unit_price_cents bigint not null check (unit_price_cents > 0),
  line_total_cents bigint not null,
  vat_rate numeric(5, 4) not null,
  tax_base_cents bigint not null,
  commission_rate numeric(5, 4) not null,
  commission_rule_id uuid references public.commission_rules (id),
  commission_cents bigint not null,
  provider_net_cents bigint not null,
  -- Unidades que ya no había en stock al aprobarse el pago: el proveedor
  -- las resuelve o se reembolsan (fase 9).
  backordered_units integer not null default 0 check (backordered_units between 0 and quantity),
  check (line_total_cents = unit_price_cents * quantity),
  check (provider_net_cents = line_total_cents - commission_cents)
);

create index sub_orders_order_idx on public.sub_orders (order_id);
create index sub_orders_provider_idx on public.sub_orders (provider_id, created_at desc);
create index order_items_sub_order_idx on public.order_items (sub_order_id);

create trigger orders_set_updated_at
  before update on public.orders
  for each row execute function private.set_updated_at();

create trigger sub_orders_set_updated_at
  before update on public.sub_orders
  for each row execute function private.set_updated_at();

-- Los valores no cambian después de creados. Las sub-órdenes se crean en
-- cero y se totalizan en la misma transacción, por eso el UPDATE de montos
-- solo se bloquea cuando ya tenían valor.
create trigger orders_keep_amounts
  before update of total_cents, payment_id on public.orders
  for each row
  when (old.total_cents is distinct from new.total_cents
        or old.payment_id is distinct from new.payment_id)
  execute function private.prevent_change();

create trigger sub_orders_keep_amounts
  before update of subtotal_cents, tax_base_cents, commission_cents, provider_net_cents
  on public.sub_orders
  for each row
  when (old.subtotal_cents <> 0
        and row(old.subtotal_cents, old.tax_base_cents, old.commission_cents, old.provider_net_cents)
            is distinct from
            row(new.subtotal_cents, new.tax_base_cents, new.commission_cents, new.provider_net_cents))
  execute function private.prevent_change();

create trigger order_items_immutable
  before update or delete on public.order_items
  for each row execute function private.prevent_change();

create trigger orders_no_delete
  before delete on public.orders
  for each row execute function private.prevent_change();

create trigger sub_orders_no_delete
  before delete on public.sub_orders
  for each row execute function private.prevent_change();

create trigger orders_audit
  after insert or update or delete on public.orders
  for each row execute function private.audit_row_change();

create trigger sub_orders_audit
  after insert or update or delete on public.sub_orders
  for each row execute function private.audit_row_change();

create trigger order_items_audit
  after insert on public.order_items
  for each row execute function private.audit_row_change();

alter table public.orders enable row level security;
alter table public.sub_orders enable row level security;
alter table public.order_items enable row level security;
revoke all on public.orders, public.sub_orders, public.order_items from anon, authenticated;
revoke all on sequence public.order_number_seq from anon, authenticated;

-- ---------------------------------------------------------------------------
-- Funciones auxiliares
-- ---------------------------------------------------------------------------

-- Estado de un intento de pago para la app. No incluye la comisión: es un
-- dato entre NEXUS y el proveedor.
create function private.checkout_status(p_payment_id uuid) returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'reference', p.reference,
    'status', p.status,
    'amountCents', p.amount_cents,
    'currency', p.currency,
    'transactionId', p.gateway_transaction_id,
    'paymentMethod', p.payment_method_type,
    'message', p.status_message,
    'expiresAt', p.expires_at,
    'order', (
      select jsonb_build_object(
        'id', o.id,
        'number', o.number,
        'status', o.status,
        'totalCents', o.total_cents,
        'createdAt', o.created_at,
        'subOrders', coalesce((
          select jsonb_agg(jsonb_build_object(
              'id', s.id,
              'providerName', s.provider_name,
              'status', s.status,
              'subtotalCents', s.subtotal_cents,
              'items', (
                select jsonb_agg(jsonb_build_object(
                    'productId', i.product_id,
                    'productName', i.product_name,
                    'brand', i.brand,
                    'quantity', i.quantity,
                    'unitPriceCents', i.unit_price_cents,
                    'lineTotalCents', i.line_total_cents,
                    'backorderedUnits', i.backordered_units
                  ) order by i.product_name, i.id)
                from public.order_items i
                where i.sub_order_id = s.id
              )
            ) order by s.provider_name, s.id)
          from public.sub_orders s
          where s.order_id = o.id
        ), '[]'::jsonb)
      )
      from public.orders o
      where o.payment_id = p.id
    )
  )
  from public.payments p
  where p.id = p_payment_id;
$$;

-- Contacto y facturación (RF-056), normalizado. Lanza VALIDATION_ERROR.
create function private.checkout_contact(p_contact jsonb) returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  full_name text := trim(p_contact ->> 'fullName');
  email text := lower(trim(p_contact ->> 'email'));
  phone text := regexp_replace(coalesce(p_contact ->> 'phone', ''), '[\s\-().]', '', 'g');
  document_type text := upper(trim(p_contact ->> 'documentType'));
  document_number text := regexp_replace(coalesce(p_contact ->> 'documentNumber', ''), '[\s.\-]', '', 'g');
begin
  if p_contact is null or jsonb_typeof(p_contact) <> 'object' then
    perform private.raise_api_error(400, 'VALIDATION_ERROR', 'contact debe ser un objeto');
  end if;
  if full_name is null or length(full_name) not between 2 and 120 then
    perform private.raise_api_error(400, 'VALIDATION_ERROR', 'El nombre debe tener de 2 a 120 caracteres');
  end if;
  if email is null or email !~ '^[^\s@]+@[^\s@]+\.[^\s@]+$' then
    perform private.raise_api_error(400, 'VALIDATION_ERROR', 'El correo no es válido');
  end if;
  if phone !~ '^\+?[0-9]{7,15}$' then
    perform private.raise_api_error(400, 'VALIDATION_ERROR', 'El teléfono debe tener de 7 a 15 dígitos');
  end if;
  -- Tipos de documento que acepta Wompi para Colombia.
  if document_type is null or document_type not in ('CC', 'CE', 'NIT', 'PP', 'TI') then
    perform private.raise_api_error(400, 'VALIDATION_ERROR', 'documentType debe ser CC, CE, NIT, PP o TI');
  end if;
  if document_number !~ '^[0-9A-Za-z]{4,20}$' then
    perform private.raise_api_error(400, 'VALIDATION_ERROR', 'El número de documento no es válido');
  end if;
  return jsonb_build_object(
    'fullName', full_name,
    'email', email,
    'phone', phone,
    'documentType', document_type,
    'documentNumber', upper(document_number)
  );
end;
$$;

-- Crea la orden de un pago aprobado: una sub-orden por proveedor, los ítems
-- con su comisión y el descuento de stock. Se llama una sola vez por pago,
-- con la fila del pago bloqueada.
create function private.create_order(p_payment_id uuid) returns uuid
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
begin
  select * into pay from public.payments where id = p_payment_id;

  insert into public.orders (user_id, payment_id, total_cents, shipping_address, contact)
  values (pay.user_id, pay.id, pay.amount_cents, pay.shipping_address, pay.contact)
  returning id into new_order_id;

  for provider in
    select e ->> 'providerId' as id, min(e ->> 'providerName') as name, min(t.ord) as first
    from jsonb_array_elements(pay.items) with ordinality as t(e, ord)
    group by e ->> 'providerId'
    order by first
  loop
    insert into public.sub_orders (order_id, provider_id, provider_name)
    values (new_order_id, provider.id, provider.name)
    returning id into current_sub_order_id;

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

  -- Lo comprado sale del carrito; lo demás se queda.
  delete from public.cart_items c
  where c.user_id = pay.user_id
    and c.offer_id in (select e ->> 'offerId' from jsonb_array_elements(pay.items) e);

  return new_order_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- RPC
-- ---------------------------------------------------------------------------

-- Revalida el carrito guardado y crea un intento de pago (RF-055, RF-056).
-- [expected_total_cents] es el total que vio el cliente: si cambió, se
-- rechaza con PRICE_CHANGED para que lo vea antes de pagar.
create function public.start_checkout(
  address_id uuid,
  contact jsonb,
  expected_total_cents bigint
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := private.require_user();
  normalized_contact jsonb;
  address public.addresses;
  lines jsonb;
  total bigint;
  attempts integer;
  new_payment_id uuid;
begin
  normalized_contact := private.checkout_contact(start_checkout.contact);

  select * into address
  from public.addresses a
  where a.id = start_checkout.address_id and a.user_id = current_user_id;
  if not found then
    perform private.raise_api_error(404, 'ADDRESS_NOT_FOUND', 'No encontramos esa dirección');
  end if;

  select count(*) into attempts
  from public.payments p
  where p.user_id = current_user_id and p.created_at > now() - interval '10 minutes';
  if attempts >= private.numeric_setting('checkout_attempts_per_window', 10) then
    perform private.raise_api_error(429, 'RATE_LIMITED',
      'Hiciste muchos intentos de pago seguidos. Espera unos minutos.');
  end if;

  lines := private.saved_cart(current_user_id) -> 'items';
  if jsonb_array_length(lines) = 0 then
    perform private.raise_api_error(409, 'CART_EMPTY', 'Tu carrito está vacío');
  end if;
  if exists (
    select 1 from jsonb_array_elements(lines) l
    where not (l ->> 'available')::boolean
       or (l ->> 'quantity')::integer > (l ->> 'maxQuantity')::integer
  ) then
    perform private.raise_api_error(409, 'CART_CHANGED',
      'Algunos productos de tu carrito cambiaron de disponibilidad. Revísalo antes de pagar.');
  end if;

  select sum((l ->> 'priceCents')::bigint * (l ->> 'quantity')::integer) into total
  from jsonb_array_elements(lines) l;
  if total is distinct from start_checkout.expected_total_cents then
    raise sqlstate 'PGRST' using
      message = json_build_object(
        'code', 'PRICE_CHANGED',
        'message', 'El total de tu carrito cambió. Revísalo antes de pagar.',
        'details', json_build_object('totalCents', total)::text,
        'hint', null
      )::text,
      detail = json_build_object('status', 409, 'headers', json_build_object())::text;
  end if;

  -- Un intento anterior sin transacción en la pasarela queda abandonado. Si
  -- igual llega a pagarse, se acepta: la pasarela ya cobró (RF-059).
  update public.payments p
  set status = 'abandoned'
  where p.user_id = current_user_id
    and p.status = 'pending'
    and p.gateway_transaction_id is null;

  insert into public.payments (
    reference, user_id, amount_cents, items, shipping_address, contact, expires_at
  ) values (
    'NX-' || to_char(now() at time zone 'America/Bogota', 'YYYYMMDD') || '-'
      || upper(substr(md5(gen_random_uuid()::text), 1, 10)),
    current_user_id,
    total,
    (select jsonb_agg(jsonb_build_object(
        'offerId', l ->> 'offerId',
        'productId', l ->> 'productId',
        'providerId', l ->> 'providerId',
        'providerName', l ->> 'providerName',
        'productName', l ->> 'productName',
        'brand', l ->> 'brand',
        'quantity', (l ->> 'quantity')::integer,
        'unitPriceCents', (l ->> 'priceCents')::bigint
      ) order by ord)
     from jsonb_array_elements(lines) with ordinality as t(l, ord)),
    jsonb_build_object(
      'label', address.label,
      'recipientName', address.recipient_name,
      'phone', address.phone,
      'department', address.department,
      'city', address.city,
      'addressLine', address.address_line,
      'details', address.details
    ),
    normalized_contact,
    now() + make_interval(mins => private.numeric_setting('checkout_expiration_minutes', 60)::integer)
  )
  returning id into new_payment_id;

  return private.checkout_status(new_payment_id) || jsonb_build_object('contact', normalized_contact);
end;
$$;

-- Estado de un intento de pago del usuario, con su orden si ya se aprobó.
create function public.get_checkout_status(reference text) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := private.require_user();
  found_id uuid;
begin
  select p.id into found_id
  from public.payments p
  where p.reference = get_checkout_status.reference and p.user_id = current_user_id;
  if found_id is null then
    perform private.raise_api_error(404, 'PAYMENT_NOT_FOUND', 'No encontramos ese pago');
  end if;
  return private.checkout_status(found_id);
end;
$$;

-- Aplica un resultado de la pasarela (webhook o consulta). Solo la llaman las
-- Edge Functions con el rol de servicio, después de verificar la firma o de
-- consultar la transacción en Wompi. Es idempotente (RNF-020):
-- - un pago aprobado no cambia más y su orden se crea una sola vez;
-- - un aviso repetido o atrasado se registra y no cambia nada;
-- - si el valor o la moneda no coinciden, no se crea la orden (RF-079).
-- Devuelve el estado para la app, o null si la referencia no existe.
create function public.apply_payment_event(
  reference text,
  transaction_id text,
  status text,
  amount_cents bigint,
  currency text,
  payment_method_type text default null,
  source text default 'webhook',
  payload jsonb default null
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  pay public.payments;
  new_status text := case apply_payment_event.status
    when 'PENDING' then 'pending'
    when 'APPROVED' then 'approved'
    when 'DECLINED' then 'declined'
    when 'VOIDED' then 'voided'
    when 'ERROR' then 'error'
  end;
  outcome text;
begin
  if new_status is null then
    perform private.raise_api_error(400, 'VALIDATION_ERROR',
      format('Estado de transacción desconocido: %s', apply_payment_event.status));
  end if;

  select * into pay
  from public.payments p
  where p.reference = apply_payment_event.reference
  for update;

  if not found then
    insert into public.payment_events
      (reference, source, transaction_id, status, amount_cents, currency, outcome, payload)
    values (apply_payment_event.reference, apply_payment_event.source,
      apply_payment_event.transaction_id, apply_payment_event.status,
      apply_payment_event.amount_cents, apply_payment_event.currency,
      'unknown_reference', apply_payment_event.payload);
    return null;
  end if;

  if pay.status = 'approved' then
    outcome := 'duplicate';
  elsif new_status = 'approved'
    and (apply_payment_event.amount_cents is distinct from pay.amount_cents
         or apply_payment_event.currency is distinct from pay.currency) then
    outcome := 'amount_mismatch';
    update public.payments p
    set status = 'error',
        gateway_transaction_id = apply_payment_event.transaction_id,
        status_message = format('La pasarela informó %s %s y se esperaban %s %s',
          apply_payment_event.amount_cents, apply_payment_event.currency,
          pay.amount_cents, pay.currency)
    where p.id = pay.id;
  elsif new_status = 'approved' then
    outcome := 'order_created';
    update public.payments p
    set status = 'approved',
        gateway_transaction_id = apply_payment_event.transaction_id,
        payment_method_type = apply_payment_event.payment_method_type,
        status_message = null,
        approved_at = now()
    where p.id = pay.id;
    perform private.create_order(pay.id);
  elsif new_status = 'pending'
    and pay.status in ('declined', 'voided', 'error')
    and pay.gateway_transaction_id is not distinct from apply_payment_event.transaction_id then
    -- Aviso atrasado de la misma transacción: ya se sabe que terminó.
    outcome := 'stale';
  elsif pay.status = new_status
    and pay.gateway_transaction_id is not distinct from apply_payment_event.transaction_id then
    outcome := 'duplicate';
  else
    -- Pendiente o rechazado. Un rechazo no cierra el intento: el cliente
    -- puede reintentar con otro medio y esa transacción puede aprobarse.
    outcome := 'status_updated';
    update public.payments p
    set status = new_status,
        gateway_transaction_id = apply_payment_event.transaction_id,
        payment_method_type = coalesce(apply_payment_event.payment_method_type, p.payment_method_type),
        status_message = null
    where p.id = pay.id;
  end if;

  insert into public.payment_events
    (payment_id, reference, source, transaction_id, status, amount_cents, currency, outcome, payload)
  values (pay.id, pay.reference, apply_payment_event.source, apply_payment_event.transaction_id,
    apply_payment_event.status, apply_payment_event.amount_cents, apply_payment_event.currency,
    outcome, apply_payment_event.payload);

  return private.checkout_status(pay.id);
end;
$$;

revoke all on function public.start_checkout(uuid, jsonb, bigint) from public;
revoke all on function public.get_checkout_status(text) from public;
revoke all on function public.apply_payment_event(text, text, text, bigint, text, text, text, jsonb)
  from public, anon, authenticated;

grant execute on function public.start_checkout(uuid, jsonb, bigint) to authenticated;
grant execute on function public.get_checkout_status(text) to authenticated;
grant execute on function public.apply_payment_event(text, text, text, bigint, text, text, text, jsonb)
  to service_role;
