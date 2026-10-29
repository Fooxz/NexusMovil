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
| `categories` | Tipos de pieza (RF-012). | `code` es el valor `category` del contrato. `family` siempre es `part`: la restricción `categories_parts_only` impide otra familia (solo piezas, 2026-10-27). `search_terms` alimenta la búsqueda (`procesador`, `placa base`...). Datos de referencia en la migración. |
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
`private.audit_row_change()` a sus tablas: reglas de compatibilidad (fase 6), modelos 3D (fase 6.1) y pagos, órdenes y comisiones (fase 8).

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

**Checkout (fase 8):** `start_checkout` revalida el precio y el stock antes de pagar (RF-055). Reservar stock durante el pago (RF-067, Could) sigue pendiente: si otra compra se lleva las unidades mientras el cliente paga, queda registrado en `order_items.backordered_units`.

## PC Builder (fase 6)

| Tabla | Para qué | Acceso de clientes |
|---|---|---|
| `builder_slots` | Ranuras del armador: categoría, etiqueta, si es obligatoria y orden (RF-046, RF-048). | Lectura pública. |
| `compat_rules` | Catálogo de reglas: código y nombre. | Ninguno (las aplican las RPC). |
| `compat_rule_versions` | Cada versión de una regla: tipo, categorías y atributos que compara, parámetros, severidad, mensaje, quién y cuándo la creó, y si está activa. Una sola activa por regla (RF-050). | Ninguno. |

**Motor determinista (RN-013).** `private.evaluate_rules` recorre las reglas activas y compara los **atributos tipados** de las piezas (`product_attributes`). Tipos de regla:

| Tipo | Compara | Regla del seed |
|---|---|---|
| `equals` | A.attr = B.attr | Socket CPU = socket placa; tipo de RAM = tipo que acepta la placa |
| `containedIn` | A.attr está en la lista B.attr | Formato de placa ⊂ formatos del gabinete; socket del CPU ⊂ sockets del disipador |
| `atMost` | A.attr ≤ B.attr | Largo de GPU, altura del disipador, módulos y capacidad de RAM |
| `powerBudget` | Fuente ≥ (consumo de `sources`) × `factor` + `baseWatts`, redondeado a `roundTo` | (TDP CPU + TDP GPU) × 1,3 + 100 W, en múltiplos de 50 |
| `requiredUnless` | Falta la pieza A salvo que B.attr sea verdadero | Gráfica obligatoria si el CPU no tiene gráficos integrados |

- **Si falta un dato obligatorio** de la plantilla para verificar una regla, el resultado es un `warning` ("no pudimos verificar"): no se supone compatibilidad. Si el dato que falta es opcional, la regla no aplica. Por ejemplo, un disipador líquido no tiene altura.
- **Agregar o cambiar una regla no requiere código.** Se inserta una versión nueva, se desactiva la anterior y se activa la nueva. Un trigger valida que los atributos existan en la plantilla de la categoría, y las dos tablas se auditan.
- **RPC:** `get_builder_slots`, `validate_build` y `get_builder_candidates` (API_CONTRATO, sección 11). El asistente de la fase 7 usará `validate_build` para proponer configuraciones de piezas (RF-040).

**Decisión:** el motor se implementó en PostgreSQL y no en una Edge Function de TypeScript, como decía el plan. Así las reglas, los datos y su evaluación viven juntos, las pruebas usan pgTAP y no hace falta Deno. El asistente llama a la misma RPC.

## Vista 3D (fase 6.1)

| Tabla | Para qué | Acceso de clientes |
|---|---|---|
| `component_models` | Qué archivo `.glb` usa una pieza: categoría, producto (nulo para el genérico de la categoría), ruta en el bucket, rotación, título, autor, licencia y enlace. Un solo modelo activo por producto y uno genérico por categoría. | Ninguno (lo entrega `get_build_scene`). |

- **Archivos:** bucket público `component-models` de Storage, máximo 5 MiB por archivo. Se define en `config.toml`; en local se suben los de `backend/supabase/models` al iniciar o al hacer `db reset`.
- **Validaciones:** solo archivos `.glb`, rotación de tres ángulos, el producto debe ser de la categoría y CC BY exige el enlace a la obra. La tabla se audita.
- **Sin modelo**, la app genera la pieza con su forma y las medidas de sus atributos (largo de la GPU, formato de la placa...). Cómo agregar modelos: `backend/MODELOS_3D.md`.

### Componentes de los armados (retirada)

La tabla `prebuilt_components` y la RPC `get_prebuilt_scene` mostraban en 3D los componentes de un computador armado. Se eliminaron el 2026-10-27, cuando NEXUS pasó a vender solo piezas (ver "Solo piezas" más abajo).

## Asistente (fase 7)

| Tabla | Para qué | Acceso de clientes |
|---|---|---|
| `assistant_interactions` | Cada pregunta y su respuesta: sesión, usuario (si había sesión), hash del cliente, mensaje, tipo y cuerpo de la respuesta, productos y ofertas recomendados, modelo, herramientas usadas y latencia (RF-043, RNF-034). | Ninguno. Solo la Edge Function, con el rol de servicio. |

- **RPC `get_product_attributes(product_ids)`:** atributos tipados de productos visibles, con etiqueta y unidad (por ejemplo, "Memoria de video: 16 GB"). La usa el asistente para justificar con datos reales (RF-038).
- **Privacidad (Ley 1581):**
  - se guarda un hash del cliente y no la IP;
  - si se borra la cuenta, `user_id` queda nulo;
  - el mensaje puede contener datos que el cliente escriba. **Pendiente para la fase 12:** fijar cuánto tiempo se conservan las interacciones y borrar las vencidas con `pg_cron`.

## Checkout, pagos y comisión (fase 8)

```text
payments 1─0..1 orders 1─* sub_orders 1─* order_items *─0..1 commission_rules
    1                         (una por proveedor)
    *
payment_events
```

| Tabla | Para qué | Acceso de clientes |
|---|---|---|
| `payments` | Cada intento de pago (RF-058): referencia `NX-AAAAMMDD-XXXXXXXXXX`, usuario, estado, valor, transacción y medio de Wompi, y la **foto** de lo que se compra: líneas con el precio revalidado, dirección y contacto. Vence a los 60 minutos. | Ninguno. Solo las RPC `start_checkout` y `get_checkout_status`. |
| `payment_events` | Cada aviso del webhook y cada consulta a Wompi, con lo que se hizo (`order_created`, `status_updated`, `duplicate`, `stale`, `amount_mismatch`, `unknown_reference`). Sirve para conciliar (RF-079). | Ninguno. No se edita ni se borra. |
| `orders` | La orden, creada solo con el pago aprobado (RN-025): número `NX-000123`, usuario, pago, total, dirección y contacto. Estado `paid`. | Ninguno (fase 9: historial). |
| `sub_orders` | Una por proveedor (S-06): subtotal, base sin IVA, comisión y neto del proveedor. Estado `pending`, esperando al proveedor. | Ninguno. |
| `order_items` | Precio, cantidad, IVA, base, porcentaje y regla de comisión, comisión y neto **del momento de la compra** (RN-026, RF-075). `backordered_units`: unidades que ya no había al aprobarse el pago. | Ninguno. No se edita ni se borra. |
| `commission_rules` | Comisión de un proveedor (`product_id` nulo) o de un producto suyo, con vigencia (RF-071, RF-072). | Ninguno. El administrador las opera desde Studio o SQL. |

**Estados del pago.** `pending` → `approved` (con orden), `declined`, `voided`, `error` o `abandoned`. Solo `approved` es final: después de un rechazo el cliente puede reintentar en Wompi, y si esa transacción se aprueba, se acepta. Un intento abandonado que igual se paga también crea su orden, porque la pasarela ya cobró.

**`apply_payment_event`, idempotente (RNF-020).**
- La llaman el webhook y la consulta de `checkout`, con el rol de servicio.
- Bloquea la fila del pago, así que dos avisos simultáneos no crean dos órdenes.
- Un aviso repetido o atrasado se registra y no cambia nada.
- Si el valor o la moneda no coinciden, el pago queda en `error` y no se crea la orden.

**Al aprobarse:**
- se crea la orden con una sub-orden por proveedor;
- se descuenta el stock de cada oferta, sin bajar de 0 (RF-066);
- lo comprado sale del carrito.

**Comisión (RF-073, RF-074).**
- **Regla aplicable:** la del producto; si no hay, la del proveedor; si no hay, `app_settings.default_commission_rate`. Siempre la vigente en el momento de la compra.
- Un trigger impide reglas por encima de `commission_rate_max` y vigencias superpuestas para el mismo proveedor y producto.
- **Cálculo:**
  - los precios incluyen IVA (`vat_rate` = 0,19);
  - `base = total de la línea / 1,19` y `comisión = base × porcentaje`, los dos redondeados a pesos enteros;
  - `neto del proveedor = total de la línea − comisión`.
- El cliente paga el precio publicado (RN-002) y la comisión nunca viaja a la app.

**Inmutabilidad y auditoría.**
- Los ítems no se modifican. Tampoco cambian los montos de las órdenes y sub-órdenes. Ninguna orden ni ningún pago se borra.
- Cambiar una regla de comisión no altera las órdenes anteriores (HU-026).
- `payments`, `orders`, `sub_orders`, `order_items` y `commission_rules` están en `audit_log`.

**Supuestos pendientes del negocio:**
- **Comisión por defecto: 10 %** (`default_commission_rate`, S-07).
- **Máximo: 30 %** (`commission_rate_max`, RN-024).
- **Envío:** sin costo adicional para el cliente.
- **IVA:** se asume del 19 % para todo el catálogo. Algunos computadores están excluidos de IVA en Colombia según su valor; si aplica, `vat_rate` debe pasar a ser por producto.

## Solo piezas (cambio de alcance, 2026-10-27)

NEXUS vende solo piezas de computador: el cliente arma su equipo en el PC Builder o con el asistente. La migración
`20261027010000_parts_only.sql`:
- borra los computadores armados con sus ofertas, atributos, imágenes, modelos 3D, reglas de comisión y líneas de carrito;
- borra la categoría `prebuiltPc` con su plantilla de atributos y la vista 3D de armados;
- agrega `categories_parts_only` y hace que el filtro `family` solo admita `part`.

Si algún armado ya estuviera en una orden, la migración se detiene: las órdenes conservan sus ítems (RN-026) y ese armado
habría que retirarlo a mano. El valor `prebuiltPc` sigue en el tipo `product_family`, porque PostgreSQL no permite quitar
valores de un enum, pero ninguna categoría puede usarlo.

## Roles, tiendas y publicaciones (2026-10-27)

Tres roles exclusivos: **cliente** (compra), **tienda** (publica sus ofertas) y **administrador** (crea y habilita
tiendas). Migraciones `20261027030000_roles_accounts.sql`, `20261027040000_offer_catalog.sql` y
`20261027050000_provider_catalog.sql` (API_CONTRATO, partes 6 a 8). No borran ni reescriben datos.

| Tabla o columna | Qué guarda | Quién la cambia |
|---|---|---|
| `profiles.role` (`app_role`: `customer`, `provider`, `admin`) | El rol de la cuenta. Por defecto `customer`. | Solo el backend: el usuario solo puede editar `full_name` y `phone` (permiso por columna) y un trigger rechaza cualquier cambio de rol que venga de la app. Los cambios quedan en `audit_log` (solo el rol, sin datos personales). |
| `profiles.must_change_password` | La contraseña es temporal (la generó un administrador). | La pone el alta de la tienda; la quita un trigger de `auth.users` cuando cambia el hash de la contraseña. |
| `providers.user_id` | Cuenta que opera la tienda (una por tienda). Las tiendas cargadas antes de los roles no tienen. | El alta de la cuenta (`admin_provision_provider`). |
| `providers.created_by`, `verification_note` | Administrador que creó la tienda y cómo verificó que existe. | El administrador. |
| `products.created_by_provider_id` | Tienda que registró la ficha; vacío en el catálogo base. Da derecho a editarla mientras ninguna otra tienda tenga una oferta sobre ella. | `create_my_product`. |
| `products_catalog_key_idx` | Índice único de (categoría, marca, modelo) normalizados con `private.name_key` (sin mayúsculas, acentos ni signos). | — |
| `private.account_provisioning` | Tickets de alta de cuentas de tienda (vencen en 10 minutos, se consumen al crear la cuenta). | Solo el rol de servicio (`admin_prepare_provider_account`). |
| Bucket `product-images` | Imágenes de las fichas, públicas para leer. JPG, PNG o WEBP de hasta 5 MB. | Cada tienda sube solo a su carpeta (`<tienda>/<archivo>`); nadie las reemplaza ni las borra desde la app. |

**Alta de usuarios.** El registro público sigue exigiendo los documentos vigentes y crea un cliente; el rol nunca sale
de los metadatos que envía la app. La excepción son las cuentas de tienda: la API de administración de Auth inserta el
usuario y escribe `app_metadata` después, en la misma transacción, así que el trigger de alta no puede ver esa marca. Por
eso la Edge Function deja antes un ticket en `private.account_provisioning`; con un ticket vigente, el alta no exige los
documentos y la tienda los acepta en su primer ingreso. El alta de la tienda (`admin_provision_provider`) exige además
la marca `nexus_provisioned` en `raw_app_meta_data`, que solo escribe el rol de servicio.

**Controles de acceso** (funciones `private.*`):
- `require_admin()`: rol administrador, leído del perfil en cada llamada.
- `require_active_provider()`: rol tienda, tienda `active`, contraseña definitiva y documentos vigentes aceptados.
  Devuelve el id de la tienda; las RPC de publicaciones filtran por él.
- `require_user()` (carrito y checkout): además de la sesión, exige el rol cliente (`CUSTOMER_ONLY`).
- `grant_admin(email)` / `revoke_admin(email)`: solo por SQL, como propietario de la base.

**Catálogo por oferta.** La vista `private.catalog_offers` tiene una fila por oferta visible (publicada, de tienda
activa, en categoría activa) con los datos del producto y `offer_count` (tiendas que venden el producto). `get_offers`
la pagina con los mismos filtros que el catálogo más el filtro por tienda. Las vistas y RPC existentes no cambian.

**Publicaciones.** Una tienda publica sin aprobación: `create_my_product` valida la plantilla de atributos, el precio, el
stock, las imágenes, los duplicados y un límite diario (`provider_daily_product_limit`, 50) y crea la ficha y la oferta.
La ficha queda fija en cuanto otra tienda oferta sobre ella (las ofertas nunca se borran: retirar es lógico).
`create_my_offer` y `update_my_product` bloquean la fila del producto para que una edición y una oferta nueva no se
crucen.

## Panel de la tienda (2026-10-29)

Migración `20261029010000_vendor_dashboard.sql` (API_CONTRATO, parte 9).

| Tabla o columna | Para qué | Acceso de clientes |
|---|---|---|
| `offers.min_stock` | Stock mínimo de la oferta (por defecto 5): con esa cantidad o menos hay alerta de stock bajo. | Por `set_my_min_stock`. |
| `inventory_movements` | Cada cambio de stock: oferta, tienda, tipo (`entry`, `exit`, `adjustment`, `sale`, `cancellation`), cantidad, stock antes y después, motivo, sub-orden y usuario. | Ninguno. La tienda lee los suyos por `get_my_stock_movements`. |
| `sub_orders` (columnas nuevas) | Nueve estados en lugar de uno, transportadora y guía, motivo del último cambio y fechas de envío y entrega. | Ninguno. La tienda opera los suyos por RPC. |
| `sub_order_status_history` | Cada cambio de estado de una sub-orden: de qué estado a cuál, motivo, quién y cuándo (RN-029). | Ninguno. |

- **Ningún cambio de stock se salta el historial.** El trigger `offers_stock_movement` registra cada cambio de `stock_units`. El motivo lo deja quien hace el cambio con `private.set_stock_movement` en la misma transacción: el checkout (venta), las RPC de la tienda (entrada, salida, ajuste, edición de la publicación) y el rechazo o la cancelación de un pedido (devolución al stock). Sin motivo, queda como ajuste. Al aplicar la migración, cada oferta con stock arrancó con una entrada "Inventario inicial".
- **Reservado** son las unidades vendidas y todavía no enviadas: el checkout ya las descontó de `stock_units`, así que el disponible es `stock_units`.
- **Transiciones** en `private.sub_order_next_statuses`. Rechazar o cancelar devuelve las unidades al stock; devolver no, porque un producto devuelto puede venir dañado (la tienda registra la entrada si lo vuelve a vender).
- **Inmutables:** los dos historiales no se modifican ni se borran. Lo único permitido es lo que hace la base al borrar una cuenta: `actor_id` queda nulo y el resto del registro no cambia.
- **Pendiente para la fase 2 del panel:** reembolsos al cliente, liquidaciones a la tienda y notificaciones.

## Consola del administrador (2026-10-29)

Migración `20261029020000_admin_console.sql` (API_CONTRATO, parte 10).

| Tabla o columna | Para qué | Acceso de clientes |
|---|---|---|
| `provider_status` (valores nuevos) | `blocked` (incumplió las políticas) y `deactivated` (dejó de operar), además de `suspended` (temporal). | Por `admin_set_provider_status`. |
| `provider_admin_notes` | Historial administrativo de cada tienda: observaciones, advertencias, incidencias recurrentes, incumplimientos y cambios de estado con su motivo, quién y cuándo. | Ninguno. El administrador lo lee en la ficha de la tienda. |
| `offers.moderation_status`, `moderation_reason`, `moderated_at`, `moderated_by` | Moderación posterior: `approved` (por defecto), `hidden`, `review` o `rejected`, con el motivo que ve la tienda. | La tienda lee los suyos en sus publicaciones. |
| `order_admin_notes` | Observaciones del administrador sobre un pedido o una de sus sub-órdenes. | Ninguno. |
| `private.admin_offers` (vista) | Cada oferta con sus alertas de calidad: ficha incompleta, precio anómalo frente a la mediana del producto y posible duplicado por nombre. | Ninguno. |

- **Solo `approved` se ve:** `private.visible_offers` exige la moderación aprobada, así el catálogo, el carrito, el checkout, el asistente y el PC Builder dejan de ofrecer lo oculto sin cambiar sus consultas.
- **El administrador interviene pedidos** con transiciones propias (`private.admin_next_statuses`) y siempre con una observación, que queda en `sub_order_status_history` como "NEXUS: ...". Cancelar o rechazar devuelve las unidades al stock (`private.restock_sub_order`).
- **Inmutables:** los dos historiales nuevos, con la misma excepción al borrar una cuenta.
- **Pendiente para la entrega 2:** liquidaciones a las tiendas, reembolsos con Wompi y la sección de clientes.

## Datos de desarrollo

`backend/supabase/seed.sql` (lo carga `npx supabase db reset`) contiene:
- **3 proveedores:** 2 activos y 1 pendiente.
- **26 piezas** con sus atributos tipados: las 6 del mock de la app con los mismos ids, 6 de gama alta y 14 de gama de entrada y media (Ryzen 5 8600G, Core i5-14400, placas microATX, DDR4 y DDR5, RTX 5060, RX 9060 XT, fuentes de 600 y 750 W...). Alcanzan para armar equipos válidos de oficina desde unos $2.300.000 y de gaming desde unos $4.500.000.
- **29 ofertas:** incluyen un producto con dos proveedores, niveles `stable`, `critical` y `outOfStock`, una oferta de un proveedor pendiente y una en borrador. Estas dos últimas no deben verse.
- **3 modelos 3D genéricos:** CPU, RAM y gráfica, descargados de Poly Pizza (ver `backend/MODELOS_3D.md`).

**Catálogo grande** (`backend/supabase/seeds/catalog_generated.sql`, se carga después de `seed.sql`):
- **734 piezas más** (760 en total): 58 procesadores AM4, AM5, LGA1700 y LGA1851; 194 placas madre de 15 chipsets; 80 kits de RAM DDR4 y DDR5; 148 gráficas de NVIDIA, AMD e Intel en versiones de varios ensambladores; 73 unidades de almacenamiento; 55 fuentes; 59 gabinetes y 67 sistemas de refrigeración.
- **4 proveedores activos más** (6 en total) y **964 ofertas**: un 30 % de las piezas tiene dos proveedores, un 15 % trae descuento, un 15 % queda en stock crítico y un 10 % agotado.
- Lo genera `tool/catalog/generate_catalog.mjs` con una semilla fija: siempre produce el mismo archivo. Los nombres siguen líneas reales de cada marca, pero no todas las combinaciones existen; especificaciones aproximadas y precios de ejemplo.

No trae usuarios: las cuentas se crean desde la app, que pasa por el trigger de consentimiento.
