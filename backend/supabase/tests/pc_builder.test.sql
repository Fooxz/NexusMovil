-- PC Builder: motor de compatibilidad (API_CONTRATO parte 3).
-- Usa las piezas de seed.sql (ver docs/MODELO_DATOS.md, "Datos de desarrollo")
-- y crea las que el seed no tiene.
begin;
create extension if not exists pgtap with schema extensions;
select plan(35);

-- Configuración válida del seed: AM5 + DDR5 + ATX + RTX 5080 con fuente de 850 W.
create function pg_temp.valid_build() returns text[]
language sql as $$
  select array['off-tp-9950x', 'off-mp-b650ef', 'off-tp-vengeance32', 'off-tp-990pro2tb',
               'off-mp-rm850x', 'off-mp-o11evo', 'off-tp-rtx5080'];
$$;

create function pg_temp.rule_codes(result jsonb) returns text[]
language sql as $$
  select coalesce(array_agg(i ->> 'ruleCode' order by i ->> 'ruleCode'), '{}')
  from jsonb_array_elements(result -> 'issues') i;
$$;

-- Cambia una pieza de la configuración (sin consultar tablas: corre como anon).
create function pg_temp.swap(build text[], old_offer text, new_offer text) returns text[]
language sql as $$ select array_replace(build, old_offer, new_offer); $$;

set local role anon;

-- Configuración válida (RN-031)
select is(public.validate_build(pg_temp.valid_build()) ->> 'valid', 'true', 'una configuración compatible y completa es válida');
select is(public.validate_build(pg_temp.valid_build()) ->> 'purchasable', 'true', 'y se puede comprar');
select is(public.validate_build(pg_temp.valid_build()) -> 'issues', '[]'::jsonb, 'sin incompatibilidades');
select is((public.validate_build(pg_temp.valid_build()) ->> 'totalCents')::bigint,
  259600000::bigint + 139990000 + 54990000 + 79990000 + 64990000 + 74990000 + 169900000,
  'suma el precio de las piezas');
select is(jsonb_array_length(public.validate_build(pg_temp.valid_build()) -> 'parts'), 7,
  'devuelve cada pieza');

-- Incompatibilidades (RF-047)
select is(pg_temp.rule_codes(public.validate_build(pg_temp.swap(pg_temp.valid_build(), 'off-mp-b650ef', 'off-mp-z790hero'))),
  array['cpu_motherboard_socket'], 'detecta sockets distintos');
select is(
  public.validate_build(pg_temp.swap(pg_temp.valid_build(), 'off-mp-b650ef', 'off-mp-z790hero')) -> 'issues' -> 0 ->> 'message',
  'El procesador usa el socket AM5 y la placa madre el LGA1700: no encajan entre sí.',
  'explica la causa en lenguaje simple (RNF-023)');
select is(
  public.validate_build(pg_temp.swap(pg_temp.valid_build(), 'off-mp-b650ef', 'off-mp-z790hero')) -> 'issues' -> 0 -> 'offerIds',
  '["off-tp-9950x", "off-mp-z790hero"]'::jsonb, 'indica qué piezas la causan');
select is(public.validate_build(pg_temp.swap(pg_temp.valid_build(), 'off-mp-b650ef', 'off-mp-z790hero')) ->> 'valid', 'false',
  'una incompatibilidad invalida la configuración');

select is(
  public.validate_build(pg_temp.swap(pg_temp.valid_build(), 'off-tp-rtx5080', 'off-tp-rtx5090')) -> 'issues' -> 0 ->> 'message',
  'Este equipo necesita una fuente de al menos 1100 W y la elegida es de 850 W.',
  'calcula la potencia: (170 + 575) × 1,3 + 100 = 1068,5 → 1100 W');

select is(
  public.validate_build(pg_temp.swap(pg_temp.valid_build(), 'off-tp-rtx5080', 'off-tp-rtx5090')) -> 'issues' -> 0 -> 'offerIds',
  '["off-mp-rm850x", "off-tp-9950x", "off-tp-rtx5090"]'::jsonb,
  'la falta de potencia señala la fuente y lo que consume');

select is(pg_temp.rule_codes(public.validate_build(array['off-tp-265k', 'off-mp-cmliquid360'])),
  array['cooler_cpu_socket'], 'detecta un disipador sin soporte para el socket');

-- Faltantes (RF-048)
select is(
  (select array_agg(m ->> 'label') from jsonb_array_elements(public.validate_build(array['off-tp-9950x']) -> 'missingSlots') m),
  array['Placa madre', 'Memoria RAM', 'Almacenamiento', 'Fuente de poder', 'Gabinete'],
  'informa las piezas obligatorias que faltan, en orden');
select is(public.validate_build(array['off-tp-9950x']) ->> 'valid', 'false', 'con faltantes no es válida');
select is(public.validate_build('{}') -> 'missingSlots' -> 0 ->> 'category', 'cpu', 'una configuración vacía empieza por el procesador');

-- Sin stock (HU-008): sigue siendo válida, pero no se puede comprar.
select is(public.validate_build(pg_temp.valid_build() || 'off-mp-kraken360'::text) ->> 'purchasable', 'false',
  'una pieza agotada impide comprar la configuración');
select is(
  (select p ->> 'available' from jsonb_array_elements(public.validate_build(pg_temp.valid_build() || 'off-mp-kraken360'::text) -> 'parts') p
   where p ->> 'offerId' = 'off-mp-kraken360'),
  'false', 'y se marca la pieza');

-- Entradas inválidas
select throws_ok($$ select public.validate_build(array['no-existe']) $$, 'PGRST', null,
  'una oferta que no existe se rechaza');
select throws_ok($$ select public.validate_build(array['off-tp-9950x', 'off-tp-265k']) $$, 'PGRST', null,
  'una sola pieza por categoría');
select throws_ok($$ select public.validate_build(array['no-existe']) $$, 'PGRST', null,
  'una oferta inexistente es OFFER_NOT_FOUND');

-- Alternativas compatibles (RF-049). El catálogo de desarrollo es grande: se
-- comprueban las reglas, no la lista exacta.
create temp table cands as
  select row_number() over () as pos, c
  from jsonb_array_elements(public.get_builder_candidates('cpu', array['off-mp-z790hero'], 50)) c;
select ok(
  (select max(pos) from cands where (c ->> 'compatible')::boolean)
    < (select min(pos) from cands where not (c ->> 'compatible')::boolean),
  'primero las compatibles con lo ya elegido, después las demás');
select is(
  (select c ->> 'incompatibilityReason'
   from jsonb_array_elements(public.get_builder_candidates('cpu', array['off-mp-z790hero'], 5, 'ryzen 9 9950x')) c
   where c ->> 'id' = 'ryzen-9-9950x'),
  'El procesador usa el socket AM5 y la placa madre el LGA1700: no encajan entre sí.',
  'y explica por qué no sirve');
select is(
  (select c ->> 'compatible' from jsonb_array_elements(public.get_builder_candidates(
     'gpu', array['off-tp-9950x', 'off-mp-rm850x', 'off-mp-o11evo'], 5, 'rtx 5090')) c
   where c ->> 'id' = 'rtx-5090'),
  'false', 'una gráfica que la fuente no alcanza a alimentar no es compatible');

-- Búsqueda, precio máximo, orden y páginas (v0.12)
select ok(
  (select bool_and(c ->> 'name' ilike '%5090%')
   from jsonb_array_elements(public.get_builder_candidates('gpu', '{}', 10, 'rtx 5090')) c),
  'busca por texto, sin distinguir mayúsculas');
select ok(
  (select bool_and((c ->> 'priceCents')::bigint <= 300000000)
   from jsonb_array_elements(public.get_builder_candidates('gpu', '{}', 30, null, 300000000)) c),
  'respeta el precio máximo');
select ok(
  (select (array_agg((c ->> 'priceCents')::bigint))[1] >= (array_agg((c ->> 'priceCents')::bigint))[2]
   from jsonb_array_elements(public.get_builder_candidates('gpu', '{}', 2, null, null, 'priceDesc')) c),
  'priceDesc empieza por la más cara');
select is(
  (select count(*) from jsonb_array_elements(public.get_builder_candidates('gpu', '{}', 10, null, null, 'priceAsc', 0)) a
   join jsonb_array_elements(public.get_builder_candidates('gpu', '{}', 10, null, null, 'priceAsc', 1)) b
     on a ->> 'id' = b ->> 'id'),
  0::bigint, 'la página siguiente no repite piezas');
select throws_ok($$ select public.get_builder_candidates('gpu', '{}', 10, null, null, 'nombre') $$, 'PGRST', null,
  'el orden solo puede ser por precio');
select throws_ok($$ select public.get_builder_candidates('monitor') $$, 'PGRST', null,
  'las alternativas son solo de ranuras del armador');

reset role;

-- Piezas que el seed no tiene: CPU sin gráficos integrados y GPU sin largo.
insert into public.products (id, name, brand, category_code) values
  ('zz-cpu-noigpu', 'ZZTEST CPU sin gráficos', 'Marca', 'cpu'),
  ('zz-gpu-nolength', 'ZZTEST GPU sin largo', 'Marca', 'gpu');
insert into public.product_attributes (product_id, attribute_id, value_number, value_text, value_bool)
select v.product_id, d.id, v.num, v.txt, v.flag
from (values
  ('zz-cpu-noigpu', 'socket', null::numeric, 'AM5', null::boolean),
  ('zz-cpu-noigpu', 'cores', 8, null, null),
  ('zz-cpu-noigpu', 'tdp_w', 65, null, null),
  ('zz-cpu-noigpu', 'integrated_graphics', null, null, false),
  ('zz-gpu-nolength', 'chipset', null, 'ZZ', null),
  ('zz-gpu-nolength', 'vram_gb', 8, null, null),
  ('zz-gpu-nolength', 'tdp_w', 200, null, null)
) as v (product_id, key, num, txt, flag)
join public.products p on p.id = v.product_id
join public.attribute_definitions d on d.category_code = p.category_code and d.key = v.key;
insert into public.offers (id, product_id, provider_id, external_sku, price_cents, stock_units, status) values
  ('zz-o-cpu', 'zz-cpu-noigpu', 'prov-tecnopartes', 'ZZ-CPU', 100000, 5, 'published'),
  ('zz-o-gpu', 'zz-gpu-nolength', 'prov-tecnopartes', 'ZZ-GPU', 100000, 5, 'published');

select is(pg_temp.rule_codes(public.validate_build(array['zz-o-cpu', 'off-mp-b650ef'])),
  array['video_output'], 'sin gráficos integrados exige una tarjeta gráfica');
select is(pg_temp.rule_codes(public.validate_build(array['zz-o-cpu', 'off-mp-b650ef', 'off-tp-rtx5080'])),
  '{}'::text[], 'con tarjeta gráfica ya no hay aviso');
select is(
  public.validate_build(array['zz-o-gpu', 'off-mp-o11evo']) -> 'issues' -> 0 ->> 'severity', 'warning',
  'si falta un dato obligatorio avisa que no pudo verificar, sin suponer');

-- Versiones de reglas (RF-050)
update public.compat_rule_versions set is_active = false where rule_code = 'gpu_case_length' and version = 1;
insert into public.compat_rule_versions
  (rule_code, version, kind, category_a, attribute_a, category_b, attribute_b, message, is_active)
values
  ('gpu_case_length', 2, 'atMost', 'gpu', 'length_mm', 'pcCase', 'max_gpu_length_mm',
   'V2: la gráfica mide {aValue} mm; caben {bValue} mm.', true);
update public.product_attributes set value_number = 500
where product_id = 'rtx-5080'
  and attribute_id = (select id from public.attribute_definitions where category_code = 'gpu' and key = 'length_mm');
select is(
  public.validate_build(array['off-tp-rtx5080', 'off-mp-o11evo']) -> 'issues' -> 0 ->> 'message',
  'V2: la gráfica mide 500 mm; caben 426 mm.', 'se aplica la versión activa de la regla');

select throws_ok($$
  insert into public.compat_rule_versions (rule_code, version, kind, category_a, attribute_a, category_b, attribute_b, message, is_active)
  values ('gpu_case_length', 3, 'atMost', 'gpu', 'length_mm', 'pcCase', 'max_gpu_length_mm', 'x', true) $$,
  '23505', null, 'solo una versión activa por regla');

select throws_ok($$
  insert into public.compat_rule_versions (rule_code, version, kind, category_a, attribute_a, category_b, attribute_b, message)
  values ('gpu_case_length', 4, 'atMost', 'gpu', 'no_existe', 'pcCase', 'max_gpu_length_mm', 'x') $$,
  '23514', null, 'una regla debe usar atributos de la plantilla');

select * from finish();
rollback;
