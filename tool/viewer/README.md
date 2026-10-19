# Visor 3D del PC Builder

Página web con three.js que dibuja la configuración en 3D (RF-090). La app la muestra:
- en Android e iOS, dentro de un WebView;
- en la web, dentro de un iframe.

En escritorio no hay visor; la pantalla lo explica.

## Cómo está repartido el trabajo
- **Flutter decide dónde va cada pieza.** Lo hace `lib/features/pc_builder/presentation/viewer/scene_layout.dart`, que es Dart puro y tiene pruebas. Con eso arma el mensaje `scene`.
- **El visor solo dibuja.** Carga los modelos, los ajusta a su caja, los colorea según su estado y dibuja solo cuando algo cambia.
- **Si una pieza no tiene modelo,** el visor la genera (`src/procedural.js`).
- **Mensajes entre los dos lados:** están en `src/bridge.js`.

## Compilar
El visor se empaqueta en `assets/viewer/viewer.html`, que **sí va en el repositorio**: así nadie necesita Node para correr la app. Después de cambiar algo en `src/`:

```sh
cd tool/viewer
npm install
npm run build
```

Las versiones de three.js y esbuild están fijas en `package.json`.

## Revisar el visor sin la app
1. Servir `assets/viewer/` por HTTP. Por ejemplo, desde la raíz del repo:
   ```sh
   npx http-server assets/viewer -p 8099
   ```
2. Generar una escena de ejemplo. El primer argumento es la dirección de los modelos y el segundo, la refrigeración (`aire`, `liquida` o `sin`):
   ```sh
   dart run tool/viewer/demo_scene.dart http://127.0.0.1:54321/storage/v1/object/public/component-models aire
   ```
3. Abrir `http://127.0.0.1:8099/viewer.html` seguido del texto que imprime (`#scene=...`).

Sin la dirección de los modelos, todas las piezas se generan. Sirve para revisar la orientación de un modelo nuevo antes de registrarlo (`backend/MODELOS_3D.md`).
