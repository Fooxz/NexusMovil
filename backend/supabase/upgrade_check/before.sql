-- Prueba de migración, paso 1 de 2: datos y foto del estado anterior.
-- Procedimiento completo en upgrade_check/README.md. Solo para la base local.
--
-- Simula lo que ya existe en la nube antes de los roles: clientes registrados
-- con sus consentimientos, direcciones, un carrito abierto y una compra pagada
-- (por el flujo real: carrito, start_checkout y apply_payment_event). Después
-- guarda la foto (conteos, sumas de verificación y respuestas de las RPC) que
-- after.sql compara con la base ya migrada.

create schema upgrade_check;

create table upgrade_check.snapshot (
  key text primary key,
  value jsonb not null
);

-- Foto del estado. Solo usa columnas que existían antes de los roles, para
-- poder repetirla después de migrar.
create function upgrade_check.capture() returns table (key text, value jsonb)
language plpgsql
as $$
declare
  buyer constant uuid := '00000000-0000-0000-0000-00000000e001';
  shopper constant uuid := '00000000-0000-0000-0000-00000000e002';
  ref text := (select p.reference from public.payments p where p.user_id = buyer order by p.created_at limit 1);
begin
  return query
  select 'count:' || t.name, to_jsonb(t.n)
  from (values
    ('auth.users', (select count(*) from auth.users)),
    ('providers', (select count(*) from public.providers)),
    ('products', (select count(*) from public.products)),
    ('offers', (select count(*) from public.offers)),
    ('product_attributes', (select count(*) from public.product_attributes)),
    ('product_images', (select count(*) from public.product_images)),
    ('component_models', (select count(*) from public.component_models)),
    ('profiles', (select count(*) from public.profiles)),
    ('user_consents', (select count(*) from public.user_consents)),
    ('addresses', (select count(*) from public.addresses)),
    ('cart_items', (select count(*) from public.cart_items)),
    ('payments', (select count(*) from public.payments)),
    ('payment_events', (select count(*) from public.payment_events)),
    ('orders', (select count(*) from public.orders)),
    ('sub_orders', (select count(*) from public.sub_orders)),
    ('order_items', (select count(*) from public.order_items)),
    ('commission_rules', (select count(*) from public.commission_rules))
  ) as t(name, n);

  -- Sumas de verificación. Las tablas que reciben columnas nuevas se comparan
  -- con sus columnas originales.
  return query select 'rows:providers', to_jsonb(md5(coalesce(string_agg(
    concat_ws('|', pr.id, pr.legal_name, pr.display_name, pr.tax_id, pr.contact_email,
      pr.status, pr.created_at, pr.updated_at), '||' order by pr.id), '')))
  from public.providers pr;
  return query select 'rows:products', to_jsonb(md5(coalesce(string_agg(
    concat_ws('|', p.id, p.name, p.brand, p.model, p.category_code, p.summary,
      p.quick_specs::text, p.specs::text, p.created_at, p.updated_at), '||' order by p.id), '')))
  from public.products p;
  return query select 'rows:profiles', to_jsonb(md5(coalesce(string_agg(
    concat_ws('|', p.id, p.full_name, p.phone, p.created_at, p.updated_at), '||' order by p.id), '')))
  from public.profiles p;
  return query select 'rows:offers', to_jsonb(md5(coalesce(string_agg(
    row_to_json(o)::text, '||' order by o.id), ''))) from public.offers o;
  return query select 'rows:product_attributes', to_jsonb(md5(coalesce(string_agg(
    row_to_json(a)::text, '||' order by a.product_id, a.attribute_id), ''))) from public.product_attributes a;
  return query select 'rows:product_images', to_jsonb(md5(coalesce(string_agg(
    row_to_json(i)::text, '||' order by i.id), ''))) from public.product_images i;
  return query select 'rows:user_consents', to_jsonb(md5(coalesce(string_agg(
    row_to_json(c)::text, '||' order by c.id), ''))) from public.user_consents c;
  return query select 'rows:addresses', to_jsonb(md5(coalesce(string_agg(
    row_to_json(a)::text, '||' order by a.id), ''))) from public.addresses a;
  return query select 'rows:cart_items', to_jsonb(md5(coalesce(string_agg(
    row_to_json(c)::text, '||' order by c.user_id, c.offer_id), ''))) from public.cart_items c;
  return query select 'rows:payments', to_jsonb(md5(coalesce(string_agg(
    row_to_json(p)::text, '||' order by p.id), ''))) from public.payments p;
  return query select 'rows:orders', to_jsonb(md5(coalesce(string_agg(
    row_to_json(o)::text, '||' order by o.id), ''))) from public.orders o;
  return query select 'rows:sub_orders', to_jsonb(md5(coalesce(string_agg(
    row_to_json(s)::text, '||' order by s.id), ''))) from public.sub_orders s;
  return query select 'rows:order_items', to_jsonb(md5(coalesce(string_agg(
    row_to_json(i)::text, '||' order by i.id), ''))) from public.order_items i;
  return query select 'rows:app_settings', coalesce(jsonb_object_agg(s.key, s.value), '{}'::jsonb)
  from public.app_settings s;

  -- Respuestas de las RPC que usan el catálogo, el PC Builder y el asistente.
  return query select 'rpc:get_products', public.get_products();
  return query select 'rpc:get_products:gpu_priceAsc',
    public.get_products(0, 20, null, null, 'gpu', null, null, null, 'priceAsc');
  return query select 'rpc:get_products:search_page1', public.get_products(1, 10, 'ryzen');
  return query select 'rpc:get_product', public.get_product('rtx-5090');
  return query select 'rpc:get_related', public.get_related('rtx-5090', 4);
  return query select 'rpc:get_catalog_brands', public.get_catalog_brands(null, 'cpu');
  return query select 'rpc:get_builder_slots', public.get_builder_slots();
  return query select 'rpc:get_builder_candidates',
    public.get_builder_candidates(category => 'gpu', offer_ids => array['off-tp-9950x']);
  return query select 'rpc:validate_build', public.validate_build(array['off-tp-9950x', 'off-tp-nv3-1tb']);
  return query select 'rpc:get_build_scene', public.get_build_scene(array['off-tp-9950x', 'off-tp-nv3-1tb']);
  return query select 'rpc:get_product_attributes', public.get_product_attributes(array['rtx-5090', 'ryzen-9-9950x']);

  -- Carrito y compra de los clientes, como ellos mismos.
  perform set_config('request.jwt.claims',
    json_build_object('sub', shopper, 'role', 'authenticated')::text, true);
  return query select 'rpc:get_cart:shopper', public.get_cart();
  perform set_config('request.jwt.claims',
    json_build_object('sub', buyer, 'role', 'authenticated')::text, true);
  return query select 'rpc:get_cart:buyer', public.get_cart();
  return query select 'rpc:get_checkout_status:buyer', public.get_checkout_status(ref);
  perform set_config('request.jwt.claims', null, true);
end;
$$;

-- ---------------------------------------------------------------------------
-- Datos como los de la nube
-- ---------------------------------------------------------------------------

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-00000000e001', 'cliente.compra@upgrade.test',
   '{"full_name": "Cliente Compra", "accepted_documents": [{"code": "terms", "version": "1.0"}, {"code": "privacy", "version": "1.0"}]}'),
  ('00000000-0000-0000-0000-00000000e002', 'cliente.carrito@upgrade.test',
   '{"full_name": "Cliente Carrito", "accepted_documents": [{"code": "terms", "version": "1.0"}, {"code": "privacy", "version": "1.0"}]}');

insert into public.addresses (id, user_id, label, recipient_name, phone, department, city, address_line) values
  ('00000000-0000-0000-0000-00000000ea01', '00000000-0000-0000-0000-00000000e001',
   'Casa', 'Cliente Compra', '3001234567', 'Antioquia', 'Medellín', 'Calle 10 # 20-30'),
  ('00000000-0000-0000-0000-00000000ea02', '00000000-0000-0000-0000-00000000e002',
   'Oficina', 'Cliente Carrito', '3007654321', 'Atlántico', 'Barranquilla', 'Carrera 50 # 70-10');

-- Compra pagada: carrito, intento de pago y aprobación de la pasarela.
select set_config('request.jwt.claims',
  json_build_object('sub', '00000000-0000-0000-0000-00000000e001', 'role', 'authenticated')::text, false);
select public.add_cart_item('off-tp-nv3-1tb', 2);
select public.add_cart_item('off-tp-9950x', 1);

create temporary table upgrade_payment as
select public.start_checkout(
  '00000000-0000-0000-0000-00000000ea01'::uuid,
  '{"fullName": "Cliente Compra", "email": "cliente.compra@upgrade.test", "phone": "3001234567",
    "documentType": "CC", "documentNumber": "1065123456"}'::jsonb,
  (select sum((i ->> 'priceCents')::bigint * (i ->> 'quantity')::bigint)::bigint
   from jsonb_array_elements(public.get_cart() -> 'items') i)
) as payment;

select public.apply_payment_event(
  (select payment ->> 'reference' from upgrade_payment),
  'tx-upgrade-0001', 'APPROVED',
  (select (payment ->> 'amountCents')::bigint from upgrade_payment),
  'COP', 'CARD', 'webhook', null);

-- Carrito abierto de otro cliente.
select set_config('request.jwt.claims',
  json_build_object('sub', '00000000-0000-0000-0000-00000000e002', 'role', 'authenticated')::text, false);
select public.add_cart_item('off-tp-rtx5090', 1);
select set_config('request.jwt.claims', null, false);

-- ---------------------------------------------------------------------------
-- Foto
-- ---------------------------------------------------------------------------

insert into upgrade_check.snapshot (key, value)
select c.key, c.value from upgrade_check.capture() c;

select count(*) as claves_guardadas,
       (select count(*) from public.orders) as ordenes,
       (select count(*) from public.cart_items) as lineas_de_carrito
from upgrade_check.snapshot;
