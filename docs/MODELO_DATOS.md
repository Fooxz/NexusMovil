# Modelo de datos (backend Supabase)

Fuente: las migraciones de `backend/supabase/migrations/`. Si este documento y las migraciones no coinciden,
mandan las migraciones y este archivo se corrige.

## Catálogo (fase 2)

```text
categories 1─* attribute_definitions          (plantilla por categoría)
     │                    │
     1                    1
     *                    *
  products 1─────* product_attributes          (valores tipados, EAV)
     │  1─────* product_images
     1
     *
   offers *─────1 providers
```

| Tabla | Para qué | Notas |
|---|---|---|
| `categories` | Familias y tipos de pieza (RF-012). | `code` es el valor `category` del contrato. `family`: `prebuiltPc` o `part`. `search_terms` alimenta la búsqueda (`procesador`, `placa base`...). Datos de referencia en la migración. |
| `attribute_definitions` | Plantilla de atributos técnicos por categoría (RF-013, RNF-027). | `data_type`: `number`, `text`, `boolean`, `enum`, `enumList`; `unit`, `is_required`, `allowed_values`. Agregar un tipo de pieza o atributo es un `insert`, sin cambios de código. |
| `products` | El producto del catálogo, independiente de quién lo vende. | `specs` y `quick_specs` son texto **solo para mostrar**. |
| `product_attributes` | Valores tipados de cada producto. | Un valor por fila, en la columna de su tipo (`value_number`, `value_text`, `value_bool`, `value_list`). Un trigger exige que el atributo sea de la categoría del producto y que el valor respete el tipo y los valores permitidos (RN-032). Lo usarán el PC Builder (fase 6) y el asistente (fase 7). |
| `product_images` | Imágenes en orden. | `imageUrl` del contrato = `thumb_url` (o `url`) de la primera. |
| `providers` | Proveedores. | `status`: `pending`, `active`, `suspended`, `rejected`. Solo los `active` venden (RN-022). |
| `offers` | Lo que un proveedor vende de un producto (RF-014). | `price_cents` `BIGINT` > 0 y múltiplo de 100; `old_price_cents` > `price_cents`; `stock_units` >= 0. `status`: `draft`, `published`, `paused`, `retired`. Únicos: `(provider_id, external_sku)` para el upsert idempotente de la API de proveedores (RF-023) y `(provider_id, product_id)`. |
| `app_settings` | Parámetros del negocio. | `critical_stock_threshold` = N de `critical` (D3, valor 5). |

### Visibilidad

Un producto aparece en el catálogo si tiene al menos una oferta `published` de un proveedor `active`
(RF-015, RF-035). Su precio es el de la **mejor oferta**: la más barata con stock; si ninguna tiene stock,
la más barata. Su `stockLevel` es el mejor entre sus ofertas.

Estas reglas viven en las vistas `private.visible_offers` y `private.catalog_products`. Las RPC
(`get_products`, `get_product`, `get_related`) las aplican.

### Acceso y seguridad

- Todas las tablas tienen RLS.
- `anon` y `authenticated` solo pueden leer directamente `categories` y `attribute_definitions`, las dos activas. Sirven para armar los filtros.
- Productos, ofertas y proveedores **no** tienen políticas públicas: se leen solo por las RPC del contrato, que son `SECURITY DEFINER` con `search_path` vacío. Así nunca salen `stock_units`, `tax_id` ni las ofertas no publicadas.
- El esquema `private` (vistas y funciones auxiliares) no lo expone la API y los clientes no tienen permisos sobre él.

## Auditoría (fase 2)

`audit_log` registra `INSERT`, `UPDATE` y `DELETE` con:
- tabla, id del registro y acción;
- valores anterior y nuevo (`old_data`, `new_data`) y `changed_fields`;
- `actor_id` (`auth.uid()`), `actor_role` y fecha (RF-081).

Las actualizaciones sin cambios reales no se registran, y los cambios que solo tocan `updated_at` tampoco.

Tablas auditadas hoy: `offers`, `products`, `product_attributes`, `providers`, `categories`,
`attribute_definitions` y `app_settings`. Cada fase nueva agrega el trigger
`private.audit_row_change()` a sus tablas (comisiones, reglas, órdenes, pagos).

La bitácora es de solo inserción: hay triggers que impiden `UPDATE`, `DELETE` y `TRUNCATE` (RNF-030), y ningún cliente la puede leer.
La retención (RNF-031) está pendiente de definir.

## Datos de desarrollo

`backend/supabase/seed.sql` (lo carga `npx supabase db reset`) contiene:
- **3 proveedores:** 2 activos y 1 pendiente.
- **15 productos:** los 6 del mock de la app con los mismos ids, 6 piezas más y 3 computadores armados, con sus atributos tipados.
- **18 ofertas:** incluyen un producto con dos proveedores, niveles `stable`, `critical` y `outOfStock`, una oferta de un proveedor pendiente y una en borrador. Estas dos últimas no deben verse.
