# Arquitectura

## Estructura por feature

```text
lib/
|-- main.dart
|-- core/                    # lo que usa cualquier feature (utils, red, errores)
|-- widgets/                 # widgets visuales compartidos (como hoy)
|-- theme/
`-- features/
    `-- catalog/
        |-- catalog_providers.dart
        |-- domain/               # Product, ProductOffer, ProductFilters, ProductPage, ProductRepository
        |-- data/                 # Mock, Supabase y lectura del JSON del contrato
        `-- presentation/         # catálogo, filtros, detalle y recursos visuales
```

El catálogo es la primera feature migrada y la primera conectada al backend
(fase 3). Las pantallas que aún no tienen una implementación basada en
repositorios permanecen en `lib/screens/`; el carrito se migra en la fase 5 y
PC Builder en la 6 (`docs/PLAN_IMPLEMENTACION.md`). No se crean carpetas vacías
por adelantado.

## Regla de dependencias

- `domain` no importa Flutter ni Riverpod: es Dart puro.
- `data` importa `domain`.
- `presentation` importa `domain`, los providers y los widgets compartidos.
- Solo `<nombre>_providers.dart` decide si se usa el repositorio mock o el real.
- Solo los repositorios de `data/` leen `supabaseClientProvider`
  (`core/network/`). Traducen las excepciones de Supabase o de red a un
  `AppFailure` (`core/errors/`), de modo que controladores y pantallas no
  dependen de la infraestructura.
- La configuración de entorno (`core/config/env.dart`) llega por
  `--dart-define`. Sin ella la app arranca con los mocks y las pruebas no
  necesitan backend.

Así, las reglas de negocio se prueban sin widgets y cambiar el mock por el
backend requiere modificar un único archivo de providers.

### Catálogo como ejemplo

**Dominio** (`features/catalog/domain/`):
- `Product` con su familia (derivada de la categoría), estado de stock, imagen y ofertas (`ProductOffer`).
- `ProductFilters`: búsqueda, familia, categoría, marca, rango de precio y orden.
- `ProductPage` y el contrato `ProductRepository`.

**Datos** (`data/`):
- `SupabaseProductRepository` llama a las RPC del contrato. Recibe una función `RpcCall`, así que se prueba sin red.
- `product_json.dart` lee el JSON del contrato y se prueba con sus mismos ejemplos (`test/support/contract_fixtures.dart`).
- `MockProductRepository` imita el contrato en memoria.

**Providers:** `catalog_providers.dart` es el único archivo que elige el repositorio. Con Supabase configurado usa el real; si no, el mock. Los providers de detalle y relacionados son families `autoDispose` parametrizadas por `productId`.

**Controlador:** `CatalogController` guarda un `ProductFilters` y se encarga de:
- la búsqueda con debounce de 300 ms;
- las reglas entre familia y categoría: la categoría implica su familia, y cambiar de familia quita la categoría ajena;
- marca, precio y orden;
- el total y la paginación incremental.

**Pantalla:** cada widget observa solo su parte del estado con `select`. La grilla usa slivers y pide otra página al acercarse al final.

Para probar el catálogo con más datos sin backend, se puede cambiar
temporalmente el mock de `productRepositoryProvider` en `catalog_providers.dart`
por `MockProductRepository.generated(200)`. Este cambio es solo para desarrollo
local: no debe quedar en un commit. Las pruebas de widgets montan el mismo
catálogo con un repositorio falso y pueden cambiar `catalogPageSizeProvider`
para recorrer la paginación con pocas filas.

`ProductSpec` contiene texto de presentación, no datos tipados de compatibilidad.
Los datos para PC Builder se modelarán por separado como `PcPartSpec` en el paso
7, sin acoplar el dominio del catálogo al builder.

## Reglas de uso de Riverpod

- Usar `Notifier` y `AsyncNotifier` con `NotifierProvider` y
  `AsyncNotifierProvider`; no usar `StateNotifier` ni `ChangeNotifier`, que son
  la API antigua.
- Usar `ref.watch` solo dentro de `build`. En callbacks como `onPressed`, usar
  `ref.read`: `watch` suscribe y reconstruye, mientras `read` consulta una vez.
- Observar solo lo necesario con `select`, por ejemplo
  `ref.watch(provider.select((s) => s.total))`, para evitar reconstrucciones
  ajenas al dato usado (R4).
- Un controlador nunca guarda ni toca widgets ni `BuildContext`; recibe datos y
  devuelve estado.
- Calcular valores derivados (totales, progreso y compatibilidad) en el
  controlador o en providers derivados, nunca dentro de `build` (R3).
- El estado es inmutable: crear una copia nueva al cambiarlo, sin mutar listas
  u objetos existentes.
- Definir los repositorios como `abstract class` en `domain`; los controladores
  dependen de esa abstracción, nunca de una implementación concreta.
- En Riverpod 3.4.3, `ProviderScope.retry` permite configurar los reintentos.
  La app devuelve `null` desde esa función para desactivar reintentos
  automáticos y mostrar los errores sin demoras adicionales.

## Decisiones tomadas

- **Riverpod:** permite reconstrucciones granulares y mantiene la lógica
  independiente de los widgets.
- **Sin generación de código:** menos herramientas y conceptos mientras se
  aprende Riverpod.
- **Sin `go_router` por ahora:** la navegación actual alcanza hasta el paso 6.
- **Sin `Navigator` anidado:** añade una complejidad que no se necesita.
