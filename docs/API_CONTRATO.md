# Contrato de API: NEXUS Movil (v0.15, borrador)

**Estado:** borrador. Parte 1: catalogo (secciones 1 a 5). Parte 2: carrito (seccion 10). Parte 3: PC Builder y vista 3D (seccion 11). Parte 4: asistente (seccion 12). Parte 5: checkout y pagos (seccion 13). Parte 6: catalogo por oferta (seccion 14). Parte 7: roles y administracion de tiendas (seccion 15). Parte 8: publicaciones de tiendas (seccion 16). Parte 9: panel de la tienda (seccion 17). Parte 10: consola del administrador (seccion 18). Implementado en el backend (`backend/`) y consumido por el front desde las fases 3, 5, 6, 6.1, 7 y 8 de `docs/PLAN_IMPLEMENTACION.md`.
**Quien lo escribe:** el front, a partir de sus modelos reales (`lib/features/catalog/domain`).
**Quien lo implementa:** el backend Supabase de `backend/`.
**Regla de oro:** ninguno de los dos lados cambia el comportamiento sin editar este archivo primero. Si el codigo y este documento no coinciden, el documento gana hasta que se actualice.

---

## 1. Convenciones generales

- REST sobre HTTP, cuerpos en **JSON UTF-8**.
- Prefijo de rutas: `/api/v1`. Con Supabase, cada endpoint de este documento se implementa como una funcion RPC de PostgREST (por ejemplo `GET /api/v1/products` → `rpc/get_products`). La ruta es el nombre logico; **la forma del JSON, los parametros y los errores de este documento no cambian**. Ver la seccion 3.4 para los nombres de los parametros de cada RPC.
- Nombres de campos en **camelCase**.
- **Dinero: enteros en centavos, moneda unica COP (peso colombiano).** Nunca decimales ni texto. Ejemplo: 9.200.000 COP se envia como `920000000`.
  - Los precios son siempre **multiplos de 100** (no existen fracciones de peso en los precios de la tienda).
  - **Usar enteros de 64 bits** en el backend (columna `BIGINT` en PostgreSQL). Un entero de 32 bits (maximo 2.147.483.647) se desborda con una PC de unos 21 millones de pesos, y los totales de carrito pueden superarlo.
  - El front muestra los montos sin decimales y con punto como separador de miles (ejemplo: `$9.200.000`).
- **Ids: siempre `String`**, aunque en la base de datos sean numeros. El front no interpreta el id.
- **Enums: strings en minuscula con camelCase**, exactamente como se listan en la seccion 2.
- **Campos opcionales:** si no hay valor se envia `null` (o se omite). **Las listas nunca son `null`**: si estan vacias se envia `[]`.
- **Campos desconocidos:** el front **ignora** los campos que no conoce. El backend puede agregar campos sin romper al front. Lo que **no** puede hacer es renombrar, quitar o cambiar el tipo de un campo existente sin avisar.
- **Valores de enum desconocidos:** el front los trata como un valor por defecto. Aun asi, el backend no debe agregar valores nuevos sin registrarlos aqui.
- **Autenticacion:** los endpoints de esta parte son **publicos** (sin token). El header `Authorization: Bearer <jwt>` queda reservado para las partes que lo necesiten (carrito, pedidos).
- **Descuento:** **no viaja en la API.** El front lo calcula a partir de `priceCents` y `oldPriceCents`.

---

## 2. Modelo `Product`

```json
{
  "id": "gpu-rtx-5090",
  "name": "NVIDIA GeForce RTX 5090",
  "brand": "NVIDIA",
  "family": "part",
  "category": "gpu",
  "priceCents": 799600000,
  "oldPriceCents": 919600000,
  "stockLevel": "stable",
  "bestOfferId": "off-1001",
  "imageUrl": "https://cdn.example.com/products/gpu-rtx-5090/thumb.webp",
  "summary": "24 GB GDDR6X, 2.5K, Ray tracing",
  "quickSpecs": ["ADALACE", "16384 CORES", "24GB GDDR6X", "450W"],
  "specs": [
    { "label": "VRAM", "value": "24GB GDDR6X" },
    { "label": "TDP", "value": "450W" }
  ],
  "offers": [
    {
      "id": "off-1001",
      "providerId": "prov-12",
      "providerName": "TecnoPartes SAS",
      "priceCents": 799600000,
      "oldPriceCents": 919600000,
      "stockLevel": "stable"
    }
  ]
}
```

| Campo | Tipo | Obligatorio | Notas |
|---|---|---|---|
| `id` | string | si | Unico y estable. |
| `name` | string | si | Nombre completo para mostrar. |
| `brand` | string | si | |
| `family` | string (enum) | si | Siempre `part` (pieza). Se conserva por compatibilidad (v0.11). Ver abajo. |
| `category` | string (enum) | si | Ver tabla de categorias. |
| `priceCents` | entero (64 bits) | si | Precio de la **mejor oferta disponible** (la mas barata con stock; si ninguna tiene stock, la mas barata), en centavos de COP, mayor o igual a 0 y multiplo de 100. |
| `oldPriceCents` | entero o `null` | no | Precio anterior de esa misma oferta. Solo si hay descuento; si existe debe ser mayor que `priceCents`. |
| `stockLevel` | string (enum) | si | Nivel agregado: el mejor nivel entre todas las ofertas. Ver tabla de stock. |
| `bestOfferId` | string o `null` | no | Id de la mejor oferta (la que da `priceCents`). Es la que se agrega al carrito desde una lista (seccion 10). Viene en el listado y en el detalle. |
| `imageUrl` | string o `null` | no | URL de la miniatura para listas y tarjetas. `null` si el producto no tiene imagen: el front muestra el icono de su categoria. |
| `summary` | string o `null` | no | Una linea corta de especificaciones para la tarjeta. |
| `quickSpecs` | lista de string | si (puede ser `[]`) | Etiquetas cortas del detalle. |
| `specs` | lista de `{label, value}` | si (puede ser `[]`) | Ficha tecnica **solo para mostrar**, en texto. |
| `offers` | lista de `Offer` | si (puede ser `[]`) | Ofertas de cada proveedor (RF-014). **Solo se llena en el detalle (3.2)**; en el listado y en relacionados se envia `[]`. |

**`family`:** siempre `part`. **NEXUS solo vende piezas de computador** (RN-010, cambio de alcance del 2026-10-27): no hay computadores armados, celulares ni otras categorias. El campo queda por compatibilidad; el front no lo usa.

**`category`:** `cpu`, `gpu`, `ram`, `motherboard`, `storage`, `psu`, `pcCase`, `cooling`.

- Valores eliminados: `phone` (v0.3) y `prebuiltPc` (v0.11). Un front anterior que reciba `prebuiltPc` omite el producto, como cualquier categoria desconocida.

### 2.1 Modelo `Offer`

| Campo | Tipo | Obligatorio | Notas |
|---|---|---|---|
| `id` | string | si | Id de la oferta. |
| `providerId` | string | si | |
| `providerName` | string | si | Nombre comercial del proveedor para mostrar. |
| `priceCents` | entero (64 bits) | si | Precio fijado por el proveedor (RN-001). Mismas reglas que en `Product`. |
| `oldPriceCents` | entero o `null` | no | Mismas reglas que en `Product`. |
| `stockLevel` | string (enum) | si | Nivel de esta oferta. |

- Solo se envian ofertas publicadas de proveedores activos (RF-015, RN-022). Las agotadas si se envian, con `outOfStock`.
- Orden: primero las que tienen stock, despues por `priceCents` ascendente.

**`stockLevel`:** `stable`, `critical`, `outOfStock`. El backend lo calcula a partir de las unidades en inventario:

| Valor | Unidades | Significado |
|---|---|---|
| `outOfStock` | 0 | Producto **no disponible**. |
| `critical` | de 1 a N | Quedan pocas unidades. |
| `stable` | mas de N | Stock suficiente. |

`N` es configurable en el backend (valor sugerido: 5; ver D3). **El front no recibe las unidades**, solo el nivel, para que la regla viva en un unico lugar.

> **Importante:** `specs` es texto para mostrar. **No** sirve para calcular compatibilidad. Los atributos con tipo del PC Builder (socket, tipo de RAM, consumo...) iran en una seccion propia del contrato (ver seccion 7) y **no** se agregan a `Product`.

---

## 3. Endpoints

### 3.1 Listar productos

`GET /api/v1/products`

| Parametro | Tipo | Defecto | Notas |
|---|---|---|---|
| `page` | entero | `0` | Base 0. Si es negativo, `400`. |
| `pageSize` | entero | `20` | Maximo `50`. Si pide mas, el backend usa 50 y **devuelve el valor realmente usado** en la respuesta. |
| `search` | string | (vacio) | Sin distinguir mayusculas y sin acentos. Busca en `name`, `brand` y categoria. Vacio o ausente significa "sin filtro". |
| `family` | string (enum) | (ausente) | Solo `part`, que equivale a no filtrar (v0.11). Cualquier otro valor, incluido `prebuiltPc`: `400`. |
| `category` | string (enum) | (ausente) | Un valor de `category`. Si es invalido, `400`. |
| `brand` | string | (ausente) | Marca exacta, sin distinguir mayusculas. Los valores validos salen de 3.5. |
| `minPriceCents` | entero (64 bits) | (ausente) | Precio minimo **inclusivo**, sobre `priceCents` (la mejor oferta). Negativo: `400`. |
| `maxPriceCents` | entero (64 bits) | (ausente) | Precio maximo **inclusivo**. Negativo o menor que `minPriceCents`: `400`. |
| `sort` | string (enum) | `relevance` | `relevance`, `priceAsc` o `priceDesc`. Otro valor: `400`. |

**`sort`:**

| Valor | Orden |
|---|---|
| `relevance` | Por nombre y luego `id`, mientras no exista un puntaje de busqueda. |
| `priceAsc` | `priceCents` ascendente; desempata nombre y luego `id`. |
| `priceDesc` | `priceCents` descendente; desempata nombre y luego `id`. |

**Respuesta `200`:**

```json
{
  "items": [ { "...": "Product" } ],
  "total": 6,
  "page": 0,
  "pageSize": 20
}
```

- `total` es la cantidad de productos que cumplen los filtros **en todas las paginas**, no solo en esta.
- El front calcula si hay mas paginas con `(page + 1) * pageSize < total`.
- **El orden debe ser determinista y estable entre paginas** (si no, un producto puede aparecer dos veces o ninguna). Por eso todos los valores de `sort` desempatan por `id`.
- Los productos `outOfStock` **si aparecen** en el listado y cuentan en `total`. El front los muestra como "AGOTADO".
- Si no hay resultados: `200` con `items: []` y `total: 0`. No es un error.

### 3.2 Detalle de un producto

`GET /api/v1/products/{id}`

- `200`: un objeto `Product`, con `offers` lleno (seccion 2.1).
- `404`: el producto no existe. El front lo convierte en "Producto no encontrado".

### 3.3 Productos relacionados

`GET /api/v1/products/{id}/related?limit=2`

| Parametro | Tipo | Defecto | Notas |
|---|---|---|---|
| `limit` | entero | `2` | Maximo `10`. |

- `200`: **lista** de `Product` (no un objeto paginado). Puede traer menos que `limit`, o `[]`.
- **Nunca incluye el producto consultado.**
- `404` si `{id}` no existe.
- **Quien decide que es "relacionado" es el backend.** Regla sugerida: primero la misma categoria, despues el resto. El front solo muestra lo que llega, en el orden recibido.

### 3.4 Implementacion con Supabase (RPC)

Cada endpoint es un `POST /rest/v1/rpc/<funcion>` con los parametros en un cuerpo JSON. Desde Flutter: `supabase.rpc('<funcion>', params: {...})`. Las respuestas y los errores son los de las secciones 3.1 a 3.3 y 4.

| Endpoint | RPC | Parametros (cuerpo JSON) |
|---|---|---|
| 3.1 Listar | `get_products` | `page`, `page_size`, `search`, `family`, `category`, `brand`, `min_price_cents`, `max_price_cents`, `sort` |
| 3.2 Detalle | `get_product` | `id` |
| 3.3 Relacionados | `get_related` | `id`, `max_items` (equivale a `limit`, palabra reservada de SQL) |
| 3.5 Marcas | `get_catalog_brands` | `family`, `category` |

- Los nombres de parametro de las RPC van en snake_case porque son argumentos de funciones SQL. Los campos de las respuestas siguen en camelCase.
- Los errores llegan con el codigo HTTP del contrato y un cuerpo `{"code", "message", "details", "hint"}`. El front ignora `details` y `hint`.

### 3.5 Marcas del catalogo

`GET /api/v1/products/brands?family=part&category=gpu`

| Parametro | Tipo | Defecto | Notas |
|---|---|---|---|
| `family` | string (enum) | (ausente) | Como en 3.1. Invalido: `400`. |
| `category` | string (enum) | (ausente) | Como en 3.1. Invalido: `400`. |

- `200`: **lista** de string con las marcas que tienen productos visibles para esa familia y categoria, sin repetir y en orden alfabetico sin distinguir mayusculas. Puede ser `[]`.
- Alimenta el filtro `brand` de 3.1.

---

## 4. Errores

Todo error usa el mismo cuerpo:

```json
{ "code": "PRODUCT_NOT_FOUND", "message": "No existe el producto gpu-xyz" }
```

| HTTP | `code` | Cuando |
|---|---|---|
| 400 | `VALIDATION_ERROR` | Parametro invalido (`page` negativo, `category` desconocida...). |
| 404 | `PRODUCT_NOT_FOUND` | El id no existe. |
| 429 | `RATE_LIMITED` | Demasiadas preguntas seguidas al asistente (seccion 12). |
| 503 | `ASSISTANT_UNAVAILABLE` | El modelo de IA no respondio o no tiene cuota (seccion 12). |
| 500 | `INTERNAL_ERROR` | Error no esperado. No exponer trazas ni detalles internos en `message`. |

El front depende del **codigo HTTP** y del campo `code`. `message` es solo informativo.

---

## 5. Ejemplo para pruebas (fixture compartido)

Ambos lados deben poder usar este JSON como dato de prueba: el back para comprobar que su respuesta tiene esta forma, y el front para probar su lectura del JSON.

`GET /api/v1/products?page=0&pageSize=20&family=part` (resultado reducido a 2 productos):

```json
{
  "items": [
    {
      "id": "gpu-rtx-5090",
      "name": "NVIDIA GeForce RTX 5090",
      "brand": "NVIDIA",
      "family": "part",
      "category": "gpu",
      "priceCents": 799600000,
      "oldPriceCents": 919600000,
      "stockLevel": "stable",
      "bestOfferId": "off-1001",
      "imageUrl": "https://cdn.example.com/products/gpu-rtx-5090/thumb.webp",
      "summary": "24 GB GDDR6X, 2.5K, Ray tracing",
      "quickSpecs": ["ADALACE", "16384 CORES", "24GB GDDR6X", "450W"],
      "specs": [
        { "label": "VRAM", "value": "24GB GDDR6X" },
        { "label": "TDP", "value": "450W" }
      ],
      "offers": []
    },
    {
      "id": "cpu-ryzen-9-9950x",
      "name": "AMD Ryzen 9 9950X",
      "brand": "AMD",
      "family": "part",
      "category": "cpu",
      "priceCents": 259600000,
      "oldPriceCents": 279600000,
      "stockLevel": "stable",
      "bestOfferId": "off-2002",
      "imageUrl": null,
      "summary": "16 nucleos, 5.7 GHz, Zen 5",
      "quickSpecs": [],
      "specs": [],
      "offers": []
    }
  ],
  "total": 2,
  "page": 0,
  "pageSize": 20
}
```

(El segundo producto muestra un caso valido con listas vacias y sin imagen. En el listado `offers` siempre es `[]`; el ejemplo de la seccion 2 muestra un detalle con ofertas. Los datos son de ejemplo.)

---

## 6. Decisiones abiertas

| # | Tema | Estado |
|---|---|---|
| D1 | **Moneda.** COP, montos en centavos, enteros de 64 bits (ver seccion 1). | **Cerrada (v0.2)** |
| D2 | **Nombre corto.** El mismo producto necesita a veces un nombre largo (detalle) y uno corto (tarjeta). Opcion: agregar `shortName` (string o `null`) a `Product`. | Pendiente |
| D3 | **Valor de N** para `critical` (de 1 a N unidades). 0 unidades es `outOfStock`. Sugerido: N = 5. | Pendiente de confirmar el valor de N |
| D4 | **Imagenes.** Campo `imageUrl` (string o `null`) con la miniatura para listas. La galeria del detalle se define en la fase 3. | **Cerrada (v0.3)** |
| D5 | **Orden y `sort`.** `relevance`, `priceAsc` y `priceDesc` (seccion 3.1). Un puntaje real de relevancia para la busqueda queda para despues. | **Cerrada (v0.4)** |
| D6 | **Ocultar agotados.** Hoy los `outOfStock` se listan. Opcion futura: parametro `availableOnly=true`. | Pendiente |
| D7 | **Unidades disponibles.** El front no recibe las unidades: cada linea del carrito trae `maxQuantity` (el stock con un tope de 10 por linea) y el backend valida cada cambio (seccion 10). | **Cerrada (v0.5)** |
| D8 | **Computadores armados.** No se venden: NEXUS vende solo piezas y el cliente arma su equipo en el PC Builder o con el asistente (decision del 2026-10-27). | **Cerrada (v0.11)** |
| D9 | **Perifericos.** Si las piezas incluyen monitor, teclado o mouse. Supuesto S-10: no, solo componentes internos. | Pendiente (negocio) |

---

## 7. Fuera de esta version (reservado)

Estas partes se agregan a este mismo archivo cuando se necesiten. No implementar nada de esto todavia.

- **Autenticacion**: la hace Supabase Auth directamente (fase 4, `docs/MODELO_DATOS.md`); no tiene endpoints propios.
- **Historial y seguimiento de pedidos** (fase 9 del plan).

---

## 8. Como se cambia este contrato

1. Se propone el cambio **editando este archivo** (nuevo campo, endpoint o regla).
2. Los dos lados lo revisan antes de escribir codigo.
3. Se agrega una linea al registro de cambios.
4. Solo entonces se implementa.

Cambios compatibles (agregar un campo opcional, un endpoint nuevo): no rompen a nadie. Cambios que rompen (renombrar o quitar un campo, cambiar un tipo): requieren avisar y acordar antes.

### Registro de cambios

| Version | Cambio |
|---|---|
| 0.1 | Primer borrador: catalogo (listar, detalle, relacionados). |
| 0.2 | Moneda fijada en COP (centavos, enteros de 64 bits, multiplos de 100). Nuevo valor `outOfStock` en `stockLevel` (0 unidades = no disponible). `critical` = de 1 a N unidades. Los agotados se listan. Precios de los ejemplos pasados a COP. |
| 0.3 | Nuevo enfoque del analisis v2: se elimina `phone` y se agrega la categoria `prebuiltPc`. Nuevos campos en `Product`: `family`, `imageUrl` (cierra D4) y `offers` (modelo `Offer`, solo en el detalle). `priceCents`, `oldPriceCents` y `stockLevel` pasan a reflejar la mejor oferta. Nuevo parametro `family` en el listado. Fixture corregido (antes filtraba `gpu` y devolvia un CPU). Implementacion con RPC de Supabase. Nuevas decisiones D8 y D9. |
| 0.3.1 | Seccion 3.4: nombres de las RPC y de sus parametros (`page_size`, `max_items`). Sin cambios en las respuestas. |
| 0.4 | Listado: nuevos parametros `brand`, `minPriceCents`, `maxPriceCents` y `sort` (cierra D5). Nuevo endpoint 3.5 de marcas (`get_catalog_brands`). Cambios compatibles: los parametros son opcionales. |
| 0.5 | Nuevo campo `bestOfferId` en `Product`. Parte 2: carrito (seccion 10), con nuevos codigos de error `OUT_OF_STOCK`, `QUANTITY_UNAVAILABLE`, `OFFER_NOT_FOUND` y `AUTH_REQUIRED`. `details` puede traer JSON en texto. Cierra D7. Cambios compatibles. |
| 0.6 | Parte 3: PC Builder (seccion 11): ranuras, validacion con el motor de reglas y piezas candidatas. Endpoints nuevos; sin cambios en los existentes. |
| 0.7 | Seccion 11.4: `get_build_scene`, modelos 3D y atributos visuales de una configuracion (RF-090). Endpoint nuevo; sin cambios en los existentes. |
| 0.9 | Seccion 11.5: `get_prebuilt_scene`, componentes de un computador armado para verlo en 3D. Endpoint nuevo; sin cambios en los existentes. |
| 0.8 | Parte 4: asistente (seccion 12), la Edge Function `assistant`. Nuevos codigos `RATE_LIMITED` y `ASSISTANT_UNAVAILABLE`. Endpoint nuevo; sin cambios en los existentes. |
| 0.10 | Parte 5: checkout y pagos con Wompi (seccion 13): la Edge Function `checkout` y el webhook `payment-webhook`. Nuevos codigos `CART_EMPTY`, `CART_CHANGED`, `PRICE_CHANGED`, `ADDRESS_NOT_FOUND`, `PAYMENT_NOT_FOUND` y `PAYMENTS_UNAVAILABLE`. Endpoints nuevos; sin cambios en los existentes. |
| 0.11 | **Solo piezas** (cierra D8): se eliminan la categoria `prebuiltPc` y la seccion 11.5 (`get_prebuilt_scene`). `family` queda siempre en `part` y el parametro `family` solo admite `part`. El asistente recomienda piezas sueltas o una configuracion completa. Cambio que rompe para un front que dependa de los armados; el front actual ya no los usa. |
| 0.12 | Seccion 11.3: `get_builder_candidates` acepta `search`, `max_price_cents`, `sort` y `page`, para elegir entre cientos de piezas por tipo. Parametros opcionales: compatible. |
| 0.13 | Tres roles (cliente, tienda y administrador). Parte 6: catalogo por oferta, una tarjeta por tienda (`get_offers`, `get_catalog_providers`). Parte 7: cuenta propia, administracion de tiendas y la Edge Function `admin-providers`. Parte 8: publicaciones de tiendas sin aprobacion, con validaciones automaticas. Nuevos codigos de error de las partes 7 y 8; `VALIDATION_ERROR` puede traer `details.field`. El carrito y el checkout responden `CUSTOMER_ONLY` a las cuentas que no son de cliente. Endpoints nuevos; los existentes no cambian. |
| 0.14 | Parte 9: panel de la tienda (seccion 17): resumen (`get_my_dashboard`), pedidos con su flujo de estados (`get_my_orders`, `get_my_order`, `update_my_order_status`) e inventario con movimientos y stock minimo (`get_my_inventory`, `adjust_my_stock`, `set_my_min_stock`, `get_my_stock_movements`). La sub-orden pasa de un solo estado (`pending`) a nueve. Nuevo codigo `INVALID_TRANSITION`. Endpoints nuevos; los existentes no cambian. |
| 0.15 | Parte 10: consola del administrador (seccion 18): resumen global (`admin_get_dashboard`), tiendas con metricas e historial (`admin_list_providers`, `admin_get_provider_overview`, `admin_add_provider_note`), moderacion posterior con alertas de calidad (`admin_list_offers`, `admin_get_offer`, `admin_moderate_offer`, `admin_update_product`, `request_my_offer_review`) y pedidos de todas las tiendas (`admin_list_orders`, `admin_get_order`, `admin_update_sub_order_status`, `admin_add_order_note`). **Cambia** `admin_set_provider_status`: suma `blocked` y `deactivated` y exige el motivo. Las publicaciones de la tienda suman `moderationStatus` y `moderationReason`. Codigos nuevos: `SAME_STATUS`, `NOT_HIDDEN`. |

---

## 9. Notas de desarrollo

- Desde el **emulador de Android**, `localhost` apunta al propio emulador. Para llegar al backend que corre en tu PC se usa `http://10.0.2.2:<puerto>`.
- Desde un **celular fisico**, usar la IP del PC en la red local (ambos en la misma red).
- Android puede bloquear HTTP sin TLS. Eso se resuelve en el front en el paso de conexion real y **no afecta al contrato**.

---

## 10. Parte 2: carrito (v0.5)

Una **linea** del carrito es una **oferta** (producto + proveedor), porque cada proveedor fija su precio y despacha por separado. El front guarda o envia `offerId` y cantidad; el backend devuelve siempre los datos vigentes.

### 10.1 Modelo `CartLine`

```json
{
  "offerId": "off-mp-z790hero",
  "quantity": 2,
  "maxQuantity": 3,
  "available": true,
  "priceCents": 599990000,
  "oldPriceCents": 699990000,
  "stockLevel": "critical",
  "providerId": "prov-mundopc",
  "providerName": "Mundo PC",
  "productId": "rog-maximus-z790-hero",
  "productName": "ROG MAXIMUS Z790 HERO",
  "brand": "ASUS",
  "category": "motherboard",
  "imageUrl": null
}
```

| Campo | Tipo | Notas |
|---|---|---|
| `quantity` | entero | Lo que hay en el carrito. Puede ser mayor que `maxQuantity` si el stock bajo despues de agregar. |
| `maxQuantity` | entero | Unidades que se pueden comprar: el stock con un tope de **10 por linea**. `0` si no esta disponible. **Nunca se envian las unidades reales** cuando superan el tope. |
| `available` | bool | `false` si la oferta se pauso, se retiro, se agoto o su proveedor no esta activo. |
| `priceCents`, `oldPriceCents` | entero | Precio **vigente** de la oferta (RN-001). |
| `stockLevel` | enum | Como en `Product`; `outOfStock` si `available` es `false`. |
| `category` | enum o `null` | Como en `Product`. |

Una linea se puede pagar si `available` y `quantity <= maxQuantity`. El front solo suma esas al total, y no permite confirmar si alguna linea no se puede pagar.

### 10.2 Endpoints (RPC)

Todas responden `200` con `{"items": [CartLine, ...]}`: el carrito completo, en el orden en que se agregaron las lineas.

| RPC | Sesion | Parametros | Que hace |
|---|---|---|---|
| `preview_cart` | no | `items`: `[{"offerId", "quantity"}]`, maximo 50 | Vista vigente del carrito de invitado (que guarda el front). Omite ofertas inexistentes. No guarda nada. |
| `get_cart` | si | — | Carrito guardado del usuario (RF-054). |
| `add_cart_item` | si | `offer_id`, `quantity` (defecto 1) | Suma unidades a la linea (la crea si no existe). |
| `set_cart_item` | si | `offer_id`, `quantity` | Fija la cantidad de la linea. |
| `remove_cart_item` | si | `offer_id` | Quita la linea. |
| `clear_cart` | si | — | Vacia el carrito. |
| `merge_cart` | si | `items`: `[{"offerId", "quantity"}]` | Al iniciar sesion: suma el carrito de invitado al guardado. Cada linea queda limitada a `maxQuantity`; las no disponibles se descartan sin error. |

Reglas (RN-028): la cantidad va de 1 a `maxQuantity`. Cada linea es una oferta distinta: la misma oferta no se repite.

### 10.3 Errores del carrito

| HTTP | `code` | Cuando | `details` |
|---|---|---|---|
| 401 | `AUTH_REQUIRED` | RPC con sesion llamada sin sesion. | — |
| 404 | `OFFER_NOT_FOUND` | La oferta no existe. | — |
| 409 | `OUT_OF_STOCK` | La oferta no esta disponible (pausada, agotada, proveedor inactivo). | — |
| 409 | `QUANTITY_UNAVAILABLE` | La cantidad pedida supera `maxQuantity`. | **JSON en texto**: `"{\"maxQuantity\" : 3}"` |
| 400 | `VALIDATION_ERROR` | `quantity` menor que 1 o `items` no es una lista. | — |

`details` es siempre **texto** (asi lo exige PostgREST). Cuando trae datos, es un JSON serializado que el front decodifica.

---

## 11. Parte 3: PC Builder (v0.6)

La compatibilidad la decide **el backend** con reglas tecnicas versionadas (RN-013). El front no la calcula ni la supone: envia las ofertas elegidas y muestra lo que el backend responde.

### 11.1 Ranuras: `get_builder_slots`

`200`: lista de `{"category", "label", "required"}` en el orden del armador. Hoy son `cpu`, `motherboard`, `ram`, `gpu` (opcional), `storage`, `psu`, `pcCase` y `cooling` (opcional). La grafica pasa a ser obligatoria si el procesador no tiene graficos integrados: lo dice la regla `video_output`.

### 11.2 Validar una configuracion: `validate_build`

Parametro: `offer_ids`, una lista de 0 a 12 ids de oferta, con una sola pieza por ranura. No requiere sesion.

```json
{
  "valid": false,
  "purchasable": false,
  "parts": [
    { "offerId": "off-tp-9950x", "category": "cpu", "productId": "ryzen-9-9950x",
      "productName": "RYZEN 9 9950X", "brand": "AMD", "providerName": "TecnoPartes",
      "priceCents": 259600000, "available": true, "imageUrl": null }
  ],
  "issues": [
    { "ruleCode": "cpu_motherboard_socket", "severity": "error",
      "message": "El procesador usa el socket AM5 y la placa madre el LGA1700: no encajan entre si.",
      "offerIds": ["off-tp-9950x", "off-mp-z790hero"] }
  ],
  "missingSlots": [ { "category": "ram", "label": "Memoria RAM" } ],
  "totalCents": 859590000
}
```

| Campo | Notas |
|---|---|
| `valid` | Sin incompatibilidades (`issues` con `severity: "error"`) y sin ranuras obligatorias vacias (RN-031). |
| `purchasable` | `valid` y, ademas, todas las piezas disponibles. Solo entonces el front ofrece llevar la configuracion al carrito. |
| `issues[].severity` | `error`: incompatibilidad. `warning`: **no se pudo verificar** una regla porque a una pieza le falta un dato tecnico obligatorio. El backend nunca supone compatibilidad. Un valor desconocido se trata como `error`. |
| `issues[].message` | Texto listo para mostrar, en lenguaje simple (RNF-023). |
| `issues[].offerIds` | Piezas que causan el problema. En la falta de potencia incluye la fuente y las piezas que consumen. Puede ser `[]` para avisos generales. |
| `parts[].available` | `false` si la oferta ya no se puede comprar. |

Errores: `400 VALIDATION_ERROR` (mas de 12 ofertas o dos piezas de la misma ranura) y `404 OFFER_NOT_FOUND`.

### 11.3 Piezas para una ranura: `get_builder_candidates`

Parametros:
- `category` (una ranura) y `offer_ids` (la configuracion actual; la pieza de esa ranura se ignora).
- `max_items`: tamano de pagina, defecto 30, maximo 50.
- `search` (v0.12): texto del nombre, la marca o el tipo, sin distinguir mayusculas ni acentos.
- `max_price_cents` (v0.12): precio maximo inclusivo, sobre la mejor oferta.
- `sort` (v0.12): `priceAsc` (defecto) o `priceDesc`.
- `page` (v0.12): base 0. La siguiente pagina se pide si la anterior vino llena.

`200`: lista de `Product` (seccion 2) con dos campos mas:
- `compatible` (bool): si al ponerla en la ranura no aparece ninguna incompatibilidad que la involucre;
- `incompatibilityReason` (string o `null`): el primer motivo, si no es compatible.

Orden: primero las compatibles, luego las que tienen stock, luego por precio (segun `sort`). La pieza se agrega con su `bestOfferId`.

Errores: `400 VALIDATION_ERROR` si `category` no es una ranura del armador, `sort` es otro valor, o `page` o `max_price_cents` son negativos.

### 11.4 Escena para la vista 3D: `get_build_scene` (v0.7)

Parametro: `offer_ids`, con las mismas reglas y errores que `validate_build`.

`200`:

```json
{
  "parts": [
    {
      "offerId": "off-tp-rtx5080",
      "category": "gpu",
      "productName": "NVIDIA RTX 5080",
      "attributes": { "length_mm": 304 },
      "model": {
        "path": "generic/gpu.glb",
        "rotation": [0, 180, 0],
        "generic": true,
        "title": "Graphics card",
        "author": "pgonarg",
        "license": "CC-BY-3.0",
        "sourceUrl": "https://poly.pizza/m/i45v5trpyR"
      }
    },
    {
      "offerId": "off-mp-rm850x",
      "category": "psu",
      "productName": "CORSAIR RM850x",
      "attributes": {},
      "model": null
    }
  ]
}
```

- `parts` va en el orden de las ranuras.
- `attributes` trae solo los atributos que cambian como se ve la pieza, si el producto los tiene: `form_factor`, `ram_slots`, `modules`, `length_mm`, `storage_type`, `cooling_type`, `height_mm`, `radiator_mm`, `max_gpu_length_mm` y `max_cooler_height_mm`.
- `model` es el modelo del producto exacto o, si no hay, el generico de la categoria (`generic: true`). Es `null` si no hay ninguno: la app genera la pieza.
  - `path` es la ruta del archivo `.glb` en el bucket publico `component-models` de Storage. La app arma la direccion con el cliente de Supabase, para que sirva igual en el emulador (`10.0.2.2`) y en el PC.
  - `rotation` son los grados (X, Y, Z) que dejan el modelo en la orientacion de su categoria.
  - `license` es `CC0-1.0`, `CC-BY-3.0`, `CC-BY-4.0` o `propia`. Con CC BY, la app muestra titulo, autor, licencia y `sourceUrl`.

### 11.5 Computador armado en 3D (retirado en v0.11)

`get_prebuilt_scene` existio de la v0.9 a la v0.10 para ver en 3D los componentes de un computador armado. Se elimino junto con los armados: la vista 3D muestra la configuracion de piezas del cliente (11.4).

---

## 12. Parte 4: asistente (v0.8)

Asistente de recomendacion (HU-006, RF-036 a RF-045, RF-089). Es una Edge Function, no una RPC: `POST /functions/v1/assistant`. No exige sesion; si la app envia el token de una sesion, la interaccion queda asociada a la cuenta.

### 12.1 Pregunta

```json
{
  "sessionId": "9f1c2a7be0d34c55a1f0b2c3d4e5f607",
  "messages": [
    { "role": "user", "text": "Necesito un computador de oficina para trabajar y editar videos" },
    { "role": "assistant", "text": "¿Cual es tu presupuesto aproximado?" },
    { "role": "user", "text": "Unos 8 millones de pesos" }
  ]
}
```

- `messages`: la conversacion, de 1 a 12 turnos (se usan los ultimos 12). Cada texto tiene de 1 a 1000 caracteres. El ultimo turno es del cliente (`user`).
- Los turnos `assistant` resumen lo que respondio antes, incluidos los productos y las ofertas que recomendo, para que pueda seguir la conversacion.
- `sessionId`: de 8 a 64 caracteres (letras, numeros, `_` o `-`), generado por la app. Agrupa los turnos para la trazabilidad (RF-043).

### 12.2 Respuesta `200`

```json
{
  "type": "recommendation",
  "message": "Para jugar en 1080p con tu fuente de 650 W, estas tarjetas te sirven.",
  "products": [
    { "product": { "id": "rtx-5060", "...": "Product (seccion 2)" },
      "reason": "8 GB de memoria de video y pide una fuente de 550 W: la tuya alcanza." }
  ],
  "build": null,
  "interactionId": "f7b369de-20e2-4a23-ab7a-896e450fb762",
  "sessionId": "9f1c2a7be0d34c55a1f0b2c3d4e5f607"
}
```

| `type` | Significado | Campos |
|---|---|---|
| `question` | Falta informacion, por ejemplo el uso o el presupuesto (RF-037). | `message` es la pregunta. |
| `recommendation` | Recomendacion (RF-038 a RF-040). | `products` (hasta 3 piezas sueltas, cuando el cliente busca una pieza o mejorar su equipo) y/o `build` (un computador completo por piezas). |
| `noMatch` | No hay nada adecuado o la peticion no es sobre computadores (RF-041). | `message` explica que si puede hacer. |

- `products[].product` es un `Product` completo (seccion 2) y `reason` explica por que le sirve, con sus atributos reales.
- `build` es una configuracion de piezas: `{ "reason": "...", "validation": <respuesta de validate_build> }`. Las piezas de la configuracion no se repiten en `products`.
- **Garantia del servidor (RF-041, RN-015):** antes de responder, la funcion comprueba que cada producto exista, este publicado y tenga stock, y que `build` sea valido y comprable.
  - Si el modelo propone algo que no cumple, se le pide corregir.
  - Si al final no queda nada valido, responde `noMatch`.
- El asistente nunca agrega al carrito ni compra (RF-088). La app ofrece ver el producto, agregarlo o abrir la configuracion en el PC Builder (RF-042).

### 12.3 Errores

| HTTP | `code` | Cuando |
|---|---|---|
| 400 | `VALIDATION_ERROR` | La conversacion no cumple 12.1. |
| 429 | `RATE_LIMITED` | Mas de 20 preguntas en 10 minutos desde el mismo cliente. |
| 503 | `ASSISTANT_UNAVAILABLE` | Ningun modelo respondio (caido o sin cuota). La app ofrece el catalogo y el PC Builder (RNF-018). |

---

## 13. Parte 5: checkout y pagos (v0.10)

Compra del carrito guardado con pago en **Wompi** (COP), en modo de pruebas mientras no haya cuenta de produccion (HU-010, HU-011, RF-055 a RF-061). Exige sesion (RN-027). Es una Edge Function: `POST /functions/v1/checkout`, con el token de la sesion en `Authorization`.

**Flujo:**
1. La app envia `start` con la direccion, el contacto y el total que vio el cliente.
2. El backend revalida el carrito (RF-055), guarda el intento de pago y devuelve la URL firmada del Web Checkout.
3. El cliente paga en Wompi (tarjeta, PSE o Nequi). Al terminar, Wompi redirige a `redirectUrl?id=<transaccion>`; la app intercepta esa URL y no la abre.
4. La app envia `status` con la referencia y el id. Wompi tambien avisa al webhook. Los dos caminos aplican el resultado una sola vez (RNF-020).
5. **La orden se crea solo con el pago aprobado (RN-025)**: una sub-orden por proveedor, el stock descontado y lo comprado fuera del carrito.

**Precios:** el cliente paga el precio publicado, que ya incluye el IVA del 19 % (RN-001). La comision de NEXUS se calcula sobre el valor sin IVA y se descuenta de lo que recibe el proveedor; no viaja a la app (RN-002). **Envio:** sin costo adicional para el cliente (supuesto, pendiente del negocio).

### 13.1 Iniciar el pago: `start`

```json
{
  "action": "start",
  "addressId": "8d0c4f8e-2b7a-4c1e-9a55-0f3e2d1c4b6a",
  "contact": {
    "fullName": "Ana Perez",
    "email": "ana@correo.co",
    "phone": "3001234567",
    "documentType": "CC",
    "documentNumber": "1065123456"
  },
  "expectedTotalCents": 313990000
}
```

- `addressId`: una direccion del usuario (cuentas, `docs/MODELO_DATOS.md`). Se guarda una copia: cambiarla despues no altera el pedido.
- `contact`: nombre (2 a 120 caracteres), correo, telefono (7 a 15 digitos), `documentType` (`CC`, `CE`, `NIT`, `PP` o `TI`) y `documentNumber` (4 a 20 letras o numeros; se ignoran puntos y espacios). Wompi los usa para prellenar el pago.
- `expectedTotalCents`: el total del carrito que vio el cliente.

Respuesta `200`:

```json
{
  "reference": "NX-20261024-733D2C28F6",
  "amountCents": 313990000,
  "currency": "COP",
  "expiresAt": "2026-10-25T00:41:55.756115+00:00",
  "checkoutUrl": "https://checkout.wompi.co/p/?public-key=pub_test_...&reference=NX-20261024-733D2C28F6&signature:integrity=...",
  "redirectUrl": "https://<proyecto>.supabase.co/functions/v1/checkout"
}
```

- El intento vence en `expiresAt` (60 minutos). Un intento nuevo abandona el anterior si este no llego a Wompi.
- `checkoutUrl` lleva la firma de integridad: si se cambia el valor o la referencia en la URL, Wompi la rechaza.

### 13.2 Consultar el resultado: `status`

```json
{ "action": "status", "reference": "NX-20261024-733D2C28F6", "transactionId": "1234-1730000000-00001" }
```

`transactionId` es opcional: es el `id` que Wompi agrega a `redirectUrl`. Si el pago no esta aprobado, el backend consulta la transaccion en Wompi y aplica lo que responda. Sin `transactionId`, solo puede hacerlo si tiene la llave privada.

Respuesta `200`:

```json
{
  "reference": "NX-20261024-733D2C28F6",
  "status": "approved",
  "amountCents": 313990000,
  "currency": "COP",
  "transactionId": "1234-1730000000-00001",
  "paymentMethod": "CARD",
  "message": null,
  "expiresAt": "2026-10-25T00:41:55.756115+00:00",
  "order": {
    "id": "df3759c9-de3c-434c-9c3b-2028e68fd3c6",
    "number": "NX-000005",
    "status": "paid",
    "totalCents": 313990000,
    "createdAt": "2026-10-24T23:41:55.846419+00:00",
    "subOrders": [
      {
        "id": "aa2ac493-e82e-4db0-bd90-9873f423c932",
        "providerName": "Mundo PC",
        "status": "pending",
        "subtotalCents": 313990000,
        "items": [
          { "productId": "corsair-rm850x", "productName": "CORSAIR RM850x", "brand": "Corsair",
            "quantity": 1, "unitPriceCents": 64990000, "lineTotalCents": 64990000, "backorderedUnits": 0 }
        ]
      }
    ]
  }
}
```

| `status` | Significado | `order` |
|---|---|---|
| `pending` | Esperando a Wompi. Sin `transactionId`, el cliente no termino el pago o el aviso no ha llegado. | `null` |
| `approved` | Pagado. No cambia mas. | La orden |
| `declined`, `voided`, `error` | Wompi no cobro. El cliente puede intentar de nuevo con otro medio; si una transaccion posterior se aprueba, se acepta. | `null` |
| `abandoned` | El cliente empezo otro intento sin pagar este. Si igual se paga, se acepta. | `null` |

- `backorderedUnits`: unidades que ya no habia en stock cuando se aprobo el pago, porque otra compra se las llevo. El proveedor las resuelve; la fase 9 define el reembolso.
- `subOrders[].status` es `pending` (esperando al proveedor). La fase 9 agrega los demas estados.
- `GET /functions/v1/checkout` es la pagina de regreso para quien paga fuera de la app (web): un texto que pide volver a NEXUS.

### 13.3 Webhook de Wompi: `payment-webhook`

`POST /functions/v1/payment-webhook` recibe los eventos `transaction.updated` de Wompi. No lo usa la app.

- Verifica `signature.checksum` con el secreto de eventos: SHA-256 de los valores de `signature.properties`, el `timestamp` y el secreto. Con firma invalida responde `401` y no aplica nada.
- Responde `200` cuando aplica el evento, cuando ya lo conocia y cuando la referencia no existe. Responde `500` si falla la base, para que Wompi reintente.
- Cada evento queda en `payment_events` (RF-058, RF-079).

### 13.4 Errores

| HTTP | `code` | Cuando |
|---|---|---|
| 400 | `VALIDATION_ERROR` | El contacto o el cuerpo no cumplen 13.1. |
| 401 | `AUTH_REQUIRED` | Sin sesion. |
| 404 | `ADDRESS_NOT_FOUND` | La direccion no existe o es de otro usuario. |
| 404 | `PAYMENT_NOT_FOUND` | La referencia no existe o es de otro usuario. |
| 409 | `CART_EMPTY` | El carrito guardado esta vacio. |
| 409 | `CART_CHANGED` | Una linea se agoto o tiene mas unidades de las disponibles. La app recarga el carrito. |
| 409 | `PRICE_CHANGED` | El total cambio. `details` trae `{"totalCents": n}` en texto. La app recarga el carrito. |
| 429 | `RATE_LIMITED` | Mas de 10 intentos de pago en 10 minutos. |
| 503 | `PAYMENTS_UNAVAILABLE` | Faltan las llaves de Wompi en el servidor. El carrito no se pierde. |

---

## 14. Parte 6: catalogo por oferta (v0.13)

Regla del negocio: **si varias tiendas venden el mismo producto, el catalogo muestra una tarjeta por tienda**, cada una con su precio, su descuento y su stock, aunque el nombre, la marca y el modelo sean iguales. La ficha tecnica sigue siendo una sola (`Product`) y cada tienda es duena de su oferta (`Offer`). La comparacion entre tiendas esta en el detalle (`get_product`, seccion 3.2: `offers[]`).

`get_products`, `get_product` y `get_related` no cambian: los siguen usando el detalle, el PC Builder y el asistente.

### 14.1 Modelo `CatalogOffer`

```json
{
  "offerId": "off-b-5070",
  "productId": "rtx-5070",
  "name": "NVIDIA GeForce RTX 5070",
  "brand": "NVIDIA",
  "category": "gpu",
  "providerId": "prov-b",
  "providerName": "Tienda B",
  "priceCents": 265000000,
  "oldPriceCents": 280000000,
  "stockLevel": "critical",
  "imageUrl": null,
  "summary": "12 GB GDDR7",
  "quickSpecs": ["12GB"],
  "offerCount": 3
}
```

- `priceCents`, `oldPriceCents` y `stockLevel` son **de esta oferta**, no la mejor del producto.
- `providerName` es el nombre visible de la tienda (lo cambia solo un administrador).
- `offerCount`: cuantas tiendas venden el producto (ofertas visibles), para "Comparar N".

### 14.2 Listar ofertas: `get_offers`

`rpc/get_offers(page, page_size, search, category, brand, provider, min_price_cents, max_price_cents, sort)` responde `{items: [CatalogOffer], total, page, pageSize}`.

- Mismas reglas de visibilidad que el resto del catalogo: ofertas publicadas de tiendas activas en categorias activas. Las agotadas se listan.
- `provider`: id de la tienda (filtro por tienda). Se filtra por id porque dos tiendas pueden tener el mismo nombre visible.
- `search` busca tambien por el nombre de la tienda.
- `min_price_cents` y `max_price_cents` usan el precio de cada oferta.
- `sort`: `relevance` ordena por nombre y deja juntas las ofertas del mismo producto (primero con stock, despues por precio); `priceAsc` y `priceDesc`, por el precio de cada oferta. El id de la oferta desempata (paginas estables).
- `page_size` tiene tope de 50.

### 14.3 Tiendas para el filtro: `get_catalog_providers`

`rpc/get_catalog_providers(category)` responde `[{id, displayName, offerCount}]`: las tiendas con ofertas visibles, de una categoria o de todas.

### 14.4 Errores

`VALIDATION_ERROR` (400) por `page`, `sort`, `category` o precios invalidos, y por un `provider` desconocido.

---

## 15. Parte 7: roles y administracion de tiendas (v0.13)

Tres roles exclusivos: **cliente** (compra), **tienda** (publica) y **administrador** (crea y habilita tiendas). El backend valida el rol en cada funcion; la app solo lo usa para elegir la navegacion.

- Toda cuenta del registro publico es cliente. El rol no sale de los metadatos del registro y el usuario no lo puede cambiar.
- Solo los clientes usan el carrito y el checkout: las demas cuentas reciben `403 CUSTOMER_ONLY`.
- El primer administrador se habilita por SQL (`private.grant_admin`), fuera de la API (`backend/README.md`).

### 15.1 Cuenta propia

| RPC | Respuesta |
|---|---|
| `get_my_account()` | `{userId, role, fullName, mustChangePassword, pendingDocuments: [{code, version, title}], provider: {id, displayName, status} o null}` |
| `accept_current_documents(documents)` | La cuenta actualizada. `documents` = `[{code, version}]` con **todas** las versiones vigentes; si falta alguna, `400 CONSENT_REQUIRED`. |

`role`: `customer`, `provider` o `admin`. `provider.status`: `pending`, `active`, `suspended`, `blocked`, `deactivated` o `rejected` (18.2).

Una cuenta de tienda creada por un administrador tiene `mustChangePassword = true` (contrasena temporal) y los documentos pendientes. El cambio de contrasena se hace con Supabase Auth (`updateUser`); el backend quita la marca solo.

### 15.2 Administracion (solo administradores)

| RPC | Que hace |
|---|---|
| `admin_get_providers(search)` | Lista de tiendas (`AdminStore`). |
| `admin_get_provider(id)` | Una tienda. |
| `admin_set_provider_status(id, status, reason?)` | `status`: `active`, `suspended`, `blocked` o `deactivated`, con motivo salvo para habilitar (18.2). Sin habilitar, sus ofertas salen del catalogo y no puede operar. |
| `admin_update_provider(id, store, confirm_similar_name)` | Edita los datos (incluido el nombre visible). |
| `admin_validate_store(store, confirm_similar_name)` | Valida los datos antes del alta (la usa la Edge Function). |

`AdminStore`: `{id, legalName, displayName, taxId, contactEmail, status, verificationNote, accountEmail, publishedOffers, createdAt}`. `store` en las entradas: `{legalName, displayName, taxId, contactEmail, verificationNote?}`.

### 15.3 Alta de cuentas de tienda: Edge Function `admin-providers`

`POST /functions/v1/admin-providers` con la sesion del administrador. La clave de servicio solo existe en el servidor.

| `action` | Cuerpo | Que hace |
|---|---|---|
| `create_provider` | `{store, account: {email, fullName}, confirmSimilarName?}` | Crea la tienda (activa) y su cuenta. |
| `create_account` | `{providerId, account}` | Crea la cuenta de una tienda que ya existia sin cuenta. Conserva su estado y sus ofertas. |
| `reset_password` | `{providerId}` | Regenera la contrasena temporal. La anterior deja de servir. |

Responde `{provider: AdminStore, temporaryPassword}` (201 al crear, 200 al regenerar) con `cache-control: no-store`. La contrasena es aleatoria (20 caracteres), se entrega una sola vez y NEXUS no la guarda ni la registra en logs.

### 15.4 Errores

| HTTP | `code` | Cuando |
|---|---|---|
| 401 | `AUTH_REQUIRED` | Sin sesion. |
| 403 | `FORBIDDEN` | La cuenta no es administradora. |
| 403 | `CUSTOMER_ONLY` | Una tienda o un administrador usan el carrito o el checkout. |
| 400 | `VALIDATION_ERROR` | Datos invalidos. |
| 400 | `CONSENT_REQUIRED` | Faltan versiones vigentes al aceptar documentos. |
| 404 | `PROVIDER_NOT_FOUND` | La tienda no existe (o no tiene cuenta, al regenerar). |
| 409 | `TAX_ID_TAKEN` | Otra tienda tiene ese NIT. |
| 409 | `SIMILAR_STORE_NAME` | Otra tienda tiene un nombre visible equivalente. `details`: `{providerId, displayName}`. Se acepta con `confirmSimilarName` (dos negocios distintos pueden llamarse igual). |
| 409 | `EMAIL_EXISTS` | Ya hay una cuenta con ese correo. |
| 409 | `PROVIDER_HAS_ACCOUNT` | La tienda ya tiene cuenta. |
| 502 | `AUTH_UNAVAILABLE` | Supabase Auth no respondio. |

---

## 16. Parte 8: publicaciones de tiendas (v0.13)

Una tienda publica **sin aprobacion del administrador**: el producto queda en el catalogo en cuanto pasa las validaciones automaticas. Todas las RPC exigen una tienda que pueda operar (rol tienda, tienda activa, contrasena definitiva y documentos aceptados) y filtran por la tienda de la cuenta; ninguna recibe el id de la tienda.

- La ficha (`Product`) es compartida. Si el producto ya existe, la tienda solo crea su oferta y queda en la comparacion de precios.
- Quien registro la ficha la puede editar mientras sea la unica tienda con una oferta sobre ella (en cualquier estado). Despues queda fija; las correcciones las hace un administrador.
- Cada tienda administra solo su oferta: precio, precio anterior (descuento), stock y estado (`draft`, `published`, `paused`). Retirar es logico (`retired`) y se vuelve a publicar con `create_my_offer`.

### 16.1 RPC

| RPC | Que hace |
|---|---|
| `search_catalog_sheets(search, category, page, page_size)` | Fichas del catalogo, tengan o no ofertas visibles: `{items: [{productId, name, brand, model, category, imageUrl, sellers, myOffer: {offerId, status} o null}], total, page, pageSize}`. |
| `get_my_offers(status, search, page, page_size)` | "Mis publicaciones" (`MyOffer`). Sin `status`, todas menos las retiradas. |
| `get_my_offer(product_id)` | La publicacion con la ficha completa. |
| `create_my_product(product, offer, confirm_distinct)` | Registra un producto nuevo con la oferta de la tienda. |
| `update_my_product(product_id, product)` | Edita la ficha (reglas arriba). La categoria no cambia. |
| `create_my_offer(product_id, offer)` | Publica la oferta sobre un producto existente o reactiva la retirada. |
| `update_my_offer(product_id, offer)` | Precio, descuento, stock y estado. |
| `retire_my_offer(product_id)` | Retiro logico. |

`MyOffer`: `{offerId, productId, name, brand, model, category, imageUrl, priceCents, oldPriceCents, stockUnits, stockLevel, status, externalSku, visible, canEditSheet, updatedAt}`. A la tienda si se le muestran sus unidades (`stockUnits`). El detalle agrega `{summary, quickSpecs, specs, attributes: {clave: valor}, images: [{url, path}], sellers}`.

`product`: `{category, name, brand, model, summary?, quickSpecs?, specs?, attributes: {clave: valor}, images: [ruta]}`. `offer`: `{priceCents, oldPriceCents?, stockUnits, status?, externalSku?}`.

### 16.2 Validaciones automaticas

- Categoria activa; nombre, marca y **modelo** obligatorios.
- Atributos contra la plantilla de la categoria (`attribute_definitions`): obligatorios, tipo y valores permitidos.
- Precio mayor que 0 en pesos enteros (multiplo de 100); precio anterior mayor que el precio; stock entero de 0 a 100000.
- Entre 1 y 8 imagenes: rutas del bucket `product-images` en la carpeta de la tienda (`<tienda>/<archivo>`), subidas por la misma cuenta. La URL publica la arma el backend.
- **Duplicados:** (categoria, marca, modelo) normalizados son unicos (`PRODUCT_EXISTS`). Modelos parecidos de la misma marca responden `POSSIBLE_DUPLICATE` salvo `confirm_distinct`.
- Limite diario de productos nuevos por tienda (`app_settings.provider_daily_product_limit`, 50).

### 16.3 Imagenes

Bucket publico `product-images` (JPG, PNG o WEBP de hasta 5 MB). La tienda sube solo a su carpeta y no puede reemplazar ni borrar lo subido: una ficha compartida no cambia de imagen. La app sube el archivo y envia la ruta en `product.images`.

### 16.4 Errores

| HTTP | `code` | Cuando |
|---|---|---|
| 401 | `AUTH_REQUIRED` | Sin sesion. |
| 403 | `PROVIDER_REQUIRED` | La cuenta no es de una tienda. |
| 403 | `PROVIDER_NOT_ACTIVE` | La tienda no esta habilitada. |
| 403 | `PASSWORD_CHANGE_REQUIRED` | Falta cambiar la contrasena temporal. |
| 403 | `CONSENT_REQUIRED` | Faltan los documentos vigentes. |
| 403 | `PRODUCT_LOCKED` | La ficha es del catalogo compartido (no la registro esta tienda). |
| 400 | `VALIDATION_ERROR` | Un dato no paso una validacion. `details`: `{"field": "..."}` y `message` es el texto para el usuario. |
| 404 | `OFFER_NOT_FOUND` / `PRODUCT_NOT_FOUND` | La tienda no tiene oferta de ese producto, o el producto no existe. |
| 409 | `PRODUCT_EXISTS` | El modelo ya esta en el catalogo. `details`: `{productId, name}`. |
| 409 | `POSSIBLE_DUPLICATE` | Hay modelos parecidos. `details`: `{candidates: [{productId, name, model}]}`. |
| 409 | `PRODUCT_SHARED` | Otra tienda vende el producto: la ficha ya no se edita. |
| 409 | `OFFER_EXISTS` | La tienda ya tiene una oferta de ese producto. |
| 409 | `OFFER_RETIRED` | La oferta esta retirada: se vuelve a publicar con `create_my_offer`. |
| 429 | `RATE_LIMITED` | Limite diario de productos nuevos. |

---

## 17. Parte 9: panel de la tienda (v0.14)

Resumen del negocio, pedidos e inventario de la tienda con sesion (fase 1 del panel; HU-018, HU-020, HU-021, RF-063, RF-066, RF-069). Todas son RPC para `authenticated` y exigen una tienda que pueda operar, como la parte 8: rol tienda, tienda activa, contrasena definitiva y documentos aceptados (`PROVIDER_REQUIRED`, `PROVIDER_NOT_ACTIVE`, `PASSWORD_CHANGE_REQUIRED`, `CONSENT_REQUIRED`). **Ninguna recibe el id de la tienda**: el backend la toma de la sesion, asi que una tienda nunca ve pedidos, stock ni dinero de otra.

### 17.1 Resumen: `get_my_dashboard()`

```json
{
  "sales": { "todayCents": 230000000, "yesterdayCents": 0, "weekCents": 230000000, "previousWeekCents": 0,
             "monthCents": 230000000, "previousMonthCents": 0 },
  "orders": { "pending": 1, "confirmed": 0, "preparing": 0, "shipped": 0, "delivered": 1,
              "cancelled": 1, "returned": 0, "incident": 0 },
  "inventory": { "active": 12, "outOfStock": 1, "lowStock": 2 },
  "lowStockItems": [ "InventoryItem (17.3), hasta 5" ],
  "finance": { "grossCents": 230000000, "commissionCents": 18500000, "netCents": 211500000,
               "pendingPayoutCents": 211500000 },
  "recentOrders": [ "VendorOrder (17.2), hasta 5" ]
}
```

- **Periodos** de Colombia (America/Bogota). El periodo anterior se mide hasta el mismo momento: hoy contra ayer a esta hora, la semana en curso contra la anterior al mismo dia y hora, y el mes contra el anterior.
- **Ventas:** subtotal (IVA incluido) de los pedidos no rechazados ni cancelados.
- **`orders.cancelled`** suma rechazados y cancelados.
- **`finance`:** los montos son del mes. `pendingPayoutCents` es el neto de todos los pedidos no rechazados, cancelados ni devueltos: sin liquidaciones todavia (fase 2), nada se marca como pagado.

### 17.2 Pedidos

- `get_my_orders(status?, search?, page = 0, page_size = 20)`: `{items: [VendorOrder], total, page, pageSize}`, del mas reciente al mas antiguo. `search` busca por numero de pedido o nombre del cliente.
- `get_my_order(id)`: el detalle. `404 ORDER_NOT_FOUND` si no es de la tienda.
- `update_my_order_status(id, status, note?, carrier?, tracking_number?)`: cambia el estado y devuelve el detalle.

`VendorOrder`:

| Campo | Notas |
|---|---|
| `id` | Id de la sub-orden de la tienda. |
| `orderNumber`, `createdAt`, `status`, `statusChangedAt` | `status`: ver la tabla de estados. |
| `units`, `subtotalCents`, `commissionCents`, `netCents` | `netCents = subtotalCents - commissionCents`: lo que recibe la tienda. |
| `customerName`, `city`, `department` | Para la lista. |
| `carrier`, `trackingNumber` | Al enviarlo. |
| `hasBackorders` | Alguna unidad ya no estaba en stock al aprobarse el pago. |

El detalle suma `statusNote` (motivo del ultimo cambio), `shippingAddress`, `contact` (nombre, correo, telefono, tipo y numero de documento: la tienda vende y factura), `items` (con la comision y el neto por item), `history` (`fromStatus`, `toStatus`, `note`, `actorName`, `createdAt`) y `nextStatuses`, los estados a los que puede pasar.

| `status` | Etiqueta | Puede pasar a |
|---|---|---|
| `pending` | Nuevo | `confirmed`, `rejected` |
| `confirmed` | Confirmado | `preparing`, `cancelled`, `incident` |
| `preparing` | Preparando | `shipped`, `cancelled`, `incident` |
| `shipped` | Enviado | `delivered`, `incident` |
| `delivered` | Entregado | `returned`, `incident` |
| `incident` | Con incidencia | `confirmed`, `preparing`, `shipped`, `delivered`, `cancelled` |
| `rejected`, `cancelled`, `returned` | Rechazado, Cancelado, Devuelto | (finales) |

- `rejected`, `cancelled`, `returned` e `incident` exigen `note` (3 a 300 caracteres); `shipped` exige `carrier` y `tracking_number`. Si falta, `400 VALIDATION_ERROR` con `details.field`.
- Un estado que no esta en `nextStatuses`: `409 INVALID_TRANSITION`, con `details` `{from, to, allowed}`.
- **Rechazar o cancelar devuelve al stock** las unidades que se habian descontado (menos las que ya faltaban). El reembolso al cliente queda pendiente (fase 2).
- La guia se registra a mano: todavia no hay integracion con transportadoras (RF-070).

### 17.3 Inventario

- `get_my_inventory(alert?, search?, page = 0, page_size = 20)`: `{items: [InventoryItem], total, counts: {all, low, out}, page, pageSize}`. Sin las ofertas retiradas; primero las que estan mas cerca del minimo. `alert`: `low` (1 unidad hasta `minStock`) u `out` (0 unidades). `search` busca por nombre o codigo interno.
- `adjust_my_stock(product_id, kind, quantity, reason)`: `kind` es `entry` (suma `quantity`), `exit` (resta `quantity`) o `adjustment` (deja el stock en `quantity`, el conteo real). `reason` es obligatorio (3 a 200 caracteres). No deja el stock negativo ni igual al actual. Devuelve el `InventoryItem`.
- `set_my_min_stock(product_id, min_stock)`: stock minimo de 0 a 100000 (por defecto 5).
- `get_my_stock_movements(product_id?, page = 0, page_size = 30)`: historial de un producto o de toda la tienda, del mas reciente al mas antiguo.

`InventoryItem`: `offerId`, `productId`, `name`, `brand`, `category`, `imageUrl`, `status`, `externalSku`, `stockUnits` (disponible), `minStock`, `reservedUnits` (vendidas y sin enviar: ya descontadas de `stockUnits`), `soldUnits` (en pedidos no rechazados ni cancelados) y `alert` (`low`, `out` o `null`).

Movimiento: `id`, `productId`, `productName`, `kind` (`entry`, `exit`, `adjustment`, `sale`, `cancellation`), `quantityDelta`, `stockBefore`, `stockAfter`, `reason`, `orderNumber` (ventas y devoluciones al stock), `actorName` (null si fue el sistema) y `createdAt`.

**Todo cambio de stock queda en el historial**, venga de donde venga: la venta del checkout, un movimiento manual, la edicion de la publicacion (`update_my_offer`, como ajuste con el motivo "Edicion de la publicacion") o un pedido rechazado.

---

## 18. Parte 10: consola del administrador (v0.15)

Entrega 1 de la consola de NEXUS: resumen global, supervision de tiendas, moderacion del catalogo y pedidos de todas las tiendas (HU-022, HU-024, HU-025, RF-011, RF-080). Todas son RPC para `authenticated` y exigen el rol administrador (`403 FORBIDDEN` si no). La entrega 2 agrega finanzas (liquidaciones y reembolsos con Wompi) y clientes.

**Decisiones del equipo:** solo los clientes compran (las tiendas y los administradores siguen con `CUSTOMER_ONLY`). La moderacion es **posterior**: las tiendas publican sin aprobacion y el administrador revisa lo publicado.

### 18.1 Resumen: `admin_get_dashboard()`

```json
{
  "sales": { "totalCents": 0, "totalCommissionCents": 0, "todayCents": 0, "yesterdayCents": 0,
             "weekCents": 0, "previousWeekCents": 0, "monthCents": 0, "previousMonthCents": 0,
             "monthCommissionCents": 0, "monthProviderNetCents": 0 },
  "orders": { "total": 0, "inProgress": 0, "pending": 0, "delivered": 0, "cancelled": 0,
              "returned": 0, "incident": 0, "stale": 0 },
  "users": { "customers": 0, "activeCustomers": 0, "newCustomers": 0, "providers": { "active": 7 } },
  "catalog": { "products": 760, "visibleProducts": 760, "outOfStockProducts": 0, "offers": 993,
               "hidden": 0, "review": 0, "rejected": 0, "flagged": 0 },
  "alerts": [ { "kind": "offers_review", "count": 1 } ],
  "series": [ { "date": "2026-10-28", "salesCents": 0, "commissionCents": 0, "orders": 0,
                "newCustomers": 0, "newProviders": 0 } ],
  "topCategories": [ { "category": "storage", "name": "Almacenamiento", "salesCents": 0, "units": 0 } ]
}
```

- **Ventas:** subtotal (IVA incluido) de las sub-ordenes no rechazadas ni canceladas; la comision es el ingreso de NEXUS. Periodos de Colombia, comparados hasta el mismo momento, como en 17.1.
- **`orders`** cuenta sub-ordenes (el pedido de cada tienda), salvo `total`, que cuenta pedidos. `cancelled` suma rechazados y cancelados. `stale`: nuevos sin respuesta de la tienda en 48 horas.
- **`users`:** `activeCustomers` iniciaron sesion en 30 dias y `newCustomers` se registraron en 30 dias. `providers`: tiendas por estado.
- **`catalog.flagged`:** ofertas publicadas y aprobadas con alguna alerta de calidad (18.3).
- **`alerts`:** solo las que tienen casos. `offers_review`, `orders_incident`, `orders_stale`, `providers_pending`, `new_providers` (7 dias), `payments_error` (30 dias), `payment_events_unknown` (avisos de Wompi con referencia desconocida en 7 dias) y `assistant_unavailable` (24 horas).
- **`series`:** los ultimos 30 dias, uno por dia, incluidos los dias sin ventas. **`topCategories`:** hasta 6 categorias por ventas de 30 dias.

### 18.2 Tiendas

| RPC | Que hace |
|---|---|
| `admin_list_providers(search?, status?, sort = 'name')` | Tiendas (`AdminStore`, 15.2) con `metrics`. `sort`: `name`, `sales` (ventas de 30 dias), `performance` (entregas cumplidas) o `recent`. |
| `admin_get_provider_overview(id)` | La tienda con `metrics`, `inventory`, `ordersByStatus`, `recentOrders` (5, como 18.4) y `notes`. |
| `admin_set_provider_status(id, status, reason?)` | **Cambia** respecto de 15.2: `status` es `active`, `suspended`, `blocked` o `deactivated`, y `reason` (3 a 500) es obligatorio salvo para `active`. El cambio queda en `notes`. `409 SAME_STATUS` si ya esta en ese estado. |
| `admin_add_provider_note(id, kind, message)` | `kind`: `note`, `warning`, `incident` o `policy_violation`. `message` de 3 a 500. Devuelve la ficha. |

- **Estados:** suspendida es temporal; bloqueada, por incumplir las politicas; desactivada, dejo de operar. En los tres casos sus ofertas salen del catalogo y la cuenta responde `PROVIDER_NOT_ACTIVE`.
- **`metrics`:** `sales30dCents`, `commission30dCents`, `orders`, `openOrders`, `incidents`, `deliveredRate` y `cancelRate` (de 0 a 1 sobre los pedidos cerrados; `null` sin pedidos cerrados) y `warnings` (advertencias, incidencias e incumplimientos).
- **`inventory`:** `published`, `lowStock`, `outOfStock`, `hidden` (ocultas o en revision) y `rejected`.
- **`notes`:** `{id, kind, message, fromStatus, toStatus, actorName, createdAt}`, del mas reciente al mas antiguo. `kind` `status_change` lleva los estados. El historial no se modifica ni se borra.

### 18.3 Catalogo y moderacion

| RPC | Que hace |
|---|---|
| `admin_list_offers(search?, provider?, category?, brand?, moderation?, flag?, page = 0, page_size = 20)` | `{items: [AdminOffer], total, counts, page, pageSize}`. Primero las que piden revision y las que tienen mas alertas. |
| `admin_get_offer(offer_id)` | La oferta con `summary`, `createdByProviderId`, `attributes`, `images` (URL) y `otherOffers`. |
| `admin_moderate_offer(offer_id, action, reason?)` | `action`: `approve`, `hide` o `reject`. Ocultar y rechazar exigen `reason` (3 a 300), que ve la tienda. Devuelve el detalle. |
| `admin_update_product(product_id, product)` | Corrige la ficha compartida: `{category, name, brand, model, summary?, attributes, specs?, quickSpecs?}`. Valida la plantilla como 16.2 y los duplicados por marca y modelo. Las imagenes no cambian. Devuelve `{productId, offers: [AdminOffer]}`. |
| `request_my_offer_review(product_id)` | **De la tienda:** pide la revision de una oferta oculta (`409 NOT_HIDDEN` si no lo esta). Devuelve su publicacion (16.1). |

- **Moderacion** (`moderationStatus`): `approved` (por defecto), `hidden` (oculta hasta que la tienda corrija), `review` (la tienda corrigio y pide revision; sigue oculta) y `rejected` (no vuelve). Solo `approved` se ve en el catalogo.
- **La tienda lo ve:** las publicaciones de 16.1 suman `moderationStatus` y `moderationReason`, y `visible` exige `approved`.
- **Alertas** (`flags`): `incomplete` (falta un atributo obligatorio de la plantilla), `price_anomaly` (menos de la mitad o mas del doble de la mediana de las ofertas publicadas del producto, con al menos 2) y `duplicate` (otro producto de la misma categoria con el mismo nombre normalizado). `flag = 'any'` filtra las que tienen alguna. Las fotos no son alerta: el catalogo muestra el icono de la categoria.
- **`counts`:** con la busqueda y los filtros de tienda, categoria y marca: `all`, `approved`, `hidden`, `review`, `rejected` y `flagged`.

`AdminOffer`: `offerId`, `productId`, `productName`, `brand`, `model`, `category`, `providerId`, `providerName`, `providerStatus`, `priceCents`, `oldPriceCents`, `stockUnits`, `status`, `moderationStatus`, `moderationReason`, `moderatedAt`, `imageUrl`, `flags`, `visible` y `updatedAt`.

### 18.4 Pedidos

| RPC | Que hace |
|---|---|
| `admin_list_orders(search?, provider?, status?, from_date?, to_date?, page = 0, page_size = 20)` | Una fila por sub-orden: `VendorOrder` (17.2) con `orderId`, `providerId`, `providerName`, `customerEmail` y `paymentMethod`. `search`: numero, cliente (nombre o correo) o tienda. Fechas de Colombia, inclusivas. |
| `admin_get_order(id)` | El pedido: `number`, `createdAt`, `totalCents`, `contact`, `shippingAddress`, `payment` (`reference`, `status`, `amountCents`, `method`, `transactionId`, `approvedAt`), `subOrders` y `notes`. |
| `admin_update_sub_order_status(id, status, note, carrier?, tracking_number?)` | Interviene una sub-orden. `note` (3 a 300) siempre es obligatoria y queda en el historial como "NEXUS: ...". Devuelve el pedido. |
| `admin_add_order_note(id, message, sub_order_id?)` | Observacion del administrador (3 a 500). Devuelve el pedido. |

- **`subOrders`:** el detalle de 17.2 de cada tienda con `providerId`, `providerName` y `adminNextStatuses`.
- **Transiciones del administrador:** las de la tienda, mas cancelar un pedido nuevo o enviado (por ejemplo, perdido), reportar una incidencia desde cualquier estado abierto y cerrar una incidencia como devuelta. Fuera de ellas, `409 INVALID_TRANSITION`.
- **Cancelar o rechazar devuelve las unidades al stock**, como 17.2. El reembolso llega en la entrega 2.
