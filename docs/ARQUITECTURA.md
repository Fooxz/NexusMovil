# Arquitectura

## Estructura por feature

```text
lib/
|-- main.dart
|-- core/                    # lo que usa cualquier feature (utils, red, errores)
|-- widgets/                 # widgets visuales compartidos (como hoy)
|-- theme/
`-- features/
    |-- catalog/
    |   |-- catalog_providers.dart
    |   |-- domain/               # Product, ProductOffer, ProductFilters, ProductPage, ProductRepository
    |   |-- data/                 # Mock, Supabase y lectura del JSON del contrato
    |   `-- presentation/         # catálogo, filtros, detalle y recursos visuales
    |-- auth/
    |   |-- auth_providers.dart   # repositorio, sesión y controladores de formulario
    |   |-- domain/               # AuthUser, LegalDocument, AuthRepository
    |   |-- data/                 # Supabase Auth y mock en memoria
    |   `-- presentation/         # login, registro, recuperación y ensureSignedIn
    `-- profile/
        |-- profile_providers.dart
        |-- domain/               # UserProfile, Address, ProfileRepository
        |-- data/                 # tablas profiles y addresses, y mock
        `-- presentation/         # pestaña PERFIL, editar datos y formulario de dirección
```

El catálogo fue la primera feature migrada y la primera conectada al backend
(fase 3). La fase 4 agregó cuentas y perfil. Las pantallas que aún no tienen una
implementación basada en repositorios permanecen en `lib/screens/`; el carrito
se migra en la fase 5 y PC Builder en la 6 (`docs/PLAN_IMPLEMENTACION.md`). No
se crean carpetas vacías por adelantado.

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
Los datos para PC Builder se modelarán por separado como `PcPartSpec` en la fase
6, sin acoplar el dominio del catálogo al builder.

### Sesión y navegación (fase 4)

- **Se puede navegar sin cuenta.** La app abre en Inicio. La pestaña PERFIL invita a
  iniciar sesión o muestra la cuenta.
- **Acciones protegidas** (RN-027, por ejemplo confirmar un pedido): llaman a
  `ensureSignedIn(context, ref, reason: ...)` (`features/auth/presentation/auth_guard.dart`).
  Si no hay sesión, abre el login con el motivo y devuelve `true` solo si el usuario
  terminó con sesión.
- **Rutas de cuenta** (login, registro, recuperación): son `MaterialPageRoute<bool>`
  generadas en `generateNexusRoute` (`main.dart`). Al cerrarse devuelven si hay sesión.
  No van en la tabla `routes`, porque esta crea rutas `<dynamic>` y `pushNamed<bool>`
  falla.
- **`currentUserProvider`** se recalcula con el stream de sesión, pero lee el usuario del
  repositorio. Justo después de iniciar sesión, el aviso del stream puede llegar un
  instante tarde; por eso `ensureSignedIn` consulta el repositorio directamente.
- **El perfil va en pareja con la autenticación:** con `MockAuthRepository` se usa
  `MockProfileRepository`; con Supabase Auth, las tablas de Supabase.
- **Errores de formulario:** cada formulario tiene su `AsyncNotifier` de acción
  (`signInControllerProvider`, `addressFormControllerProvider`...). Su `loading` bloquea
  el botón (`NexusPrimaryButton.loading`) y su `error` (un `AppFailure`) se muestra en
  `AuthErrorBanner`. Las acciones de la lista de direcciones usan su propio provider,
  para que un error ahí no aparezca en el formulario.

### Carrito (fase 5)

- **`CartController`** (`features/cart/cart_providers.dart`) es el carrito visible:
  - **Sin sesión:** muestra la vista previa (`preview`) de las líneas de `guestCartProvider`, que vive en memoria.
  - **Con sesión:** muestra el guardado.
  - **Al iniciar sesión:** suma el carrito de invitado al guardado (`merge`) y vacía el de invitado.
- **Operaciones en serie:** las operaciones se encadenan en una cola, para que dos toques rápidos en "+" no calculen la cantidad sobre el mismo estado. Sin sesión, antes de cambiar una línea se pide la vista previa con la cantidad nueva y se aplican las mismas reglas que el backend (stock y tope).
- **`CartState`** calcula una sola vez (R3): grupos por proveedor, unidades, subtotal de las líneas que se pueden pagar, si hay líneas con problemas y si se puede confirmar.
- **Contador del ícono:** `NexusTopBar` lo lee de `NexusCartBadge`, un `InheritedWidget` de `widgets/`. Lo provee `CartBadgeHost` en `MaterialApp.builder`. Así los widgets compartidos no dependen de `features/` y solo se reconstruyen los íconos cuando cambia el número.
- **Agregar desde cualquier pantalla:** con `addToCart()` (`features/cart/presentation/cart_actions.dart`), que muestra el aviso o el error del `AppFailure`. Las tarjetas del catálogo agregan `bestOfferId`; el detalle agrega la oferta elegida con la cantidad elegida.
- **El repositorio del carrito va en pareja con los mocks:** con `MockProductRepository` y `MockAuthRepository` se usa `MockCartRepository`; si no, las RPC.

### Checkout (fase 8)

- **`CheckoutController`** (`features/checkout/checkout_providers.dart`, `autoDispose`) lleva el flujo: `form` → `starting` → `paying` → `verifying` → `done`. Un error al iniciar vuelve al formulario con el `AppFailure`; `retry()` empieza de nuevo.
- **La pantalla orquesta la pasarela,** porque necesita el `BuildContext`: `start()` devuelve la sesión, `PaymentLauncher.open()` espera al cliente y `verify(transactionId)` consulta el resultado. Si sigue pendiente, consulta 3 veces más, a un intervalo de `checkoutPollIntervalProvider` (las pruebas lo ponen en cero).
- **La app no decide si se pagó:** solo muestra lo que responde `checkout`. El backend aplica el resultado de Wompi con `apply_payment_event` y crea la orden.
- **`PaymentLauncher`** es intercambiable: `WompiPaymentLauncher` (WebView en móvil, `url_launcher` en web y escritorio) o `SimulatedPaymentLauncher` cuando el checkout es el mock. Las pruebas usan uno falso.
- **Al aprobarse** se invalida `cartControllerProvider`: el backend ya sacó lo comprado. También se invalida si el carrito cambió (`PRICE_CHANGED`, `CART_CHANGED`).
- **En pareja con el carrito:** con `MockCartRepository` se usa `MockCheckoutRepository`; si no, la Edge Function.

### PC Builder (fase 6)

- **La app no calcula compatibilidad.** `PcBuilderController` (`features/pc_builder/pc_builder_providers.dart`) guarda qué oferta hay en cada ranura y, en cada cambio, pide la evaluación al motor del backend (`validate_build`). Las operaciones van en serie. Si una falla, se conserva la configuración anterior y el error llega a la pantalla.
- **Estado fuera del árbol de widgets.** La configuración vive en el provider y se conserva al cambiar de pestaña mientras la app está abierta. Guardar configuraciones (RF-052) queda para más adelante.
- **Candidatos por ranura.** `builderCandidatesProvider(category)` se recalcula cuando cambia la selección; usa una clave de texto para no recargar sin cambios. La pieza se agrega con su `bestOfferId`: en el armador no se elige proveedor.
- **Sin backend** (`MockPcBuilderRepository`): el mock del catálogo no tiene atributos técnicos. Por eso aplica las ranuras obligatorias y la disponibilidad, pero devuelve un aviso que dice que **no verifica compatibilidad**, en lugar de afirmarla.
- **Llevar al carrito (RF-051):** solo si `purchasable`. Agrega cada pieza con el `CartController` e informa cuáles no se pudieron agregar.
- El ícono fijo que hacía de "visor 3D" se retiró en esta fase. El visor real
  (RF-090) llegó en la fase 6.1.

### Visor 3D (fase 6.1)

- **Flutter decide, el visor dibuja.**
  - `buildSceneProvider` pide `get_build_scene` cuando cambia la selección.
  - `viewerSceneProvider` junta esa escena con las incompatibilidades de la validación y la pasa por `layoutScene` (`presentation/viewer/scene_layout.dart`). El cálculo queda fuera de `build` (R3).
  - El resultado es un mensaje JSON con una caja en milímetros por pieza.
  - La página `assets/viewer/viewer.html` (three.js, código en `tool/viewer`) carga los modelos, los ajusta a su caja y dibuja solo cuando algo cambia.
- **Un host por plataforma** (`viewer_host.dart`, con import condicional):
  - en Android e iOS, un WebView con un canal JavaScript;
  - en la web, un iframe con `postMessage`;
  - en escritorio, nada: la pantalla explica dónde está disponible.
  - `viewerHostProvider` permite cambiar el host en las pruebas por `FakeViewer`.
- **Eventos del visor:**
  - `ready`: Flutter envía la escena;
  - `loaded`: avisa qué modelos no cargaron;
  - `tap`: abre el selector de esa pieza;
  - `error`: sin WebGL, la pantalla lo explica.
- **Sin modelo,** la pieza se genera con sus medidas. Si un archivo no carga, también se genera, y la pantalla lo avisa.
- **Créditos:** la escena lleva el crédito de cada modelo que usa. La pantalla los muestra, porque CC BY lo exige.

### Asistente (fase 7)

- **La IA corre solo en el servidor.** `SupabaseAssistantRepository` llama a la Edge Function `assistant` con `functions.invoke`. La app nunca ve la clave de Gemini.
- **`AssistantController`** (`features/assistant/assistant_providers.dart`) guarda la conversación fuera del árbol de widgets:
  - turnos del cliente, respuestas y errores;
  - envía los últimos 12 turnos;
  - bloquea el envío mientras espera;
  - permite reintentar sin repetir el mensaje;
  - "Nueva" descarta una respuesta que todavía no llega.
- **Las respuestas son datos, no texto libre:** pregunta, recomendación (productos con motivo y configuración validada) o "no hay nada adecuado". Por eso la app puede mostrar tarjetas con acciones reales.
- **Del asistente al armador:** "Ver en el PC Builder (3D)" llama a `PcBuilderController.loadBuild`, que toma las ranuras de la validación del motor, y cambia de pestaña con `MainShellScope`.
- **Voz:** `VoiceInput` (`data/voice_input.dart`) envuelve `speech_to_text`. Las pruebas usan `FakeVoiceInput`.
- **Sin backend:** `MockAssistantRepository` dice que el asistente necesita el servidor, en lugar de inventar recomendaciones.

### Ver un computador armado en 3D

- **"Visualizar en 3D"** en una recomendación de armado llama a `prebuiltPreviewProvider.show(productId)` y cambia a la pestaña PC BUILDER.
- **Vista aparte:** mientras está activa, el armador muestra `PrebuiltPreviewView`, con el armado, sus componentes por sección y la vista 3D. `viewerSceneProvider` toma la escena de `prebuiltSceneProvider`.
  - La configuración del cliente (`PcBuilderController`) no se toca y vuelve con "Volver a mi configuración".
  - Los componentes no se compran por separado: el botón agrega el armado completo.
- **Al cambiar de vista,** el visor se vuelve a crear y recarga la página 3D.

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
- **Sin `go_router` por ahora** (revisado en la fase 4). Las rutas con nombre más
  `ensureSignedIn` cubren la sesión, y la recuperación por código no necesita
  deep links. Se vuelve a evaluar en la fase 8, por el retorno desde la pasarela
  de pago.
- **Mocks sin latencia en pruebas:** con `latency: Duration.zero` los mocks no
  llaman a `Future.delayed`, porque dentro de `testWidgets` solo avanza con `pump`
  y las pruebas que preparan datos se quedarían esperando.
- **Sin `Navigator` anidado:** añade una complejidad que no se necesita.
