-- Fase 7: asistente de recomendación (HU-006, RF-036 a 045, RF-089).
-- docs/API_CONTRATO.md, parte 4. La Edge Function `assistant` conversa con el
-- modelo (Gemini) y solo lee el catálogo con las RPC públicas; nunca datos de
-- otros usuarios (RNF-009).

-- ---------------------------------------------------------------------------
-- Trazabilidad (RF-043, RNF-034)
-- ---------------------------------------------------------------------------

create table public.assistant_interactions (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  -- Nulo si quien preguntó no había iniciado sesión.
  user_id uuid references auth.users (id) on delete set null,
  -- Conversación (lo genera la app) y cliente (hash, no la IP) para limitar
  -- el uso.
  session_id text not null check (length(session_id) between 8 and 64),
  client_hash text not null check (length(client_hash) = 64),
  user_message text not null check (length(user_message) between 1 and 1000),
  reply_type text not null
    check (reply_type in ('question', 'recommendation', 'noMatch', 'unavailable')),
  reply jsonb not null,
  product_ids text[] not null default '{}',
  offer_ids text[] not null default '{}',
  model text,
  model_calls integer not null default 0 check (model_calls >= 0),
  -- Herramientas que usó el modelo, en orden: [{name, args}].
  tool_calls jsonb not null default '[]' check (jsonb_typeof(tool_calls) = 'array'),
  latency_ms integer check (latency_ms >= 0)
);

comment on table public.assistant_interactions is
  'Cada pregunta al asistente y su respuesta: qué recomendó y con qué modelo (RF-043).';

create index assistant_interactions_client_idx
  on public.assistant_interactions (client_hash, created_at desc);
create index assistant_interactions_user_idx
  on public.assistant_interactions (user_id, created_at desc)
  where user_id is not null;

-- Solo la Edge Function (rol de servicio) lee y escribe.
alter table public.assistant_interactions enable row level security;
revoke all on public.assistant_interactions from anon, authenticated;

-- ---------------------------------------------------------------------------
-- Atributos técnicos para justificar recomendaciones (RF-038)
-- ---------------------------------------------------------------------------

-- Atributos tipados de productos visibles, con etiqueta y unidad, en el orden
-- de la plantilla. Los productos ocultos o inexistentes se omiten.
create function public.get_product_attributes(product_ids text[]) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if product_ids is null or cardinality(product_ids) > 30 then
    perform private.raise_api_error(400, 'VALIDATION_ERROR', 'Envía entre 0 y 30 productos');
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'productId', cp.id,
      'attributes', (
        select coalesce(jsonb_agg(jsonb_build_object(
            'key', d.key,
            'label', d.label,
            'value', private.part_attribute(cp.id, d.key),
            'unit', d.unit
          ) order by d.sort_order, d.key), '[]'::jsonb)
        from public.attribute_definitions d
        join public.product_attributes pa on pa.attribute_id = d.id and pa.product_id = cp.id
        where d.category_code = cp.category
      )
    ) order by requested.position)
    from unnest(product_ids) with ordinality as requested(id, position)
    join private.catalog_products cp on cp.id = requested.id
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.get_product_attributes(text[]) from public;
grant execute on function public.get_product_attributes(text[]) to anon, authenticated;
