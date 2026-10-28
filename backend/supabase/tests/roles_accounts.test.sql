-- Roles y cuentas: el rol no se puede autoasignar, las tiendas las crea un
-- administrador (rol de servicio), el primer administrador solo por SQL y
-- las funciones administrativas solo para administradores.
begin;
create extension if not exists pgtap with schema extensions;
select plan(80);

create function pg_temp.login_as(user_id uuid) returns void
language sql as $$
  select set_config('role', 'authenticated', true),
         set_config('request.jwt.claims',
           json_build_object('sub', user_id, 'role', 'authenticated')::text, true);
$$;

-- Solo la sesión (sin cambiar de rol), para llamar funciones de private
-- como lo hacen las RPC.
create function pg_temp.claims_as(user_id uuid) returns void
language sql as $$
  select set_config('request.jwt.claims',
           json_build_object('sub', user_id, 'role', 'authenticated')::text, true);
$$;

create function pg_temp.signup(user_id uuid, email text, metadata jsonb,
  app_metadata jsonb default '{}') returns void
language sql as $$
  insert into auth.users (id, email, raw_user_meta_data, raw_app_meta_data)
  values (user_id, email, metadata, app_metadata);
$$;

create function pg_temp.role_of(user_id uuid) returns text
language sql as $$ select role::text from public.profiles where id = user_id $$;

create temporary table ids (name text primary key, id uuid not null);
insert into ids values
  ('ana', '00000000-0000-0000-0000-0000000000f1'),
  ('mallory', '00000000-0000-0000-0000-0000000000f2'),
  ('admin', '00000000-0000-0000-0000-0000000000f3'),
  ('nueva', '00000000-0000-0000-0000-0000000000f4'),
  ('homonima', '00000000-0000-0000-0000-0000000000f5'),
  ('existente', '00000000-0000-0000-0000-0000000000f6'),
  ('otra', '00000000-0000-0000-0000-0000000000f7'),
  ('nit', '00000000-0000-0000-0000-0000000000f8');
grant select on ids to authenticated, service_role;

create function pg_temp.id(name text) returns uuid
language sql as $$ select id from ids where ids.name = $1 $$;

-- Alta como la hace la Edge Function: ticket (rol de servicio), cuenta en
-- Auth y después app_metadata, que la API de administración de Auth escribe
-- tras insertar el usuario.
create function pg_temp.provisioned_signup(p_user_id uuid, p_email text, p_full_name text) returns void
language plpgsql as $$
begin
  perform public.admin_prepare_provider_account(pg_temp.id('admin'), p_email);
  insert into auth.users (id, email, raw_user_meta_data)
  values (p_user_id, p_email, jsonb_build_object('full_name', p_full_name));
  update auth.users u
  set raw_app_meta_data = coalesce(u.raw_app_meta_data, '{}'::jsonb) || '{"nexus_provisioned": true}'
  where u.id = p_user_id;
end;
$$;

-- Tienda cargada antes de los roles, con una oferta publicada.
insert into public.providers (id, legal_name, display_name, tax_id, contact_email, status) values
  ('zz-r1', 'Tienda Existente S.A.S.', 'Tienda Existente', '900000001-1', 'existente@zz.test', 'active');
insert into public.products (id, name, brand, category_code) values
  ('zz-r1-p', 'ZZTEST ROLES GPU', 'Marca', 'gpu');
insert into public.offers (id, product_id, provider_id, external_sku, price_cents, stock_units, status) values
  ('zz-r1-o', 'zz-r1-p', 'zz-r1', 'R1', 100000, 5, 'published');

-- ---------------------------------------------------------------------------
-- Alta: el rol nunca sale de lo que envía la app
-- ---------------------------------------------------------------------------

select pg_temp.signup(pg_temp.id('ana'), 'ana.roles@zz.test',
  '{"full_name": "Ana", "accepted_documents": [{"code": "terms", "version": "1.0"}, {"code": "privacy", "version": "1.0"}]}');
select pg_temp.signup(pg_temp.id('mallory'), 'mallory.roles@zz.test',
  '{"full_name": "Mallory", "role": "admin", "accepted_documents": [{"code": "terms", "version": "1.0"}, {"code": "privacy", "version": "1.0"}]}');

select is(pg_temp.role_of(pg_temp.id('ana')), 'customer', 'toda cuenta del registro nace como cliente');
select is(pg_temp.role_of(pg_temp.id('mallory')), 'customer',
  'un rol en los metadatos del registro se ignora');
select throws_ok(
  $$ select pg_temp.signup('00000000-0000-0000-0000-0000000000fa', 'marca@zz.test',
       '{"full_name": "Marca", "nexus_provisioned": true}') $$,
  '23514', null, 'la marca de tienda en los metadatos que escribe la app no evita los documentos');

select throws_ok(
  $$ select pg_temp.signup('00000000-0000-0000-0000-0000000000fb', 'sinticket@zz.test',
       '{"full_name": "Sin Ticket"}', '{"nexus_provisioned": true}') $$,
  '23514', null, 'sin ticket de alta, ni la marca de app_metadata evita los documentos');

-- ---------------------------------------------------------------------------
-- Primer administrador: solo por SQL, como propietario de la base
-- ---------------------------------------------------------------------------

select pg_temp.signup(pg_temp.id('admin'), 'admin.roles@zz.test',
  '{"full_name": "Admin", "accepted_documents": [{"code": "terms", "version": "1.0"}, {"code": "privacy", "version": "1.0"}]}');
select lives_ok($$ select private.grant_admin('  ADMIN.roles@zz.test ') $$,
  'el propietario habilita un administrador por SQL');
select is(pg_temp.role_of(pg_temp.id('admin')), 'admin', 'la cuenta queda como administradora');
select is(
  (select new_data ->> 'role' from public.audit_log
   where table_name = 'profiles' and record_id = pg_temp.id('admin')::text
   order by id desc limit 1),
  'admin', 'el cambio de rol queda en la bitácora');
select throws_ok($$ select private.grant_admin('no-existe@zz.test') $$, 'P0001', null,
  'no habilita correos que no existen');

-- ---------------------------------------------------------------------------
-- Cuenta de tienda creada por la Edge Function (ticket del rol de servicio)
-- ---------------------------------------------------------------------------

select pg_temp.provisioned_signup(pg_temp.id('nueva'), 'tienda.nueva@zz.test', 'Tienda Nueva');
select is(pg_temp.role_of(pg_temp.id('nueva')), 'customer',
  'la cuenta creada para una tienda es cliente hasta vincularla');
select is((select count(*) from public.user_consents where user_id = pg_temp.id('nueva')), 0::bigint,
  'y acepta los documentos en su primer ingreso');
select is((select count(*) from private.account_provisioning where email = 'tienda.nueva@zz.test'), 0::bigint,
  'el alta consume el ticket');

insert into private.account_provisioning (email, admin_id, created_at)
values ('vencido@zz.test', pg_temp.id('admin'), now() - interval '11 minutes');
select throws_ok(
  $$ select pg_temp.signup('00000000-0000-0000-0000-0000000000fc', 'vencido@zz.test', '{"full_name": "Vencido"}') $$,
  '23514', null, 'un ticket vencido no sirve');
select throws_like($$ select public.admin_prepare_provider_account(pg_temp.id('ana'), 'x@zz.test') $$,
  '%FORBIDDEN%', 'solo un administrador pide tickets de alta');
select throws_like($$ select public.admin_prepare_provider_account(pg_temp.id('admin'), ' ANA.roles@zz.test') $$,
  '%EMAIL_EXISTS%', 'no hay ticket para un correo ya registrado');

-- ---------------------------------------------------------------------------
-- El cliente no puede cambiar su rol
-- ---------------------------------------------------------------------------

select pg_temp.login_as(pg_temp.id('ana'));
select throws_ok($$ update public.profiles set role = 'admin' $$, '42501', null,
  'un cliente no puede volverse administrador');
select throws_ok($$ update public.profiles set role = 'provider' $$, '42501', null,
  'ni proveedor');
select throws_ok($$ update public.profiles set must_change_password = true $$, '42501', null,
  'ni tocar la marca de contraseña temporal');
select lives_ok($$ update public.profiles set full_name = 'Ana María', phone = '3001234567' $$,
  'sí edita su nombre y su teléfono');
select throws_ok($$ select private.grant_admin('ana.roles@zz.test') $$, '42501', null,
  'no puede ejecutar el alta de administradores');
select throws_ok(
  $$ select public.admin_provision_provider(pg_temp.id('admin'), pg_temp.id('ana'), 'zz-r1') $$,
  '42501', null, 'ni el alta de tiendas');
reset role;

-- Segunda barrera: aunque alguien otorgara el permiso de columna, el trigger
-- rechaza el cambio.
grant update (role) on public.profiles to authenticated;
select pg_temp.login_as(pg_temp.id('ana'));
select throws_like($$ update public.profiles set role = 'admin' $$, '%solo lo cambia NEXUS%',
  'el trigger rechaza el cambio de rol aunque haya permiso');
reset role;
revoke update (role) on public.profiles from authenticated;

-- Cambiar los metadatos de la cuenta (lo que la app sí puede) no cambia el rol.
update auth.users set raw_user_meta_data = raw_user_meta_data || '{"role": "admin"}'
where id = pg_temp.id('ana');
select pg_temp.login_as(pg_temp.id('ana'));
select is(public.get_my_account() ->> 'role', 'customer',
  'los metadatos de la cuenta no cambian el rol');
reset role;

set local role service_role;
select throws_ok($$ select private.grant_admin('ana.roles@zz.test') $$, '42501', null,
  'ni el rol de servicio habilita administradores');
reset role;

-- ---------------------------------------------------------------------------
-- Funciones administrativas
-- ---------------------------------------------------------------------------

select is(
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname like 'admin\_%'
     and has_function_privilege('anon', p.oid, 'execute')),
  0::bigint, 'ninguna función administrativa es ejecutable sin sesión');
select is(
  (select array_agg(p.proname::text order by p.proname) from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname like 'admin\_%'
     and has_function_privilege('authenticated', p.oid, 'execute')),
  array['admin_get_provider', 'admin_get_providers', 'admin_set_provider_status', 'admin_update_provider',
        'admin_validate_store'],
  'con sesión solo se ejecutan las que exigen el rol administrador');
select is(
  (select array_agg(p.proname::text order by p.proname) from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname like 'admin\_%'
     and not has_function_privilege('authenticated', p.oid, 'execute')),
  array['admin_prepare_provider_account', 'admin_provider_account', 'admin_provision_provider',
        'admin_require_password_change'],
  'el alta y la contraseña de las tiendas son solo del rol de servicio');

set local role anon;
select throws_ok($$ select public.admin_get_providers() $$, '42501', null,
  'anon no ejecuta funciones administrativas');
select throws_ok($$ select public.get_my_account() $$, '42501', null,
  'ni consulta una cuenta');
reset role;

select pg_temp.login_as(pg_temp.id('ana'));
select throws_like($$ select public.admin_get_providers() $$, '%FORBIDDEN%',
  'un cliente recibe FORBIDDEN al listar tiendas');
select throws_like($$ select public.admin_get_provider('zz-r1') $$, '%FORBIDDEN%',
  'ni ve el detalle de una tienda');
select throws_like($$ select public.admin_set_provider_status('zz-r1', 'suspended') $$, '%FORBIDDEN%',
  'ni suspende tiendas');
select throws_like(
  $$ select public.admin_update_provider('zz-r1', '{"legalName": "X S.A.S.", "displayName": "X",
       "taxId": "900000009-9", "contactEmail": "x@zz.test"}') $$,
  '%FORBIDDEN%', 'ni edita tiendas');
select throws_like(
  $$ select public.admin_validate_store('{"legalName": "X S.A.S.", "displayName": "X",
       "taxId": "900000009-9", "contactEmail": "x@zz.test"}') $$,
  '%FORBIDDEN%', 'ni valida datos de tiendas');
reset role;
select is((select status::text from public.providers where id = 'zz-r1'), 'active',
  'la tienda sigue igual');

-- ---------------------------------------------------------------------------
-- Alta de tiendas (rol de servicio, como la Edge Function)
-- ---------------------------------------------------------------------------

select pg_temp.provisioned_signup(pg_temp.id('homonima'), 'homonima@zz.test', 'Homónima');
select pg_temp.provisioned_signup(pg_temp.id('existente'), 'existente.cuenta@zz.test', 'Existente');
select pg_temp.provisioned_signup(pg_temp.id('otra'), 'otra@zz.test', 'Otra');
select pg_temp.provisioned_signup(pg_temp.id('nit'), 'nit@zz.test', 'Nit Repetido');

set local role service_role;
select throws_like(
  $$ select public.admin_provision_provider(pg_temp.id('ana'), pg_temp.id('nueva'), null,
       '{"legalName": "Tienda Nueva S.A.S.", "displayName": "Tienda Nueva", "taxId": "900000002-2", "contactEmail": "nueva@zz.test"}') $$,
  '%FORBIDDEN%', 'el alta exige que quien la pide sea administrador');
select throws_like(
  $$ select public.admin_provision_provider(pg_temp.id('admin'), pg_temp.id('ana'), null,
       '{"legalName": "Tienda Ana S.A.S.", "displayName": "Tienda Ana", "taxId": "900000003-3", "contactEmail": "ana@zz.test"}') $$,
  '%VALIDATION_ERROR%', 'no convierte en tienda la cuenta de un cliente registrado');
select throws_like(
  $$ select public.admin_provision_provider(pg_temp.id('admin'), pg_temp.id('nueva'), null,
       '{"legalName": "T", "displayName": "Tienda Nueva", "taxId": "900000002-2", "contactEmail": "nueva@zz.test"}') $$,
  '%VALIDATION_ERROR%', 'valida los datos de la tienda');
select is(
  public.admin_provision_provider(pg_temp.id('admin'), pg_temp.id('nueva'), null,
    '{"legalName": "Tienda Nueva S.A.S.", "displayName": "Tienda Nueva", "taxId": "900000002-2",
      "contactEmail": "Nueva@ZZ.test", "verificationNote": "Visita al local el 27/10"}') ->> 'accountEmail',
  'tienda.nueva@zz.test', 'crea la tienda y vincula la cuenta');
reset role;

select is(pg_temp.role_of(pg_temp.id('nueva')), 'provider', 'la cuenta queda como tienda');
select is((select must_change_password from public.profiles where id = pg_temp.id('nueva')), true,
  'con contraseña temporal');
select is(
  (select status::text || '/' || (created_by = pg_temp.id('admin'))::text || '/' || contact_email
   from public.providers where user_id = pg_temp.id('nueva')),
  'active/true/nueva@zz.test', 'activa, con el administrador que la creó y el correo normalizado');

set local role service_role;
select throws_like(
  $$ select public.admin_provision_provider(pg_temp.id('admin'), pg_temp.id('homonima'), null,
       '{"legalName": "Otra Razón S.A.S.", "displayName": "TIENDA-nueva", "taxId": "900000004-4", "contactEmail": "h@zz.test"}') $$,
  '%SIMILAR_STORE_NAME%', 'avisa si otra tienda tiene un nombre visible equivalente');
select lives_ok(
  $$ select public.admin_provision_provider(pg_temp.id('admin'), pg_temp.id('homonima'), null,
       '{"legalName": "Otra Razón S.A.S.", "displayName": "TIENDA-nueva", "taxId": "900000004-4", "contactEmail": "h@zz.test"}',
       true) $$,
  'con confirmación se acepta: dos negocios distintos pueden llamarse igual');
select throws_like(
  $$ select public.admin_provision_provider(pg_temp.id('admin'), pg_temp.id('nit'), null,
       '{"legalName": "Repetida S.A.S.", "displayName": "Repetida", "taxId": "900000002-2", "contactEmail": "r@zz.test"}') $$,
  '%TAX_ID_TAKEN%', 'el NIT sigue siendo único');
select lives_ok(
  $$ select public.admin_provision_provider(pg_temp.id('admin'), pg_temp.id('existente'), 'zz-r1') $$,
  'vincula una cuenta a una tienda que ya existía');
select throws_like(
  $$ select public.admin_provision_provider(pg_temp.id('admin'), pg_temp.id('otra'), 'zz-r1') $$,
  '%PROVIDER_HAS_ACCOUNT%', 'una tienda tiene una sola cuenta');
select throws_like(
  $$ select public.admin_provision_provider(pg_temp.id('admin'), pg_temp.id('nueva'), 'zz-r1') $$,
  '%ACCOUNT_IN_USE%', 'una cuenta de tienda no se vincula a otra');
reset role;

select is(
  (select status::text from public.providers where id = 'zz-r1')
    || '/' || (select count(*) from public.offers where provider_id = 'zz-r1')::text,
  'active/1', 'vincular no cambia el estado ni las ofertas de la tienda');

-- ---------------------------------------------------------------------------
-- Primer ingreso de la tienda: contraseña y documentos antes de publicar
-- ---------------------------------------------------------------------------

select pg_temp.login_as(pg_temp.id('nueva'));
select is(
  (select jsonb_build_object('role', a -> 'role', 'mustChangePassword', a -> 'mustChangePassword',
     'pending', jsonb_array_length(a -> 'pendingDocuments'), 'store', a -> 'provider' ->> 'displayName')
   from (select public.get_my_account() as a) s),
  '{"role": "provider", "mustChangePassword": true, "pending": 2, "store": "Tienda Nueva"}'::jsonb,
  'la cuenta informa el rol, la tienda y lo pendiente del primer ingreso');
reset role;

select pg_temp.claims_as(pg_temp.id('nueva'));
select throws_like($$ select private.require_active_provider() $$, '%PASSWORD_CHANGE_REQUIRED%',
  'con la contraseña temporal no puede operar');
reset role;

-- Supabase Auth cambia el hash al actualizar la contraseña.
update auth.users set encrypted_password = 'hash-definitivo' where id = pg_temp.id('nueva');
select is((select must_change_password from public.profiles where id = pg_temp.id('nueva')), false,
  'cambiar la contraseña quita la marca');

select pg_temp.claims_as(pg_temp.id('nueva'));
select throws_like($$ select private.require_active_provider() $$, '%CONSENT_REQUIRED%',
  'sin aceptar los documentos vigentes no puede publicar');
reset role;

select pg_temp.login_as(pg_temp.id('nueva'));
select throws_like($$ select public.accept_current_documents('[{"code": "terms", "version": "1.0"}]') $$,
  '%CONSENT_REQUIRED%', 'hay que aceptar todas las versiones vigentes');
select throws_like(
  $$ select public.accept_current_documents('[{"code": "terms", "version": "0.9"}, {"code": "privacy", "version": "1.0"}]') $$,
  '%CONSENT_REQUIRED%', 'una versión vieja no sirve');
select is(
  public.accept_current_documents('[{"code": "terms", "version": "1.0"}, {"code": "privacy", "version": "1.0"}]')
    -> 'pendingDocuments',
  '[]'::jsonb, 'acepta los documentos vigentes');
reset role;

select pg_temp.claims_as(pg_temp.id('nueva'));
select is(private.require_active_provider(),
  (select id from public.providers where user_id = pg_temp.id('nueva')),
  'con todo en regla, opera su tienda');
reset role;

-- Una versión nueva de los términos vuelve a exigir la aceptación.
update public.legal_documents set is_current = false where code = 'terms';
insert into public.legal_documents (code, version, title, content, is_current)
values ('terms', '1.1', 'Términos y condiciones', 'Versión de prueba', true);
select pg_temp.claims_as(pg_temp.id('nueva'));
select throws_like($$ select private.require_active_provider() $$, '%CONSENT_REQUIRED%',
  'una versión nueva de los documentos se acepta antes de volver a publicar');
reset role;
delete from public.legal_documents where code = 'terms' and version = '1.1';
update public.legal_documents set is_current = true where code = 'terms' and version = '1.0';

-- ---------------------------------------------------------------------------
-- Roles exclusivos: solo los clientes compran
-- ---------------------------------------------------------------------------

select pg_temp.login_as(pg_temp.id('nueva'));
select throws_like($$ select public.add_cart_item('zz-r1-o') $$, '%CUSTOMER_ONLY%',
  'una tienda no compra');
select throws_like($$ select public.admin_get_providers() $$, '%FORBIDDEN%',
  'ni ejecuta funciones administrativas');
reset role;

select pg_temp.login_as(pg_temp.id('admin'));
select throws_like($$ select public.get_cart() $$, '%CUSTOMER_ONLY%', 'un administrador no compra');
reset role;

select pg_temp.claims_as(pg_temp.id('admin'));
select throws_like($$ select private.require_active_provider() $$, '%PROVIDER_REQUIRED%',
  'ni publica');
reset role;

select pg_temp.login_as(pg_temp.id('ana'));
select lives_ok($$ select public.add_cart_item('zz-r1-o') $$, 'un cliente sí compra');
reset role;

-- ---------------------------------------------------------------------------
-- El administrador habilita, suspende y edita tiendas
-- ---------------------------------------------------------------------------

select pg_temp.login_as(pg_temp.id('admin'));
select lives_ok(
  $$ select public.admin_validate_store('{"legalName": "Tienda Sur S.A.S.", "displayName": "Tienda Sur",
       "taxId": "900000005-5", "contactEmail": "sur@zz.test"}') $$,
  'el administrador valida los datos antes de crear la cuenta');
select throws_like(
  $$ select public.admin_validate_store('{"legalName": "Tienda Sur S.A.S.", "displayName": "tienda nueva",
       "taxId": "900000005-5", "contactEmail": "sur@zz.test"}') $$,
  '%SIMILAR_STORE_NAME%', 'la validación previa también avisa del nombre parecido');
select is(
  (select p ->> 'accountEmail' from jsonb_array_elements(public.admin_get_providers('nueva s.a.s')) p),
  'tienda.nueva@zz.test', 'lista las tiendas con su cuenta, buscando por razón social');
select is(public.admin_get_provider('zz-r1') ->> 'publishedOffers', '1',
  'el detalle muestra las ofertas publicadas');
select is(public.admin_set_provider_status('zz-r1', 'suspended') ->> 'status', 'suspended',
  'suspende una tienda');
reset role;

select throws_ok($$ select public.get_product('zz-r1-p') $$, 'PGRST', null,
  'las ofertas de una tienda suspendida salen del catálogo');
select pg_temp.claims_as(pg_temp.id('existente'));
select throws_like($$ select private.require_active_provider() $$, '%PROVIDER_NOT_ACTIVE%',
  'una tienda suspendida no opera');
reset role;

select pg_temp.login_as(pg_temp.id('admin'));
select throws_like($$ select public.admin_set_provider_status('zz-r1', 'pending') $$, '%VALIDATION_ERROR%',
  'solo se habilita o se suspende');
select throws_like($$ select public.admin_set_provider_status('no-existe', 'active') $$, '%PROVIDER_NOT_FOUND%',
  'responde 404 si la tienda no existe');
select is(public.admin_set_provider_status('zz-r1', 'active') ->> 'status', 'active',
  'la vuelve a habilitar');
select is(
  public.admin_update_provider('zz-r1', '{"legalName": "Tienda Existente S.A.S.", "displayName": "Tienda Existente Centro",
    "taxId": "900000001-1", "contactEmail": "existente@zz.test"}') ->> 'displayName',
  'Tienda Existente Centro', 'edita el nombre visible');
select throws_like(
  $$ select public.admin_update_provider('zz-r1', '{"legalName": "Tienda Existente S.A.S.", "displayName": "Tienda Existente Centro",
       "taxId": "900000002-2", "contactEmail": "existente@zz.test"}') $$,
  '%TAX_ID_TAKEN%', 'no repite un NIT al editar');
reset role;

-- Regenerar la contraseña temporal (rol de servicio, como la Edge Function).
set local role service_role;
select is(public.admin_provider_account(pg_temp.id('admin'), 'zz-r1'), pg_temp.id('existente'),
  'la función encuentra la cuenta de la tienda');
select throws_like($$ select public.admin_provider_account(pg_temp.id('ana'), 'zz-r1') $$, '%FORBIDDEN%',
  'solo para administradores');
select lives_ok(
  $$ select public.admin_require_password_change(pg_temp.id('admin'),
       (select id from public.providers where user_id = pg_temp.id('nueva'))) $$,
  'después de regenerarla, vuelve a exigir el cambio');
reset role;
select is((select must_change_password from public.profiles where id = pg_temp.id('nueva')), true,
  'la tienda debe cambiarla otra vez');

-- Quitar un administrador también es solo por SQL.
select lives_ok($$ select private.revoke_admin('admin.roles@zz.test') $$, 'el propietario quita un administrador');
select is(pg_temp.role_of(pg_temp.id('admin')), 'customer', 'la cuenta vuelve a ser cliente');

select * from finish();
rollback;
