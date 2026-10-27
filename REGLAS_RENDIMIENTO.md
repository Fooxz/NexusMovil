# Reglas permanentes de rendimiento

Estas reglas aplican a todos los pasos de desarrollo desde el paso 3. Deben guiar la implementación desde el primer cambio, no dejarse para una optimización posterior.

## R1. Listas y grillas: construir solo lo visible

- Para datos de repositorio, usar `ListView.builder`, `SliverList.builder` o `SliverGrid.builder`.
- No usar `shrinkWrap: true` junto con `NeverScrollableScrollPhysics` para listas variables dentro de `SingleChildScrollView`.
- No materializar listas variables con `Column(children: [...])`.
- `Column` y `Wrap` son válidos para colecciones fijas y cortas, como slots del PC builder o chips de filtros.

## R2. `NexusPage` debe admitir slivers

- Añadir una API de `slivers` que construya la página con `CustomScrollView`.
- Conservar `children` para pantallas cortas existentes.
- El catálogo será el primer consumidor de la API de slivers en el paso 5.

## R3. `build` solo presenta

- No filtrar, ordenar, sumar, parsear JSON ni calcular compatibilidad en `build`.
- Calcular valores derivados una vez al cambiar el estado, en el controlador correspondiente.

## R4. Reconstruir lo mínimo

- Cada widget debe observar solo el dato que necesita.
- Evitar un único objeto de estado monolítico observado por toda la pantalla.
- Mantener constructores e instancias `const` siempre que se pueda.
- Extraer partes estables a widgets propios; los métodos `_buildX()` no aíslan reconstrucciones.

## R5. Trabajo fuera del hilo de UI

- Parsear respuestas JSON grandes con `compute()` o `Isolate.run`.
- Evitar bucles pesados sincrónicos en controladores.

## R6. Búsqueda y entrada

- Implementar debounce de 300 ms en el controlador, nunca en `NexusTextField`.
- Cancelar la petición anterior cuando llegue una búsqueda nueva.
- `NexusTextField` solo reenvía `onChanged`.

## R7. Paginación

- El catálogo solicita páginas (por ejemplo, 20 productos), no todo el inventario.
- Solicitar la siguiente página al acercarse al final de la lista.

## R8. Imágenes

- Al sustituir placeholders, usar `cached_network_image` para caché en memoria y disco.
- Solicitar miniaturas del backend para grillas.
- Decodificar al tamaño mostrado mediante `memCacheWidth`, no a resolución completa.

## R9. Efectos costosos

- Evitar `Opacity`, `BackdropFilter` y sombras grandes en elementos repetidos de listas.
- Usar `Clip.antiAlias` solo cuando sea necesario; preferir `Clip.hardEdge` en listas largas si visualmente basta.
- Envolver animaciones autónomas, como visor 3D o spinners, en `RepaintBoundary`.

## R10. Ciclo de vida

- Quien crea un `TextEditingController`, `ScrollController`, `AnimationController` o una suscripción debe liberarlo en `dispose()`.
- En `MainShell` (paso 4), crear las pestañas la primera vez que se visiten, no todas al iniciar.

## Aplicación por pasos

| Paso | Aplicación |
|---|---|
| 3 | Sin cambios visuales en las pantallas. R10: el creador libera los controladores. R6: el campo no implementa debounce. |
| 4 | Pestañas perezosas en `MainShell` y estado fuera del árbol de widgets. |
| 5 | Aplicar R1, R2, R6 y R7 al catálogo. R3-R5 se aplican según corresponda al trabajo del feature. |
| 7 (fase 6) | El selector de piezas usa `SliverList.builder` (R1). El ícono fijo del visor se retiró; el visor real llega en la fase 6.1. |
| Fase 6.1 | Visor 3D. R9: `RepaintBoundary` alrededor del visor. El visor dibuja solo cuando algo cambia (un toque o una escena nueva): no hay bucle de animación que gaste batería. Los modelos se piden al abrir el armador (la pestaña se crea al visitarla), se guardan en memoria y Storage los sirve con una hora de caché. Resolución limitada a 2× y sin sombras. Los modelos actuales pesan entre 21 y 63 KB. Pendiente: medir en un teléfono físico con `--profile`. |
| Fase 7 | Asistente. R1: el chat usa `ListView.builder` invertido. R4: la lista, el aviso y el campo observan solo su parte del estado (`select`). R10: el campo de texto libera su controlador y detiene el dictado al cerrarse. La espera la marca el modelo, no la app: entre 1 y 9 s por respuesta. |

### Catálogo (5C)

- **R1 aplicada:** `CatalogScreen` construye resultados con `SliverGrid.builder`.
- **R2 aplicada:** la pantalla consume `NexusPage.slivers` y conserva el scroll
  común de la página.
- **R6 aplicada:** el campo solo reenvía `onChanged`; el debounce de 300 ms y
  la gestión de solicitudes viven en `CatalogController`.
- **R7 aplicada:** el catálogo solicita páginas configurables y pide la
  siguiente al quedar menos de 600 px de contenido.

### Catálogo con backend (fase 3)

- **R4 aplicada:** los chips de tipo de pieza, el botón de filtros y el menú
  de orden observan solo su parte de `ProductFilters` con `select`.
- **R5:** el cliente de Supabase ya decodifica el JSON en un isolate
  (`yet_another_json_isolate`). En el hilo de UI solo se convierten mapas en
  objetos, como mucho 50 productos por página, así que no se agregó `compute`.
  Si alguna respuesta llega a ser grande (por ejemplo, el asistente o el PC
  Builder), se mide antes de moverla a un isolate.
- **R8 aplicada:** `NexusProductImage` usa `cached_network_image` (caché en
  memoria y disco) y `memCacheWidth` calculado con el ancho mostrado y el
  `devicePixelRatio`. Las listas usan la miniatura del contrato (`imageUrl`).
  Sin imagen, mientras carga o si falla, muestra el icono de la categoría.

## Verificación de rendimiento

- Chrome sirve para comprobar lógica y aspecto, no para medir fluidez móvil.
- Medir en un teléfono físico con `flutter run --profile`, no en modo debug.
- Revisar Performance en DevTools; a 60 Hz, los cuadros que exceden aproximadamente 16 ms pueden producir tirones.
- Usar `Track widget rebuilds` para detectar reconstrucciones innecesarias.
- Medir en dispositivo físico las pantallas con listas, imágenes y visor 3D al validar una versión; no usar resultados de Chrome como mediciones de fluidez móvil.