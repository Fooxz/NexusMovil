-- Carrito: validación de stock, RLS, invitado y fusión (API_CONTRATO parte 2).
begin;
create extension if not exists pgtap with schema extensions;
select plan(22);

create function pg_temp.login_as(user_id uuid) returns void
language sql as $$
  select set_config('role', 'authenticated', true),
         set_config('request.jwt.claims',
           json_build_object('sub', user_id, 'role', 'authenticated')::text, true);
$$;

-- Ofertas de prueba: 3 unidades, 50 unidades (tope 10), agotada y pausada.
insert into public.providers (id, legal_name, display_name, tax_id, contact_email, status) values
  ('zz-prov', 'ZZ S.A.S.', 'Proveedor ZZ', 'zz-1', 'zz@zz.test', 'active');
insert into public.products (id, name, brand, category_code) values
  ('zz-gpu', 'ZZTEST GPU', 'Marca', 'gpu'),
  ('zz-ram', 'ZZTEST RAM', 'Marca', 'ram');
insert into public.offers (id, product_id, provider_id, external_sku, price_cents, stock_units, status) values
  ('zz-o3', 'zz-gpu', 'zz-prov', 'A', 100000, 3, 'published'),
  ('zz-o50', 'zz-ram', 'zz-prov', 'B', 50000, 50, 'published');
insert into public.products (id, name, brand, category_code) values
  ('zz-cpu', 'ZZTEST CPU', 'Marca', 'cpu');
insert into public.offers (id, product_id, provider_id, external_sku, price_cents, stock_units, status) values
  ('zz-o0', 'zz-cpu', 'zz-prov', 'C', 70000, 0, 'published');
insert into public.products (id, name, brand, category_code) values
  ('zz-psu', 'ZZTEST PSU', 'Marca', 'psu');
insert into public.offers (id, product_id, provider_id, external_sku, price_cents, stock_units, status) values
  ('zz-paused', 'zz-psu', 'zz-prov', 'D', 80000, 9, 'paused');

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000c1', 'ana.cart@zz.test',
   '{"full_name": "Ana", "accepted_documents": [{"code": "terms", "version": "1.0"}, {"code": "privacy", "version": "1.0"}]}'),
  ('00000000-0000-0000-0000-0000000000c2', 'beto.cart@zz.test',
   '{"full_name": "Beto", "accepted_documents": [{"code": "terms", "version": "1.0"}, {"code": "privacy", "version": "1.0"}]}');

-- Catálogo: la mejor oferta viaja en el listado (v0.5).
select is(public.get_product('zz-gpu') ->> 'bestOfferId', 'zz-o3', 'el producto trae bestOfferId');

-- Invitado
set local role anon;
select throws_ok($$ select public.get_cart() $$, 'PGRST', null,
  'sin sesión, el carrito guardado responde AUTH_REQUIRED');

select is(
  (public.preview_cart('[{"offerId": "zz-o50", "quantity": 2}, {"offerId": "zz-o3"}, {"offerId": "no-existe"}]')
    -> 'items' -> 0) - array['productName', 'brand', 'imageUrl'],
  '{"offerId": "zz-o50", "quantity": 2, "maxQuantity": 10, "available": true, "priceCents": 50000,
    "oldPriceCents": null, "stockLevel": "stable", "providerId": "zz-prov", "providerName": "Proveedor ZZ",
    "productId": "zz-ram", "category": "ram"}'::jsonb,
  'la vista previa trae precio, proveedor y el máximo comprable (tope 10)');
select is(
  jsonb_array_length(public.preview_cart('[{"offerId": "zz-o50"}, {"offerId": "no-existe"}]') -> 'items'), 1,
  'omite ofertas que no existen');
select is(
  public.preview_cart('[{"offerId": "zz-o3"}]') -> 'items' -> 0 ->> 'maxQuantity', '3',
  'el máximo es el stock cuando es menor que el tope');
select is(
  (select jsonb_agg(i ->> 'available') from jsonb_array_elements(
     public.preview_cart('[{"offerId": "zz-o0"}, {"offerId": "zz-paused"}]') -> 'items') i),
  '["false", "false"]'::jsonb,
  'agotadas y pausadas se muestran como no disponibles');
select is(
  public.preview_cart('[{"offerId": "zz-paused"}]') -> 'items' -> 0 ->> 'stockLevel', 'outOfStock',
  'una oferta pausada se informa como agotada');
select throws_ok($$ select public.preview_cart('{"no": "lista"}') $$, 'PGRST', null,
  'items debe ser una lista');

reset role;

-- Usuario con sesión
select pg_temp.login_as('00000000-0000-0000-0000-0000000000c1');

select is(jsonb_array_length(public.get_cart() -> 'items'), 0, 'el carrito empieza vacío');
select is(public.add_cart_item('zz-o3') -> 'items' -> 0 ->> 'quantity', '1', 'agrega una unidad');
select is(public.add_cart_item('zz-o3', 2) -> 'items' -> 0 ->> 'quantity', '3', 'suma unidades a la línea');
select throws_ok($$ select public.add_cart_item('zz-o3') $$, 'PGRST', null,
  'no deja pasar del stock (RN-028)');
select throws_ok($$ select public.set_cart_item('zz-o50', 11) $$, 'PGRST', null,
  'no deja pasar del tope por línea');
select throws_ok($$ select public.set_cart_item('zz-o3', 0) $$, 'PGRST', null,
  'la cantidad mínima es 1');
select throws_ok($$ select public.add_cart_item('zz-o0') $$, 'PGRST', null,
  'una oferta agotada no se agrega');
select throws_ok($$ select public.add_cart_item('no-existe') $$, 'PGRST', null,
  'una oferta inexistente es OFFER_NOT_FOUND');
select is(public.set_cart_item('zz-o50', 10) -> 'items' -> 1 ->> 'quantity', '10',
  'fija la cantidad; las líneas salen en orden de agregado');
select throws_ok($$ insert into public.cart_items (offer_id, quantity) values ('zz-o0', 5) $$,
  '42501', null, 'el carrito no se escribe directo: solo por RPC');

-- Fusión del carrito de invitado: suma y limita al máximo; descarta no disponibles.
select is(
  public.merge_cart('[{"offerId": "zz-o3", "quantity": 5}, {"offerId": "zz-o0", "quantity": 1}]') -> 'items',
  public.get_cart() -> 'items',
  'merge devuelve el carrito guardado');
select is(
  (select jsonb_agg(i ->> 'offerId' || ':' || (i ->> 'quantity')) from jsonb_array_elements(public.get_cart() -> 'items') i),
  '["zz-o3:3", "zz-o50:10"]'::jsonb,
  'la fusión limita al stock y descarta las agotadas');

-- RLS: otro usuario no ve el carrito de Ana.
select pg_temp.login_as('00000000-0000-0000-0000-0000000000c2');
select is((select count(*) from public.cart_items), 0::bigint, 'no ve carritos ajenos');
select is(jsonb_array_length(public.clear_cart() -> 'items'), 0, 'vaciar solo afecta su carrito');

reset role;
select * from finish();
rollback;
