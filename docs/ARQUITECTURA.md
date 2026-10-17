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
        |-- domain/               # Product, ProductPage y ProductRepository
        |-- data/                 # MockProductRepository
        `-- presentation/         # catálogo, detalle y recursos visuales
```

El catálogo es la primera feature migrada (paso 5B). Las pantallas que aún no
tienen una implementación basada en repositorios permanecen en `lib/screens/`;
el carrito se migra en 5D y PC Builder en 7. No se crean carpetas vacías por
adelantado.

## Regla de dependencias

- `domain` no importa Flutter ni Riverpod: es Dart puro.
- `data` importa `domain`.
- `presentation` importa `domain`, los providers y los widgets compartidos.
- Solo `<nombre>_providers.dart` decide si se usa el repositorio mock o el real.

Así, las reglas de negocio se prueban sin widgets y cambiar el mock por el
backend requiere modificar un único archivo de providers.

### Catálogo como ejemplo

`features/catalog/domain/` define `Product`, sus categorías y estado de stock,
`ProductPage` y el contrato `ProductRepository`. `data/` implementa el contrato
con seis productos de muestra, latencia configurable, búsqueda por nombre,
marca o categoría, filtro por categoría y paginación en memoria.
`catalog_providers.dart` es el único archivo de producción que selecciona
`MockProductRepository`; los providers de detalle y relacionados son families
`autoDispose` parametrizadas por `productId`. El proveedor de catálogo solicita
la primera página. `CatalogController` administra la búsqueda con debounce de
300 ms, el filtro de categoría, el total reportado por el repositorio y la
paginación incremental. La pantalla observa por separado los datos de filtros
y el total; la grilla usa slivers y solicita otra página al acercarse al final.

Para probar el catálogo con más datos, se puede sustituir temporalmente el
override de `productRepositoryProvider` en `main.dart` por
`MockProductRepository.generated(200)`. Este cambio es solo para desarrollo
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
