# Contrato de API: NEXUS Movil (v0.3, borrador)

**Estado:** borrador. Parte 1: catalogo. Los campos nuevos de la v0.3 (`family`, `imageUrl`, `offers`) los adopta el front en la fase 3 de `docs/PLAN_IMPLEMENTACION.md`.
**Quien lo escribe:** el front, a partir de sus modelos reales (`lib/features/catalog/domain`).
**Quien lo implementa:** el backend Supabase de `backend/`.
**Regla de oro:** ninguno de los dos lados cambia el comportamiento sin editar este archivo primero. Si el codigo y este documento no coinciden, el documento gana hasta que se actualice.

---

## 1. Convenciones generales

- REST sobre HTTP, cuerpos en **JSON UTF-8**.
- Prefijo de rutas: `/api/v1`. Con Supabase, cada endpoint de este documento se implementa como una funcion RPC de PostgREST (por ejemplo `GET /api/v1/products` → `rpc/get_products`). La ruta es el nombre logico; **la forma del JSON, los parametros y los errores de este documento no cambian**.
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
- **El orden debe ser determinista y estable entre paginas** (si no, un producto puede aparecer dos veces o ninguna). Un parametro `sort` queda reservado para una version futura.
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
| D5 | **Orden y `sort`.** El front muestra "Orden: Relevancia" pero aun no filtra. Se define con el paso de busqueda del catalogo. | Pendiente |
| D6 | **Ocultar agotados.** Hoy los `outOfStock` se listan. Opcion futura: parametro `availableOnly=true`. | Pendiente |
| D7 | **Unidades disponibles.** Para limitar la cantidad en el carrito (paso 5D) el front podria necesitar `stockQuantity` (entero). Se decide al disenar el carrito. | Pendiente |
| D8 | **Tipos de computador armado.** Si se aceptan escritorio, portatil o ambos, y equipos usados o reacondicionados (vacio de informacion del analisis v2). Hasta decidirlo, `prebuiltPc` es la unica categoria de la familia. | Pendiente (negocio) |
| D9 | **Perifericos.** Si las piezas incluyen monitor, teclado o mouse. Supuesto S-10: no, solo componentes internos. | Pendiente (negocio) |

---

## 7. Fuera de esta version (reservado)

Estas partes se agregan a este mismo archivo cuando se necesiten. No implementar nada de esto todavia.

- **Carrito** (agregar, quitar, cantidades, totales).
- **Autenticacion** (registro, login con JWT).
- **PC Builder:** endpoint propio que devuelva producto **mas** su ficha con tipo, solo para piezas compatibles con el builder. Depende de las reglas de compatibilidad de negocio (RN-013) y se escribe antes de la fase 6 del plan.
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

---

## 9. Notas de desarrollo

- Desde el **emulador de Android**, `localhost` apunta al propio emulador. Para llegar al backend que corre en tu PC se usa `http://10.0.2.2:<puerto>`.
- Desde un **celular fisico**, usar la IP del PC en la red local (ambos en la misma red).
- Android puede bloquear HTTP sin TLS. Eso se resuelve en el front en el paso de conexion real y **no afecta al contrato**.
