-- Integridad del catálogo y bitácora de auditoría.
begin;
create extension if not exists pgtap with schema extensions;
select plan(13);

insert into public.providers (id, legal_name, display_name, tax_id, contact_email, status) values
  ('zz-prov', 'ZZ S.A.S.', 'ZZ', 'zz-1', 'zz@zz.test', 'active');
insert into public.products (id, name, brand, category_code) values
  ('zz-cpu', 'ZZTEST CPU', 'Marca', 'cpu');

-- Precios (API_CONTRATO, sección 1)
select throws_ok($$
  insert into public.offers (product_id, provider_id, external_sku, price_cents)
  values ('zz-cpu', 'zz-prov', 'X1', 12345) $$,
  '23514', null, 'el precio debe ser múltiplo de 100');

select throws_ok($$
  insert into public.offers (product_id, provider_id, external_sku, price_cents, old_price_cents)
  values ('zz-cpu', 'zz-prov', 'X1', 100000, 90000) $$,
  '23514', null, 'el precio anterior debe ser mayor que el actual');

insert into public.offers (id, product_id, provider_id, external_sku, price_cents, stock_units, status)
values ('zz-offer', 'zz-cpu', 'zz-prov', 'X1', 100000, 4, 'published');

select throws_ok($$
  insert into public.products (id, name, brand, category_code)
  values ('zz-phone', 'Celular', 'Marca', 'phone') $$,
  '23503', null, 'no existen categorías fuera del alcance (RN-010)');

-- Atributos tipados (RN-032)
select lives_ok($$
  insert into public.product_attributes (product_id, attribute_id, value_text)
  select 'zz-cpu', d.id, 'AM5' from public.attribute_definitions d
  where d.category_code = 'cpu' and d.key = 'socket' $$,
  'acepta un valor permitido de su categoría');

select throws_ok($$
  insert into public.product_attributes (product_id, attribute_id, value_number)
  select 'zz-cpu', d.id, 32 from public.attribute_definitions d
  where d.category_code = 'gpu' and d.key = 'vram_gb' $$,
  '23514', null, 'rechaza atributos de otra categoría');

select throws_ok($$
  insert into public.product_attributes (product_id, attribute_id, value_number)
  select 'zz-cpu', d.id, 1 from public.attribute_definitions d
  where d.category_code = 'cpu' and d.key = 'integrated_graphics' $$,
  '23514', null, 'rechaza un valor en la columna de otro tipo');

select throws_ok($$
  update public.product_attributes set value_text = 'AM9'
  where product_id = 'zz-cpu' $$,
  '23514', null, 'rechaza valores fuera de la lista permitida');

-- Bitácora (RF-081, RNF-030)
update public.offers set price_cents = 120000 where id = 'zz-offer';

select is(
  (select changed_fields from public.audit_log
   where table_name = 'offers' and record_id = 'zz-offer' and action = 'UPDATE'),
  array['price_cents'],
  'registra qué campos cambiaron');

select is(
  (select array[old_data ->> 'price_cents', new_data ->> 'price_cents'] from public.audit_log
   where table_name = 'offers' and record_id = 'zz-offer' and action = 'UPDATE'),
  array['100000', '120000'],
  'registra el valor anterior y el nuevo');

update public.offers set price_cents = 120000 where id = 'zz-offer';
select is(
  (select count(*) from public.audit_log
   where table_name = 'offers' and record_id = 'zz-offer' and action = 'UPDATE'),
  1::bigint,
  'una actualización sin cambios no se registra');

select throws_ok($$ delete from public.audit_log $$, '42501', null,
  'la bitácora no se puede borrar');

-- Alcance 2026-10-27: solo piezas.
select is((select count(*) from public.categories where family <> 'part'), 0::bigint,
  'todas las categorías son piezas');
select throws_ok($$ insert into public.categories (code, family, name) values ('zzPc', 'prebuiltPc', 'PC') $$,
  '23514', null, 'no se pueden crear categorías de computadores armados');

select * from finish();
rollback;
