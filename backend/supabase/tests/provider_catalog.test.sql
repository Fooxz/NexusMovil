-- Publicaciones de las tiendas: validaciones automáticas, duplicados, ficha
-- compartida, oferta propia, aislamiento entre tiendas e imágenes.
begin;
create extension if not exists pgtap with schema extensions;
select plan(65);

create function pg_temp.login_as(user_id uuid) returns void
language sql as $$
  select set_config('role', 'authenticated', true),
         set_config('request.jwt.claims', json_build_object(
           'sub', user_id, 'role', 'authenticated', 'iss', 'http://127.0.0.1:54321/auth/v1')::text, true);
$$;

-- Cuerpo del error del contrato ({code, message, details}), o null si no falla.
create function pg_temp.api_error(statement text) returns jsonb
language plpgsql as $$
begin
  execute statement;
  return null;
exception when sqlstate 'PGRST' then
  return sqlerrm::jsonb;
end;
$$;

create temporary table ids (name text primary key, id uuid not null);
insert into ids values
  ('a', '00000000-0000-0000-0000-00000000cc01'),
  ('b', '00000000-0000-0000-0000-00000000cc02'),
  ('c', '00000000-0000-0000-0000-00000000cc03'),
  ('cliente', '00000000-0000-0000-0000-00000000cc04');
create temporary table saved (key text primary key, value jsonb);
grant select on ids to authenticated;
grant all on saved to authenticated;

create function pg_temp.id(name text) returns uuid
language sql as $$ select id from ids where ids.name = $1 $$;

-- Ficha de una tarjeta gráfica con los atributos obligatorios de su plantilla.
create function pg_temp.gpu(name text, model text, images jsonb default '["zz-pa/gpu-1.jpg"]',
  brand text default 'ZZGráficas', attributes jsonb default null) returns jsonb
language sql as $$
  select jsonb_build_object(
    'category', 'gpu', 'name', name, 'brand', brand, 'model', model,
    'summary', '12 GB GDDR7', 'quickSpecs', '["12GB", "GDDR7"]'::jsonb,
    'specs', '[{"label": "VRAM", "value": "12 GB"}]'::jsonb,
    'attributes', coalesce(attributes, '{"chipset": "ZZ 5070", "vram_gb": 12, "tdp_w": 250, "length_mm": 300}'::jsonb),
    'images', images);
$$;

create function pg_temp.offer(price bigint, stock integer, status text default 'published',
  old_price bigint default null) returns jsonb
language sql as $$
  select jsonb_build_object('priceCents', price, 'oldPriceCents', old_price, 'stockUnits', stock, 'status', status);
$$;

-- Cuentas: dos tiendas activas (con documentos aceptados), una suspendida y
-- un cliente.
insert into auth.users (id, email, raw_user_meta_data)
select i.id, i.name || '.pc@zz.test',
  '{"full_name": "Cuenta ZZ", "accepted_documents": [{"code": "terms", "version": "1.0"}, {"code": "privacy", "version": "1.0"}]}'
from ids i;
update public.profiles set role = 'provider' where id in (pg_temp.id('a'), pg_temp.id('b'), pg_temp.id('c'));
insert into public.providers (id, legal_name, display_name, tax_id, contact_email, status, user_id) values
  ('zz-pa', 'ZZ A S.A.S.', 'ZZ Tienda A', 'zz-pc-a', 'a@zz.test', 'active', pg_temp.id('a')),
  ('zz-pb', 'ZZ B S.A.S.', 'ZZ Tienda B', 'zz-pc-b', 'b@zz.test', 'active', pg_temp.id('b')),
  ('zz-pc', 'ZZ C S.A.S.', 'ZZ Tienda C', 'zz-pc-c', 'c@zz.test', 'suspended', pg_temp.id('c'));

-- Imágenes ya subidas a Storage (la política de subida se prueba al final).
insert into storage.objects (bucket_id, name, owner_id) values
  ('product-images', 'zz-pa/gpu-1.jpg', pg_temp.id('a')::text),
  ('product-images', 'zz-pa/gpu-2.jpg', pg_temp.id('a')::text),
  ('product-images', 'zz-pa/ram-1.jpg', pg_temp.id('a')::text),
  ('product-images', 'zz-pb/b-1.jpg', pg_temp.id('b')::text),
  ('product-images', 'zz-pa/de-otro.jpg', pg_temp.id('b')::text);

-- ---------------------------------------------------------------------------
-- Acceso
-- ---------------------------------------------------------------------------

set local role anon;
select throws_ok($$ select public.search_catalog_sheets() $$, '42501', null, 'sin sesión no se usan las RPC de tiendas');
reset role;
select pg_temp.login_as(pg_temp.id('cliente'));
select throws_like($$ select public.create_my_product(pg_temp.gpu('ZZTEST X', 'ZZ-X'), pg_temp.offer(100000, 1)) $$,
  '%PROVIDER_REQUIRED%', 'un cliente no publica productos');
reset role;
select pg_temp.login_as(pg_temp.id('c'));
select throws_like($$ select public.get_my_offers() $$, '%PROVIDER_NOT_ACTIVE%', 'una tienda suspendida no opera');
reset role;

-- ---------------------------------------------------------------------------
-- Registrar un producto: se publica en cuanto pasa las validaciones
-- ---------------------------------------------------------------------------

select pg_temp.login_as(pg_temp.id('a'));
select lives_ok(
  $$ insert into saved select 'uno', public.create_my_product(
       pg_temp.gpu('ZZTEST Gráfica Uno', 'ZZ-G1'), pg_temp.offer(250000000, 10)) $$,
  'la tienda registra un producto nuevo con su oferta');
select is(
  (select jsonb_build_object('status', value -> 'status', 'canEditSheet', value -> 'canEditSheet',
     'sellers', value -> 'sellers', 'stockUnits', value -> 'stockUnits', 'visible', value -> 'visible')
   from saved where key = 'uno'),
  '{"status": "published", "canEditSheet": true, "sellers": 1, "stockUnits": 10, "visible": true}'::jsonb,
  'queda publicada sin aprobación y editable por quien la registró');
select is(
  (select jsonb_build_object('total', r -> 'total', 'store', r -> 'items' -> 0 ->> 'providerName')
   from (select public.get_offers(search => 'zztest grafica uno') as r) s),
  '{"total": 1, "store": "ZZ Tienda A"}'::jsonb, 'aparece de inmediato en el catálogo con su tienda');
reset role;

select is(
  (select p.created_by_provider_id || ' ' || i.url
   from public.products p join public.product_images i on i.product_id = p.id
   where p.id = (select value ->> 'productId' from saved where key = 'uno')),
  'zz-pa http://127.0.0.1:54321/storage/v1/object/public/product-images/zz-pa/gpu-1.jpg',
  'registra la tienda que la creó y arma la URL de la imagen en el servidor');
select is(private.attributes_json((select value ->> 'productId' from saved where key = 'uno')),
  '{"chipset": "ZZ 5070", "vram_gb": 12, "tdp_w": 250, "length_mm": 300}'::jsonb,
  'guarda los atributos tipados que usan el PC Builder y el asistente');

-- Validaciones automáticas
select pg_temp.login_as(pg_temp.id('a'));
select throws_like(
  $$ select public.create_my_product(pg_temp.gpu('ZZTEST Val', 'ZZ-V1',
       attributes => '{"chipset": "X", "vram_gb": 12, "tdp_w": 250}'), pg_temp.offer(100000, 1)) $$,
  '%Falta el atributo obligatorio%', 'exige los atributos obligatorios de la plantilla');
select throws_like(
  $$ select public.create_my_product(jsonb_build_object('category', 'ram', 'name', 'ZZTEST RAM', 'brand', 'ZZ',
       'model', 'ZZ-R1', 'images', '["zz-pa/ram-1.jpg"]'::jsonb,
       'attributes', '{"ram_type": "DDR3", "capacity_gb": 16, "modules": 2, "speed_mts": 3200}'::jsonb),
       pg_temp.offer(100000, 1)) $$,
  '%debe ser uno de%', 'respeta los valores permitidos');
select throws_like(
  $$ select public.create_my_product(pg_temp.gpu('ZZTEST Val', 'ZZ-V1',
       attributes => '{"chipset": "X", "vram_gb": 12, "tdp_w": 250, "length_mm": 300, "socket": "AM5"}'),
       pg_temp.offer(100000, 1)) $$,
  '%no son de esta categoría%', 'rechaza atributos de otra categoría');
select throws_like(
  $$ select public.create_my_product(pg_temp.gpu('ZZTEST Val', 'ZZ-V1',
       attributes => '{"chipset": "X", "vram_gb": "doce", "tdp_w": 250, "length_mm": 300}'), pg_temp.offer(100000, 1)) $$,
  '%Valor inválido%', 'valida el tipo de cada atributo');
select throws_like($$ select public.create_my_product(pg_temp.gpu('ZZTEST Val', 'ZZ-V1'), pg_temp.offer(100050, 1)) $$,
  '%precio debe%', 'el precio va en pesos enteros');
select throws_like(
  $$ select public.create_my_product(pg_temp.gpu('ZZTEST Val', 'ZZ-V1'), pg_temp.offer(100000, 1, old_price => 100000)) $$,
  '%precio anterior%', 'el precio anterior debe ser mayor (descuento)');
select throws_like($$ select public.create_my_product(pg_temp.gpu('ZZTEST Val', 'ZZ-V1'), pg_temp.offer(100000, -1)) $$,
  '%existencias%', 'las existencias no son negativas');
select throws_like(
  $$ select public.create_my_product(pg_temp.gpu('ZZTEST Val', 'ZZ-V1'), pg_temp.offer(100000, 1, 'retired')) $$,
  '%estado%', 'no se crea retirada');
select throws_like(
  $$ select public.create_my_product(pg_temp.gpu('ZZTEST Val', 'ZZ-V1', '["zz-pb/b-1.jpg"]'), pg_temp.offer(100000, 1)) $$,
  '%no es de tu tienda%', 'no usa imágenes de la carpeta de otra tienda');
select throws_like(
  $$ select public.create_my_product(pg_temp.gpu('ZZTEST Val', 'ZZ-V1', '["zz-pa/de-otro.jpg"]'), pg_temp.offer(100000, 1)) $$,
  '%no es de tu tienda%', 'ni imágenes que subió otra cuenta');
select throws_like(
  $$ select public.create_my_product(pg_temp.gpu('ZZTEST Val', 'ZZ-V1', '["zz-pa/no-subida.jpg"]'), pg_temp.offer(100000, 1)) $$,
  '%no es de tu tienda%', 'ni imágenes que no se subieron');
select throws_like(
  $$ select public.create_my_product(pg_temp.gpu('ZZTEST Val', 'ZZ-V1', '[]'), pg_temp.offer(100000, 1)) $$,
  '%Agrega entre 1%', 'exige al menos una imagen');
select throws_like(
  $$ select public.create_my_product(pg_temp.gpu('ZZTEST Val', 'ZZ-V1') || '{"category": "phone"}', pg_temp.offer(100000, 1)) $$,
  '%tipo de pieza%', 'solo categorías del catálogo');

-- Duplicados
select is(
  pg_temp.api_error($$ select public.create_my_product(
    pg_temp.gpu('Otra forma de llamarla', 'zz g1', brand => 'ZZ-Graficas'), pg_temp.offer(100000, 1)) $$) ->> 'code',
  'PRODUCT_EXISTS', 'el mismo modelo escrito distinto es el mismo producto');
select is(
  (pg_temp.api_error($$ select public.create_my_product(
    pg_temp.gpu('Mi RTX', 'RTX-5090', brand => 'nvidia'), pg_temp.offer(100000, 1)) $$) ->> 'details')::jsonb ->> 'productId',
  'rtx-5090', 'si ya está en el catálogo base, informa cuál es para ofertar sobre él');
select ok(
  (pg_temp.api_error($$ select public.create_my_product(
    pg_temp.gpu('NVIDIA GeForce RTX 5090', 'GeForce RTX 5090', brand => 'NVIDIA'), pg_temp.offer(100000, 1)) $$) ->> 'details')::jsonb
    -> 'candidates' @> '[{"productId": "rtx-5090"}]',
  'avisa de un posible duplicado con los parecidos');
select lives_ok(
  $$ insert into saved select 'distinto', public.create_my_product(
       pg_temp.gpu('NVIDIA GeForce RTX 5090 Edición ZZ', 'GeForce RTX 5090', brand => 'NVIDIA', images => '["zz-pa/gpu-2.jpg"]'),
       pg_temp.offer(900000000, 2), confirm_distinct => true) $$,
  'con confirmación se registra como otro producto');
select lives_ok(
  $$ insert into saved select 'borrador', public.create_my_product(
       pg_temp.gpu('ZZTEST Borrador', 'ZZ-B1'), pg_temp.offer(100000, 1, 'draft')) $$,
  'puede guardarse como borrador');
select is((public.get_offers(search => 'zztest borrador') ->> 'total')::int, 0, 'un borrador no aparece en el catálogo');

-- ---------------------------------------------------------------------------
-- Ofertas sobre productos existentes: una tarjeta por tienda
-- ---------------------------------------------------------------------------

reset role;
select pg_temp.login_as(pg_temp.id('b'));
select is(
  public.create_my_offer((select value ->> 'productId' from saved where key = 'uno'),
    pg_temp.offer(240000000, 4, old_price => 260000000)) ->> 'status',
  'published', 'otra tienda publica su oferta sobre el producto existente');
select is(
  (select jsonb_agg(jsonb_build_array(i ->> 'providerName', i -> 'priceCents', i -> 'offerCount') order by i ->> 'providerName')
   from jsonb_array_elements(public.get_offers(search => 'zztest grafica uno') -> 'items') i),
  '[["ZZ Tienda A", 250000000, 2], ["ZZ Tienda B", 240000000, 2]]'::jsonb,
  'el catálogo muestra una tarjeta por tienda con su precio');
select throws_like(
  $$ select public.create_my_offer((select value ->> 'productId' from saved where key = 'uno'), pg_temp.offer(1000, 1)) $$,
  '%OFFER_EXISTS%', 'una oferta por tienda y producto');
select throws_like($$ select public.create_my_offer('no-existe', pg_temp.offer(1000, 1)) $$,
  '%PRODUCT_NOT_FOUND%', 'no oferta sobre productos que no existen');
reset role;
select pg_temp.login_as(pg_temp.id('a'));
select lives_ok($$ select public.create_my_offer('rtx-5090', pg_temp.offer(780000000, 3)) $$,
  'una tienda oferta sobre el catálogo base');

-- ---------------------------------------------------------------------------
-- La ficha compartida no se modifica
-- ---------------------------------------------------------------------------

select throws_like(
  $$ select public.update_my_product((select value ->> 'productId' from saved where key = 'uno'),
       pg_temp.gpu('ZZTEST Cambiada', 'ZZ-G1')) $$,
  '%PRODUCT_SHARED%', 'quien la registró no la edita si otra tienda la vende');
select lives_ok(
  $$ insert into saved select 'dos', public.create_my_product(
       pg_temp.gpu('ZZTEST Gráfica Dos', 'ZZ-G2', '["zz-pa/gpu-2.jpg"]'), pg_temp.offer(180000000, 5)) $$,
  'registra otro producto que solo vende ella');
select is(
  public.update_my_product((select value ->> 'productId' from saved where key = 'dos'),
    pg_temp.gpu('ZZTEST Gráfica Dos Pro', 'ZZ-G2', '["zz-pa/gpu-2.jpg"]',
      attributes => '{"chipset": "ZZ 5070", "vram_gb": 16, "tdp_w": 260, "length_mm": 305}')) ->> 'name',
  'ZZTEST Gráfica Dos Pro', 'mientras sea la única tienda, edita su ficha');
reset role;
select is(private.attributes_json((select value ->> 'productId' from saved where key = 'dos')) -> 'vram_gb',
  '16'::jsonb, 'y sus atributos');
select pg_temp.login_as(pg_temp.id('a'));
select throws_like(
  $$ select public.update_my_product((select value ->> 'productId' from saved where key = 'dos'),
       pg_temp.gpu('ZZTEST Gráfica Dos Pro', 'ZZ-G1', '["zz-pa/gpu-2.jpg"]')) $$,
  '%PRODUCT_EXISTS%', 'al editar tampoco puede duplicar otro modelo');
select throws_like($$ select public.update_my_product('rtx-5090', pg_temp.gpu('Hackeada', 'RTX 5090')) $$,
  '%PRODUCT_LOCKED%', 'el catálogo base no lo edita ninguna tienda');
reset role;
select pg_temp.login_as(pg_temp.id('b'));
select throws_like(
  $$ select public.update_my_product((select value ->> 'productId' from saved where key = 'uno'),
       pg_temp.gpu('ZZTEST Cambiada', 'ZZ-G1', '["zz-pb/b-1.jpg"]')) $$,
  '%PRODUCT_LOCKED%', 'otra tienda que la vende tampoco edita la ficha');
select throws_like(
  $$ select public.update_my_product((select value ->> 'productId' from saved where key = 'dos'),
       pg_temp.gpu('ZZTEST Cambiada', 'ZZ-G2', '["zz-pb/b-1.jpg"]')) $$,
  '%OFFER_NOT_FOUND%', 'ni la de un producto que no vende');
select lives_ok($$ select public.retire_my_offer((select value ->> 'productId' from saved where key = 'uno')) $$,
  'la otra tienda retira su oferta');
reset role;
select pg_temp.login_as(pg_temp.id('a'));
select throws_like(
  $$ select public.update_my_product((select value ->> 'productId' from saved where key = 'uno'),
       pg_temp.gpu('ZZTEST Cambiada', 'ZZ-G1')) $$,
  '%PRODUCT_SHARED%', 'una ficha que se compartió sigue fija aunque la otra oferta esté retirada');

-- ---------------------------------------------------------------------------
-- Cada tienda administra solo su oferta
-- ---------------------------------------------------------------------------

reset role;
insert into saved select 'precio_tp', to_jsonb(price_cents) from public.offers where id = 'off-tp-rtx5090';
select pg_temp.login_as(pg_temp.id('a'));
select is(
  public.update_my_offer('rtx-5090', pg_temp.offer(770000000, 7, old_price => 800000000)) -> 'oldPriceCents',
  '800000000'::jsonb, 'cambia su precio, su descuento y su stock');
select is(
  (select jsonb_agg(o -> 'priceCents' order by o ->> 'providerId')
   from jsonb_array_elements(public.get_product('rtx-5090') -> 'offers') o
   where o ->> 'providerId' in ('zz-pa', 'prov-tecnopartes')),
  jsonb_build_array((select value from saved where key = 'precio_tp'), to_jsonb(770000000)),
  'sin tocar la oferta de otra tienda del mismo producto');
select is(
  public.update_my_offer('rtx-5090', pg_temp.offer(770000000, 7, 'paused')) ->> 'visible', 'false',
  'puede pausar su publicación');
select ok(
  not exists (select 1 from jsonb_array_elements(public.get_product('rtx-5090') -> 'offers') o where o ->> 'providerId' = 'zz-pa')
  and jsonb_array_length(public.get_product('rtx-5090') -> 'offers') > 0,
  'su tarjeta sale del catálogo y las de las demás tiendas siguen');
select throws_like($$ select public.update_my_offer('rtx-5090', pg_temp.offer(770000000, 7, 'retired')) $$,
  '%estado%', 'retirar tiene su propia acción');
insert into saved select 'oferta_dos', public.get_my_offer((select value ->> 'productId' from saved where key = 'dos'));
select is(public.retire_my_offer((select value ->> 'productId' from saved where key = 'dos')) ->> 'status', 'retired',
  'retira su publicación (lógico)');
select is(
  (select array[
     (select count(*) from jsonb_array_elements(public.get_my_offers() -> 'items') i where i ->> 'productId' = s.value ->> 'productId'),
     (select count(*) from jsonb_array_elements(public.get_my_offers('retired') -> 'items') i where i ->> 'productId' = s.value ->> 'productId')]
   from saved s where s.key = 'dos'),
  array[0::bigint, 1::bigint], 'las retiradas se ven solo en su filtro');
select throws_like(
  $$ select public.update_my_offer((select value ->> 'productId' from saved where key = 'dos'), pg_temp.offer(1000, 1)) $$,
  '%OFFER_RETIRED%', 'una retirada no se edita: se vuelve a publicar');
select is(
  public.create_my_offer((select value ->> 'productId' from saved where key = 'dos'), pg_temp.offer(175000000, 2)) ->> 'offerId',
  (select value ->> 'offerId' from saved where key = 'oferta_dos'), 'volver a publicarla reactiva la misma oferta');
insert into saved select 'mis_ofertas', public.get_my_offers(page_size => 50);
reset role;
select is(
  (select array_agg(i ->> 'offerId' order by i ->> 'offerId')
   from saved s, jsonb_array_elements(s.value -> 'items') i where s.key = 'mis_ofertas'),
  (select array_agg(x.id order by x.id) from public.offers x
   where x.provider_id = 'zz-pa' and x.status <> 'retired'),
  '"Mis publicaciones" trae exactamente las ofertas de la tienda');
select pg_temp.login_as(pg_temp.id('b'));
select throws_like(
  $$ select public.update_my_offer((select value ->> 'productId' from saved where key = 'dos'), pg_temp.offer(1000, 1)) $$,
  '%OFFER_NOT_FOUND%', 'otra tienda no cambia esa oferta');
reset role;
select is((select price_cents from public.offers where provider_id = 'zz-pa'
           and product_id = (select value ->> 'productId' from saved where key = 'dos')),
  175000000::bigint, 'y la oferta queda como la dejó su tienda');

-- Límite diario
update public.app_settings set value = to_jsonb(
  (select count(*) from public.products where created_by_provider_id = 'zz-pa'))
where key = 'provider_daily_product_limit';
select pg_temp.login_as(pg_temp.id('a'));
select throws_like(
  $$ select public.create_my_product(pg_temp.gpu('ZZTEST Límite', 'ZZ-L1'), pg_temp.offer(100000, 1)) $$,
  '%RATE_LIMITED%', 'hay un límite diario de productos nuevos por tienda');

-- Escritura directa en las tablas (sin pasar por las RPC)
update public.offers set price_cents = 100 where provider_id = 'zz-pb';
delete from public.offers where provider_id = 'zz-pb';
reset role;
select is((select count(*) || '/' || min(price_cents) from public.offers where provider_id = 'zz-pb'),
  '1/240000000', 'una tienda no cambia ni borra ofertas ajenas escribiendo en la tabla');
select pg_temp.login_as(pg_temp.id('a'));
select throws_ok($$ insert into public.products (name, brand, category_code) values ('ZZTEST Directo', 'ZZ', 'gpu') $$,
  '42501', null, 'ni crea productos sin las validaciones');
select throws_ok(
  $$ insert into public.offers (product_id, provider_id, external_sku, price_cents, status)
     values ('rtx-5090', 'zz-pb', 'X', 100, 'published') $$,
  '42501', null, 'ni ofertas a nombre de otra tienda');
reset role;

-- ---------------------------------------------------------------------------
-- Storage: cada tienda sube solo a su carpeta y no reemplaza ni borra
-- ---------------------------------------------------------------------------

select pg_temp.login_as(pg_temp.id('a'));
select lives_ok(
  $$ insert into storage.objects (bucket_id, name, owner_id) values ('product-images', 'zz-pa/subida.jpg', pg_temp.id('a')::text) $$,
  'la tienda sube a su carpeta');
select throws_ok(
  $$ insert into storage.objects (bucket_id, name, owner_id) values ('product-images', 'zz-pb/intruso.jpg', pg_temp.id('a')::text) $$,
  '42501', null, 'no sube a la carpeta de otra tienda');
select throws_ok(
  $$ insert into storage.objects (bucket_id, name, owner_id) values ('product-images', 'zz-pa/sub/x.jpg', pg_temp.id('a')::text) $$,
  '42501', null, 'ni a subcarpetas');
select throws_ok(
  $$ insert into storage.objects (bucket_id, name, owner_id) values ('component-models', 'zz-pa/x.glb', pg_temp.id('a')::text) $$,
  '42501', null, 'ni a otros buckets');
do $$
begin
  update storage.objects set metadata = '{"cambiada": true}' where name = 'zz-pa/gpu-1.jpg';
  delete from storage.objects where name = 'zz-pa/gpu-1.jpg';
exception when others then null;
end;
$$;
reset role;
select is((select coalesce(metadata::text, 'sin cambios') from storage.objects where name = 'zz-pa/gpu-1.jpg'),
  'sin cambios', 'no reemplaza ni borra lo que subió');
select pg_temp.login_as(pg_temp.id('cliente'));
select throws_ok(
  $$ insert into storage.objects (bucket_id, name, owner_id) values ('product-images', 'zz-pa/cliente.jpg', pg_temp.id('cliente')::text) $$,
  '42501', null, 'un cliente no sube imágenes');
reset role;
select pg_temp.login_as(pg_temp.id('c'));
select throws_ok(
  $$ insert into storage.objects (bucket_id, name, owner_id) values ('product-images', 'zz-pc/x.jpg', pg_temp.id('c')::text) $$,
  '42501', null, 'ni una tienda suspendida');
reset role;

select * from finish();
rollback;
