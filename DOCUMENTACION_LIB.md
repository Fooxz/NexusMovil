# Documentación del código Dart de NEXUS

Este documento describe el código Dart actual de `lib/`, el punto de entrada, la navegación, las pantallas, los componentes compartidos y el estado real de los datos. Las reglas de rendimiento permanentes están en `REGLAS_RENDIMIENTO.md`.

## Estado general

NEXUS es actualmente un prototipo Flutter navegable de una tienda de computadoras y componentes. El catálogo ya usa un dominio y un repositorio mock con carga asíncrona; las demás pantallas aún presentan datos de ejemplo escritos directamente en el código. La app ya puede inicializar Supabase (fase 1), pero ningún feature lo usa todavía: no hay conexión a datos reales, autenticación ni persistencia local. La mayoría de los controles muestran el flujo esperado, pero todavía no ejecutan operaciones de negocio. Búsqueda y filtros del catálogo actualizan el repositorio mock.

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
|       `-- format_price.dart         # Formateo de precios en centavos
|-- screens/
|   |-- auth/
|   |   |-- login_screen.dart         # Inicio de sesión visual
|   |   `-- signup_screen.dart        # Registro visual
|   |-- home/
|   |   `-- home_screen.dart          # Inicio, productos destacados y accesos al shell
|   |-- cart/
|   |   `-- cart_screen.dart          # Carrito y resumen de ejemplo
|   |-- pc_builder/
|   |   `-- pc_builder_screen.dart    # Configuración de PC de ejemplo
|   `-- shell/
|       |-- main_shell.dart           # Shell de pestañas con LazyIndexedStack y back handling
|       `-- main_shell_scope.dart     # Scope para cambiar de pestaña desde los widgets hijos
|-- features/
|   `-- catalog/
|       |-- catalog_providers.dart    # Selecciona el mock y expone providers
|       |-- domain/
|       |   |-- product.dart          # Producto, categorías, stock y ProductSpec
|       |   |-- product_page.dart     # Página de productos y hasMore
|       |   `-- product_repository.dart # Contrato del repositorio
|       |-- data/
|       |   `-- mock_product_repository.dart # Seis productos y consultas en memoria
|       `-- presentation/
|           |-- catalog_screen.dart   # Catálogo basado en provider
|           |-- product_detail_screen.dart # Detalle por productId
|           `-- product_visuals.dart # Icono, degradado y etiqueta por categoría
|-- theme/
|   `-- nexus_theme.dart              # Colores, estilos y ThemeData compartidos
`-- widgets/
    |-- lazy_indexed_stack.dart       # IndexedStack perezoso que crea solo la pestaña visitada
    |-- nexus_auth_header.dart        # Encabezado compartido de autenticación
    |-- nexus_bottom_nav.dart         # Barra inferior sin rutas: emite un NexusTab
    |-- nexus_page.dart               # Scaffold y estructura para páginas
    |-- nexus_product_card.dart       # Tarjeta de producto configurable
    |-- nexus_quantity_stepper.dart   # Control visual de cantidad
    |-- nexus_top_bar.dart            # Barra superior y acceso al carrito
    |-- nexus_loading.dart            # Indicador de carga cian
    |-- nexus_error_state.dart        # Mensaje de error y acción de reintento
    `-- nexus_widgets.dart            # Componentes visuales reutilizables
```

## Inicio y navegación

### Punto de entrada activo

`main.dart` contiene `main()`. Si la app se compiló con `SUPABASE_URL` y `SUPABASE_PUBLISHABLE_KEY` (por ejemplo `flutter run --dart-define-from-file=env.json`, ver [backend/README.md](backend/README.md)), primero llama a `Supabase.initialize`; si no, arranca sin backend. Después ejecuta la app dentro de `ProviderScope`. Su parámetro `retry` devuelve `null`, desactivando reintentos automáticos en Riverpod 3.4.3. `NexusApp` configura el `MaterialApp`, usa `buildNexusTheme()` y define `NexusRoutes.login` como ruta inicial. Por tanto, al iniciar la app, la primera pantalla es el inicio de sesión. Las reglas de organización y uso de estado están en [docs/ARQUITECTURA.md](docs/ARQUITECTURA.md).

El mapa de rutas conecta estos nombres con sus pantallas principales y con las pantallas empujadas por encima del shell:

| Ruta | Pantalla |
|---|---|
| `/login` | `LoginScreen` |
| `/signup` | `SignupScreen` |
| `/home` | `MainShell` |
| `/cart` | `CartScreen` |

`/product-detail` se resuelve mediante `onGenerateRoute`: la pantalla recibe el `String` `productId` desde `settings.arguments`. Si el argumento no es un `String`, se pasa un id vacío y el detalle presenta "Producto no encontrado". El catálogo y PC Builder viven dentro de `MainShell`, que mantiene una sola barra inferior y conserva el estado de la interfaz al cambiar entre pestañas.

### Recorrido principal

```text
Inicio de app
  -> Login
      -> Crear cuenta -> Registro
      -> Ingresar -> Inicio
  -> Inicio
      -> Catálogo
          -> Detalle del producto
      -> Carrito
      -> PC Builder
  -> Navegación inferior
      -> Inicio / Catálogo / PC Builder / Perfil
```

La barra inferior ya no conoce rutas. `MainShell` conserva el tab activo con `LazyIndexedStack`, y `NexusBottomNav` emite un `NexusTab` al `onTap`. El destino `PERFIL` sigue abriendo `/login` mediante `pushReplacementNamed`, pero el shell mantiene las 4 pestañas principales sin destruir el árbol de widgets. El botón atrá de Android, si no se está en `Inicio`, vuelve a `Inicio` y no sale de la ruta; las pantallas empujadas como detalle y carrito conservan la barra oculta.

## Pantallas y responsabilidades

### Autenticación

- `screens/auth/login_screen.dart`: muestra campos de correo y contraseña. El botón `INGRESAR` navega al inicio sin validar credenciales. El enlace para crear cuenta abre `/signup`.
- `screens/auth/signup_screen.dart`: muestra nombre, correo, contraseña y confirmación. `CREAR CUENTA` navega al inicio sin crear ni guardar una cuenta. El enlace `Ingresar` vuelve a `/login`.

### Inicio

`screens/home/home_screen.dart` compone la pantalla principal con barra superior, hero, franja de productos, categorías, tendencias, acceso a PC Builder y pie de página. Los productos y etiquetas siguen siendo constantes dentro de los widgets; los precios literales se convierten a COP con tasa 4.000 y redondeo unitario al millar. Los accesos a detalle pasan el id mock `rtx-5090` como fallback hasta que Home migre al repositorio.

### Catálogo y detalle

- `features/catalog/presentation/catalog_screen.dart`: observa `catalogPageProvider`, muestra carga/error/datos y dibuja las tarjetas de la página recibida. El contador procede de `CatalogState.total`; tarjetas y botón `Ver` envían su propio `productId`. El campo ejecuta búsqueda con debounce, los chips filtran por categoría y el scroll carga páginas adicionales.
- `features/catalog/presentation/product_detail_screen.dart`: recibe `productId` y obtiene el producto mediante `productDetailProvider`. Muestra estado de carga, error recuperable o "Producto no encontrado"; marca, categoría, stock, precios, descuento, especificaciones y relacionados se derivan del producto y del repositorio. Los productos agotados se identifican como "AGOTADO" en gris. Las secciones sin especificaciones no se dibujan. Cantidad, compra y agregar al carrito siguen teniendo callbacks vacíos.
- `features/catalog/domain/` define `ProductCategory`, `StockLevel`, `ProductSpec`, `Product`, `ProductPage` y `ProductRepository` sin importar Flutter ni Riverpod. El descuento se deriva de los precios.
- `features/catalog/data/mock_product_repository.dart` contiene seis productos de muestra y permite generar catálogos sintéticos. Simula 300 ms de latencia (configurable para pruebas) y ejecuta búsqueda insensible a mayúsculas y acentos, filtro y paginación en memoria. No hay DTOs, JSON ni conexión a backend.
- `features/catalog/catalog_providers.dart` es el único archivo de producción que conoce `MockProductRepository`. El catálogo usa un `AsyncNotifier` con estado de consulta, categoría, página y carga incremental; detalle y relacionados son providers `FutureProvider.autoDispose.family` que reciben el id.

### Carrito

`screens/cart/cart_screen.dart` muestra dos líneas fijas, cantidades, subtotales, envío y total precalculados en el código. Los precios mock se convierten a COP con tasa 4.000 y redondeo unitario al millar; el total fijo es la suma de los subtotales convertidos. Los botones para cambiar cantidad, eliminar, confirmar pedido y vaciar carrito no modifican el carrito ni disparan una compra.

### PC Builder

`screens/pc_builder/pc_builder_screen.dart` presenta componentes fijos, un gabinete vacío, un progreso fijo de 8/9, estado compatible, desglose y total fijo. Los precios mock se convierten a COP con tasa 4.000 y redondeo unitario al millar; el total fijo suma los componentes convertidos. Las acciones de editar, eliminar, seleccionar, comprar y agregar al carrito no cambian la configuración. El cálculo de compatibilidad descrito en comentarios todavía no está implementado.

## Entrada y origen de datos

| Superficie | Dato que se muestra o solicita | Comportamiento actual |
|---|---|---|
| Login | Correo y contraseña | `NexusTextField` sin controlador, validador ni envío conectado. El botón solo navega al inicio. |
| Registro | Nombre, correo, contraseña y confirmación | Campos visuales sin controlador, validador, creación de cuenta o persistencia. |
| Catálogo inicial | Primera página de productos | `catalogControllerProvider` obtiene 20 productos por página; el mock inicial contiene seis. |
| Búsqueda del catálogo | Texto de producto, marca o categoría | El campo usa el controlador, que aplica debounce y búsqueda normalizada en el repositorio. |
| Filtros y orden | Categoría y orden de catálogo | Los chips filtran por categoría; el selector de orden sigue siendo visual. |
| Cantidad de producto | Unidades en detalle | Valor fijo `01`; los controles `+`/`-` no lo alteran. |
| Carrito | Producto, cantidad y totales | Datos fijos en los constructores; no hay estado de carrito compartido. |
| PC Builder | Piezas, compatibilidad y precio | Componentes, progreso, compatibilidad y total fijos; no se recalculan. |

`NexusTextField`, en `widgets/nexus_widgets.dart`, usa `TextFormField` y conserva `hint`, `obscure` y `prefixIcon`. También acepta opcionalmente `controller`, `onChanged`, `onSubmitted`, `validator`, `keyboardType`, `textInputAction` y `enabled`. Los errores de validación usan el rosa de la paleta NEXUS. Sigue siendo `StatelessWidget` y no crea controladores propios; quien proporciona un controlador externo es responsable de destruirlo. No implementa debounce: esa lógica debe vivir en el controlador de búsqueda, no en el campo.

El paso 3 se limitó al widget y a `test/nexus_text_field_test.dart`; login, registro y catálogo no conectan todavía las nuevas opciones. La suite del campo cubre controlador, `onChanged`, validación dentro de `Form`, uso sin `Form`, texto oculto y campo deshabilitado.

No hay llamadas a servicios, serialización JSON ni almacenamiento local. El catálogo es la excepción al origen de datos por literales: sus datos proceden del repositorio mock y la navegación al detalle conserva el id seleccionado. Home, carrito y PC Builder todavía usan datos locales; la navegación no conserva formularios enviados.

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
- `widgets/nexus_quantity_stepper.dart`: control visual de cantidad reutilizado en detalle y carrito.
- `widgets/nexus_top_bar.dart`: barra superior con navegación y acceso opcional al carrito.
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
  en el backend ([docs/MODELO_DATOS.md](docs/MODELO_DATOS.md)). La app todavía
  usa el mock; se conecta en la fase 3.

La hoja de ruta vigente está en [docs/PLAN_IMPLEMENTACION.md](docs/PLAN_IMPLEMENTACION.md).
Los requisitos son los de [docs/REQUISITOS.md](docs/REQUISITOS.md) (análisis v2):
el catálogo se limita a computadores armados y piezas, el asistente de
recomendación es el núcleo del producto y los proveedores publican por API.
El antiguo paso 5D (carrito) es ahora la fase 5, y el paso 7 (PC Builder) es la
fase 6. Autenticación pasa a ser la fase 4.

## Archivos y validación

El árbol anterior refleja los archivos Dart actuales bajo `lib/`; también hay pruebas en `test/`, incluidas pruebas de formato COP, estados de stock, búsqueda/paginación, controlador, widgets, carga/error/reintento y navegación por producto. Validación del paso 5C: `flutter analyze` sin hallazgos y `flutter test` con 59 pruebas aprobadas. No se probó en dispositivo. Para mediciones de rendimiento, usar un teléfono físico con `flutter run --profile`, según `REGLAS_RENDIMIENTO.md`.
