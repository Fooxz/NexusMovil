-- Cuentas: alta con consentimiento, perfiles y direcciones con RLS.
begin;
create extension if not exists pgtap with schema extensions;
select plan(18);

-- Simula una sesión de Supabase Auth para el usuario dado.
create function pg_temp.login_as(user_id uuid) returns void
language sql as $$
  select set_config('role', 'authenticated', true),
         set_config('request.jwt.claims',
           json_build_object('sub', user_id, 'role', 'authenticated')::text, true);
$$;

create function pg_temp.signup(user_id uuid, email text, metadata jsonb) returns void
language sql as $$
  insert into auth.users (id, email, raw_user_meta_data) values (user_id, email, metadata);
$$;

-- Alta (RF-007, RN-033)
select throws_ok(
  $$ select pg_temp.signup('00000000-0000-0000-0000-0000000000a1', 'sin@zz.test',
       '{"full_name": "Sin Consentimiento"}') $$,
  '23514', null, 'no se crea una cuenta sin aceptar los documentos');

select throws_ok(
  $$ select pg_temp.signup('00000000-0000-0000-0000-0000000000a2', 'parcial@zz.test',
       '{"full_name": "Solo Terminos", "accepted_documents": [{"code": "terms", "version": "1.0"}]}') $$,
  '23514', null, 'aceptar solo los términos no basta');

select throws_ok(
  $$ select pg_temp.signup('00000000-0000-0000-0000-0000000000a3', 'vieja@zz.test',
       '{"full_name": "Version Vieja", "accepted_documents": [{"code": "terms", "version": "0.9"}, {"code": "privacy", "version": "1.0"}]}') $$,
  '23514', null, 'se exige la versión vigente');

select lives_ok(
  $$ select pg_temp.signup('00000000-0000-0000-0000-000000000001', 'ana@zz.test',
       '{"full_name": "  Ana Pérez ", "accepted_documents": [{"code": "terms", "version": "1.0"}, {"code": "privacy", "version": "1.0"}]}') $$,
  'con ambos documentos vigentes se crea la cuenta');

select pg_temp.signup('00000000-0000-0000-0000-000000000002', 'beto@zz.test',
  '{"full_name": "Beto Ruiz", "accepted_documents": [{"code": "terms", "version": "1.0"}, {"code": "privacy", "version": "1.0"}]}');

select is((select full_name from public.profiles where id = '00000000-0000-0000-0000-000000000001'),
  'Ana Pérez', 'el alta crea el perfil con el nombre sin espacios sobrantes');

select is(
  (select array_agg(document_code || '@' || document_version order by document_code)
   from public.user_consents where user_id = '00000000-0000-0000-0000-000000000001'),
  array['privacy@1.0', 'terms@1.0'], 'registra la aceptación de cada documento vigente');

-- RLS (RNF-002): cada usuario ve solo lo suyo
select pg_temp.login_as('00000000-0000-0000-0000-000000000001');

select is((select count(*) from public.profiles), 1::bigint, 've solo su perfil');
select is((select count(*) from public.user_consents), 2::bigint, 've solo sus consentimientos');

select lives_ok($$ update public.profiles set phone = '3001234567' $$, 'edita su teléfono');
select throws_ok($$ update public.profiles set phone = '12ab' $$, '23514', null,
  'rechaza un teléfono inválido');
select throws_ok($$ delete from public.user_consents $$, '42501', null,
  'no puede borrar sus consentimientos');

insert into public.addresses (label, recipient_name, phone, department, city, address_line)
values ('Casa', 'Ana Pérez', '3001234567', 'Antioquia', 'Medellín', 'Calle 10 # 20-30');

select is((select is_default from public.addresses where label = 'Casa'), true,
  'la primera dirección queda como predeterminada');

insert into public.addresses (label, recipient_name, phone, department, city, address_line, is_default)
values ('Oficina', 'Ana Pérez', '3001234567', 'Antioquia', 'Envigado', 'Carrera 43A # 1-50', true);

select is(
  (select array_agg(label order by label) from public.addresses where is_default),
  array['Oficina'], 'marcar otra como predeterminada desmarca la anterior');

delete from public.addresses where label = 'Oficina';
select is((select is_default from public.addresses where label = 'Casa'), true,
  'al borrar la predeterminada, otra pasa a serlo');

select throws_ok(
  $$ insert into public.addresses (user_id, label, recipient_name, phone, department, city, address_line)
     values ('00000000-0000-0000-0000-000000000002', 'Ajena', 'X Y', '3001234567', 'Cundinamarca', 'Chía', 'Calle 1 # 2-3') $$,
  '42501', null, 'no puede crear direcciones para otro usuario');

-- El otro usuario no ve ni modifica las direcciones de Ana.
select pg_temp.login_as('00000000-0000-0000-0000-000000000002');

select is((select count(*) from public.addresses), 0::bigint, 'no ve direcciones ajenas');

update public.addresses set city = 'Hackeada';
reset role;
select is((select city from public.addresses where label = 'Casa'), 'Medellín',
  'no modifica direcciones ajenas');

-- Los documentos legales vigentes son públicos (se leen antes del registro).
set local role anon;
select is((select count(*) from public.legal_documents), 2::bigint,
  'anon ve los documentos legales vigentes');

reset role;
select * from finish();
rollback;
