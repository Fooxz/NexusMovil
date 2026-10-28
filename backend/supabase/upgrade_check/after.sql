-- Prueba de migración, paso 2 de 2: compara la base migrada con la foto de
-- before.sql y verifica los datos nuevos. Procedimiento en README.md.
-- El resultado es una fila: OK, o FALLA con la lista de comprobaciones que no
-- pasaron.

create temporary table upgrade_result (
  check_name text primary key,
  ok boolean not null
);

-- Lo que existía no cambió: conteos, filas y respuestas de las RPC. Las
-- migraciones pueden agregar parámetros a app_settings, pero no cambiar los
-- que ya estaban.
insert into upgrade_result
select coalesce(s.key, c.key),
       s.value is not distinct from c.value
         or (s.key = 'rows:app_settings' and s.value <@ c.value)
from upgrade_check.snapshot s
full join upgrade_check.capture() c on c.key = s.key;

-- Datos nuevos de cada migración (solo si ya está aplicada).
do $$
begin
  -- Roles y cuentas
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'profiles' and column_name = 'role'
  ) then
    insert into upgrade_result values
      ('roles:perfiles_existentes_quedan_como_clientes',
        not exists (select 1 from public.profiles p where p.role <> 'customer' or p.must_change_password)),
      ('roles:tiendas_existentes_sin_cuenta',
        not exists (select 1 from public.providers pr where pr.user_id is not null or pr.created_by is not null)),
      ('roles:tiendas_existentes_conservan_su_estado',
        (select count(*) from public.providers pr where pr.status = 'active') = 6
        and (select status from public.providers where id = 'prov-norte') = 'pending');
  end if;

  -- Catálogo por oferta: una tarjeta por cada oferta visible.
  if to_regproc('public.get_offers') is not null then
    insert into upgrade_result values
      ('ofertas:una_por_cada_oferta_visible',
        (public.get_offers() ->> 'total')::bigint = (
          select count(*)
          from private.visible_offers o
          join public.products p on p.id = o.product_id
          join public.categories c on c.code = p.category_code and c.is_active));
  end if;

  -- Publicaciones de tiendas: el catálogo existente no tiene creador y la
  -- clave contra duplicados se pudo crear.
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'products' and column_name = 'created_by_provider_id'
  ) then
    insert into upgrade_result values
      ('productos:catalogo_existente_sin_creador',
        not exists (select 1 from public.products p where p.created_by_provider_id is not null)),
      ('productos:indice_de_duplicados_creado',
        to_regclass('public.products_catalog_key_idx') is not null);
  end if;
end;
$$;

select case when count(*) filter (where not ok) = 0 then 'OK' else 'FALLA' end as resultado,
       count(*) as comprobaciones,
       string_agg(check_name, ', ' order by check_name) filter (where not ok) as fallas
from upgrade_result;
