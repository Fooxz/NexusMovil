-- Fase 2: bitácora de auditoría (RF-081, RNF-030, RN-021).
-- Registra actor, fecha y valores anterior y nuevo de los cambios relevantes.
-- Es de solo inserción: ningún rol puede modificarla ni borrarla.
-- La retención (RNF-031) queda pendiente de la política del negocio.

create table public.audit_log (
  id bigint generated always as identity primary key,
  occurred_at timestamptz not null default now(),
  table_name text not null,
  record_id text not null,
  action text not null check (action in ('INSERT', 'UPDATE', 'DELETE')),
  old_data jsonb,
  new_data jsonb,
  changed_fields text[],
  actor_id uuid,
  actor_role text
);

create index audit_log_record_idx
  on public.audit_log (table_name, record_id, occurred_at desc);
create index audit_log_occurred_idx on public.audit_log (occurred_at desc);

-- Sin políticas: invisible para anon y authenticated. Se consulta con rol
-- administrador (fase 11) o desde Studio.
alter table public.audit_log enable row level security;
revoke all on public.audit_log from anon, authenticated;

-- Trigger genérico. El argumento opcional es la columna que identifica el
-- registro (por defecto, "id").
create function private.audit_row_change() returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  old_row jsonb;
  new_row jsonb;
  changed text[];
  key_column text := coalesce(tg_argv[0], 'id');
begin
  if tg_op <> 'INSERT' then old_row := to_jsonb(old); end if;
  if tg_op <> 'DELETE' then new_row := to_jsonb(new); end if;

  if tg_op = 'UPDATE' then
    select array_agg(n.key order by n.key) into changed
    from jsonb_each(new_row) n
    where n.value is distinct from old_row -> n.key
      and n.key <> 'updated_at';

    -- Una actualización sin cambios reales no se registra.
    if changed is null then
      return null;
    end if;
  end if;

  insert into public.audit_log
    (table_name, record_id, action, old_data, new_data, changed_fields, actor_id, actor_role)
  values (
    tg_table_name,
    coalesce(new_row, old_row) ->> key_column,
    tg_op,
    old_row,
    new_row,
    changed,
    auth.uid(),
    coalesce(auth.role(), session_user)
  );

  return null;
end;
$$;

create function private.prevent_audit_mutation() returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'audit_log es de solo inserción'
    using errcode = '42501';
end;
$$;

create trigger audit_log_immutable
  before update or delete on public.audit_log
  for each row execute function private.prevent_audit_mutation();

create trigger audit_log_no_truncate
  before truncate on public.audit_log
  for each statement execute function private.prevent_audit_mutation();

-- Tablas auditadas del catálogo. Las de comisiones, reglas, órdenes y pagos
-- se agregan en sus fases con el mismo trigger.
create trigger offers_audit
  after insert or update or delete on public.offers
  for each row execute function private.audit_row_change();

create trigger products_audit
  after insert or update or delete on public.products
  for each row execute function private.audit_row_change();

create trigger product_attributes_audit
  after insert or update or delete on public.product_attributes
  for each row execute function private.audit_row_change('product_id');

create trigger providers_audit
  after insert or update or delete on public.providers
  for each row execute function private.audit_row_change();

create trigger categories_audit
  after insert or update or delete on public.categories
  for each row execute function private.audit_row_change('code');

create trigger attribute_definitions_audit
  after insert or update or delete on public.attribute_definitions
  for each row execute function private.audit_row_change();

create trigger app_settings_audit
  after insert or update or delete on public.app_settings
  for each row execute function private.audit_row_change('key');
