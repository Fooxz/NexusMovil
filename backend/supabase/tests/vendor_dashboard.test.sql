-- Panel de la tienda (API_CONTRATO parte 9): pedidos con su flujo de estados,
-- inventario con movimientos, resumen del negocio y aislamiento entre tiendas.
begin;
create extension if not exists pgtap with schema extensions;
select plan(46);

create function pg_temp.login_as(user_id uuid) returns void
language sql as $$
  select set_config('role', 'authenticated', true),
         set_config('request.jwt.claims',
           json_build_object('sub', user_id, 'role', 'authenticated')::text, true);
$$;

-- Código del error de la API (PGRST), o null si no falla.
create function pg_temp.api_error(statement text) returns text
language plpgsql as $$
begin
  execute statement;
  return null;
exception when sqlstate 'PGRST' then
  return sqlerrm::json ->> 'code';
end;
$$;

create temporary table saved (key text primary key, value text);
grant all on saved to authenticated, service_role;
create function pg_temp.saved(k text) returns text
language sql as $$ select value from saved where key = k $$;

-- Dos tiendas con cuenta y un cliente con dirección.
insert into auth.users (id, email, raw_user_meta_data)
select id::uuid, email,
  '{"full_name": "Cuenta ZZ", "accepted_documents": [{"code": "terms", "version": "1.0"}, {"code": "privacy", "version": "1.0"}]}'
from (values
  ('00000000-0000-0000-0000-0000000000a1', 'a.vendor@zz.test'),
  ('00000000-0000-0000-0000-0000000000b1', 'b.vendor@zz.test'),
  ('00000000-0000-0000-0000-0000000000c1', 'cliente.vendor@zz.test')
) as u (id, email);
update public.profiles set role = 'provider', full_name = 'Ana Tienda'
where id = '00000000-0000-0000-0000-0000000000a1';
update public.profiles set role = 'provider' where id = '00000000-0000-0000-0000-0000000000b1';
update public.profiles set full_name = 'Carlos Cliente' where id = '00000000-0000-0000-0000-0000000000c1';

insert into public.providers (id, legal_name, display_name, tax_id, contact_email, status, user_id) values
  ('zz-va', 'ZZ A S.A.S.', 'ZZ Tienda A', 'zz-va', 'a@zz.test', 'active', '00000000-0000-0000-0000-0000000000a1'),
  ('zz-vb', 'ZZ B S.A.S.', 'ZZ Tienda B', 'zz-vb', 'b@zz.test', 'active', '00000000-0000-0000-0000-0000000000b1');
insert into public.products (id, name, brand, category_code) values
  ('zz-vp1', 'ZZTEST GPU', 'Marca', 'gpu'),
  ('zz-vp2', 'ZZTEST RAM', 'Marca', 'ram'),
  ('zz-vp3', 'ZZTEST SSD', 'Marca', 'storage');
insert into public.offers (id, product_id, provider_id, external_sku, price_cents, stock_units, status, min_stock) values
  ('zz-va1', 'zz-vp1', 'zz-va', 'A1', 100000000, 10, 'published', 3),
  ('zz-va2', 'zz-vp2', 'zz-va', 'A2', 30000000, 4, 'published', 5),
  ('zz-vb1', 'zz-vp3', 'zz-vb', 'B1', 20000000, 6, 'published', 2);
insert into public.addresses (user_id, label, recipient_name, phone, department, city, address_line) values
  ('00000000-0000-0000-0000-0000000000c1', 'Casa', 'Carlos Cliente', '3001234567', 'Cesar', 'Valledupar', 'Calle 10 # 20-30');

select is((select count(*) from public.inventory_movements where offer_id like 'zz-v%' and kind = 'entry'), 3::bigint,
  'el stock inicial de cada oferta queda como entrada');

-- El cliente compra a las dos tiendas: A1 x2, A2 x1 y B1 x1.
select pg_temp.login_as('00000000-0000-0000-0000-0000000000c1');
select public.add_cart_item('zz-va1', 2);
select public.add_cart_item('zz-va2', 1);
select public.add_cart_item('zz-vb1', 1);
insert into saved select 'ref', public.start_checkout(
  (select id from public.addresses where user_id = '00000000-0000-0000-0000-0000000000c1'),
  '{"fullName": "Carlos Cliente", "email": "carlos@zz.test", "phone": "3001234567", "documentType": "CC", "documentNumber": "1065000000"}',
  250000000) ->> 'reference';
reset role;
set local role service_role;
select public.apply_payment_event(pg_temp.saved('ref'), 'tx-v1', 'APPROVED', 250000000, 'COP', 'CARD');
reset role;

insert into saved select 'a_order', s.id::text from public.sub_orders s where s.provider_id = 'zz-va';
insert into saved select 'b_order', s.id::text from public.sub_orders s where s.provider_id = 'zz-vb';

select is(
  (select kind || ':' || quantity_delta || ':' || (sub_order_id::text = pg_temp.saved('a_order')) || ':' || (reason like 'Pedido NX-%')
   from public.inventory_movements where offer_id = 'zz-va1' order by id desc limit 1),
  'sale:-2:true:true', 'la venta queda en el historial con el pedido');

-- Pedidos de la tienda A
select pg_temp.login_as('00000000-0000-0000-0000-0000000000a1');
select is((public.get_my_orders() ->> 'total')::int, 1, 'cada tienda ve solo su sub-orden');
select is(pg_temp.api_error(format($$ select public.get_my_order(%L) $$, pg_temp.saved('b_order'))),
  'ORDER_NOT_FOUND', 'no ve pedidos de otra tienda');
insert into saved select 'detail', public.get_my_order(pg_temp.saved('a_order')::uuid)::text;
select is((pg_temp.saved('detail')::jsonb ->> 'status'), 'pending', 'el pedido empieza como nuevo');
select is((pg_temp.saved('detail')::jsonb -> 'nextStatuses'), '["confirmed", "rejected"]'::jsonb,
  'un pedido nuevo se acepta o se rechaza');
select is((pg_temp.saved('detail')::jsonb -> 'shippingAddress' ->> 'city'), 'Valledupar',
  'trae la dirección de entrega');
select is((pg_temp.saved('detail')::jsonb -> 'contact' ->> 'documentNumber'), '1065000000',
  'y el documento del cliente para facturar');
select is(jsonb_array_length(pg_temp.saved('detail')::jsonb -> 'items'), 2, 'con sus ítems');
select is((pg_temp.saved('detail')::jsonb ->> 'netCents')::bigint,
  (pg_temp.saved('detail')::jsonb ->> 'subtotalCents')::bigint - (pg_temp.saved('detail')::jsonb ->> 'commissionCents')::bigint,
  'muestra la comisión y el neto de la tienda');
select is((select (i ->> 'reservedUnits')::int from jsonb_array_elements(public.get_my_inventory() -> 'items') i
           where i ->> 'offerId' = 'zz-va1'), 2, 'lo vendido sin enviar queda reservado');

select is(pg_temp.api_error(format($$ select public.update_my_order_status(%L, 'shipped', null, 'Servientrega', '123') $$,
  pg_temp.saved('a_order'))), 'INVALID_TRANSITION', 'no se salta estados (RN-029)');
select is(public.update_my_order_status(pg_temp.saved('a_order')::uuid, 'confirmed') ->> 'status', 'confirmed',
  'la tienda acepta el pedido');
select is(public.update_my_order_status(pg_temp.saved('a_order')::uuid, 'preparing') ->> 'status', 'preparing',
  'lo prepara');
select is(pg_temp.api_error(format($$ select public.update_my_order_status(%L, 'shipped') $$, pg_temp.saved('a_order'))),
  'VALIDATION_ERROR', 'enviar exige transportadora y guía');
select is(public.update_my_order_status(pg_temp.saved('a_order')::uuid, 'shipped', null, 'Servientrega', 'SV-12345')
  ->> 'trackingNumber', 'SV-12345', 'lo envía con su guía (RF-069)');
select is((select (i ->> 'reservedUnits')::int from jsonb_array_elements(public.get_my_inventory() -> 'items') i
           where i ->> 'offerId' = 'zz-va1'), 0, 'enviado, ya no está reservado');
select is(pg_temp.api_error(format($$ select public.update_my_order_status(%L, 'incident') $$, pg_temp.saved('a_order'))),
  'VALIDATION_ERROR', 'una incidencia exige el motivo');
select is(public.update_my_order_status(pg_temp.saved('a_order')::uuid, 'incident', 'La transportadora no lo encuentra')
  ->> 'status', 'incident', 'reporta la incidencia');
select is(public.update_my_order_status(pg_temp.saved('a_order')::uuid, 'delivered') ->> 'status', 'delivered',
  'y la resuelve con la entrega');
select is(
  (select jsonb_agg(h ->> 'toStatus') from jsonb_array_elements(public.get_my_order(pg_temp.saved('a_order')::uuid) -> 'history') h),
  '["pending", "confirmed", "preparing", "shipped", "incident", "delivered"]'::jsonb,
  'cada cambio queda en el historial');
select is(
  (select h ->> 'actorName' from jsonb_array_elements(public.get_my_order(pg_temp.saved('a_order')::uuid) -> 'history') h
   where h ->> 'toStatus' = 'confirmed'),
  'Ana Tienda', 'con quién lo hizo');

-- La tienda B rechaza su pedido: las unidades vuelven al stock.
select pg_temp.login_as('00000000-0000-0000-0000-0000000000b1');
select is(pg_temp.api_error(format($$ select public.update_my_order_status(%L, 'rejected') $$, pg_temp.saved('b_order'))),
  'VALIDATION_ERROR', 'rechazar exige el motivo');
select is(public.update_my_order_status(pg_temp.saved('b_order')::uuid, 'rejected', 'Sin unidades en bodega')
  ->> 'status', 'rejected', 'la tienda rechaza el pedido');
reset role;
select is((select stock_units from public.offers where id = 'zz-vb1'), 6, 'el stock vuelve a como estaba');
select is((select kind from public.inventory_movements where offer_id = 'zz-vb1' order by id desc limit 1),
  'cancellation', 'y queda la devolución al stock en el historial');
select pg_temp.login_as('00000000-0000-0000-0000-0000000000b1');
select is(public.get_my_dashboard() -> 'sales' ->> 'todayCents', '0', 'un pedido rechazado no cuenta como venta');
select is(public.get_my_dashboard() -> 'orders' ->> 'cancelled', '1', 'pero sí entre los cancelados');

-- Inventario de la tienda A
select pg_temp.login_as('00000000-0000-0000-0000-0000000000a1');
select is(public.get_my_inventory() -> 'counts', '{"all": 2, "low": 1, "out": 0}'::jsonb,
  'cuenta las ofertas con stock bajo (A2: 3 de mínimo 5)');
select is((select i ->> 'alert' from jsonb_array_elements(public.get_my_inventory('low') -> 'items') i), 'low',
  'filtra las de stock bajo');
select is(pg_temp.api_error($$ select public.adjust_my_stock('zz-vp2', 'entry', 5, '') $$), 'VALIDATION_ERROR',
  'un movimiento exige el motivo');
select is(public.adjust_my_stock('zz-vp2', 'entry', 5, 'Llegó un pedido del distribuidor') ->> 'stockUnits', '8',
  'una entrada suma unidades');
select is(pg_temp.api_error($$ select public.adjust_my_stock('zz-vp2', 'exit', 50, 'Muestras') $$), 'VALIDATION_ERROR',
  'no se sacan más unidades de las que hay');
select is(public.adjust_my_stock('zz-vp2', 'adjustment', 7, 'Conteo físico') ->> 'stockUnits', '7',
  'un ajuste deja el stock en el conteo real');
select is(public.set_my_min_stock('zz-vp2', 8) ->> 'alert', 'low', 'el stock mínimo es configurable y cambia la alerta');
select is(pg_temp.api_error($$ select public.adjust_my_stock('zz-vp3', 'entry', 5, 'Ajeno') $$), 'OFFER_NOT_FOUND',
  'no mueve el inventario de otra tienda');
select is(
  (select m ->> 'kind' || ':' || (m ->> 'quantityDelta') || ':' || (m ->> 'reason') || ':' || (m ->> 'actorName')
   from jsonb_array_elements(public.get_my_stock_movements('zz-vp2') -> 'items') m limit 1),
  'adjustment:-1:Conteo físico:Ana Tienda', 'el historial guarda tipo, cantidad, motivo y usuario');
select public.update_my_offer('zz-vp1', '{"priceCents": 100000000, "stockUnits": 12, "status": "published"}');
select is(
  (select m ->> 'reason' from jsonb_array_elements(public.get_my_stock_movements('zz-vp1') -> 'items') m limit 1),
  'Edición de la publicación', 'editar la publicación también deja el movimiento');

-- Resumen de la tienda A
select is(public.get_my_dashboard() -> 'sales' ->> 'todayCents', '230000000', 'ventas del día');
select is(public.get_my_dashboard() -> 'orders' ->> 'delivered', '1', 'pedidos por estado');
select is((public.get_my_dashboard() -> 'finance' ->> 'netCents')::bigint,
  (public.get_my_dashboard() -> 'finance' ->> 'grossCents')::bigint
    - (public.get_my_dashboard() -> 'finance' ->> 'commissionCents')::bigint,
  'ingresos brutos menos la comisión de NEXUS es la ganancia neta');

-- Acceso
select pg_temp.login_as('00000000-0000-0000-0000-0000000000c1');
select is(pg_temp.api_error($$ select public.get_my_dashboard() $$), 'PROVIDER_REQUIRED', 'un cliente no tiene panel');
select throws_ok($$ select * from public.inventory_movements $$, '42501', null, 'los movimientos no se leen directo');
reset role;
select throws_ok($$ delete from public.inventory_movements where offer_id = 'zz-va1' $$, '42501', null,
  'ni se borran');
select throws_ok($$ update public.inventory_movements set quantity_delta = 0 where offer_id = 'zz-va1' $$, '42501', null,
  'ni se modifican');
-- Borrar una cuenta deja sus movimientos y cambios de estado sin autor.
delete from auth.users where id = '00000000-0000-0000-0000-0000000000b1';
select is((select count(*) from public.sub_order_status_history h
           where h.sub_order_id = pg_temp.saved('b_order')::uuid and h.actor_id is null), 2::bigint,
  'se puede borrar la cuenta de una tienda: su historial queda sin autor');

select * from finish();
rollback;
