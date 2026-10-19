-- RPC del catálogo y visibilidad (docs/API_CONTRATO.md).
-- Los datos de prueba llevan "zztest" en el nombre para aislarlos del seed.
begin;
create extension if not exists pgtap with schema extensions;
select plan(24);

insert into public.providers (id, legal_name, display_name, tax_id, contact_email, status) values
  ('zz-prov-a', 'ZZ A S.A.S.', 'Proveedor A', 'zz-1', 'a@zz.test', 'active'),
  ('zz-prov-b', 'ZZ B S.A.S.', 'Proveedor B', 'zz-2', 'b@zz.test', 'active'),
  ('zz-prov-s', 'ZZ S S.A.S.', 'Proveedor S', 'zz-3', 's@zz.test', 'suspended');

insert into public.products (id, name, brand, category_code) values
  ('zz-gpu', 'ZZTEST Gráfica', 'Marca', 'gpu'),
  ('zz-cpu', 'ZZTEST Procesador', 'Marca', 'cpu'),
  ('zz-hidden-suspended', 'ZZTEST Oculto suspendido', 'Marca', 'cpu'),
  ('zz-hidden-draft', 'ZZTEST Oculto borrador', 'Marca', 'prebuiltPc');

insert into public.offers (id, product_id, provider_id, external_sku, price_cents, old_price_cents, stock_units, status) values
  -- La más barata está agotada: la mejor oferta es la de B, con stock.
  ('zz-o1', 'zz-gpu', 'zz-prov-a', 'A1', 400000, null, 0, 'published'),
  ('zz-o2', 'zz-gpu', 'zz-prov-b', 'B1', 500000, 600000, 10, 'published'),
  ('zz-o3', 'zz-cpu', 'zz-prov-a', 'A2', 300000, null, 2, 'published'),
  ('zz-o4', 'zz-hidden-suspended', 'zz-prov-s', 'S1', 300000, null, 9, 'published'),
  ('zz-o5', 'zz-hidden-draft', 'zz-prov-a', 'A3', 300000, null, 9, 'draft');

-- Los clientes no leen las tablas del catálogo directamente.
set local role anon;

select is((select count(*) from public.offers), 0::bigint, 'anon no ve ofertas');
select is((select count(*) from public.providers), 0::bigint, 'anon no ve proveedores');
select is((select count(*) from public.products), 0::bigint, 'anon no ve productos');
select ok((select count(*) from public.categories) = 9, 'anon ve las 9 categorías');

-- Listado
select is((public.get_products(search => 'zztest') ->> 'total')::integer, 2,
  'solo cuenta productos con oferta publicada de proveedor activo');

select is(
  (select jsonb_agg(i ->> 'id' order by i ->> 'id')
   from jsonb_array_elements(public.get_products(search => 'zztest') -> 'items') i),
  '["zz-cpu", "zz-gpu"]'::jsonb,
  'excluye proveedor suspendido y oferta en borrador');

select is(
  (select i from jsonb_array_elements(public.get_products(search => 'zztest') -> 'items') i
   where i ->> 'id' = 'zz-gpu') - array['name', 'brand', 'summary', 'quickSpecs', 'specs'],
  '{"id": "zz-gpu", "family": "part", "category": "gpu", "priceCents": 500000,
    "oldPriceCents": 600000, "stockLevel": "stable", "imageUrl": null, "offers": []}'::jsonb,
  'la mejor oferta es la más barata con stock y el listado no trae ofertas');

select is(
  (select i ->> 'stockLevel' from jsonb_array_elements(public.get_products(search => 'zztest') -> 'items') i
   where i ->> 'id' = 'zz-cpu'),
  'critical', '2 unidades es critical (N = 5)');

select is((public.get_products(search => 'ZZTÉST gráfica') ->> 'total')::integer, 1,
  'busca sin distinguir mayúsculas ni acentos');

select is((public.get_products(search => 'zztest', family => 'prebuiltPc') ->> 'total')::integer, 0,
  'filtra por familia');

select is((public.get_products(search => 'zztest', category => 'cpu') ->> 'total')::integer, 1,
  'filtra por categoría');

select is((public.get_products(search => 'zz%') ->> 'total')::integer, 0,
  'escapa los comodines del usuario');

select is(
  (public.get_products(search => 'zztest', page => 0, page_size => 1) -> 'items' -> 0 ->> 'id')
  || ',' ||
  (public.get_products(search => 'zztest', page => 1, page_size => 1) -> 'items' -> 0 ->> 'id'),
  'zz-gpu,zz-cpu',
  'paginación estable por nombre e id');

select is(public.get_products(search => 'zztest', page => 5) -> 'items', '[]'::jsonb,
  'una página fuera de rango devuelve items vacío');

select is((public.get_products(page_size => 500) ->> 'pageSize')::integer, 50,
  'pageSize máximo 50 y se devuelve el usado');

select throws_ok($$ select public.get_products(page => -1) $$, 'PGRST', null,
  'page negativo es VALIDATION_ERROR');
select throws_ok($$ select public.get_products(category => 'phone') $$, 'PGRST', null,
  'categoría desconocida es VALIDATION_ERROR');
select throws_ok($$ select public.get_products(family => 'laptop') $$, 'PGRST', null,
  'familia desconocida es VALIDATION_ERROR');

-- Detalle
select is(
  (select jsonb_agg(o ->> 'providerName') from jsonb_array_elements(public.get_product('zz-gpu') -> 'offers') o),
  '["Proveedor B", "Proveedor A"]'::jsonb,
  'el detalle trae las ofertas: primero con stock, luego por precio');

select is(public.get_product('zz-gpu') -> 'offers' -> 1 ->> 'stockLevel', 'outOfStock',
  'cada oferta trae su nivel de stock');

select ok(not (public.get_product('zz-gpu') -> 'offers' -> 0 ? 'stock_units'),
  'las unidades nunca salen de la base');

select throws_ok($$ select public.get_product('zz-hidden-suspended') $$, 'PGRST', null,
  'un producto sin ofertas visibles es PRODUCT_NOT_FOUND');

-- Relacionados
select ok(
  not exists (
    select 1 from jsonb_array_elements(public.get_related('zz-gpu', 10)) i
    where i ->> 'id' = 'zz-gpu'),
  'relacionados nunca incluye el producto consultado');

select is(jsonb_array_length(public.get_related('zz-gpu', 0)), 0, 'max_items 0 devuelve lista vacía');

reset role;
select * from finish();
rollback;
