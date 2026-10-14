# NEXUS

Prototipo Flutter navegable para una tienda de componentes tecnológicos. La app inicia en login y permite recorrer inicio, catálogo, detalle, carrito, comparador y PC Builder. Actualmente utiliza datos de ejemplo; autenticación, búsqueda, filtros, carrito y cálculos todavía no están conectados a servicios ni a estado de negocio.

## Ejecutar y comprobar

```powershell
flutter pub get
flutter run
```

```powershell
flutter analyze
flutter test
```

Para inspección de rendimiento, usar un dispositivo físico y `flutter run --profile`; Chrome solo sirve para revisar lógica y aspecto, no fluidez.

## Documentación

- [Documentación del código y estado funcional](DOCUMENTACION_LIB.md)
- [Reglas permanentes de rendimiento](REGLAS_RENDIMIENTO.md)
- [Registro histórico de refactorización de los pasos 1 y 2](REFACTORIZACION_PASOS_1_Y_2.md)
