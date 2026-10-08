# Documentación del código Dart de NEXUS

Este documento describe el código Dart actual de `lib/`, el punto de entrada, la navegación, las pantallas, los componentes compartidos y el estado real de los datos. Las reglas de rendimiento permanentes están en `REGLAS_RENDIMIENTO.md`.

## Estado general

NEXUS es actualmente un prototipo Flutter navegable de una tienda tecnológica. Las pantallas presentan datos de ejemplo escritos directamente en el código. No hay conexión a una API, base de datos, autenticación, persistencia local ni modelos de dominio compartidos. La mayoría de los controles muestran el flujo esperado, pero todavía no ejecutan operaciones de negocio. `NexusTextField` ya permite entregar texto y definir validadores; las pantallas aún no están conectadas a esas capacidades.

## Estructura de `lib/`

```text
lib/
|-- main.dart                         # Arranque activo, tema y mapa de rutas
|-- routes.dart                       # Nombres centralizados de rutas
|-- core/
|   `-- utils/
|       `-- format_price.dart         # Formateo de precios en centavos
|-- screens/
|   |-- auth/
|   |   |-- login_screen.dart         # Inicio de sesión visual
|   |   `-- signup_screen.dart        # Registro visual
|   |-- home/
|   |   `-- home_screen.dart          # Inicio, productos destacados y accesos
|   |-- catalog/
|   |   |-- catalog_screen.dart       # Búsqueda, filtros y productos de ejemplo
|   |   `-- product_detail_screen.dart # Detalle fijo de una tarjeta gráfica
|   |-- cart/
|   |   `-- cart_screen.dart          # Carrito y resumen de ejemplo
|   |-- comparator/
|   |   `-- comparator_screen.dart    # Comparación fija de dos celulares
|   `-- pc_builder/
|       `-- pc_builder_screen.dart    # Configuración de PC de ejemplo
|-- theme/
|   `-- nexus_theme.dart              # Colores, estilos y ThemeData compartidos
`-- widgets/
    |-- nexus_auth_header.dart        # Encabezado compartido de autenticación
    |-- nexus_bottom_nav.dart         # Navegación inferior principal
    |-- nexus_page.dart               # Scaffold y estructura para páginas
    |-- nexus_product_card.dart       # Tarjeta de producto configurable
    |-- nexus_quantity_stepper.dart   # Control visual de cantidad
    |-- nexus_top_bar.dart            # Barra superior y acceso al carrito
    `-- nexus_widgets.dart            # Componentes visuales reutilizables
```

## Inicio y navegación

### Punto de entrada activo

`main.dart` contiene `main()`, que ejecuta `runApp(const NexusApp())`. `NexusApp` configura el `MaterialApp`, usa `buildNexusTheme()` y define `NexusRoutes.login` como ruta inicial. Por tanto, al iniciar la app, la primera pantalla es el inicio de sesión.

El mapa de rutas conecta estos nombres con sus pantallas:

| Ruta | Pantalla |
|---|---|
| `/login` | `LoginScreen` |
| `/signup` | `SignupScreen` |
| `/home` | `HomeScreen` |
| `/catalog` | `CatalogScreen` |
| `/product-detail` | `ProductDetailScreen` |
| `/cart` | `CartScreen` |
| `/comparator` | `ComparatorScreen` |
| `/pc-builder` | `PcBuilderScreen` |

`routes.dart` declara los nombres como constantes estáticas de `NexusRoutes`; no contiene lógica de navegación adicional.

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
      -> Comparador
  -> Navegación inferior
      -> Inicio / Catálogo / PC Builder / Comparador / Perfil
```

La barra inferior usa `pushReplacementNamed` para cambiar entre las pestañas principales sin acumular cada pestaña en la pila. El destino `PERFIL` apunta temporalmente a `/login`; no existe una pantalla de perfil. Las barras superiores pueden volver con `Navigator.pop` y abrir el carrito.

## Pantallas y responsabilidades

### Autenticación

- `screens/auth/login_screen.dart`: muestra campos de correo y contraseña. El botón `INGRESAR` navega al inicio sin validar credenciales. El enlace para crear cuenta abre `/signup`.
- `screens/auth/signup_screen.dart`: muestra nombre, correo, contraseña y confirmación. `CREAR CUENTA` navega al inicio sin crear ni guardar una cuenta. El enlace `Ingresar` vuelve a `/login`.

### Inicio

`screens/home/home_screen.dart` compone la pantalla principal con barra superior, hero, franja de productos, categorías, tendencias, accesos a PC Builder y comparador, y pie de página. Los productos y etiquetas son constantes dentro de los widgets. Los accesos llevan a catálogo, detalle, carrito, comparador o PC Builder; no transmiten identificadores ni datos del producto seleccionado.

### Catálogo y detalle

- `screens/catalog/catalog_screen.dart`: dibuja un campo de búsqueda, chips de categoría, el texto fijo `128 productos` y cuatro tarjetas. Búsqueda, filtros, orden y botón de carrito no actualizan datos; las tarjetas y el botón `Ver` abren el mismo detalle genérico. La grilla todavía usa `GridView.count` con `shrinkWrap` dentro de la estructura de scroll de `NexusPage`; deberá migrarse a slivers y carga paginada en el paso 5.
- `screens/catalog/product_detail_screen.dart`: muestra siempre la ficha fija de una NVIDIA GeForce RTX 5090, sus especificaciones y dos relacionados. No recibe argumentos de ruta ni producto seleccionado. Cantidad, compra y agregar al carrito tienen callbacks vacíos.

### Carrito

`screens/cart/cart_screen.dart` muestra dos líneas fijas, cantidades, subtotales, envío y total precalculados en el código. Los botones para cambiar cantidad, eliminar, confirmar pedido y vaciar carrito no modifican el carrito ni disparan una compra.

### Comparador

`screens/comparator/comparator_screen.dart` muestra Samsung S26 Ultra e iPhone 17 Pro Max como selección fija y una tabla de nueve atributos cuyos valores son guiones. Los botones `+` son decorativos; no seleccionan dispositivos ni calculan diferencias.

### PC Builder

`screens/pc_builder/pc_builder_screen.dart` presenta componentes fijos, un gabinete vacío, un progreso fijo de 8/9, estado compatible, desglose y total fijo. Las acciones de editar, eliminar, seleccionar, comprar y agregar al carrito no cambian la configuración. El cálculo de compatibilidad descrito en comentarios todavía no está implementado.

## Entrada y origen de datos

| Superficie | Dato que se muestra o solicita | Comportamiento actual |
|---|---|---|
| Login | Correo y contraseña | `NexusTextField` sin controlador, validador ni envío conectado. El botón solo navega al inicio. |
| Registro | Nombre, correo, contraseña y confirmación | Campos visuales sin controlador, validador, creación de cuenta o persistencia. |
| Búsqueda del catálogo | Texto de producto, marca o categoría | `NexusTextField` sin callback/controlador ni filtro asociado. |
| Filtros y orden | Categoría y orden de catálogo | Elementos visuales; no cambian selección ni resultados. |
| Cantidad de producto | Unidades en detalle | Valor fijo `01`; los controles `+`/`-` no lo alteran. |
| Carrito | Producto, cantidad y totales | Datos fijos en los constructores; no hay estado de carrito compartido. |
| Comparador | Dos celulares y especificaciones | Modelos fijos; no hay selección, carga ni comparación de datos. |
| PC Builder | Piezas, compatibilidad y precio | Componentes, progreso, compatibilidad y total fijos; no se recalculan. |

`NexusTextField`, en `widgets/nexus_widgets.dart`, usa `TextFormField` y conserva `hint`, `obscure` y `prefixIcon`. También acepta opcionalmente `controller`, `onChanged`, `onSubmitted`, `validator`, `keyboardType`, `textInputAction` y `enabled`. Los errores de validación usan el rosa de la paleta NEXUS. Sigue siendo `StatelessWidget` y no crea controladores propios; quien proporciona un controlador externo es responsable de destruirlo. No implementa debounce: esa lógica debe vivir en el controlador de búsqueda, no en el campo.

El paso 3 se limitó al widget y a `test/nexus_text_field_test.dart`; login, registro y catálogo no conectan todavía las nuevas opciones. La suite del campo cubre controlador, `onChanged`, validación dentro de `Form`, uso sin `Form`, texto oculto y campo deshabilitado.

En la implementación actual tampoco hay llamadas a servicios, carga asíncrona de datos, serialización JSON ni almacenamiento local. Los datos visibles proceden de literales y listas constantes dentro de cada pantalla. La navegación entre pantallas no conserva una selección de producto o un formulario enviado.

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
- `widgets/nexus_bottom_nav.dart`: navegación inferior de cinco destinos.
- `widgets/nexus_page.dart`: `Scaffold`, `SafeArea`, barra superior, scroll vertical y padding común. Por ahora recibe `children`; todavía no admite `slivers`.
- `widgets/nexus_product_card.dart`: tarjeta de producto con precio en centavos y acciones provistas por la pantalla.
- `widgets/nexus_quantity_stepper.dart`: control visual de cantidad reutilizado en detalle y carrito.
- `widgets/nexus_top_bar.dart`: barra superior con navegación y acceso opcional al carrito.
- `core/utils/format_price.dart`: función `formatPrice` para presentar importes almacenados en centavos.

## Tema

`theme/nexus_theme.dart` define `NexusColors`, `NexusText` y `buildNexusTheme()`. La paleta es oscura con cian, rosa y verde para acentos, estados y acciones. El tema Material 3 comparte fondo, tipografía, `ColorScheme` y color de divisores entre pantallas.

## Siguientes pasos y límites actuales

Para convertir el prototipo en una aplicación funcional, las superficies principales que aún requieren implementación son:

1. Definir modelos y una fuente de datos para productos, usuarios, carrito y configuración de PC.
2. Conectar formularios y búsqueda a estado/controladores, usar la validación expuesta por `NexusTextField` y liberar los controladores desde quien los crea.
3. Pasar el producto seleccionado al detalle mediante argumentos de ruta o una solución de estado compartido.
4. Implementar filtros, orden, cantidades, acciones del carrito, selección del comparador y cálculos de compatibilidad/precio.
5. Conectar autenticación y persistencia (servicio remoto o almacenamiento local, según el alcance del proyecto).
6. Aplicar paginación y slivers al catálogo de acuerdo con `REGLAS_RENDIMIENTO.md`; hoy los cuatro productos son datos locales fijos.

## Archivos y validación

El árbol anterior refleja los archivos Dart actuales bajo `lib/`; también hay pruebas en `test/`. Las validaciones posteriores al paso 3 fueron `flutter analyze` y `flutter test`, ambas aprobadas. La inspección visual disponible se hizo en Chrome; no equivale a medir fluidez en un teléfono. Para las mediciones de rendimiento indicadas por hito, usar un dispositivo físico con `flutter run --profile`, según `REGLAS_RENDIMIENTO.md`.