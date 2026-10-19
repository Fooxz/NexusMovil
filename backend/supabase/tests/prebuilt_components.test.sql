-- Componentes de los armados para la vista 3D (API_CONTRATO 11.5).
begin;
create extension if not exists pgtap with schema extensions;
select plan(12);

create function pg_temp.part(scene jsonb, category text) returns jsonb
language sql as $$
  select p from jsonb_array_elements(scene -> 'parts') p where p ->> 'category' = category;
$$;

set local role anon;

select is(public.get_prebuilt_scene('pc-gamer-pro-r7-5070') -> 'product' ->> 'id', 'pc-gamer-pro-r7-5070',
  'trae el producto del armado');
select is(
  (select array_agg(p ->> 'category' order by n)
   from jsonb_array_elements(public.get_prebuilt_scene('pc-gamer-pro-r7-5070') -> 'parts') with ordinality t(p, n)),
  array['cpu', 'motherboard', 'ram', 'gpu', 'storage', 'psu', 'pcCase', 'cooling'],
  'un componente por sección, en el orden del PC Builder');
select is(pg_temp.part(public.get_prebuilt_scene('pc-gamer-pro-r7-5070'), 'gpu') -> 'attributes',
  '{"length_mm": 242}'::jsonb, 'las medidas propias del componente');
select is(pg_temp.part(public.get_prebuilt_scene('pc-gamer-pro-r7-5070'), 'gpu') -> 'model' ->> 'path',
  'generic/gpu.glb', 'y el modelo genérico de su categoría');
select is(pg_temp.part(public.get_prebuilt_scene('pc-gamer-pro-r7-5070'), 'cpu') ->> 'componentId',
  'pc-gamer-pro-r7-5070:cpu', 'cada componente tiene un id estable');
select is(pg_temp.part(public.get_prebuilt_scene('pc-oficina-i5-14400'), 'gpu'), null,
  'sin tarjeta gráfica si usa los gráficos integrados');
select is(pg_temp.part(public.get_prebuilt_scene('pc-workstation-r9-5080'), 'cooling') -> 'attributes',
  '{"cooling_type": "liquid", "radiator_mm": 360}'::jsonb,
  'una pieza enlazada aporta las medidas del catálogo');
select throws_ok($$ select public.get_prebuilt_scene('rtx-5080') $$, 'PGRST', null,
  'una pieza suelta no es un armado');
select throws_ok($$ select public.get_prebuilt_scene('no-existe') $$, 'PGRST', null,
  'un producto que no existe');

reset role;

select throws_ok($$
  insert into public.prebuilt_components (prebuilt_id, category_code, name)
  values ('rtx-5080', 'cpu', 'x') $$, '23514', null, 'solo computadores armados');
select throws_ok($$
  insert into public.prebuilt_components (prebuilt_id, category_code, name, part_product_id)
  values ('pc-oficina-i5-14400', 'gpu', 'x', 'corsair-rm850x') $$, '23514', null,
  'la pieza enlazada debe ser de esa sección');
select throws_ok($$
  insert into public.prebuilt_components (prebuilt_id, category_code, name, attributes)
  values ('pc-oficina-i5-14400', 'gpu', 'x', '{"color": "rojo"}') $$, '23514', null,
  'solo atributos que usa la vista 3D');

select * from finish();
rollback;
