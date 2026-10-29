-- Consola del administrador (API_CONTRATO parte 10): resumen global,
-- proveedores con su historial disciplinario, moderación posterior del
-- catálogo con alertas de calidad y supervisión de los pedidos.
begin;
create extension if not exists pgtap with schema extensions;
select plan(53);

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

-- Un administrador, dos tiendas con cuenta y un cliente con dirección.
insert into auth.users (id, email, raw_user_meta_data)
select id::uuid, email,
  '{"full_name": "Cuenta ZZ", "accepted_documents": [{"code": "terms", "version": "1.0"}, {"code": "privacy", "version": "1.0"}]}'
from (values
  ('00000000-0000-0000-0000-0000000000d0', 'admin.consola@zz.test'),
  ('00000000-0000-0000-0000-0000000000d1', 'a.consola@zz.test'),
  ('00000000-0000-0000-0000-0000000000d2', 'b.consola@zz.test'),
  ('00000000-0000-0000-0000-0000000000d3', 'cliente.consola@zz.test')
) as u (id, email);
update public.profiles set role = 'admin', full_name = 'Ada Admin' where id = '00000000-0000-0000-0000-0000000000d0';
update public.profiles set role = 'provider' where id in
  ('00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000d2');

insert into public.providers (id, legal_name, display_name, tax_id, contact_email, status, user_id) values
  ('zz-ca', 'ZZADM A S.A.S.', 'ZZADM Tienda A', 'zz-ca', 'a@zz.test', 'active', '00000000-0000-0000-0000-0000000000d1'),
  ('zz-cb', 'ZZADM B S.A.S.', 'ZZADM Tienda B', 'zz-cb', 'b@zz.test', 'active', '00000000-0000-0000-0000-0000000000d2');
-- p1: sin atributos. p2 y p3: el mismo nombre en la misma
-- categoría (duplicado). p4: completo y con dos precios (uno anómalo).
insert into public.products (id, name, brand, category_code) values
  ('zz-cp1', 'ZZADM SSD Incompleto', 'Marca', 'storage'),
  ('zz-cp2', 'ZZADM RAM Doble', 'Marca', 'ram'),
  ('zz-cp3', 'ZZADM  ram doble', 'Otra', 'ram'),
  ('zz-cp4', 'ZZADM SSD Completo', 'Marca', 'storage');
insert into public.product_attributes (product_id, attribute_id, value_text)
select 'zz-cp4', d.id, case d.key when 'storage_type' then 'NVMe' else 'PCIe4' end
from public.attribute_definitions d
where d.category_code = 'storage' and d.key in ('storage_type', 'interface');
insert into public.product_attributes (product_id, attribute_id, value_number)
select 'zz-cp4', d.id, 1000 from public.attribute_definitions d
where d.category_code = 'storage' and d.key = 'capacity_gb';
insert into public.offers (id, product_id, provider_id, external_sku, price_cents, stock_units, status) values
  ('zz-ca1', 'zz-cp1', 'zz-ca', 'A1', 30000000, 10, 'published'),
  ('zz-ca2', 'zz-cp2', 'zz-ca', 'A2', 20000000, 5, 'published'),
  ('zz-ca4', 'zz-cp4', 'zz-ca', 'A4', 10000000, 8, 'published'),
  ('zz-cb3', 'zz-cp3', 'zz-cb', 'B3', 20000000, 5, 'published'),
  ('zz-cb4', 'zz-cp4', 'zz-cb', 'B4', 40000000, 8, 'published');
insert into public.addresses (user_id, label, recipient_name, phone, department, city, address_line) values
  ('00000000-0000-0000-0000-0000000000d3', 'Casa', 'Clara Cliente', '3001234567', 'Cesar', 'Valledupar', 'Calle 10 # 20-30');

-- El cliente compra a las dos tiendas: A1 x2 y B3 x1.
select pg_temp.login_as('00000000-0000-0000-0000-0000000000d3');
select public.add_cart_item('zz-ca1', 2);
select public.add_cart_item('zz-cb3', 1);
insert into saved select 'ref', public.start_checkout(
  (select id from public.addresses where user_id = '00000000-0000-0000-0000-0000000000d3'),
  '{"fullName": "Clara Cliente", "email": "clara@zz.test", "phone": "3001234567", "documentType": "CC", "documentNumber": "1065000001"}',
  80000000) ->> 'reference';
reset role;
set local role service_role;
select public.apply_payment_event(pg_temp.saved('ref'), 'tx-c1', 'APPROVED', 80000000, 'COP', 'CARD');
reset role;
insert into saved select 'order', o.id::text from public.orders o
  join public.payments p on p.id = o.payment_id where p.reference = pg_temp.saved('ref');
insert into saved select 'number', o.number from public.orders o where o.id = pg_temp.saved('order')::uuid;
insert into saved select 'a_sub', s.id::text from public.sub_orders s where s.provider_id = 'zz-ca';
insert into saved select 'b_sub', s.id::text from public.sub_orders s where s.provider_id = 'zz-cb';

-- Solo el administrador
select pg_temp.login_as('00000000-0000-0000-0000-0000000000d3');
select is(pg_temp.api_error($$ select public.admin_get_dashboard() $$), 'FORBIDDEN',
  'un cliente no ve el resumen global');
select is(pg_temp.api_error($$ select public.admin_list_orders() $$), 'FORBIDDEN',
  'ni los pedidos de todos');
select pg_temp.login_as('00000000-0000-0000-0000-0000000000d1');
select is(pg_temp.api_error($$ select public.admin_list_offers() $$), 'FORBIDDEN',
  'ni una tienda modera el catálogo');

-- Resumen global
select pg_temp.login_as('00000000-0000-0000-0000-0000000000d0');
insert into saved select 'dash', public.admin_get_dashboard()::text;
select ok((pg_temp.saved('dash')::jsonb -> 'sales' ->> 'todayCents')::bigint >= 80000000,
  'las ventas de hoy incluyen el pedido');
select ok((pg_temp.saved('dash')::jsonb -> 'sales' ->> 'monthCommissionCents')::bigint > 0,
  'y la comisión de NEXUS del mes');
select ok((pg_temp.saved('dash')::jsonb -> 'orders' ->> 'pending')::int >= 2, 'cuenta los pedidos nuevos');
select is(jsonb_array_length(pg_temp.saved('dash')::jsonb -> 'series'), 30, 'la serie diaria cubre 30 días');
select ok((select (d ->> 'salesCents')::bigint from jsonb_array_elements(pg_temp.saved('dash')::jsonb -> 'series') d
           order by d ->> 'date' desc limit 1) >= 80000000, 'el último día de la serie es hoy');
select ok((pg_temp.saved('dash')::jsonb -> 'catalog' ->> 'flagged')::int >= 4, 'cuenta las ofertas con alertas');
select ok((pg_temp.saved('dash')::jsonb -> 'users' -> 'providers' ->> 'active')::int >= 2,
  'y las tiendas por estado');

-- Alertas de calidad
select is(public.admin_get_offer('zz-ca1') -> 'flags', '["incomplete"]'::jsonb, 'sin atributos obligatorios');
select is(public.admin_get_offer('zz-ca2') -> 'flags', '["incomplete", "duplicate"]'::jsonb,
  'mismo nombre en la misma categoría: posible duplicado');
select is(public.admin_get_offer('zz-ca4') -> 'flags', '["price_anomaly"]'::jsonb,
  'menos de la mitad de la mediana del producto: precio anómalo');
select is(public.admin_get_offer('zz-cb4') -> 'flags', '[]'::jsonb, 'una oferta sana no tiene alertas');
select is(jsonb_array_length(public.admin_get_offer('zz-ca4') -> 'otherOffers'), 1,
  'el detalle muestra las otras tiendas del producto');
select is((public.admin_list_offers(search => 'zzadm') ->> 'total')::int, 5, 'busca por nombre');
select is((public.admin_list_offers(search => 'zzadm', flag => 'any') ->> 'total')::int, 4,
  'filtra las que tienen alguna alerta');
select is((public.admin_list_offers(search => 'zzadm', provider => 'zz-cb') ->> 'total')::int, 2,
  'filtra por tienda');
select is(pg_temp.api_error($$ select public.admin_list_offers(flag => 'otra') $$), 'VALIDATION_ERROR',
  'rechaza un filtro desconocido');

-- Moderación posterior
select is(pg_temp.api_error($$ select public.admin_moderate_offer('zz-ca1', 'hide') $$), 'VALIDATION_ERROR',
  'ocultar exige el motivo');
select is(public.admin_moderate_offer('zz-ca1', 'hide', 'Completa la ficha técnica y agrega fotos')
  ->> 'moderationStatus', 'hidden', 'el administrador oculta la oferta');
select is(pg_temp.api_error($$ select public.get_product('zz-cp1') $$), 'PRODUCT_NOT_FOUND',
  'una oferta oculta sale del catálogo');
select pg_temp.login_as('00000000-0000-0000-0000-0000000000d1');
select is((select o ->> 'moderationReason' from jsonb_array_elements(public.get_my_offers() -> 'items') o
           where o ->> 'offerId' = 'zz-ca1'), 'Completa la ficha técnica y agrega fotos',
  'la tienda ve el motivo');
select is((select (o ->> 'visible')::boolean from jsonb_array_elements(public.get_my_offers() -> 'items') o
           where o ->> 'offerId' = 'zz-ca1'), false, 'y que no está visible');
select is(public.request_my_offer_review('zz-cp1') ->> 'moderationStatus', 'review',
  'al corregirla pide la revisión');
select is(pg_temp.api_error($$ select public.request_my_offer_review('zz-cp1') $$), 'NOT_HIDDEN',
  'una sola vez');
select pg_temp.login_as('00000000-0000-0000-0000-0000000000d0');
select is((public.admin_list_offers(moderation => 'review', search => 'zzadm') -> 'items' -> 0 ->> 'offerId'), 'zz-ca1',
  'el administrador la encuentra entre las que piden revisión');
select is(public.admin_moderate_offer('zz-ca1', 'approve') ->> 'moderationReason', null,
  'al aprobarla se borra el motivo');
select ok(public.get_product('zz-cp1') is not null, 'y vuelve al catálogo');
select is(public.admin_moderate_offer('zz-cb3', 'reject', 'Producto falsificado') ->> 'moderationStatus', 'rejected',
  'rechaza una oferta');
select pg_temp.login_as('00000000-0000-0000-0000-0000000000d2');
select is(pg_temp.api_error($$ select public.request_my_offer_review('zz-cp3') $$), 'NOT_HIDDEN',
  'una oferta rechazada no se puede volver a pedir');

-- Corrección de la ficha
select pg_temp.login_as('00000000-0000-0000-0000-0000000000d0');
select is(pg_temp.api_error($$ select public.admin_update_product('zz-cp1',
  '{"category": "storage", "name": "ZZADM SSD Corregido", "brand": "Marca", "model": "ZZ-1", "attributes": {"capacity_gb": 500}}') $$),
  'VALIDATION_ERROR', 'la ficha corregida respeta la plantilla');
select is(jsonb_array_length(public.admin_update_product('zz-cp1',
  '{"category": "storage", "name": "ZZADM SSD Corregido", "brand": "Marca", "model": "ZZ-1",
    "attributes": {"storage_type": "SATA_SSD", "capacity_gb": 500, "interface": "SATA"},
    "specs": [{"label": "CAPACIDAD", "value": "500 GB"}], "quickSpecs": ["500 GB"]}') -> 'offers'), 1,
  'el administrador corrige la ficha');
select is(public.admin_get_offer('zz-ca1') -> 'flags', '[]'::jsonb, 'ya no está incompleta');
reset role;
select is((select name || '|' || model || '|' || coalesce(quick_specs[1], '-') from public.products where id = 'zz-cp1'),
  'ZZADM SSD Corregido|ZZ-1|500 GB', 'con sus datos y la ficha para mostrar');
select pg_temp.login_as('00000000-0000-0000-0000-0000000000d0');

-- Proveedores
select is((select jsonb_agg(p ->> 'id') from jsonb_array_elements(public.admin_list_providers('zzadm', sort => 'sales')) p),
  '["zz-ca", "zz-cb"]'::jsonb, 'lista las tiendas por ventas');
select is((select (p -> 'metrics' ->> 'openOrders')::int from jsonb_array_elements(public.admin_list_providers('zzadm')) p
           where p ->> 'id' = 'zz-ca'), 1, 'con sus métricas');
select is(pg_temp.api_error($$ select public.admin_set_provider_status('zz-cb', 'blocked') $$), 'VALIDATION_ERROR',
  'bloquear exige el motivo');
select is(public.admin_set_provider_status('zz-cb', 'blocked', 'Vende productos falsificados') ->> 'status', 'blocked',
  'bloquea una tienda');
select is(pg_temp.api_error($$ select public.admin_set_provider_status('zz-cb', 'blocked', 'Otra vez') $$), 'SAME_STATUS',
  'no repite el estado');
select pg_temp.login_as('00000000-0000-0000-0000-0000000000d2');
select is(pg_temp.api_error($$ select public.get_my_offers() $$), 'PROVIDER_NOT_ACTIVE', 'una tienda bloqueada no opera');
select pg_temp.login_as('00000000-0000-0000-0000-0000000000d0');
select is((public.admin_add_provider_note('zz-cb', 'warning', 'Tercer reclamo por demoras') -> 'metrics' ->> 'warnings')::int, 1,
  'registra una advertencia');
select is((select jsonb_agg(n ->> 'kind') from jsonb_array_elements(public.admin_get_provider_overview('zz-cb') -> 'notes') n),
  '["warning", "status_change"]'::jsonb, 'el historial muestra la advertencia y el bloqueo');
select is((select n ->> 'actorName' || '|' || (n ->> 'toStatus') from jsonb_array_elements(public.admin_get_provider_overview('zz-cb') -> 'notes') n
           where n ->> 'kind' = 'status_change'), 'Ada Admin|blocked', 'con quién lo hizo');
reset role;
select throws_ok($$ update public.provider_admin_notes set message = 'otro' where provider_id = 'zz-cb' $$,
  null, 'el historial no se modifica');

-- Pedidos
select pg_temp.login_as('00000000-0000-0000-0000-0000000000d0');
select is((public.admin_list_orders(search => pg_temp.saved('number')) ->> 'total')::int, 2,
  'busca por número: una fila por tienda');
insert into saved select 'detail', public.admin_get_order(pg_temp.saved('order')::uuid)::text;
select is(pg_temp.saved('detail')::jsonb -> 'payment' ->> 'method', 'CARD', 'el detalle muestra el pago');
select is(jsonb_array_length(pg_temp.saved('detail')::jsonb -> 'subOrders'), 2, 'y cada sub-orden');
select is(pg_temp.api_error(format($$ select public.admin_update_sub_order_status(%L, 'cancelled', '') $$,
  pg_temp.saved('a_sub'))), 'VALIDATION_ERROR', 'intervenir exige la observación');
select is((select s ->> 'status' from jsonb_array_elements(
  public.admin_update_sub_order_status(pg_temp.saved('a_sub')::uuid, 'cancelled', 'El cliente pidió cancelar por soporte')
  -> 'subOrders') s where s ->> 'id' = pg_temp.saved('a_sub')), 'cancelled', 'el administrador cancela una sub-orden');
reset role;
select is((select stock_units from public.offers where id = 'zz-ca1'), 10, 'las unidades vuelven al stock');
select is((select note from public.sub_order_status_history where sub_order_id = pg_temp.saved('a_sub')::uuid
           order by id desc limit 1), 'NEXUS: El cliente pidió cancelar por soporte',
  'el historial dice que intervino NEXUS');
select pg_temp.login_as('00000000-0000-0000-0000-0000000000d0');
select is(jsonb_array_length(public.admin_add_order_note(pg_temp.saved('order')::uuid,
  'Cliente contactado por WhatsApp') -> 'notes'), 1, 'agrega una observación al pedido');

select * from finish();
rollback;
