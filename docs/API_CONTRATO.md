# Contrato de API: NEXUS Movil (v0.9, borrador)

**Estado:** borrador. Parte 1: catalogo (secciones 1 a 5). Parte 2: carrito (seccion 10). Parte 3: PC Builder y vista 3D (seccion 11). Parte 4: asistente (seccion 12). Implementado en el backend (`backend/`) y consumido por el front desde las fases 3, 5, 6, 6.1 y 7 de `docs/PLAN_IMPLEMENTACION.md`.
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
| `family` | string (enum) | si | `prebuiltPc` (computador armado) o `part` (pieza). Ver abajo. |
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

**`family`:** `prebuiltPc`, `part`. El catalogo solo admite computadores armados y piezas de computador (RN-010); no hay celulares ni otras categorias.

**`category`:** `prebuiltPc`, `cpu`, `gpu`, `ram`, `motherboard`, `storage`, `psu`, `pcCase`, `cooling`.

- Si `family` es `prebuiltPc`, `category` es `prebuiltPc`. Mientras no se decida si hay portatiles (D8), los armados tienen una sola categoria.
- Si `family` es `part`, `category` es uno de los tipos de pieza (`cpu` a `cooling`).
- Valor eliminado en v0.3: `phone`.

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
| `family` | string (enum) | (ausente) | `prebuiltPc` o `part`. Si es invalido, `400`. |
| `category` | string (enum) | (ausente) | Un valor de `category`. Si es invalido, `400`. Si se envia junto con `family` y no corresponde a ella, la respuesta es `200` con `items: []`. |
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
| D8 | **Tipos de computador armado.** Si se aceptan escritorio, portatil o ambos, y equipos usados o reacondicionados (vacio de informacion del analisis v2). Hasta decidirlo, `prebuiltPc` es la unica categoria de la familia. | Pendiente (negocio) |
| D9 | **Perifericos.** Si las piezas incluyen monitor, teclado o mouse. Supuesto S-10: no, solo componentes internos. | Pendiente (negocio) |

---

## 7. Fuera de esta version (reservado)

Estas partes se agregan a este mismo archivo cuando se necesiten. No implementar nada de esto todavia.

- **Autenticacion**: la hace Supabase Auth directamente (fase 4, `docs/MODELO_DATOS.md`); no tiene endpoints propios.
- **Asistente de recomendacion** (fase 7 del plan).
- **Pedidos.**

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

Errores: `400 VALIDATION_ERROR` (mas de 12 ofertas, dos piezas de la misma ranura o un computador armado) y `404 OFFER_NOT_FOUND`.

### 11.3 Piezas para una ranura: `get_builder_candidates`

Parametros: `category` (una ranura), `offer_ids` (la configuracion actual; la pieza de esa ranura se ignora) y `max_items` (defecto 30, maximo 50).

`200`: lista de `Product` (seccion 2) con dos campos mas:
- `compatible` (bool): si al ponerla en la ranura no aparece ninguna incompatibilidad que la involucre;
- `incompatibilityReason` (string o `null`): el primer motivo, si no es compatible.

Orden: primero las compatibles, luego las que tienen stock, luego por precio. La pieza se agrega con su `bestOfferId`.

Errores: `400 VALIDATION_ERROR` si `category` no es una ranura del armador.

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

### 11.5 Computador armado en 3D: `get_prebuilt_scene` (v0.9)

Parametro: `product_id` de un computador armado visible.

`200`:

```json
{
  "product": { "id": "pc-gamer-pro-r7-5070", "...": "Product (seccion 2)" },
  "parts": [
    {
      "componentId": "pc-gamer-pro-r7-5070:gpu",
      "category": "gpu",
      "name": "NVIDIA GeForce RTX 5070 12 GB",
      "partProductId": null,
      "attributes": { "length_mm": 242 },
      "model": { "path": "generic/gpu.glb", "rotation": [0, 180, 0], "generic": true,
                 "title": "Graphics card", "author": "pgonarg", "license": "CC-BY-3.0",
                 "sourceUrl": "https://poly.pizza/m/i45v5trpyR" }
    }
  ]
}
```

- Un componente por seccion del PC Builder, en el orden de las ranuras. Una seccion sin componente no viene; por ejemplo, la grafica de un equipo con graficos integrados.
- `componentId` es estable y reemplaza a `offerId` en la vista 3D. Los componentes **no se compran por separado**: el armado se compra completo con su `bestOfferId`.
- `partProductId` enlaza la pieza del catalogo si tambien se vende suelta. En ese caso, `attributes` suma sus medidas.
- `attributes` y `model` tienen el mismo significado que en 11.4.
- `parts` vacio: el armado aun no tiene sus componentes registrados.

Errores: `404 PRODUCT_NOT_FOUND` si no existe o no esta visible; `400 VALIDATION_ERROR` si no es un computador armado.

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
  "message": "Para editar video dentro de tu presupuesto te recomiendo este equipo.",
  "products": [
    { "product": { "id": "pc-gamer-pro-r7-5070", "...": "Product (seccion 2)" },
      "reason": "Tiene 8 nucleos y 32 GB de RAM DDR5, de sobra para editar video." }
  ],
  "build": null,
  "interactionId": "f7b369de-20e2-4a23-ab7a-896e450fb762",
  "sessionId": "9f1c2a7be0d34c55a1f0b2c3d4e5f607"
}
```

| `type` | Significado | Campos |
|---|---|---|
| `question` | Falta informacion, por ejemplo el uso o el presupuesto (RF-037). | `message` es la pregunta. |
| `recommendation` | Recomendacion (RF-038 a RF-040). | `products` (hasta 3) y/o `build`. |
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
