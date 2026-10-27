-- Cambio de alcance (2026-10-27): NEXUS vende solo piezas de computador.
-- Los computadores armados salen del catálogo: el cliente arma su equipo por
-- piezas en el PC Builder, o con el asistente, que propone una configuración
-- validada por el motor de compatibilidad.
--
-- Esta migración:
-- - quita la vista 3D de armados (prebuilt_components y get_prebuilt_scene);
-- - borra los computadores armados con sus ofertas, atributos e imágenes;
-- - borra la categoría prebuiltPc y su plantilla de atributos;
-- - impide crear categorías que no sean piezas.
-- El valor 'prebuiltPc' queda en el tipo product_family porque PostgreSQL no
-- permite quitar valores de un enum; ninguna categoría puede usarlo.

-- ---------------------------------------------------------------------------
-- Vista 3D de los armados
-- ---------------------------------------------------------------------------

drop function public.get_prebuilt_scene(text);
drop table public.prebuilt_components;
drop function private.validate_prebuilt_component();

-- ---------------------------------------------------------------------------
-- Computadores armados del catálogo
-- ---------------------------------------------------------------------------

do $$
begin
  -- Una orden conserva sus ítems (RN-026): si un armado ya se vendió, no se
  -- borra y hay que retirarlo a mano.
  if exists (
    select 1
    from public.order_items i
    join public.products p on p.id = i.product_id
    where p.category_code = 'prebuiltPc'
  ) then
    raise exception 'Hay órdenes con computadores armados: retíralos (offers.status = retired) en lugar de borrarlos';
  end if;
end;
$$;

delete from public.commission_rules r
using public.products p
where p.id = r.product_id and p.category_code = 'prebuiltPc';

-- cart_items se borra en cascada con las ofertas.
delete from public.offers o
using public.products p
where p.id = o.product_id and p.category_code = 'prebuiltPc';

delete from public.component_models m
using public.products p
where p.id = m.product_id and p.category_code = 'prebuiltPc';

delete from public.product_attributes a
using public.products p
where p.id = a.product_id and p.category_code = 'prebuiltPc';

delete from public.product_images i
using public.products p
where p.id = i.product_id and p.category_code = 'prebuiltPc';

delete from public.products where category_code = 'prebuiltPc';

delete from public.attribute_definitions where category_code = 'prebuiltPc';
delete from public.component_models where category_code = 'prebuiltPc';
delete from public.categories where code = 'prebuiltPc';

-- Solo piezas (RN-010, alcance 2026-10-27).
alter table public.categories drop constraint categories_check;
alter table public.categories
  add constraint categories_parts_only check (family = 'part');

-- ---------------------------------------------------------------------------
-- Filtros del catálogo
-- ---------------------------------------------------------------------------

-- `family` se conserva en la API por compatibilidad (API_CONTRATO v0.11):
-- solo admite "part", que equivale a no filtrar.
create or replace function private.validate_catalog_filters(p_family text, p_category text)
returns void
language plpgsql
stable
set search_path = ''
as $$
begin
  if p_family is not null and p_family <> 'part' then
    perform private.raise_api_error(400, 'VALIDATION_ERROR',
      format('family desconocida: %s. NEXUS solo vende piezas', p_family));
  end if;
  if p_category is not null and not exists (
    select 1 from public.categories c
    where c.code = p_category and c.is_active
  ) then
    perform private.raise_api_error(400, 'VALIDATION_ERROR',
      format('category desconocida: %s', p_category));
  end if;
end;
$$;
