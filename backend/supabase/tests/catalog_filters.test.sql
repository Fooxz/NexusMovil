-- Filtros de marca y precio, orden y lista de marcas (API_CONTRATO v0.4).
begin;
create extension if not exists pgtap with schema extensions;
select plan(12);

insert into public.providers (id, legal_name, display_name, tax_id, contact_email, status) values
  ('zz-prov', 'ZZ S.A.S.', 'ZZ', 'zz-1', 'zz@zz.test', 'active');

insert into public.products (id, name, brand, category_code) values
  ('zz-a', 'ZZTEST A', 'Zeta', 'gpu'),
  ('zz-b', 'ZZTEST B', 'Alfa', 'gpu'),
  ('zz-c', 'ZZTEST C', 'Zeta', 'cpu');

insert into public.offers (id, product_id, provider_id, external_sku, price_cents, stock_units, status) values
  ('zz-oa', 'zz-a', 'zz-prov', 'A', 300000, 5, 'published'),
  ('zz-ob', 'zz-b', 'zz-prov', 'B', 100000, 5, 'published'),
  ('zz-oc', 'zz-c', 'zz-prov', 'C', 200000, 5, 'published');

set local role anon;

select is(
  (select jsonb_agg(i ->> 'id') from jsonb_array_elements(
    public.get_products(search => 'zztest', sort => 'priceAsc') -> 'items') i),
  '["zz-b", "zz-c", "zz-a"]'::jsonb, 'priceAsc ordena por precio ascendente');

select is(
  (select jsonb_agg(i ->> 'id') from jsonb_array_elements(
    public.get_products(search => 'zztest', sort => 'priceDesc') -> 'items') i),
  '["zz-a", "zz-c", "zz-b"]'::jsonb, 'priceDesc ordena por precio descendente');

select is(
  (select jsonb_agg(i ->> 'id') from jsonb_array_elements(
    public.get_products(search => 'zztest') -> 'items') i),
  '["zz-a", "zz-b", "zz-c"]'::jsonb, 'relevance (por defecto) ordena por nombre');

select is(
  (public.get_products(search => 'zztest', sort => 'priceAsc', page => 1, page_size => 2) -> 'items' -> 0 ->> 'id'),
  'zz-a', 'el orden se mantiene entre páginas');

select is((public.get_products(search => 'zztest', brand => 'zeta') ->> 'total')::integer, 2,
  'filtra por marca sin distinguir mayúsculas');

select is((public.get_products(search => 'zztest', min_price_cents => 150000, max_price_cents => 250000) ->> 'total')::integer, 1,
  'filtra por rango de precio inclusivo');

select is((public.get_products(search => 'zztest', min_price_cents => 300000) ->> 'total')::integer, 1,
  'el mínimo es inclusivo');

select throws_ok($$ select public.get_products(sort => 'nameDesc') $$, 'PGRST', null,
  'sort desconocido es VALIDATION_ERROR');
select throws_ok($$ select public.get_products(min_price_cents => 5, max_price_cents => 1) $$, 'PGRST', null,
  'min mayor que max es VALIDATION_ERROR');

select ok(public.get_catalog_brands() @> '["Zeta", "Alfa"]'::jsonb, 'lista marcas con productos visibles');
select ok(not (public.get_catalog_brands(category => 'cpu') @> '["Alfa"]'::jsonb),
  'la lista de marcas respeta la categoría');
select throws_ok($$ select public.get_catalog_brands(family => 'laptop') $$, 'PGRST', null,
  'familia desconocida en marcas es VALIDATION_ERROR');

reset role;
select * from finish();
rollback;
