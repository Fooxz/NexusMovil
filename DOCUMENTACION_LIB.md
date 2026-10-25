# Documentación del código Dart de NEXUS

Este documento describe el código Dart actual de `lib/`, el punto de entrada, la navegación, las pantallas, los componentes compartidos y el estado real de los datos. Las reglas de rendimiento permanentes están en `REGLAS_RENDIMIENTO.md`.

## Estado general

NEXUS es una app Flutter de un marketplace de computadores armados y piezas. Con Supabase configurado, estas partes usan datos reales:
- el catálogo (fase 3);
- las cuentas: registro con consentimiento, inicio de sesión y recuperación (fase 4);
- el perfil con direcciones de entrega (fase 4);
- el carrito (fase 5);
- el PC Builder con el motor de compatibilidad (fase 6) y la vista 3D (fase 6.1);
- el asistente de recomendación con Gemini, por texto o por voz (fase 7);
- el checkout con pago en Wompi y la orden por proveedor (fase 8).

Sin configuración, las mismas pantallas usan repositorios mock en memoria (sin backend, el PC Builder avisa que no verifica compatibilidad y el asistente avisa que necesita el servidor). Inicio todavía muestra datos de ejemplo escritos en el código. Sin backend, el pago se simula con un diálogo que lo aprueba o lo rechaza.

## Estructura de `lib/`

```text
lib/
|-- main.dart                         # Arranque, Supabase opcional, tema y rutas; reintentos desactivados
|-- routes.dart                       # Nombres centralizados de rutas
|-- core/
|   |-- config/
|   |   `-- env.dart                  # AppEnv: SUPABASE_URL y SUPABASE_PUBLISHABLE_KEY por --dart-define
|   |-- errors/
|   |   `-- app_failure.dart          # Errores de dominio con mensaje en español
|   |-- network/
|   |   `-- supabase_providers.dart   # appEnvProvider y supabaseClientProvider
|   `-- utils/
|       |-- format_price.dart         # Formateo de precios en centavos
|       `-- validators.dart           # Validadores de formulario con las reglas del backend
|-- screens/
|   |-- home/
|   |   `-- home_screen.dart          # Inicio, productos destacados y accesos al shell
|   `-- shell/
|       |-- main_shell.dart           # Shell de pestañas con LazyIndexedStack y back handling
|       `-- main_shell_scope.dart     # Scope para cambiar de pestaña desde los widgets hijos
|-- features/
|   |-- assistant/
|   |   |-- assistant_providers.dart  # Repositorio, dictado y AssistantController (la conversación)
|   |   |-- domain/                   # ChatTurn, AssistantReply (pregunta, recomendación, sin resultados), ProposedBuild
|   |   |-- data/                     # Edge Function, lectura del JSON, mock sin backend y dictado (speech_to_text)
|   |   `-- presentation/
|   |       |-- assistant_screen.dart # Chat: sugerencias, tarjetas de producto y "Ver en el PC Builder (3D)"
|   |       `-- voice_composer.dart  # Campo de texto con micrófono
|   |-- pc_builder/
|   |   |-- pc_builder_providers.dart # Repositorio, ranuras, PcBuilderController, candidatos y escena 3D
|   |   |-- domain/                   # BuilderSlot, BuildPart, BuildIssue, BuildValidation, BuilderCandidate, BuildScene
|   |   |-- data/                     # RPC del motor y de la escena, lectura del JSON y mock que no verifica compatibilidad
|   |   `-- presentation/
|   |       |-- pc_builder_screen.dart # Ranuras, estado, avisos por pieza, resumen y "Agregar todo"
|   |       |-- part_picker_screen.dart # Piezas de una ranura: compatibles primero, con la causa si no
|   |       |-- prebuilt_preview.dart # Un computador armado por secciones y en 3D (solo para ver)
|   |       `-- viewer/               # Vista 3D: posición de cada pieza (scene_layout), widget y host por plataforma
|   |-- checkout/
|   |   |-- checkout_providers.dart   # Repositorio, pasarela, CheckoutController (form → pago → resultado)
|   |   |-- domain/                   # CheckoutContact, CheckoutSession, CheckoutStatus, PlacedOrder
|   |   |-- data/                     # Edge Function checkout, lectura del JSON y mock sobre el carrito mock
|   |   `-- presentation/
|   |       |-- checkout_screen.dart  # Dirección, contacto y facturación, resumen por proveedor y "Pagar"
|   |       |-- payment_launcher.dart # Wompi en WebView (Android/iOS) o navegador; pasarela simulada sin backend
|   |       `-- payment_result_view.dart # Orden aprobada, pago pendiente o rechazo con reintento
|   |-- cart/
|   |   |-- cart_providers.dart       # Repositorio, carrito de invitado, CartController y contador
|   |   |-- domain/                   # CartEntry, CartItem, CartState (grupos y totales), CartRepository
|   |   |-- data/                     # RPC del carrito, lectura del JSON y mock en memoria
|   |   `-- presentation/
|   |       |-- cart_screen.dart      # Carrito por proveedor con cantidades, avisos y resumen
|   |       `-- cart_actions.dart     # addToCart, CartBadgeHost y mensajes de error
|   |-- auth/
|   |   |-- auth_providers.dart       # Repositorio, sesión (currentUserProvider) y acciones de formulario
|   |   |-- domain/                   # AuthUser, LegalDocument, SignUpResult, AuthRepository
|   |   |-- data/                     # SupabaseAuthRepository (+ mapAuthError) y MockAuthRepository
|   |   `-- presentation/
|   |       |-- login_screen.dart     # Inicio de sesión; devuelve true si hay sesión
|   |       |-- signup_screen.dart    # Registro con aceptación de términos y política de datos
|   |       |-- forgot_password_screen.dart # Recuperación con código de 6 dígitos
|   |       |-- auth_guard.dart       # ensureSignedIn para acciones que exigen sesión
|   |       `-- auth_widgets.dart     # Marco, campos, enlaces, aviso de error y documento legal
|   |-- profile/
|   |   |-- profile_providers.dart    # Perfil, direcciones y acciones de formulario
|   |   |-- domain/                   # UserProfile, Address, AddressInput, departamentos, ProfileRepository
|   |   |-- data/                     # Tablas profiles y addresses, y mock en memoria
|   |   `-- presentation/
|   |       |-- profile_screen.dart   # Pestaña PERFIL: invitación o cuenta con direcciones
|   |       |-- edit_profile_screen.dart # Nombre y teléfono
|   |       `-- address_form_screen.dart # Crear o editar una dirección
|   `-- catalog/
|       |-- catalog_providers.dart    # Elige Supabase o mock y expone providers
|       |-- domain/
|       |   |-- product.dart          # Producto, familia, categorías, stock, ofertas y ProductSpec
|       |   |-- product_filters.dart  # Búsqueda, familia, categoría, marca, precio y orden
|       |   |-- product_page.dart     # Página de productos y hasMore
|       |   `-- product_repository.dart # Contrato del repositorio
|       |-- data/
|       |   |-- supabase_product_repository.dart # RPC del contrato y errores a AppFailure
|       |   |-- product_json.dart     # Lectura del JSON del contrato
|       |   `-- mock_product_repository.dart # Ocho productos y consultas en memoria
|       `-- presentation/
|           |-- catalog_screen.dart   # Catálogo, familia, tipos de pieza, orden y hoja de filtros
|           |-- product_detail_screen.dart # Detalle por productId con ofertas de proveedores
|           `-- product_visuals.dart # Icono, degradado y etiquetas por categoría y familia
|-- theme/
|   `-- nexus_theme.dart              # Colores, estilos y ThemeData compartidos
`-- widgets/
    |-- lazy_indexed_stack.dart       # IndexedStack perezoso que crea solo la pestaña visitada
    |-- nexus_auth_header.dart        # Encabezado compartido de autenticación
    |-- nexus_bottom_nav.dart         # Barra inferior sin rutas: emite un NexusTab
    |-- nexus_page.dart               # Scaffold y estructura para páginas
    |-- nexus_product_card.dart       # Tarjeta de producto configurable
    |-- nexus_product_image.dart      # Imagen con caché (cached_network_image) o icono de respaldo
    |-- nexus_cart_badge.dart         # Contador del carrito para NexusTopBar (InheritedWidget)
    |-- nexus_quantity_stepper.dart   # Control de cantidad; null deshabilita + o -
    |-- nexus_top_bar.dart            # Barra superior y acceso al carrito
    |-- nexus_loading.dart            # Indicador de carga cian
    |-- nexus_error_state.dart        # Mensaje de error y acción de reintento
    `-- nexus_widgets.dart            # Componentes visuales reutilizables
```

## Inicio y navegación

### Punto de entrada activo

`main.dart` contiene `main()`. Si la app se compiló con `SUPABASE_URL` y `SUPABASE_PUBLISHABLE_KEY` (por ejemplo `flutter run --dart-define-from-file=env.json`, ver [backend/README.md](backend/README.md)), primero llama a `Supabase.initialize`; si no, arranca sin backend. Después ejecuta la app dentro de `ProviderScope`. Su parámetro `retry` devuelve `null`, desactivando reintentos automáticos en Riverpod 3.4.3. `NexusApp` configura el `MaterialApp`, usa `buildNexusTheme()` y define `NexusRoutes.home` (`MainShell`) como ruta inicial: el catálogo se puede recorrer sin cuenta. Las reglas de organización y uso de estado están en [docs/ARQUITECTURA.md](docs/ARQUITECTURA.md).

| Ruta | Pantalla | Cómo se resuelve |
|---|---|---|
| `/home` | `MainShell` | tabla `routes` |
| `/cart` | `CartScreen` | `generateNexusRoute` |
| `/login` | `LoginScreen` | `generateNexusRoute`. Argumento opcional: un `String` con el motivo. Devuelve `bool`. |
| `/signup` | `SignupScreen` | `generateNexusRoute`, devuelve `bool` |
| `/forgot-password` | `ForgotPasswordScreen` | `generateNexusRoute`, devuelve `bool` |
| `/product-detail` | `ProductDetailScreen` | `generateNexusRoute`. Argumento: el `String` `productId`; si no es `String`, el detalle muestra "Producto no encontrado". |

Las rutas de cuenta son `MaterialPageRoute<bool>`: al cerrarse devuelven si el usuario quedó con sesión. Catálogo, PC Builder y Perfil viven dentro de `MainShell`, que mantiene una sola barra inferior y conserva el estado al cambiar de pestaña.

### Recorrido principal

```text
Inicio de app -> Inicio (sin cuenta)
  -> Catálogo -> Detalle del producto
  -> Carrito -> Confirmar pedido -> (sin sesión) Login -> vuelve al carrito
  -> Asistente (texto o voz) -> producto, carrito o "Ver en el PC Builder (3D)"
  -> PC Builder (con vista 3D)
  -> Perfil
      -> sin sesión: Iniciar sesión / Crear cuenta
      -> con sesión: datos personales, direcciones, cerrar sesión
Login -> Crear cuenta -> Registro
      -> ¿Olvidaste tu contraseña? -> código por correo -> contraseña nueva
```

La barra inferior no conoce rutas: `MainShell` conserva la pestaña activa con `LazyIndexedStack`, y `NexusBottomNav` emite un `NexusTab`. `PERFIL` es una pestaña más (`ProfileScreen`). El botón atrás de Android, si no se está en Inicio, vuelve a Inicio; las pantallas empujadas, como el detalle, el carrito y las de cuenta, ocultan la barra.

## Pantallas y responsabilidades

### Cuentas (fase 4)

Todas usan `AuthScaffold` (tarjeta centrada con botón de cerrar), validan antes de enviar con `Validators` (las mismas reglas que el backend), bloquean el botón mientras envían y muestran los errores de `AppFailure` en español.

- **`login_screen.dart`.** Correo y contraseña. Muestra el motivo si lo hay ("Inicia sesión para confirmar tu pedido."). Enlaza a registro y recuperación; si esas pantallas terminan con sesión, el login también se cierra con `true`.
- **`signup_screen.dart`.** Nombre, correo, contraseña de 8 caracteres o más con letras y números, y confirmación. Además, una casilla obligatoria "He leído y acepto los Términos y condiciones y la Política de tratamiento de datos personales", con enlaces que muestran cada texto. Envía las versiones vigentes que se aceptaron. Si el backend exige otra versión, recarga los documentos y desmarca la casilla. Si el proyecto pidiera confirmar el correo, lo avisa en lugar de abrir sesión.
- **`forgot_password_screen.dart`.**
  - Paso 1: correo, para enviar el código.
  - Paso 2: código de 6 dígitos y contraseña nueva, con la opción de reenviar el código.
  - Sin backend, indica el código del mock (`123456`).
- **`auth_guard.dart`.** `ensureSignedIn` abre el login si no hay sesión. Lo usa "Confirmar pedido" en el carrito.

### Perfil (fase 4)

- **`profile_screen.dart`, la pestaña PERFIL.**
  - Sin sesión: invita a iniciar sesión o crear cuenta.
  - Con sesión: datos personales (nombre, correo y teléfono, con "Editar datos") y direcciones de entrega. La predeterminada va primero con la etiqueta PREDETERMINADA. Cada dirección se puede editar, marcar como predeterminada o eliminar, previa confirmación.
  - Al final, el botón "Cerrar sesión".
- **`address_form_screen.dart`.** Nombre de la dirección, quién recibe, teléfono, departamento (lista de Colombia), ciudad, dirección, detalles opcionales y "Usar como predeterminada". Marca los campos inválidos antes de enviar.
- **`edit_profile_screen.dart`.** Nombre y teléfono opcional.

### Inicio

`screens/home/home_screen.dart` compone la pantalla principal con barra superior, hero, franja de productos, categorías, tendencias, acceso a PC Builder y pie de página. Los productos y etiquetas siguen siendo constantes dentro de los widgets; los precios literales se convierten a COP con tasa 4.000 y redondeo unitario al millar. Los accesos a detalle pasan el id mock `rtx-5090` como fallback hasta que Home migre al repositorio.

### Catálogo y detalle

- `features/catalog/presentation/catalog_screen.dart`: observa `catalogControllerProvider` con `select` por partes y muestra carga, error o datos. Arriba están la búsqueda (con debounce), los chips de familia (Todo, Computadores armados, Piezas) y los chips de tipo de pieza, que se ocultan al ver solo armados. El encabezado muestra el total, el botón "Filtros" (hoja con marcas del repositorio y rangos de precio; indica cuántos están activos) y el menú de orden. La grilla usa slivers, carga páginas al acercarse al final y muestra la imagen del producto si existe.
- `features/catalog/presentation/product_detail_screen.dart`: recibe `productId` y obtiene el producto mediante `productDetailProvider`. Muestra estado de carga, error recuperable o "Producto no encontrado". La imagen, marca, categoría, stock, precios, descuento, especificaciones y relacionados se derivan del producto y del repositorio. Si hay ofertas, lista cada proveedor con su precio y stock ("VENDIDO POR" u "OFERTAS DE PROVEEDORES"). Los productos agotados se identifican como "AGOTADO" en gris. Cantidad, compra y agregar al carrito siguen teniendo callbacks vacíos (fase 5).
- `features/catalog/domain/` define `ProductFamily`, `ProductCategory` (incluye `prebuiltPc`), `StockLevel`, `ProductSpec`, `ProductOffer`, `Product`, `ProductFilters`, `ProductSort`, `ProductPage` y `ProductRepository` sin importar Flutter ni Riverpod. La familia y el descuento se derivan.
- `features/catalog/data/`: `SupabaseProductRepository` llama a `get_products`, `get_product`, `get_related` y `get_catalog_brands` y traduce los errores a `AppFailure` (un `PRODUCT_NOT_FOUND` en el detalle se vuelve `null`). `product_json.dart` lee el JSON del contrato: ignora campos desconocidos, lee un `stockLevel` desconocido como agotado y omite productos de categorías desconocidas. `MockProductRepository` tiene ocho productos (incluidos dos armados y ofertas para la RTX 5090), simula 300 ms de latencia y aplica en memoria los mismos filtros.
- `features/catalog/catalog_providers.dart` es el único archivo que elige el repositorio: Supabase si `AppEnv.hasSupabase`, el mock si no. El catálogo usa un `AsyncNotifier` con `ProductFilters`, página y carga incremental; `catalogBrandsProvider` carga las marcas según familia y categoría; detalle y relacionados son `FutureProvider.autoDispose.family` que reciben el id.

### Carrito

`features/cart/presentation/cart_screen.dart` (HU-009):
- **Agrupación:** las líneas van por proveedor ("Vendido y despachado por …") y, si hay varios, se avisa que llegarán en envíos separados.
- **Cada línea** muestra imagen, nombre, precio unitario vigente, subtotal y un selector de cantidad que se detiene en el máximo disponible. También tiene un botón para quitarla.
- **Líneas con problemas:** las agotadas y las que superan el stock se marcan, con un botón "Ajustar a N", y no entran en el total.
- **Resumen:** artículos, subtotal y envío "Sin costo adicional" (supuesto de la fase 8).
- **Sin sesión:** se avisa que el carrito no se guarda.
- **"Confirmar pedido":** queda deshabilitado si hay líneas por revisar y exige sesión (`ensureSignedIn`). Con sesión abre el checkout.
- **"Vaciar carrito":** pide confirmación.

Se agrega desde el ícono de carrito de las tarjetas del catálogo (la mejor oferta) y desde el detalle (oferta del proveedor elegido, cantidad, "Agregar al carrito" y "Comprar ahora"). El ícono de la barra superior muestra cuántas unidades hay.

### Checkout

`features/checkout/presentation/checkout_screen.dart` (HU-010, HU-011), desde "Confirmar pedido":
- **Dirección:** una de las guardadas (la predeterminada, marcada) o "Agregar una dirección".
- **Contacto y facturación:** nombre, correo y teléfono prellenados con el perfil, tipo y número de documento.
- **Resumen:** un envío por proveedor, envío sin costo y total con IVA incluido.
- **"Pagar $X":** el backend revalida el carrito. Si el total o el stock cambiaron, avisa y recarga el carrito. Si no, abre Wompi: en Android e iOS, en un WebView que se cierra solo al volver; en web, en otra pestaña.
- **Resultado** (`payment_result_view.dart`): orden aprobada con su número y sus sub-órdenes; pago en proceso con "Consultar de nuevo"; rechazado o sin pagar con "Intentar de nuevo", que crea un intento nuevo con los mismos datos.
- Mientras el pago está en curso no se puede volver atrás.

### Asistente

`features/assistant/presentation/assistant_screen.dart` (HU-006), pestaña ASISTENTE en el centro de la barra:
- **Inicio:** sugerencias que se envían con un toque, y un aviso fijo de que las respuestas las genera la IA a partir del catálogo (RNF-025).
- **Respuestas:**
  - preguntas cuando falta el uso o el presupuesto;
  - tarjetas de producto con el motivo, "Ver detalle" y "Agregar";
  - configuración por piezas con su total y "Ver en el PC Builder (3D)", que la carga en el armador y cambia de pestaña;
  - en los computadores armados, "Visualizar en 3D", que abre el armado en el PC Builder (`prebuilt_preview.dart`): sus componentes por sección y en 3D, el botón para agregarlo completo al carrito y "Volver a mi configuración".
- **Errores:** "Reintentar". Si la IA no está disponible, atajos al catálogo y al PC Builder (RNF-018).
- **Voz** (`voice_composer.dart`): el micrófono dicta en el campo y el cliente revisa el texto antes de enviarlo.

### PC Builder

`features/pc_builder/presentation/pc_builder_screen.dart` (HU-008):
- **Estado:** un aviso dice qué hacer (empezar por el procesador, qué falta, cuántas incompatibilidades hay, piezas sin stock o "Configuración compatible y completa") y cuántas piezas obligatorias van.
- **Ranuras:** cada una muestra la pieza elegida con su proveedor y precio, sus incompatibilidades en lenguaje simple, "Cambiar" o "Ver alternativas", y "Quitar". Las vacías dicen si son obligatorias u opcionales.
- **Resumen:** precio por pieza, total, "Agregar todo al carrito" (solo si la configuración es válida y tiene stock) y "Empezar de nuevo".
- **Selector** (`part_picker_screen.dart`): lista las piezas de la ranura con COMPATIBLE o NO COMPATIBLE y el motivo; las agotadas no se pueden elegir.
- **Vista 3D** (`viewer/pc_viewer.dart`, RF-090): el gabinete con las piezas elegidas.
  - Se gira y se acerca; las piezas incompatibles se ven en rosa y tocar una pieza abre su selector.
  - Usa los modelos `.glb` del backend y genera las piezas que no tienen modelo. "Créditos de los modelos 3D" muestra los autores y las licencias.
  - Funciona en Android, iOS y la web. En escritorio explica que no está disponible.

La compatibilidad la decide el motor del backend; la app solo la muestra.

## Entrada y origen de datos

| Superficie | Dato que se muestra o solicita | Comportamiento actual |
|---|---|---|
| Login | Correo y contraseña | Formulario validado; inicia sesión con Supabase Auth o con el mock. |
| Registro | Nombre, correo, contraseña, confirmación y aceptación de documentos | Formulario validado; crea la cuenta y el backend registra el consentimiento. |
| Recuperación | Correo, código y contraseña nueva | Envía el código al correo y cambia la contraseña. |
| Perfil y direcciones | Nombre, teléfono y direcciones de entrega | Formularios validados contra las tablas `profiles` y `addresses` (o el mock). |
| Catálogo inicial | Primera página de productos | `catalogControllerProvider` obtiene 20 productos por página, de Supabase o del mock (ocho productos). |
| Búsqueda del catálogo | Texto de producto, marca o categoría | El campo usa el controlador, que aplica debounce y búsqueda normalizada en el repositorio. |
| Filtros y orden | Familia, tipo de pieza, marca, precio y orden | Chips de familia y de tipo de pieza; hoja "Filtros" con marcas del repositorio y rangos de precio; menú de orden (relevancia, menor y mayor precio). Todo se envía al repositorio. |
| Cantidad de producto | Unidades en detalle | De 1 a 10; el backend valida contra el stock y responde cuántas quedan. |
| Carrito | Ofertas, cantidades y totales | Guardado en Supabase con sesión; en memoria sin sesión, y se suma al guardado al iniciar sesión. |
| PC Builder | Una pieza por ranura | Cada cambio se valida con el motor de reglas del backend; la selección vive en memoria mientras la app está abierta. |

`NexusTextField`, en `widgets/nexus_widgets.dart`, usa `TextFormField` y conserva `hint`, `obscure` y `prefixIcon`. También acepta opcionalmente `controller`, `onChanged`, `onSubmitted`, `validator`, `keyboardType`, `textInputAction` y `enabled`. Los errores de validación usan el rosa de la paleta NEXUS. Sigue siendo `StatelessWidget` y no crea controladores propios; quien proporciona un controlador externo es responsable de destruirlo. No implementa debounce: esa lógica debe vivir en el controlador de búsqueda, no en el campo.

Los formularios de cuenta y perfil (fase 4) usan `controller`, `validator`, `keyboardType`, `textInputAction` y `autofillHints`, este último agregado en esa fase; el catálogo usa `onChanged`. La suite del campo cubre controlador, `onChanged`, validación dentro de `Form`, uso sin `Form`, texto oculto y campo deshabilitado.

Con Supabase configurado, catálogo, cuentas, perfil, carrito y PC Builder usan el backend; sin configuración, sus mocks. No hay almacenamiento local propio: la sesión la guarda Supabase.

## Componentes visuales compartidos

`widgets/nexus_widgets.dart` define:

- `NexusTag`: etiqueta compacta con color configurable.
- `NexusStatusDot`: punto y texto de estado.
- `NexusBracketTitle` y `NexusUnderlineTitle`: títulos de sección.
- `NexusPlaceholderBox`: caja con degradado e icono como sustituto de una imagen.
- `NexusCard` y `NexusSpecRow`: contenedor y fila etiqueta/valor.
- `NexusPrimaryButton` y `NexusOutlineButton`: botones reutilizables.
- `NexusFieldLabel` y `NexusTextField`: etiqueta y campo de formulario reutilizable; el segundo admite lectura de texto y validación opcionales.

Otros widgets y utilidades compartidos:

- `widgets/nexus_auth_header.dart`: cabecera de marca y formulario para login/registro.
- `widgets/nexus_bottom_nav.dart`: barra inferior "tonta" que recibe `NexusTab current` y `ValueChanged<NexusTab> onTap` sin depender de `routes.dart`.
- `widgets/nexus_page.dart`: `Scaffold`, `SafeArea`, barra superior y scroll común. Conserva `children` y admite una variante `NexusPage.slivers` basada en `CustomScrollView`.
- `widgets/nexus_empty_state.dart`: estado reutilizable para resultados vacíos, con acción opcional.
- `widgets/lazy_indexed_stack.dart`: `IndexedStack` perezoso que solo crea la pestaña visitada y pausa los tickers del resto.
- `screens/shell/main_shell.dart`: shell de navegación principal con `LazyIndexedStack`, `PopScope` y `MainShellScope`.
- `widgets/nexus_product_card.dart`: tarjeta de producto con precio en centavos y acciones provistas por la pantalla.
- `widgets/nexus_loading.dart` y `widgets/nexus_error_state.dart`: estados compartidos de carga y error con reintento.
- `widgets/nexus_quantity_stepper.dart`: control de cantidad reutilizado en detalle y carrito; un callback `null` deshabilita su botón.
- `widgets/nexus_top_bar.dart`: barra superior con navegación y acceso opcional al carrito, con el número de unidades de `NexusCartBadge`.
- `core/utils/format_price.dart`: función `formatPrice` para presentar centavos de COP en pesos enteros, con puntos como separadores de miles y redondeo al peso.

## Tema

`theme/nexus_theme.dart` define `NexusColors`, `NexusText` y `buildNexusTheme()`. La paleta es oscura con cian, rosa y verde para acentos, estados y acciones. El tema Material 3 comparte fondo, tipografía, `ColorScheme` y color de divisores entre pantallas.

## Siguientes pasos y límites actuales

Pasos completados:

- **5B:** dominio y repositorio mock del catálogo, providers y detalle que recibe
  `productId`.
- **5C:** búsqueda con debounce, chips de categoría, total y grilla con
  `SliverGrid.builder` y paginación incremental conectados a `CatalogController`.
- **Fase 0:** documentación alineada con el análisis v2 y contrato v0.3.
- **Fase 1:** proyecto Supabase en `backend/` y `core/` con configuración,
  cliente y errores. La UI no cambia.
- **Fase 2:** esquema del catálogo, bitácora de auditoría y RPC del contrato
  en el backend ([docs/MODELO_DATOS.md](docs/MODELO_DATOS.md)).
- **Fase 3:** catálogo conectado a Supabase (contrato v0.4): familias,
  computadores armados, ofertas por proveedor en el detalle, imágenes con
  caché, filtros por familia, tipo de pieza, marca y precio, y orden.
- **Fase 4:** cuentas con Supabase Auth: registro con aceptación de términos y
  política de datos (exigida también por el backend), inicio de sesión,
  recuperación con código de 6 dígitos, perfil y direcciones de entrega con
  RLS. La app abre en Inicio y pide la sesión solo para comprar.
- **Fase 5:** carrito real (contrato v0.5, parte 2): líneas por oferta y
  proveedor, cantidades validadas contra el stock sin exponer unidades,
  carrito guardado con sesión y de invitado en memoria que se fusiona al
  iniciar sesión, contador en el ícono y "Agregar"/"Comprar ahora" desde
  el catálogo y el detalle.
- **Fase 6:** PC Builder (contrato v0.6, parte 3): motor de compatibilidad
  determinista en PostgreSQL con reglas versionadas, avisos en lenguaje
  simple, faltantes, piezas sin stock, alternativas compatibles y paso de la
  configuración al carrito.
- **Fase 6.1:** vista 3D de la configuración (contrato v0.7, `get_build_scene`):
  modelos `.glb` en Storage con su licencia, piezas generadas con sus medidas
  reales cuando no hay modelo, incompatibilidades marcadas y selector al tocar
  una pieza.
- **Fase 7:** asistente de recomendación (contrato v0.8, parte 4). Edge Function con Gemini
  y herramientas de solo lectura sobre el catálogo, validación de cada
  recomendación en el servidor, cadena de modelos por cuota, registro de
  interacciones, chat con dictado por voz y paso de la configuración al PC
  Builder y a la vista 3D.
- **Fase 8:** checkout y pagos (contrato v0.10, parte 5). Wompi en modo de pruebas,
  revalidación del carrito, intento de pago firmado en el servidor, resultado
  idempotente por webhook o consulta, orden con una sub-orden por proveedor,
  comisión sobre el valor sin IVA y descuento de stock.

La hoja de ruta vigente está en [docs/PLAN_IMPLEMENTACION.md](docs/PLAN_IMPLEMENTACION.md).
Los requisitos son los de [docs/REQUISITOS.md](docs/REQUISITOS.md) (análisis v2):
el catálogo se limita a computadores armados y piezas, el asistente de
recomendación es el núcleo del producto y los proveedores publican por API.
El antiguo paso 5D (carrito) es ahora la fase 5, y el paso 7 (PC Builder) es la
fase 6. Autenticación pasa a ser la fase 4.

## Archivos y validación

El árbol anterior refleja los archivos Dart actuales bajo `lib/`. Las pruebas de `test/` cubren:
- **catálogo:** formato COP, stock, filtros, búsqueda, paginación, JSON del contrato, repositorio con RPC falsas, widgets y 360 px;
- **cuentas:** validadores, mapeo de errores de Supabase Auth, mocks de cuentas y perfil, y flujos de login, registro, recuperación, `ensureSignedIn`, perfil y direcciones;
- **PC Builder:** JSON del motor, parámetros de las RPC, mock que avisa que no verifica, selector, incompatibilidades por pieza, "Agregar todo" y 360 px;
- **vista 3D:** posición de cada pieza según la placa y los atributos, JSON de la escena, eventos del visor, sincronía con la selección, piezas marcadas, toque que abre el selector, créditos y plataformas sin visor;
- **asistente:** JSON de la función, errores (IA caída, límite de uso, red), controlador (historial, reintento, conversación nueva, envíos cruzados), pantalla (sugerencias, tarjetas, carrito, "Ver en el PC Builder", atajos, dictado, 360 px) y pestaña;
- **checkout:** JSON de la función, errores (`PRICE_CHANGED` con el total nuevo, pagos no disponibles), validador de documento y pantalla (orden aprobada por proveedor, rechazo y reintento, pago sin terminar, dirección y documento obligatorios, total que cambió);
- **carrito:** totales y grupos, JSON de líneas, controlador con y sin sesión (incluida la fusión y los toques rápidos), pantalla del carrito, agregar desde el detalle y la tarjeta, y el contador;
- **Inicio:** de 32 a 412 px.

`test/integration/` prueba los repositorios reales contra el Supabase local y se salta sin configuración.

**Validación de la fase 8:**
- `dart analyze` sin hallazgos y `flutter build apk --debug` correcto.
- `flutter test`: 251 pruebas aprobadas y 22 de integración saltadas.
- pgTAP: 198 pruebas (41 del checkout). Funciones de pago: 20 pruebas con `node --test`.
- Recorrido local con llaves falsas de Wompi: cuenta, dirección, carrito, `start` (también con un total viejo), webhook con firma falsa (401) y firmado dos veces (una sola orden), `status` con la orden y carrito vacío.
- Falta probar con llaves reales del sandbox de Wompi.

**Validación de la fase 7:**
- `dart analyze` sin hallazgos.
- `flutter test`: 235 pruebas aprobadas y 22 de integración saltadas. Contra el backend local pasan 21; la que llama a Gemini se corre aparte con `ASSISTANT_LIVE=true`.
- pgTAP: 157 pruebas. Edge Function: 21 pruebas con `node --test`.
- El flujo pregunta → presupuesto → configuración → PC Builder → vista 3D se revisó en la app web con Chrome sin interfaz.

No se probó en un dispositivo. Para mediciones de rendimiento, usar un teléfono físico con `flutter run --profile`, según `REGLAS_RENDIMIENTO.md`.
