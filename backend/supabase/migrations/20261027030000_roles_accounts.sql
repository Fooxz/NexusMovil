-- Roles y cuentas: cliente, proveedor (tienda) y administrador (RF-005,
-- RNF-002, HU-022, HU-030). Ver docs/MODELO_DATOS.md, sección "Roles".
--
-- - Toda cuenta nace como cliente. El rol nunca sale de los metadatos del
--   registro (los escribe la app) y el usuario no puede cambiarlo: solo puede
--   editar `full_name` y `phone` de su perfil, y un trigger rechaza cualquier
--   cambio de rol que no venga del backend.
-- - Las cuentas de tienda las crea un administrador con la Edge Function
--   `admin-providers`, que usa la clave de servicio en el servidor:
--   `admin_prepare_provider_account`, la cuenta en Auth y
--   `admin_provision_provider` (las dos RPC, solo para el rol de servicio).
-- - El primer administrador se habilita por SQL con `private.grant_admin`,
--   fuera de la API: el esquema private no está expuesto.
-- - Roles exclusivos: solo los clientes compran (`private.require_user`).
--
-- No borra ni reescribe datos: los perfiles existentes quedan como clientes y
-- las tiendas existentes sin cuenta vinculada.

create type public.app_role as enum ('customer', 'provider', 'admin');

-- ---------------------------------------------------------------------------
-- Utilidades
-- ---------------------------------------------------------------------------

-- Clave para comparar nombres: sin mayúsculas, acentos, espacios ni signos.
-- "Mundo PC", "mundo-pc" y "MUNDO P.C." dan la misma clave. Es inmutable para
-- poder indexarla (unaccent con diccionario explícito no depende del entorno).
create function private.name_key(value text) returns text
language sql
immutable
parallel safe
set search_path = ''
as $$
  select regexp_replace(
    lower(extensions.unaccent('extensions.unaccent'::regdictionary, coalesce(value, ''))),
    '[^a-z0-9]', '', 'g');
$$;

-- Como private.raise_api_error, con `details` para la app (por ejemplo, la
-- tienda o el producto con el que choca). PostgREST exige que "details" sea
-- texto: va el JSON serializado.
create function private.raise_api_error_details(
  status integer,
  code text,
  message text,
  details jsonb
) returns void
language plpgsql
stable
set search_path = ''
as $$
begin
  raise sqlstate 'PGRST' using
    message = json_build_object(
      'code', code,
      'message', message,
      'details', details::text,
      'hint', null
    )::text,
    detail = json_build_object('status', status, 'headers', json_build_object())::text;
end;
$$;

-- ---------------------------------------------------------------------------
-- Perfil: rol y contraseña temporal
-- ---------------------------------------------------------------------------

alter table public.profiles
  add column role public.app_role not null default 'customer',
  -- La contraseña es temporal (la generó el administrador): hay que cambiarla
  -- antes de operar. La limpia el trigger de auth.users al cambiarla.
  add column must_change_password boolean not null default false;

-- El usuario solo edita su nombre y teléfono (la política de RLS limita la
-- fila; estos permisos limitan las columnas).
revoke update on public.profiles from anon, authenticated;
grant update (full_name, phone) on public.profiles to authenticated;

-- Segunda barrera: aunque cambiaran los permisos, el rol y la marca de
-- contraseña temporal solo los cambia el backend (funciones del propietario o
-- el rol de servicio), nunca una petición de la app.
create function private.protect_profile_privileges() returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if (new.role is distinct from old.role
      or new.must_change_password is distinct from old.must_change_password)
     and current_user in ('anon', 'authenticated') then
    raise exception 'El rol de la cuenta solo lo cambia NEXUS'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger profiles_protect_privileges
  before update on public.profiles
  for each row execute function private.protect_profile_privileges();

-- Bitácora de cambios de rol (RF-081). Solo el rol: el perfil tiene datos
-- personales que no van a la bitácora.
create function private.audit_role_change() returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.audit_log
    (table_name, record_id, action, old_data, new_data, changed_fields, actor_id, actor_role)
  values (
    'profiles', new.id::text, 'UPDATE',
    jsonb_build_object('role', old.role),
    jsonb_build_object('role', new.role),
    array['role'],
    auth.uid(),
    coalesce(auth.role(), session_user)
  );
  return null;
end;
$$;

create trigger profiles_audit_role
  after update of role on public.profiles
  for each row
  when (old.role is distinct from new.role)
  execute function private.audit_role_change();

-- ---------------------------------------------------------------------------
-- Tiendas: cuenta vinculada y verificación
-- ---------------------------------------------------------------------------

alter table public.providers
  -- Cuenta que opera la tienda. Las tiendas cargadas antes de los roles no
  -- tienen (siguen vendiendo; el administrador puede crearles una).
  add column user_id uuid unique references auth.users (id) on delete set null,
  -- Administrador que creó la tienda tras verificar que existe.
  add column created_by uuid references auth.users (id) on delete set null,
  add column verification_note text
    check (verification_note is null or length(verification_note) <= 500);

-- ---------------------------------------------------------------------------
-- Alta de usuario
-- ---------------------------------------------------------------------------

-- Tickets de alta de cuentas de tienda. Los crea solo el rol de servicio (la
-- Edge Function admin-providers, después de comprobar que quien llama es
-- administrador) justo antes de crear la cuenta en Auth, y el alta los
-- consume. Hacen falta porque la API de administración de Auth inserta el
-- usuario y escribe app_metadata después, en la misma transacción: cuando
-- corre el trigger de alta, la marca de app_metadata todavía no está.
create table private.account_provisioning (
  email text primary key check (email = lower(email)),
  admin_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

-- Igual que antes para el registro público: exige los documentos vigentes y
-- crea el perfil como cliente. La excepción son las cuentas de tienda que crea
-- un administrador (ticket vigente para el correo): aceptan los documentos en
-- su primer ingreso, antes de publicar (`accept_current_documents`,
-- `private.require_active_provider`). El rol se asigna después, en
-- `admin_provision_provider`; aquí la cuenta nace como cliente.
create or replace function private.handle_new_user() returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  accepted jsonb := coalesce(new.raw_user_meta_data -> 'accepted_documents', '[]'::jsonb);
  missing text;
begin
  delete from private.account_provisioning t
  where t.email = lower(new.email)
    and t.created_at > now() - interval '10 minutes';
  if found then
    insert into public.profiles (id, full_name)
    values (new.id, trim(coalesce(new.raw_user_meta_data ->> 'full_name', '')));
    return new;
  end if;

  if jsonb_typeof(accepted) <> 'array' then
    accepted := '[]'::jsonb;
  end if;

  select string_agg(d.code, ', ' order by d.code) into missing
  from public.legal_documents d
  where d.is_current
    and not exists (
      select 1 from jsonb_array_elements(accepted) a
      where a ->> 'code' = d.code and a ->> 'version' = d.version
    );

  if missing is not null then
    raise exception 'CONSENT_REQUIRED: faltan por aceptar %', missing
      using errcode = '23514';
  end if;

  insert into public.profiles (id, full_name)
  values (new.id, trim(coalesce(new.raw_user_meta_data ->> 'full_name', '')));

  insert into public.user_consents (user_id, document_code, document_version)
  select new.id, d.code, d.version
  from public.legal_documents d
  where d.is_current;

  return new;
end;
$$;

-- Al cambiar la contraseña (Supabase Auth actualiza el hash), deja de ser
-- temporal. No hay otra forma de limpiar la marca: la app no puede saltarse
-- el cambio. Al regenerar una temporal, la Edge Function vuelve a marcarla
-- después de cambiarla (`admin_require_password_change`).
create function private.handle_password_change() returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.profiles p
  set must_change_password = false
  where p.id = new.id and p.must_change_password;
  return null;
end;
$$;

create trigger on_auth_user_password_changed
  after update of encrypted_password on auth.users
  for each row
  when (old.encrypted_password is distinct from new.encrypted_password)
  execute function private.handle_password_change();

-- ---------------------------------------------------------------------------
-- Controles de acceso para las RPC
-- ---------------------------------------------------------------------------

create function private.has_current_consents(p_user_id uuid) returns boolean
language sql
stable
set search_path = ''
as $$
  select not exists (
    select 1 from public.legal_documents d
    where d.is_current
      and not exists (
        select 1 from public.user_consents c
        where c.user_id = p_user_id
          and c.document_code = d.code
          and c.document_version = d.version
      )
  );
$$;

create function private.require_admin() returns uuid
language plpgsql
stable
set search_path = ''
as $$
begin
  if auth.uid() is null then
    perform private.raise_api_error(401, 'AUTH_REQUIRED', 'Inicia sesión para continuar');
  end if;
  if not exists (
    select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'
  ) then
    perform private.raise_api_error(403, 'FORBIDDEN', 'Esta función es solo para administradores de NEXUS');
  end if;
  return auth.uid();
end;
$$;

-- Tienda de la cuenta, si puede operar: rol proveedor, tienda activa,
-- contraseña definitiva y documentos vigentes aceptados (HU-015, RN-022,
-- RF-007). Devuelve el id de la tienda; las RPC del proveedor filtran por él.
create function private.require_active_provider() returns text
language plpgsql
stable
set search_path = ''
as $$
declare
  account public.profiles;
  store public.providers;
begin
  if auth.uid() is null then
    perform private.raise_api_error(401, 'AUTH_REQUIRED', 'Inicia sesión para continuar');
  end if;

  select * into account from public.profiles p where p.id = auth.uid();
  select * into store from public.providers pr where pr.user_id = auth.uid();

  if account.role is distinct from 'provider' or store.id is null then
    perform private.raise_api_error(403, 'PROVIDER_REQUIRED', 'Esta función es solo para tiendas');
  end if;
  if store.status <> 'active' then
    perform private.raise_api_error(403, 'PROVIDER_NOT_ACTIVE',
      'Tu tienda no está habilitada. Comunícate con NEXUS.');
  end if;
  if account.must_change_password then
    perform private.raise_api_error(403, 'PASSWORD_CHANGE_REQUIRED',
      'Cambia tu contraseña temporal para continuar');
  end if;
  if not private.has_current_consents(auth.uid()) then
    perform private.raise_api_error(403, 'CONSENT_REQUIRED',
      'Acepta los términos y la política de datos vigentes para continuar');
  end if;

  return store.id;
end;
$$;

-- Roles exclusivos: solo los clientes compran. Las cuentas de tienda y de
-- administración no usan el carrito ni el checkout, que llaman a esta función.
-- Una cuenta sin perfil se trata como cliente, como antes de los roles.
create or replace function private.require_user() returns uuid
language plpgsql
stable
set search_path = ''
as $$
begin
  if auth.uid() is null then
    perform private.raise_api_error(401, 'AUTH_REQUIRED', 'Inicia sesión para usar tu carrito');
  end if;
  if exists (
    select 1 from public.profiles p where p.id = auth.uid() and p.role <> 'customer'
  ) then
    perform private.raise_api_error(403, 'CUSTOMER_ONLY',
      'Las cuentas de tienda y de administración no compran en NEXUS');
  end if;
  return auth.uid();
end;
$$;

-- ---------------------------------------------------------------------------
-- Cuenta propia
-- ---------------------------------------------------------------------------

create function private.provider_json(store public.providers) returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'id', store.id,
    'displayName', store.display_name,
    'status', store.status
  );
$$;

-- Rol, tienda y pendientes del primer ingreso. La app lo usa para elegir la
-- navegación; las RPC no confían en lo que la app crea saber del rol.
create function public.get_my_account() returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  account public.profiles;
  store public.providers;
  pending jsonb;
begin
  if auth.uid() is null then
    perform private.raise_api_error(401, 'AUTH_REQUIRED', 'Inicia sesión para continuar');
  end if;

  select * into account from public.profiles p where p.id = auth.uid();
  select * into store from public.providers pr where pr.user_id = auth.uid();

  select coalesce(jsonb_agg(jsonb_build_object(
      'code', d.code,
      'version', d.version,
      'title', d.title
    ) order by d.code), '[]'::jsonb)
  into pending
  from public.legal_documents d
  where d.is_current
    and not exists (
      select 1 from public.user_consents c
      where c.user_id = auth.uid()
        and c.document_code = d.code
        and c.document_version = d.version
    );

  return jsonb_build_object(
    'userId', auth.uid(),
    'role', coalesce(account.role, 'customer'),
    'fullName', account.full_name,
    'mustChangePassword', coalesce(account.must_change_password, false),
    'pendingDocuments', pending,
    'provider', case when store.id is null then null else private.provider_json(store) end
  );
end;
$$;

-- Registra la aceptación de las versiones vigentes (RF-007). La usan las
-- cuentas de tienda en su primer ingreso y cualquiera cuando se publica una
-- versión nueva. Hay que enviar exactamente las versiones vigentes.
create function public.accept_current_documents(documents jsonb) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  missing text;
begin
  if auth.uid() is null then
    perform private.raise_api_error(401, 'AUTH_REQUIRED', 'Inicia sesión para continuar');
  end if;
  if documents is null or jsonb_typeof(documents) <> 'array' then
    perform private.raise_api_error(400, 'VALIDATION_ERROR',
      'documents debe ser una lista de {code, version}');
  end if;

  select string_agg(d.code, ', ' order by d.code) into missing
  from public.legal_documents d
  where d.is_current
    and not exists (
      select 1 from jsonb_array_elements(documents) a
      where a ->> 'code' = d.code and a ->> 'version' = d.version
    );

  if missing is not null then
    perform private.raise_api_error(400, 'CONSENT_REQUIRED',
      format('Faltan por aceptar las versiones vigentes de: %s', missing));
  end if;

  insert into public.user_consents (user_id, document_code, document_version)
  select auth.uid(), d.code, d.version
  from public.legal_documents d
  where d.is_current
  on conflict (user_id, document_code, document_version) do nothing;

  return public.get_my_account();
end;
$$;

-- ---------------------------------------------------------------------------
-- Administración de tiendas (solo administradores)
-- ---------------------------------------------------------------------------

create function private.admin_provider_json(store public.providers) returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'id', store.id,
    'legalName', store.legal_name,
    'displayName', store.display_name,
    'taxId', store.tax_id,
    'contactEmail', store.contact_email,
    'status', store.status,
    'verificationNote', store.verification_note,
    'accountEmail', (select u.email from auth.users u where u.id = store.user_id),
    'publishedOffers', (
      select count(*) from public.offers o
      where o.provider_id = store.id and o.status = 'published'
    ),
    'createdAt', store.created_at
  );
$$;

-- Datos de una tienda validados para crearla o editarla. `current_id` es la
-- tienda que se edita (null al crear). Responde VALIDATION_ERROR,
-- TAX_ID_TAKEN o SIMILAR_STORE_NAME (otra tienda con un nombre visible que da
-- la misma clave; se acepta con `confirm_similar_name`, porque dos negocios
-- distintos pueden llamarse igual: ver docs/MODELO_DATOS.md).
create function private.validate_store(
  store jsonb,
  current_id text,
  confirm_similar_name boolean
) returns void
language plpgsql
stable
set search_path = ''
as $$
declare
  similar_store public.providers;
begin
  if store is null or jsonb_typeof(store) <> 'object' then
    perform private.raise_api_error(400, 'VALIDATION_ERROR', 'Faltan los datos de la tienda');
  end if;
  if length(trim(coalesce(store ->> 'legalName', ''))) not between 2 and 160 then
    perform private.raise_api_error(400, 'VALIDATION_ERROR', 'La razón social debe tener de 2 a 160 caracteres');
  end if;
  if length(trim(coalesce(store ->> 'displayName', ''))) not between 2 and 60 then
    perform private.raise_api_error(400, 'VALIDATION_ERROR', 'El nombre visible debe tener de 2 a 60 caracteres');
  end if;
  if trim(coalesce(store ->> 'taxId', '')) !~ '^[0-9]{6,12}(-[0-9])?$' then
    perform private.raise_api_error(400, 'VALIDATION_ERROR', 'El NIT debe tener el formato 900123456-7');
  end if;
  if trim(coalesce(store ->> 'contactEmail', '')) !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
    perform private.raise_api_error(400, 'VALIDATION_ERROR', 'El correo de contacto no es válido');
  end if;
  if length(coalesce(store ->> 'verificationNote', '')) > 500 then
    perform private.raise_api_error(400, 'VALIDATION_ERROR', 'La nota de verificación admite hasta 500 caracteres');
  end if;

  if exists (
    select 1 from public.providers pr
    where pr.tax_id = trim(store ->> 'taxId')
      and pr.id is distinct from current_id
  ) then
    perform private.raise_api_error(409, 'TAX_ID_TAKEN', 'Ya hay una tienda con ese NIT');
  end if;

  if not coalesce(confirm_similar_name, false) then
    select * into similar_store
    from public.providers pr
    where private.name_key(pr.display_name) = private.name_key(store ->> 'displayName')
      and pr.id is distinct from current_id
    limit 1;
    if similar_store.id is not null then
      perform private.raise_api_error_details(409, 'SIMILAR_STORE_NAME',
        format('Ya hay una tienda llamada %s. Confirma si es otro negocio.', similar_store.display_name),
        jsonb_build_object('providerId', similar_store.id, 'displayName', similar_store.display_name));
    end if;
  end if;
end;
$$;

-- Validación previa al alta: la Edge Function la llama antes de crear la
-- cuenta en Auth, para no crear y borrar cuentas por un error de datos. El
-- alta vuelve a validar (admin_provision_provider).
create function public.admin_validate_store(
  store jsonb,
  confirm_similar_name boolean default false
) returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform private.require_admin();
  perform private.validate_store(admin_validate_store.store, null, admin_validate_store.confirm_similar_name);
end;
$$;

create function public.admin_get_providers(search text default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  pattern text := private.search_pattern(admin_get_providers.search);
begin
  perform private.require_admin();
  return (
    select coalesce(jsonb_agg(private.admin_provider_json(pr) order by lower(pr.display_name), pr.id), '[]'::jsonb)
    from public.providers pr
    where pattern is null
      or private.normalize_search(pr.display_name) like pattern
      or private.normalize_search(pr.legal_name) like pattern
      or pr.tax_id like pattern
  );
end;
$$;

create function public.admin_get_provider(id text) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  store public.providers;
begin
  perform private.require_admin();
  select * into store from public.providers pr where pr.id = admin_get_provider.id;
  if not found then
    perform private.raise_api_error(404, 'PROVIDER_NOT_FOUND', 'No existe esa tienda');
  end if;
  return private.admin_provider_json(store);
end;
$$;

-- Habilita o suspende una tienda (RF-011). Suspendida, sus ofertas salen del
-- catálogo (private.visible_offers) y sus RPC responden PROVIDER_NOT_ACTIVE.
create function public.admin_set_provider_status(id text, status text) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  store public.providers;
begin
  perform private.require_admin();
  if admin_set_provider_status.status is null
     or admin_set_provider_status.status not in ('active', 'suspended') then
    perform private.raise_api_error(400, 'VALIDATION_ERROR', 'status debe ser "active" o "suspended"');
  end if;

  update public.providers pr
  set status = admin_set_provider_status.status::public.provider_status
  where pr.id = admin_set_provider_status.id
  returning * into store;

  if not found then
    perform private.raise_api_error(404, 'PROVIDER_NOT_FOUND', 'No existe esa tienda');
  end if;
  return private.admin_provider_json(store);
end;
$$;

-- Edita los datos de la tienda. El nombre visible lo cambia solo un
-- administrador: es lo que identifica a la tienda en cada tarjeta.
create function public.admin_update_provider(
  id text,
  store jsonb,
  confirm_similar_name boolean default false
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  updated public.providers;
begin
  perform private.require_admin();
  if not exists (select 1 from public.providers pr where pr.id = admin_update_provider.id) then
    perform private.raise_api_error(404, 'PROVIDER_NOT_FOUND', 'No existe esa tienda');
  end if;
  perform private.validate_store(admin_update_provider.store, admin_update_provider.id,
    admin_update_provider.confirm_similar_name);

  update public.providers pr
  set legal_name = trim(admin_update_provider.store ->> 'legalName'),
      display_name = trim(admin_update_provider.store ->> 'displayName'),
      tax_id = trim(admin_update_provider.store ->> 'taxId'),
      contact_email = lower(trim(admin_update_provider.store ->> 'contactEmail')),
      verification_note = nullif(trim(admin_update_provider.store ->> 'verificationNote'), '')
  where pr.id = admin_update_provider.id
  returning * into updated;

  return private.admin_provider_json(updated);
end;
$$;

-- ---------------------------------------------------------------------------
-- Alta de cuentas de tienda (solo rol de servicio: Edge Function
-- admin-providers, después de verificar que quien llama es administrador)
-- ---------------------------------------------------------------------------

-- Primer paso del alta: comprueba el administrador y el correo y deja el
-- ticket para que el alta de la cuenta en Auth no exija los documentos.
create function public.admin_prepare_provider_account(admin_id uuid, email text) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  normalized text := lower(trim(coalesce(admin_prepare_provider_account.email, '')));
begin
  if not exists (
    select 1 from public.profiles p where p.id = admin_prepare_provider_account.admin_id and p.role = 'admin'
  ) then
    perform private.raise_api_error(403, 'FORBIDDEN', 'Solo un administrador crea cuentas de tienda');
  end if;
  if normalized !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
    perform private.raise_api_error(400, 'VALIDATION_ERROR', 'El correo de la cuenta no es válido');
  end if;
  if exists (select 1 from auth.users u where lower(u.email) = normalized) then
    perform private.raise_api_error(409, 'EMAIL_EXISTS', 'Ya existe una cuenta con ese correo. Usa otro para la tienda.');
  end if;

  delete from private.account_provisioning t where t.created_at <= now() - interval '10 minutes';
  insert into private.account_provisioning (email, admin_id)
  values (normalized, admin_prepare_provider_account.admin_id)
  on conflict on constraint account_provisioning_pkey
  do update set admin_id = excluded.admin_id, created_at = now();
end;
$$;

-- Convierte en cuenta de tienda una cuenta recién creada por la Edge Function
-- y la vincula a una tienda: la existente `provider_id` (sin cuenta) o una
-- nueva con `store`. La cuenta queda con contraseña temporal.
create function public.admin_provision_provider(
  admin_id uuid,
  user_id uuid,
  provider_id text default null,
  store jsonb default null,
  confirm_similar_name boolean default false
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  account public.profiles;
  linked public.providers;
begin
  if not exists (
    select 1 from public.profiles p where p.id = admin_provision_provider.admin_id and p.role = 'admin'
  ) then
    perform private.raise_api_error(403, 'FORBIDDEN', 'Solo un administrador crea cuentas de tienda');
  end if;

  -- Solo cuentas creadas por el flujo de administración, todavía sin rol.
  select p.* into account
  from public.profiles p
  join auth.users u on u.id = p.id
  where p.id = admin_provision_provider.user_id
    and coalesce(u.raw_app_meta_data ->> 'nexus_provisioned', '') = 'true';
  if account.id is null then
    perform private.raise_api_error(400, 'VALIDATION_ERROR', 'La cuenta no fue creada por el flujo de tiendas');
  end if;
  if account.role <> 'customer'
     or exists (select 1 from public.providers pr where pr.user_id = account.id) then
    perform private.raise_api_error(409, 'ACCOUNT_IN_USE', 'La cuenta ya tiene un rol asignado');
  end if;

  if (admin_provision_provider.provider_id is null) = (admin_provision_provider.store is null) then
    perform private.raise_api_error(400, 'VALIDATION_ERROR', 'Envía provider_id o store, no ambos');
  end if;

  if admin_provision_provider.provider_id is not null then
    update public.providers pr
    set user_id = account.id
    where pr.id = admin_provision_provider.provider_id and pr.user_id is null
    returning * into linked;
    if linked.id is null then
      if exists (select 1 from public.providers pr where pr.id = admin_provision_provider.provider_id) then
        perform private.raise_api_error(409, 'PROVIDER_HAS_ACCOUNT', 'La tienda ya tiene una cuenta');
      end if;
      perform private.raise_api_error(404, 'PROVIDER_NOT_FOUND', 'No existe esa tienda');
    end if;
  else
    perform private.validate_store(admin_provision_provider.store, null,
      admin_provision_provider.confirm_similar_name);
    insert into public.providers
      (legal_name, display_name, tax_id, contact_email, status, user_id, created_by, verification_note)
    values (
      trim(admin_provision_provider.store ->> 'legalName'),
      trim(admin_provision_provider.store ->> 'displayName'),
      trim(admin_provision_provider.store ->> 'taxId'),
      lower(trim(admin_provision_provider.store ->> 'contactEmail')),
      'active',
      account.id,
      admin_provision_provider.admin_id,
      nullif(trim(admin_provision_provider.store ->> 'verificationNote'), '')
    )
    returning * into linked;
  end if;

  update public.profiles p
  set role = 'provider', must_change_password = true
  where p.id = account.id;

  return private.admin_provider_json(linked);
end;
$$;

-- Después de regenerar la contraseña temporal de una tienda (la Edge Function
-- la cambia primero; el trigger de auth.users limpia la marca), la vuelve a
-- exigir.
create function public.admin_require_password_change(admin_id uuid, provider_id text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  store public.providers;
begin
  if not exists (
    select 1 from public.profiles p where p.id = admin_require_password_change.admin_id and p.role = 'admin'
  ) then
    perform private.raise_api_error(403, 'FORBIDDEN', 'Solo un administrador regenera contraseñas');
  end if;
  select * into store from public.providers pr where pr.id = admin_require_password_change.provider_id;
  if store.user_id is null then
    perform private.raise_api_error(404, 'PROVIDER_NOT_FOUND', 'La tienda no existe o no tiene cuenta');
  end if;

  update public.profiles p set must_change_password = true where p.id = store.user_id;
  return private.admin_provider_json(store);
end;
$$;

-- Cuenta de la tienda, para que la Edge Function regenere su contraseña.
create function public.admin_provider_account(admin_id uuid, provider_id text) returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  account_id uuid;
begin
  if not exists (
    select 1 from public.profiles p where p.id = admin_provider_account.admin_id and p.role = 'admin'
  ) then
    perform private.raise_api_error(403, 'FORBIDDEN', 'Solo un administrador consulta cuentas de tienda');
  end if;
  select pr.user_id into account_id from public.providers pr where pr.id = admin_provider_account.provider_id;
  if account_id is null then
    perform private.raise_api_error(404, 'PROVIDER_NOT_FOUND', 'La tienda no existe o no tiene cuenta');
  end if;
  return account_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Administradores (solo por SQL, como propietario de la base)
-- ---------------------------------------------------------------------------

-- Habilita un administrador. Se ejecuta en el SQL Editor de Supabase o con
-- `supabase db query`, nunca desde la app: el esquema private no está en la
-- API y nadie más tiene permiso de ejecución. La cuenta debe existir (registro
-- normal o Authentication > Add user) y no puede ser de una tienda.
create function private.grant_admin(p_email text) returns void
language plpgsql
set search_path = ''
as $$
declare
  account_id uuid;
begin
  select u.id into account_id from auth.users u where lower(u.email) = lower(trim(p_email));
  if account_id is null then
    raise exception 'No existe una cuenta con el correo %', p_email;
  end if;
  if exists (select 1 from public.providers pr where pr.user_id = account_id) then
    raise exception 'La cuenta % es de una tienda y no puede ser administradora', p_email;
  end if;
  update public.profiles p set role = 'admin', must_change_password = false where p.id = account_id;
  if not found then
    raise exception 'La cuenta % no tiene perfil', p_email;
  end if;
end;
$$;

create function private.revoke_admin(p_email text) returns void
language plpgsql
set search_path = ''
as $$
begin
  update public.profiles p
  set role = 'customer'
  from auth.users u
  where u.id = p.id and lower(u.email) = lower(trim(p_email)) and p.role = 'admin';
  if not found then
    raise exception 'No hay un administrador con el correo %', p_email;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Permisos
-- ---------------------------------------------------------------------------

-- Supabase otorga EXECUTE de las funciones nuevas de public directamente a
-- anon y authenticated (privilegios por defecto), así que se revocan de forma
-- explícita, no solo de public.
revoke all on function private.grant_admin(text) from public;
revoke all on function private.revoke_admin(text) from public;

revoke all on function public.get_my_account() from public, anon;
revoke all on function public.accept_current_documents(jsonb) from public, anon;
revoke all on function public.admin_validate_store(jsonb, boolean) from public, anon;
revoke all on function public.admin_get_providers(text) from public, anon;
revoke all on function public.admin_get_provider(text) from public, anon;
revoke all on function public.admin_set_provider_status(text, text) from public, anon;
revoke all on function public.admin_update_provider(text, jsonb, boolean) from public, anon;
revoke all on function public.admin_prepare_provider_account(uuid, text)
  from public, anon, authenticated;
revoke all on function public.admin_provision_provider(uuid, uuid, text, jsonb, boolean)
  from public, anon, authenticated;
revoke all on function public.admin_require_password_change(uuid, text)
  from public, anon, authenticated;
revoke all on function public.admin_provider_account(uuid, text)
  from public, anon, authenticated;

grant execute on function public.get_my_account() to authenticated;
grant execute on function public.accept_current_documents(jsonb) to authenticated;
-- Las de administración se otorgan a authenticated y cada una exige el rol
-- administrador (private.require_admin) leyendo el perfil en cada llamada.
grant execute on function public.admin_validate_store(jsonb, boolean) to authenticated;
grant execute on function public.admin_get_providers(text) to authenticated;
grant execute on function public.admin_get_provider(text) to authenticated;
grant execute on function public.admin_set_provider_status(text, text) to authenticated;
grant execute on function public.admin_update_provider(text, jsonb, boolean) to authenticated;
grant execute on function public.admin_prepare_provider_account(uuid, text) to service_role;
grant execute on function public.admin_provision_provider(uuid, uuid, text, jsonb, boolean) to service_role;
grant execute on function public.admin_require_password_change(uuid, text) to service_role;
grant execute on function public.admin_provider_account(uuid, text) to service_role;
