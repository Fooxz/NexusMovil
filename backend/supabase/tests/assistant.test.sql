-- Asistente: atributos para justificar y registro de interacciones (fase 7).
begin;
create extension if not exists pgtap with schema extensions;
select plan(10);

set local role anon;

select is(
  (select jsonb_agg(a ->> 'label' || '=' || (a ->> 'value') || coalesce(' ' || (a ->> 'unit'), ''))
   from jsonb_array_elements(public.get_product_attributes(array['rtx-5080']) -> 0 -> 'attributes') a
   where a ->> 'key' in ('vram_gb', 'length_mm')),
  '["Memoria de video=16 GB", "Largo=304 mm"]'::jsonb,
  'devuelve los atributos con etiqueta y unidad, en el orden de la plantilla');
select is(
  (select jsonb_agg(p ->> 'productId')
   from jsonb_array_elements(public.get_product_attributes(
     array['corsair-rm850x', 'no-existe', 'rtx-5080'])) p),
  '["corsair-rm850x", "rtx-5080"]'::jsonb,
  'respeta el orden pedido y omite lo que no existe o no se ve');
select is(
  public.get_product_attributes(array['pc-gamer-pro-r7-5070']) -> 0 -> 'attributes' -> 0 ->> 'label',
  'Procesador', 'también los computadores armados');
select is(public.get_product_attributes('{}'), '[]'::jsonb, 'sin productos, lista vacía');
select throws_ok(
  $$ select public.get_product_attributes(array_fill('x'::text, array[31])) $$,
  'PGRST', null, 'como mucho 30 productos');

select throws_ok($$ select count(*) from public.assistant_interactions $$, '42501', null,
  'la app no lee las interacciones');
select throws_ok($$
  insert into public.assistant_interactions (session_id, client_hash, user_message, reply_type, reply)
  values ('sesion-123', repeat('a', 64), 'hola', 'question', '{}') $$, '42501', null,
  'ni las escribe');

reset role;

select lives_ok($$
  insert into public.assistant_interactions
    (session_id, client_hash, user_message, reply_type, reply, product_ids, model, model_calls, tool_calls)
  values ('sesion-123', repeat('a', 64), 'Necesito un PC', 'recommendation', '{}',
          array['pc-oficina-i5-14400'], 'gemini-3.5-flash', 2,
          '[{"name": "search_catalog", "args": {}}]') $$,
  'la Edge Function registra la pregunta, la respuesta y las herramientas (RF-043)');
select throws_ok($$
  insert into public.assistant_interactions (session_id, client_hash, user_message, reply_type, reply)
  values ('sesion-123', 'corto', 'hola', 'question', '{}') $$, '23514', null,
  'guarda un hash, no la IP');
select throws_ok($$
  insert into public.assistant_interactions (session_id, client_hash, user_message, reply_type, reply)
  values ('sesion-123', repeat('a', 64), 'hola', 'otra', '{}') $$, '23514', null,
  'solo tipos de respuesta conocidos');

select * from finish();
rollback;
