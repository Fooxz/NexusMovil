# Refactorización de los pasos 1 y 2

Este documento registra la limpieza base y la extracción de widgets compartidos realizadas en la aplicación NEXUS. El objetivo fue reducir duplicación manteniendo el contenido, las rutas, los callbacks y los estilos existentes, salvo los cambios explícitos de tema descritos abajo.

## Paso 1: limpieza base

### Prototipo anterior

- Se eliminó `lib/nexus_screen.dart`: era una app independiente con su propio `main()`, no tenía importadores en `lib/` y no era el punto de entrada utilizado por `lib/main.dart`.
- Se actualizó `test/widget_test.dart` para iniciar la aplicación real (`NexusApp`) desde `lib/main.dart`, en lugar de importar el prototipo eliminado.

### Color de contraste y fuente

- Se agregó `NexusColors.onCyan = Color(0xFF04211F)` en `lib/theme/nexus_theme.dart` y se reemplazaron las referencias duplicadas en tema, widgets y pantallas.
- Se quitó `fontFamily: 'Segoe UI'` de `buildNexusTheme()` para no depender de una fuente instalada solo en algunas plataformas.
- El literal `04211F` quedó declarado únicamente en el tema.

> La eliminación de `Segoe UI` puede cambiar la fuente efectiva según plataforma. Esta instrucción de limpieza puede entrar en conflicto con una exigencia de identidad visual píxel a píxel.

## Paso 2: widgets compartidos

### Esqueleto de página

`lib/widgets/nexus_page.dart` agrega `NexusPage`, que centraliza `Scaffold`, fondo, `SafeArea`, scroll, columna, `NexusTopBar` y padding horizontal. Se utiliza en catálogo, detalle, carrito y PC builder.

El título, volver, carrito, badge, navegación inferior y padding son parámetros. Cada pantalla conserva sus hijos, el índice de navegación y sus opciones originales de barra superior. Home y autenticación no usan `NexusPage`, porque tienen composiciones diferentes.

### Cantidad y descuentos

- `lib/widgets/nexus_quantity_stepper.dart` agrega `NexusQuantityStepper`, que muestra cantidades con dos dígitos. El detalle utiliza la densidad normal y `_CartItemCard` la compacta; el layout horizontal de la tarjeta de carrito no se unificó.
- `NexusDiscountBadge`, en `lib/widgets/nexus_widgets.dart`, reemplaza las insignias rosas del catálogo y del detalle. El tamaño de texto configurable conserva la diferencia entre ambas.

### Encabezado de autenticación

`lib/widgets/nexus_auth_header.dart` agrupa logo, marca, título y subtítulo. Login y signup comparten el widget y mantienen sus textos y espacios específicos hacia los formularios.

### Botones

Se extendieron `NexusPrimaryButton` y `NexusOutlineButton` en `lib/widgets/nexus_widgets.dart` para aceptar colores, icono opcional, ancho, tamaño compacto y ajustes de estilo necesarios para conservar los botones anteriores.

Home, catálogo, detalle y PC builder usan ahora los botones compartidos. Se conservaron los callbacks vacíos mediante `onPressed ?? () {}` y se dejó un `TODO` en los widgets para señalar que aún no deshabilitan realmente esas acciones.

La búsqueda confirmó que ya no hay `ElevatedButton(` ni `OutlinedButton(` directamente en `lib/screens/`; las implementaciones Material quedan encapsuladas en los widgets compartidos.

### Tarjetas y precios

- `lib/widgets/nexus_product_card.dart` agrega `NexusProductCard` con datos opcionales para marca, estado, specs, tags, precio anterior, descuento y acciones. Recibe precios en centavos y no decide rutas: cada pantalla proporciona `onTap` y acciones.
- La tarjeta de catálogo (`_ProductGridCard`) y la tarjeta relacionada del detalle (`_RelatedCard`) se sustituyeron por `NexusProductCard` y sus clases locales se eliminaron.
- `lib/core/utils/format_price.dart` define `formatPrice(int cents)`, que formatea valores, por ejemplo, como `$1,999.00`.
- Los precios de catálogo, productos relacionados, precio principal del detalle, franja de productos del home, artículos del carrito y componentes individuales del builder ahora se expresan en centavos y se formatean con esa función.
- Los resúmenes de carrito y PC builder conservan sus importes como texto fijo de mockup; no forman parte de las tarjetas de producto y todavía no se calculan desde estado.

## Variantes que se conservaron

- `_ProductCard` y `_TrendCard` del home permanecen separados: usan formatos compactos, distintas alturas de imagen y contenido que no encaja con la tarjeta de catálogo/relacionados sin añadir modos visuales artificiales. La franja `_ProductCard` sí usa `formatPrice` y recibe el precio como centavos.
- `_CartItemCard` permanece separado porque su composición es horizontal; comparte solo `NexusQuantityStepper` y `formatPrice`.
- Home, login y signup conservan sus composiciones de página propias.

## Validación y revisión manual

- `flutter analyze`: sin errores ni warnings al finalizar.
- `flutter test test/widget_test.dart`: 4 pruebas aprobadas, incluida la prueba del formato de precios y de la delegación de `onTap` de `NexusProductCard`.
- Búsqueda de `04211F`: solo aparece en la declaración del tema.
- Búsqueda de botones Material en `lib/screens/`: sin resultados.
- Búsqueda de `_ProductGridCard` y `_RelatedCard`: sin resultados.
- Se intentó ejecutar la app en Chrome y se capturó la pantalla de login. El proceso de `flutter run` terminó desde el entorno antes de completar el recorrido manual. No había emulador Android/iOS conectado ni Flutter Driver habilitado; por tanto, no se certificó visualmente cada pantalla en dispositivo.

## Commits

Cada subpaso quedó en un commit independiente:

| Subpaso | Commit | Descripción |
|---|---|---|
| 1.1 | `bc99444` | Eliminar prototipo Nexus obsoleto |
| 1.2–1.3 | `3b5f850` | Centralizar color de contraste del tema |
| 2.1 | `cdf1eab` | Compartir shell de páginas Nexus |
| 2.2 | `6e8b58e` | Compartir contador de cantidad |
| 2.3 | `c3dfde2` | Compartir insignia de descuento |
| 2.4 | `deb807d` | Compartir encabezado de autenticación |
| 2.5 | `5242613` | Unificar botones de acciones compartidos |
| 2.6 | `31e325a` | Unificar tarjetas y formateo de precios |
