# NEXUS

Prototipo Flutter navegable para una tienda de computadoras y componentes. La app inicia en login y permite recorrer inicio, catálogo, detalle, carrito y PC Builder. Actualmente utiliza datos de ejemplo; autenticación y carrito todavía no están conectados a servicios.

## Ejecutar y comprobar

```powershell
flutter pub get
flutter run
```

Para conectar la app al backend local (Supabase), ver [backend/README.md](backend/README.md):

```powershell
flutter run --dart-define-from-file=env.json
```

```powershell
dart analyze
flutter test
```

`flutter analyze` (Flutter 3.47.2) falla en esta carpeta con `FormatException: Unexpected end of input`: el analysis server no maneja bien la `á` de `Práctica_dart` en la ruta. `dart analyze` aplica las mismas reglas de `analysis_options.yaml` y sí funciona. También funciona `flutter analyze` ejecutado desde una ruta solo ASCII, por ejemplo un junction (`New-Item -ItemType Junction`).

Para inspección de rendimiento, usar un dispositivo físico y `flutter run --profile`; Chrome solo sirve para revisar lógica y aspecto, no fluidez.

## Documentación

- [Requisitos (análisis v2)](docs/REQUISITOS.md)
- [Plan de implementación por fases](docs/PLAN_IMPLEMENTACION.md)
- [Arquitectura](docs/ARQUITECTURA.md) y [contrato de API app–backend](docs/API_CONTRATO.md)
- [Documentación del código y estado funcional](DOCUMENTACION_LIB.md)
- [Reglas permanentes de rendimiento](REGLAS_RENDIMIENTO.md)
- [Registro histórico de refactorización de los pasos 1 y 2](REFACTORIZACION_PASOS_1_Y_2.md)
