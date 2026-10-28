-- Catálogo por oferta (API_CONTRATO, parte 6): una tarjeta por tienda, con su
-- precio, descuento y stock, y el filtro por tienda.
begin;
create extension if not exists pgtap with schema extensions;
select plan(30);

-- Tres tiendas venden la misma RTX 5070; una suspendida y una pendiente
-- también, pero no deben verse (RN-022).
insert into public.providers (id, legal_name, display_name, tax_id, contact_email, status) values
  ('zz-a', 'ZZ A S.A.S.', 'ZZ Tienda A', 'zz-oc-a', 'a@zz.test', 'active'),
  ('zz-b', 'ZZ B S.A.S.', 'ZZ Tienda B', 'zz-oc-b', 'b@zz.test', 'active'),
  ('zz-c', 'ZZ C S.A.S.', 'ZZ Tienda C', 'zz-oc-c', 'c@zz.test', 'active'),
  ('zz-s', 'ZZ S S.A.S.', 'ZZ Suspendida', 'zz-oc-s', 's@zz.test', 'suspended'),
  ('zz-p', 'ZZ P S.A.S.', 'ZZ Pendiente', 'zz-oc-p', 'p@zz.test', 'pending');
insert into public.products (id, name, brand, model, category_code) values
  ('zz-5070', 'ZZTEST RTX 5070', 'ZZMarca', 'RTX 5070', 'gpu'),
  ('zz-ram', 'ZZTEST DDR5 32GB', 'ZZMarca', 'DDR5-32', 'ram'),
  ('zz-pausado', 'ZZTEST PAUSADO', 'ZZMarca', 'PAUSADO', 'psu');
insert into public.offers (id, product_id, provider_id, external_sku, price_cents, old_price_cents, stock_units, status) values
  ('zz-a-5070', 'zz-5070', 'zz-a', 'A1', 250000000, null, 20, 'published'),
  ('zz-b-5070', 'zz-5070', 'zz-b', 'B1', 265000000, 280000000, 3, 'published'),
  ('zz-c-5070', 'zz-5070', 'zz-c', 'C1', 240000000, null, 0, 'published'),
  ('zz-s-5070', 'zz-5070', 'zz-s', 'S1', 230000000, null, 9, 'published'),
  ('zz-p-5070', 'zz-5070', 'zz-p', 'P1', 220000000, null, 9, 'published'),
  ('zz-a-ram', 'zz-ram', 'zz-a', 'A2', 60000000, null, 8, 'published'),
  ('zz-b-pausado', 'zz-pausado', 'zz-b', 'B2', 30000000, null, 8, 'paused');

create function pg_temp.items(result jsonb) returns setof jsonb
language sql as $$ select jsonb_array_elements(result -> 'items') $$;

create function pg_temp.stores(result jsonb) returns text[]
language sql as $$
  select coalesce(array_agg(i ->> 'providerName' order by ord), '{}')
  from jsonb_array_elements(result -> 'items') with ordinality as t(i, ord)
$$;

-- ---------------------------------------------------------------------------
-- Una tarjeta por tienda
-- ---------------------------------------------------------------------------

select is((public.get_offers(search => 'zztest rtx 5070') ->> 'total')::int, 3,
  'tres tiendas venden la RTX 5070: tres tarjetas');
select is(
  (select array_agg(distinct i ->> 'offerId' order by i ->> 'offerId')
   from pg_temp.items(public.get_offers(search => 'zztest rtx 5070')) i),
  array['zz-a-5070', 'zz-b-5070', 'zz-c-5070'], 'cada tarjeta es una oferta distinta');
select is(
  (select array_agg(distinct i ->> 'productId') from pg_temp.items(public.get_offers(search => 'zztest rtx 5070')) i),
  array['zz-5070'], 'las tres son del mismo producto');
select is(
  (select i - 'imageUrl' - 'summary' - 'quickSpecs'
   from pg_temp.items(public.get_offers(search => 'zztest rtx 5070')) i
   where i ->> 'providerId' = 'zz-b'),
  '{"offerId": "zz-b-5070", "productId": "zz-5070", "name": "ZZTEST RTX 5070", "brand": "ZZMarca",
    "category": "gpu", "providerId": "zz-b", "providerName": "ZZ Tienda B", "priceCents": 265000000,
    "oldPriceCents": 280000000, "stockLevel": "critical", "offerCount": 3}'::jsonb,
  'la tarjeta identifica la tienda y trae su precio, su descuento y su stock');
select is(
  (select jsonb_object_agg(i ->> 'providerId', i ->> 'stockLevel')
   from pg_temp.items(public.get_offers(search => 'zztest rtx 5070')) i),
  '{"zz-a": "stable", "zz-b": "critical", "zz-c": "outOfStock"}'::jsonb,
  'el stock de cada tarjeta es el de su tienda');
select ok(
  not exists (
    select 1 from pg_temp.items(public.get_offers(search => 'zztest')) i
    where i ->> 'providerId' in ('zz-s', 'zz-p')),
  'las tiendas suspendidas o pendientes no aparecen');
select is((public.get_offers(search => 'zztest pausado') ->> 'total')::int, 0,
  'una oferta pausada no aparece');

-- Comparación: el detalle sigue trayendo todas las ofertas del producto.
select is(
  (select array_agg(o ->> 'providerName' order by ord)
   from jsonb_array_elements(public.get_product('zz-5070') -> 'offers') with ordinality as t(o, ord)),
  array['ZZ Tienda A', 'ZZ Tienda B', 'ZZ Tienda C'],
  'el detalle compara las ofertas del producto (con stock primero, por precio)');

-- ---------------------------------------------------------------------------
-- Independencia: el cambio de una tienda no toca a las demás
-- ---------------------------------------------------------------------------

update public.offers set price_cents = 255000000, old_price_cents = 270000000, stock_units = 1
where id = 'zz-a-5070';
select is(
  (select jsonb_object_agg(i ->> 'providerId', jsonb_build_array(i -> 'priceCents', i -> 'oldPriceCents', i ->> 'stockLevel'))
   from pg_temp.items(public.get_offers(search => 'zztest rtx 5070')) i),
  '{"zz-a": [255000000, 270000000, "critical"], "zz-b": [265000000, 280000000, "critical"],
    "zz-c": [240000000, null, "outOfStock"]}'::jsonb,
  'cambiar el precio, el descuento y el stock de una tienda no altera las otras');
update public.offers set price_cents = 250000000, old_price_cents = null, stock_units = 20
where id = 'zz-a-5070';

-- ---------------------------------------------------------------------------
-- Orden y paginación
-- ---------------------------------------------------------------------------

select is(pg_temp.stores(public.get_offers(search => 'zztest rtx 5070')),
  array['ZZ Tienda A', 'ZZ Tienda B', 'ZZ Tienda C'],
  'relevancia: las del mismo producto juntas, con stock primero y por precio');
select is(pg_temp.stores(public.get_offers(search => 'zztest rtx 5070', sort => 'priceAsc')),
  array['ZZ Tienda C', 'ZZ Tienda A', 'ZZ Tienda B'], 'por precio ascendente, según el precio de cada tienda');
select is(pg_temp.stores(public.get_offers(search => 'zztest rtx 5070', sort => 'priceDesc')),
  array['ZZ Tienda B', 'ZZ Tienda A', 'ZZ Tienda C'], 'por precio descendente');
select is(
  array[
    public.get_offers(0, 1, 'zztest rtx 5070') -> 'items' -> 0 ->> 'offerId',
    public.get_offers(1, 1, 'zztest rtx 5070') -> 'items' -> 0 ->> 'offerId',
    public.get_offers(2, 1, 'zztest rtx 5070') -> 'items' -> 0 ->> 'offerId'],
  array['zz-a-5070', 'zz-b-5070', 'zz-c-5070'], 'las páginas son estables, sin repetidos ni huecos');
select is(public.get_offers(page_size => 500) ->> 'pageSize', '50', 'el tamaño de página tiene tope de 50');

-- ---------------------------------------------------------------------------
-- Filtros
-- ---------------------------------------------------------------------------

select is(pg_temp.stores(public.get_offers(search => 'zztest', provider => 'zz-b')),
  array['ZZ Tienda B'], 'filtra por tienda');
select is((public.get_offers(provider => 'zz-a', search => 'zztest') ->> 'total')::int, 2,
  'todas las ofertas visibles de una tienda');
select is((public.get_offers(provider => 'zz-s') ->> 'total')::int, 0,
  'una tienda suspendida no tiene ofertas en el catálogo');
select is((public.get_offers(search => 'zztest', category => 'ram') ->> 'total')::int, 1, 'filtra por categoría');
select is((public.get_offers(search => 'zztest', brand => 'zzmarca') ->> 'total')::int, 4,
  'filtra por marca sin distinguir mayúsculas');
select is(
  pg_temp.stores(public.get_offers(search => 'zztest rtx', max_price_cents => 250000000)),
  array['ZZ Tienda A', 'ZZ Tienda C'], 'el rango de precio usa el precio de cada oferta');
select is((public.get_offers(search => 'zz tienda b') ->> 'total')::int, 1,
  'la búsqueda también encuentra por el nombre de la tienda');

select is(
  (public.get_offers() ->> 'total')::bigint,
  (select count(*) from private.visible_offers o
   join public.products p on p.id = o.product_id
   join public.categories c on c.code = p.category_code and c.is_active),
  'el catálogo completo tiene una tarjeta por cada oferta visible');

-- Validación
select throws_ok($$ select public.get_offers(page => -1) $$, 'PGRST', null, 'page negativo es VALIDATION_ERROR');
select throws_ok($$ select public.get_offers(sort => 'popular') $$, 'PGRST', null, 'un orden desconocido es VALIDATION_ERROR');
select throws_ok($$ select public.get_offers(category => 'phone') $$, 'PGRST', null, 'una categoría desconocida es VALIDATION_ERROR');
select throws_like($$ select public.get_offers(provider => 'no-existe') $$, '%provider desconocido%',
  'una tienda desconocida es VALIDATION_ERROR');

-- ---------------------------------------------------------------------------
-- Tiendas para el filtro
-- ---------------------------------------------------------------------------

select is(
  (select jsonb_agg(s order by s ->> 'id') from jsonb_array_elements(public.get_catalog_providers('gpu')) s
   where s ->> 'id' like 'zz-%'),
  '[{"id": "zz-a", "displayName": "ZZ Tienda A", "offerCount": 1},
    {"id": "zz-b", "displayName": "ZZ Tienda B", "offerCount": 1},
    {"id": "zz-c", "displayName": "ZZ Tienda C", "offerCount": 1}]'::jsonb,
  'lista las tiendas con ofertas visibles en la categoría, sin suspendidas ni pendientes');
select is(
  (select s -> 'offerCount' from jsonb_array_elements(public.get_catalog_providers()) s where s ->> 'id' = 'zz-a'),
  '2'::jsonb, 'cuenta las ofertas de cada tienda en todo el catálogo');

-- Sin cuenta
set local role anon;
select is((public.get_offers(search => 'zztest rtx 5070') ->> 'total')::int, 3,
  'el catálogo por oferta se recorre sin cuenta');
select ok(jsonb_array_length(public.get_catalog_providers()) > 0, 'y el filtro por tienda también');
reset role;

select * from finish();
rollback;
