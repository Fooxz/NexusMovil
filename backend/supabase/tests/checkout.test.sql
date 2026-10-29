-- Checkout, pagos y comisión (API_CONTRATO parte 5): revalidación, intentos
-- de pago, idempotencia del resultado de la pasarela, orden por proveedor,
-- comisión, stock e inmutabilidad.
begin;
create extension if not exists pgtap with schema extensions;
select plan(42);

create function pg_temp.login_as(user_id uuid) returns void
language sql as $$
  select set_config('role', 'authenticated', true),
         set_config('request.jwt.claims',
           json_build_object('sub', user_id, 'role', 'authenticated')::text, true);
$$;

-- Código del error de la API (PGRST) que lanza [statement], o null.
create function pg_temp.api_error(statement text) returns text
language plpgsql as $$
begin
  execute statement;
  return null;
exception when sqlstate 'PGRST' then
  return sqlerrm::json ->> 'code';
end;
$$;

create function pg_temp.payment(ref text) returns public.payments
language sql as $$ select * from public.payments where reference = ref $$;

-- Proveedor A con regla general del 8 % y una del 5 % para zz-p1; el
-- proveedor B no tiene reglas (usa la general del 10 %). Precios con IVA.
insert into public.providers (id, legal_name, display_name, tax_id, contact_email, status) values
  ('zz-a', 'A S.A.S.', 'Proveedor A', 'zz-a', 'a@zz.test', 'active'),
  ('zz-b', 'B S.A.S.', 'Proveedor B', 'zz-b', 'b@zz.test', 'active');
insert into public.products (id, name, brand, category_code) values
  ('zz-p1', 'ZZTEST GPU', 'Marca', 'gpu'),
  ('zz-p2', 'ZZTEST RAM', 'Marca', 'ram'),
  ('zz-p3', 'ZZTEST SSD', 'Marca', 'storage');
insert into public.offers (id, product_id, provider_id, external_sku, price_cents, stock_units, status) values
  ('zz-a1', 'zz-p1', 'zz-a', 'A1', 119000000, 5, 'published'),
  ('zz-a2', 'zz-p2', 'zz-a', 'A2', 59500000, 4, 'published'),
  ('zz-b1', 'zz-p3', 'zz-b', 'B1', 11900000, 1, 'published');
insert into public.commission_rules (provider_id, product_id, rate, valid_from) values
  ('zz-a', null, 0.08, now() - interval '1 day'),
  ('zz-a', 'zz-p1', 0.05, now() - interval '1 day'),
  -- Vencida: no debe aplicarse.
  ('zz-a', 'zz-p2', 0.20, now() - interval '30 days');
update public.commission_rules set valid_to = now() - interval '10 days'
where provider_id = 'zz-a' and product_id = 'zz-p2';

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000d1', 'ana.checkout@zz.test',
   '{"full_name": "Ana", "accepted_documents": [{"code": "terms", "version": "1.0"}, {"code": "privacy", "version": "1.0"}]}'),
  ('00000000-0000-0000-0000-0000000000d2', 'beto.checkout@zz.test',
   '{"full_name": "Beto", "accepted_documents": [{"code": "terms", "version": "1.0"}, {"code": "privacy", "version": "1.0"}]}');
insert into public.addresses (id, user_id, label, recipient_name, phone, department, city, address_line) values
  ('00000000-0000-0000-0000-00000000ad01', '00000000-0000-0000-0000-0000000000d1',
   'Casa', 'Ana Pérez', '3001234567', 'Cesar', 'Valledupar', 'Calle 10 # 20-30'),
  ('00000000-0000-0000-0000-00000000ad02', '00000000-0000-0000-0000-0000000000d2',
   'Casa', 'Beto Ruiz', '3007654321', 'Antioquia', 'Medellín', 'Carrera 1 # 2-3');

create temp table t (key text primary key, value text);
grant all on t to authenticated, service_role;

-- Reglas de comisión
select throws_ok($$ insert into public.commission_rules (provider_id, rate) values ('zz-b', 0.5) $$,
  '23514', null, 'la comisión no supera el máximo permitido (RN-024)');
select throws_ok($$ insert into public.commission_rules (provider_id, product_id, rate) values ('zz-a', 'zz-p1', 0.06) $$,
  '23P01', null, 'no hay dos reglas vigentes para el mismo proveedor y producto');

-- Sin sesión
set local role anon;
select is(pg_temp.api_error($$ select public.start_checkout(null, '{}', 0) $$), 'AUTH_REQUIRED',
  'sin sesión no se puede pagar (RN-027)');
select throws_ok($$ select * from public.payments $$, '42501', null, 'los pagos no se leen directo');
reset role;

-- Ana arma su carrito
select pg_temp.login_as('00000000-0000-0000-0000-0000000000d1');
select public.add_cart_item('zz-a1', 2);
select public.add_cart_item('zz-a2', 1);
select public.add_cart_item('zz-b1', 1);

insert into t values ('contact', '{"fullName": " Ana Pérez ", "email": "Ana@Correo.co", "phone": "300 123 4567",
  "documentType": "cc", "documentNumber": "1.065.123.456"}');

select is(pg_temp.api_error($$ select public.start_checkout('00000000-0000-0000-0000-00000000ad01',
    '{"fullName": "Ana", "email": "no-es-correo", "phone": "3001234567", "documentType": "CC", "documentNumber": "123456"}', 309400000) $$),
  'VALIDATION_ERROR', 'valida el contacto (RF-056)');
select is(pg_temp.api_error(format($$ select public.start_checkout('00000000-0000-0000-0000-00000000ad01', %L, 309400000) $$,
    '{"fullName": "Ana", "email": "a@b.co", "phone": "3001234567", "documentType": "XX", "documentNumber": "123456"}')),
  'VALIDATION_ERROR', 'valida el tipo de documento');
select is(pg_temp.api_error(format($$ select public.start_checkout('00000000-0000-0000-0000-00000000ad02', %L, 309400000) $$,
    (select value from t where key = 'contact'))),
  'ADDRESS_NOT_FOUND', 'no usa direcciones de otro usuario');
select is(pg_temp.api_error(format($$ select public.start_checkout('00000000-0000-0000-0000-00000000ad01', %L, 309300000) $$,
    (select value from t where key = 'contact'))),
  'PRICE_CHANGED', 'si el total cambió, avisa antes de pagar (RF-055)');

-- Una línea con más unidades que el stock bloquea el pago.
reset role;
update public.offers set stock_units = 0 where id = 'zz-a2';
select pg_temp.login_as('00000000-0000-0000-0000-0000000000d1');
select is(pg_temp.api_error(format($$ select public.start_checkout('00000000-0000-0000-0000-00000000ad01', %L, 309400000) $$,
    (select value from t where key = 'contact'))),
  'CART_CHANGED', 'revalida el stock antes de pagar (RF-055, RN-017)');
reset role;
update public.offers set stock_units = 4 where id = 'zz-a2';
select pg_temp.login_as('00000000-0000-0000-0000-0000000000d1');

-- Primer intento: queda pendiente con la foto del carrito.
insert into t select 'first', public.start_checkout('00000000-0000-0000-0000-00000000ad01',
  (select value::jsonb from t where key = 'contact'), 309400000) ->> 'reference';
select matches((select value from t where key = 'first'), '^NX-[0-9]{8}-[0-9A-F]{10}$',
  'la referencia tiene el formato NX-fecha-código');
select is(public.get_checkout_status((select value from t where key = 'first')) ->> 'status', 'pending',
  'el intento empieza pendiente');

-- Segundo intento: el primero queda abandonado.
insert into t select 'second', public.start_checkout('00000000-0000-0000-0000-00000000ad01',
  (select value::jsonb from t where key = 'contact'), 309400000)::text;
select is((select value::jsonb from t where key = 'second') -> 'contact',
  '{"fullName": "Ana Pérez", "email": "ana@correo.co", "phone": "3001234567",
    "documentType": "CC", "documentNumber": "1065123456"}'::jsonb,
  'normaliza el contacto');
update t set value = value::jsonb ->> 'reference' where key = 'second';
select is(public.get_checkout_status((select value from t where key = 'first')) ->> 'status', 'abandoned',
  'un intento nuevo abandona el anterior sin transacción');
select is(public.get_checkout_status((select value from t where key = 'second')) ->> 'amountCents',
  '309400000', 'el valor es el total del carrito');
select is(jsonb_array_length(public.get_cart() -> 'items'), 3, 'el carrito sigue igual hasta que se pague');

-- Otro usuario no ve el pago de Ana.
select pg_temp.login_as('00000000-0000-0000-0000-0000000000d2');
select is(pg_temp.api_error(format($$ select public.get_checkout_status(%L) $$, (select value from t where key = 'second'))),
  'PAYMENT_NOT_FOUND', 'no consulta pagos ajenos');
select throws_ok(format($$ select public.apply_payment_event(%L, 'tx', 'APPROVED', 309400000, 'COP') $$,
    (select value from t where key = 'second')),
  '42501', null, 'la app no puede aplicar resultados de la pasarela');
reset role;

-- La pasarela informa (rol de servicio, como las Edge Functions)
set local role service_role;

select is(public.apply_payment_event('NX-20990101-0000000000', 'tx-0', 'APPROVED', 100, 'COP'), null,
  'una referencia desconocida no hace nada');

select is(public.apply_payment_event((select value from t where key = 'second'), 'tx-1', 'DECLINED', 309400000, 'COP', 'CARD')
  ->> 'status', 'declined', 'un rechazo queda registrado sin orden (RF-059)');
select is(public.apply_payment_event((select value from t where key = 'second'), 'tx-1', 'PENDING', 309400000, 'COP')
  ->> 'status', 'declined', 'un aviso atrasado de la misma transacción no cambia el estado');

select is(public.apply_payment_event((select value from t where key = 'second'), 'tx-2', 'APPROVED', 309300000, 'COP', 'CARD')
  ->> 'status', 'error', 'si el valor no coincide, no se crea la orden');
select is((select count(*) from public.orders o join public.payments p on p.id = o.payment_id
           where p.reference = (select value from t where key = 'second')), 0::bigint,
  'sin orden por la diferencia de valor');

-- Antes de aprobar, otra compra se lleva la única unidad de zz-b1.
reset role;
update public.offers set stock_units = 0 where id = 'zz-b1';
set local role service_role;

select matches(public.apply_payment_event((select value from t where key = 'second'), 'tx-3', 'APPROVED', 309400000, 'COP', 'NEQUI')
  -> 'order' ->> 'number', '^NX-[0-9]{6}$', 'el pago aprobado crea la orden y la devuelve (RN-025)');
select is(public.apply_payment_event((select value from t where key = 'second'), 'tx-3', 'APPROVED', 309400000, 'COP', 'NEQUI')
  ->> 'status', 'approved', 'el aviso repetido responde igual');
reset role;

select is((select count(*) from public.orders o join public.payments p on p.id = o.payment_id
           where p.reference = (select value from t where key = 'second')), 1::bigint,
  'una sola orden aunque el aviso llegue dos veces (RNF-020)');
select is((select array_agg(outcome order by id) from public.payment_events
           where reference = (select value from t where key = 'second')),
  array['status_updated', 'stale', 'amount_mismatch', 'order_created', 'duplicate'],
  'cada aviso queda en payment_events con lo que se hizo');
select is((select (p).status || '/' || (p).gateway_transaction_id || '/' || (p).payment_method_type
           from (select pg_temp.payment((select value from t where key = 'second')) as p) s),
  'approved/tx-3/NEQUI', 'el pago guarda la transacción y el medio (RF-058)');
select is((select (p).gateway from (select pg_temp.payment((select value from t where key = 'second')) as p) s),
  'mercadopago', 'la pasarela es Mercado Pago');

-- Orden: una sub-orden por proveedor, con sus montos (RF-061, RF-074).
select is(
  (select jsonb_agg(jsonb_build_array(s.provider_id, s.subtotal_cents, s.tax_base_cents,
                                      s.commission_cents, s.provider_net_cents) order by s.provider_id)
   from public.sub_orders s join public.orders o on o.id = s.order_id
   join public.payments p on p.id = o.payment_id
   where p.reference = (select value from t where key = 'second')),
  '[["zz-a", 297500000, 250000000, 14000000, 283500000],
    ["zz-b", 11900000, 10000000, 1000000, 10900000]]'::jsonb,
  'una sub-orden por proveedor con base sin IVA, comisión y neto');
select is(
  (select jsonb_agg(jsonb_build_array(i.offer_id, i.quantity, i.tax_base_cents, i.commission_rate,
                                      i.commission_cents, i.commission_rule_id is not null) order by i.offer_id)
   from public.order_items i join public.sub_orders s on s.id = i.sub_order_id
   where s.provider_id in ('zz-a', 'zz-b')),
  '[["zz-a1", 2, 200000000, 0.05, 10000000, true],
    ["zz-a2", 1, 50000000, 0.08, 4000000, true],
    ["zz-b1", 1, 10000000, 0.10, 1000000, false]]'::jsonb,
  'prevalece la regla del producto, luego la del proveedor y luego la general (S-05)');
select is((select sum(total_cents) from public.orders o join public.payments p on p.id = o.payment_id
           where p.reference = (select value from t where key = 'second')), 309400000::numeric,
  'el cliente paga el precio publicado: la comisión no se suma (RN-002)');

-- Stock y carrito
select is((select jsonb_object_agg(id, stock_units) from public.offers where id like 'zz-%'),
  '{"zz-a1": 3, "zz-a2": 3, "zz-b1": 0}'::jsonb, 'descuenta el stock vendido (RF-066)');
select is((select backordered_units from public.order_items where offer_id = 'zz-b1'), 1,
  'registra las unidades que ya no había al aprobarse el pago');
select is((select count(*) from public.cart_items where user_id = '00000000-0000-0000-0000-0000000000d1'),
  0::bigint, 'lo comprado sale del carrito');

-- Un intento abandonado que igual se paga crea su orden: la pasarela cobró.
set local role service_role;
select is(public.apply_payment_event((select value from t where key = 'first'), 'tx-9', 'APPROVED', 309400000, 'COP')
  ->> 'status', 'approved', 'un intento abandonado que se paga se acepta');
reset role;
select is((select count(*) from public.orders where user_id = '00000000-0000-0000-0000-0000000000d1'), 2::bigint,
  'y genera su propia orden');

-- Inmutabilidad (RN-026)
select throws_ok($$ update public.order_items set quantity = 9 where offer_id = 'zz-a1' $$,
  '42501', null, 'los ítems de una orden no cambian');
select throws_ok($$ update public.sub_orders set commission_cents = 0 where provider_id = 'zz-a' $$,
  '42501', null, 'los montos de una sub-orden no cambian');
select throws_ok($$ delete from public.orders where user_id = '00000000-0000-0000-0000-0000000000d1' $$,
  '42501', null, 'las órdenes no se borran');
select throws_ok($$ delete from public.payment_events $$, '42501', null, 'la bitácora de pagos no se borra');
select ok((select count(*) from public.audit_log where table_name = 'order_items') >= 4,
  'los ítems quedan en la auditoría (RF-081)');

-- La orden conserva la comisión aunque la regla cambie después (HU-026).
update public.commission_rules set valid_to = now() + interval '1 second'
where provider_id = 'zz-a' and product_id = 'zz-p1';
select is((select commission_cents from public.order_items where offer_id = 'zz-a1' order by id limit 1),
  10000000::bigint, 'cambiar la regla no altera órdenes anteriores');

select * from finish();
rollback;
