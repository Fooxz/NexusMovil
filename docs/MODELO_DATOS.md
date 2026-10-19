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
(`get_products`, `get_product`, `get_related` y `get_catalog_brands`) las aplican. Los filtros de marca y
precio, y el orden por precio, usan esa mejor oferta (API_CONTRATO v0.4).

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

## Cuentas (fase 4)

La cuenta (correo y contraseña) vive en `auth.users`, que administra Supabase Auth. Las tablas propias son:

| Tabla | Para qué | Acceso de clientes |
|---|---|---|
| `legal_documents` | Términos (`terms`) y política de datos (`privacy`), versionados. Solo una versión vigente por documento (`is_current`). | Lectura pública de las vigentes: se leen antes de registrarse. |
| `profiles` | Nombre completo (2 a 120 caracteres) y teléfono opcional (7 a 15 dígitos). Mismo `id` que `auth.users`. | Cada usuario lee y edita el suyo. No puede crearlo ni borrarlo. |
| `user_consents` | Constancia de qué versión de cada documento aceptó cada usuario y cuándo (RF-007). | Cada usuario lee los suyos. No puede crearlos, cambiarlos ni borrarlos. |
| `addresses` | Direcciones de entrega: nombre, quién recibe, teléfono, departamento, ciudad, dirección y detalles (RF-004). Supuesto: Colombia (S-02). | Cada usuario gestiona las suyas (RLS por `auth.uid()`); `user_id` lo pone el backend. |

**Alta con consentimiento (RN-033).**
- La app envía en `signUp` los metadatos `full_name` y `accepted_documents` (`[{code, version}]`).
- El trigger `private.handle_new_user` (`after insert on auth.users`) comprueba que estén **todas** las versiones vigentes. Después crea el perfil y registra los consentimientos.
- Si falta alguna, lanza un error y la cuenta **no se crea**, aunque se llame a la API sin pasar por la app.
- GoTrue devuelve ese rechazo como `500 "Database error saving new user"`, sin el detalle. La app lo muestra como "debes aceptar los términos" y recarga los documentos vigentes.

**Una dirección predeterminada.**
- Un índice único parcial permite una sola por usuario.
- La primera dirección que se crea queda como predeterminada.
- Al marcar otra, se desmarca la anterior.
- Al borrar la predeterminada, pasa a serlo la más reciente que quede.
- Desmarcarla sin marcar otra no está permitido desde la app.

**Contraseña y recuperación** (`backend/supabase/config.toml`):
- **Contraseña:** 8 caracteres como mínimo, con letras y números (`password_requirements = "letters_digits"`). La app valida lo mismo.
- **Recuperación (RF-003):** la plantilla `backend/supabase/templates/recovery.html` envía un **código de 6 dígitos** (`{{ .Token }}`). La app lo valida con `verifyOTP(type: recovery)` y cambia la contraseña con `updateUser`. No hacen falta deep links, y funciona igual con PKCE, el flujo de la app.
- **Confirmación de correo:** desactivada en local (`enable_confirmations = false`). Si se activa en producción, la app ya contempla el caso: avisa que se confirme el correo y no abre sesión.

**Pendientes:**
- Texto legal definitivo: los documentos 1.0 son borradores marcados "PENDIENTE DE REVISIÓN LEGAL" (RNF-008, RNF-035).
- Supresión de la cuenta a pedido del usuario (RNF-008).
- Retención de los consentimientos cuando se borra una cuenta: hoy se borran en cascada con ella.

## Carrito (fase 5)

| Tabla | Para qué | Acceso de clientes |
|---|---|---|
| `cart_items` | Carrito guardado del usuario con sesión (RF-054): `user_id`, `offer_id`, `quantity` (1 a 99) y fecha de agregado. Clave `(user_id, offer_id)`: una línea por oferta. | Cada usuario lee las suyas. **No escribe directo**: insertar, cambiar y borrar va por las RPC del carrito (API_CONTRATO, sección 10), que validan el stock. |

- **Una línea es una oferta, no un producto.** Cada proveedor fija su precio y despacha por separado (RN-001, S-06).
- **Máximo comprable:** `private.offer_max_quantity()` devuelve el stock de una oferta visible (publicada y de proveedor activo), con el tope de `app_settings.cart_max_quantity_per_item`, que vale 10. Si la oferta no se puede comprar, devuelve 0. Las RPC rechazan cantidades mayores con `QUANTITY_UNAVAILABLE` y responden el máximo, sin exponer las unidades reales.
- **Datos vigentes:** las líneas se arman en `private.cart_lines()` con el precio y la disponibilidad del momento. Si una oferta se pausa o se agota, la línea sigue en el carrito con `available = false`, para que el usuario la vea y la quite.
- **Carrito de invitado:** no se guarda en la base. La app lo lleva en memoria, lo muestra con `preview_cart` y, al iniciar sesión, lo suma con `merge_cart`.
- El catálogo expone `bestOfferId`, el id de la mejor oferta, para agregarla desde una tarjeta: es una columna nueva al final de `private.catalog_products`.

**Pendiente (fase 8):** reservar stock durante el checkout (RF-067, Could) y revalidar el precio antes de pagar (RF-055).

## Datos de desarrollo

`backend/supabase/seed.sql` (lo carga `npx supabase db reset`) contiene:
- **3 proveedores:** 2 activos y 1 pendiente.
- **15 productos:** los 6 del mock de la app con los mismos ids, 6 piezas más y 3 computadores armados, con sus atributos tipados.
- **18 ofertas:** incluyen un producto con dos proveedores, niveles `stable`, `critical` y `outOfStock`, una oferta de un proveedor pendiente y una en borrador. Estas dos últimas no deben verse.

No trae usuarios: las cuentas se crean desde la app, que pasa por el trigger de consentimiento.
