-- Visor 3D: modelos por pieza y escena (API_CONTRATO parte 3, get_build_scene).
-- Usa las piezas y los modelos genéricos de seed.sql.
begin;
create extension if not exists pgtap with schema extensions;
select plan(18);

create function pg_temp.build() returns text[]
language sql as $$
  select array['off-tp-9950x', 'off-mp-b650ef', 'off-tp-vengeance32', 'off-tp-990pro2tb',
               'off-mp-rm850x', 'off-mp-o11evo', 'off-tp-rtx5080'];
$$;

-- Pieza de la escena por categoría.
create function pg_temp.part(scene jsonb, category text) returns jsonb
language sql as $$
  select p from jsonb_array_elements(scene -> 'parts') p where p ->> 'category' = category;
$$;

set local role anon;

select is(
  (select array_agg(p ->> 'category' order by n)
   from jsonb_array_elements(public.get_build_scene(pg_temp.build()) -> 'parts') with ordinality as t(p, n)),
  array['cpu', 'motherboard', 'ram', 'gpu', 'storage', 'psu', 'pcCase'],
  'devuelve las piezas en el orden de las ranuras');
select is(pg_temp.part(public.get_build_scene(pg_temp.build()), 'gpu') -> 'model',
  '{"path": "generic/gpu.glb", "rotation": [0, 180, 0], "generic": true, "title": "Graphics card",
    "author": "pgonarg", "license": "CC-BY-3.0", "sourceUrl": "https://poly.pizza/m/i45v5trpyR"}'::jsonb,
  'sin modelo propio usa el genérico de la categoría, con su crédito');
select is(pg_temp.part(public.get_build_scene(pg_temp.build()), 'psu') -> 'model', 'null'::jsonb,
  'sin ningún modelo, la app genera la pieza');
select is(pg_temp.part(public.get_build_scene(pg_temp.build()), 'motherboard') -> 'attributes',
  '{"form_factor": "ATX", "ram_slots": 4}'::jsonb, 'incluye los atributos que cambian cómo se ve');
select is(pg_temp.part(public.get_build_scene(pg_temp.build()), 'gpu') -> 'attributes',
  '{"length_mm": 304}'::jsonb, 'el largo real de la gráfica');
select is(pg_temp.part(public.get_build_scene(array['off-mp-kraken360']), 'cooling') -> 'attributes',
  '{"cooling_type": "liquid", "radiator_mm": 360}'::jsonb, 'el tipo de refrigeración y el radiador');
select is(public.get_build_scene('{}'), '{"parts": []}'::jsonb, 'una configuración vacía no tiene piezas');
select throws_ok($$ select public.get_build_scene(array['off-tp-pcgamerpro']) $$, 'PGRST', null,
  'valida la entrada como validate_build');
select is((select count(*) from public.component_models), 0::bigint,
  'la tabla no se lee directamente');
select throws_ok($$
  insert into public.component_models (category_code, file_path, title, author, license)
  values ('psu', 'x.glb', 'x', 'x', 'propia') $$, '42501', null, 'ni se escribe desde la app');

reset role;

-- Un modelo del producto exacto tiene prioridad sobre el genérico.
insert into public.component_models (category_code, product_id, file_path, title, author, license)
values ('gpu', 'rtx-5080', 'products/rtx-5080.glb', 'RTX 5080', 'NEXUS', 'propia');
select is(pg_temp.part(public.get_build_scene(pg_temp.build()), 'gpu') -> 'model' ->> 'path',
  'products/rtx-5080.glb', 'el modelo del producto gana al genérico');
select is(pg_temp.part(public.get_build_scene(pg_temp.build()), 'gpu') -> 'model' ->> 'generic',
  'false', 'y no es genérico');
select is((select count(*) from public.audit_log where table_name = 'component_models'
           and action = 'INSERT' and new_data ->> 'product_id' = 'rtx-5080'), 1::bigint,
  'los cambios de modelos quedan en la bitácora (RF-081)');

select throws_ok($$
  insert into public.component_models (category_code, file_path, title, author, license)
  values ('gpu', 'generic/gpu2.glb', 'Otra', 'NEXUS', 'propia') $$, '23505', null,
  'un solo genérico activo por categoría');
select throws_ok($$
  insert into public.component_models (category_code, product_id, file_path, title, author, license)
  values ('gpu', 'corsair-rm850x', 'x.glb', 'x', 'NEXUS', 'propia') $$, '23514', null,
  'el producto debe ser de la categoría');
select throws_ok($$
  insert into public.component_models (category_code, file_path, title, author, license)
  values ('psu', 'psu.glb', 'PSU', 'Alguien', 'CC-BY-4.0') $$, '23514', null,
  'CC BY exige el enlace a la obra');
select throws_ok($$
  insert into public.component_models (category_code, file_path, title, author, license)
  values ('psu', 'psu.obj', 'PSU', 'NEXUS', 'propia') $$, '23514', null,
  'solo archivos .glb');
select throws_ok($$
  insert into public.component_models (category_code, file_path, rotation_deg, title, author, license)
  values ('psu', 'psu.glb', '{0,90}', 'PSU', 'NEXUS', 'propia') $$, '23514', null,
  'la rotación tiene tres ángulos');

select * from finish();
rollback;
