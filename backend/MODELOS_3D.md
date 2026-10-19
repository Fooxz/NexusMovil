# Modelos 3D del visor (fase 6.1)

El visor del PC Builder (RF-090) arma el computador con un modelo `.glb` por pieza. Para elegir el modelo de cada pieza:
- primero busca uno del producto exacto;
- si no hay, usa el genérico de su categoría;
- si tampoco hay, la app **genera** la pieza con su forma y las medidas reales de sus atributos (largo de la GPU, formato de la placa, altura del disipador...).

Así el visor funciona con todo el catálogo, y cada modelo que se agrega mejora cómo se ve.

## Modelos actuales y créditos

| Categoría | Archivo | Obra | Autor | Licencia | Fuente |
|---|---|---|---|---|---|
| CPU | `generic/cpu.glb` | CPU | iPoly3D | CC0 1.0 (dominio público) | https://poly.pizza/m/oF0cAyddAI |
| RAM | `generic/ram.glb` | RAM | iPoly3D | CC0 1.0 (dominio público) | https://poly.pizza/m/obBMPOGYvy |
| Gráfica | `generic/gpu.glb` | Graphics card | pgonarg | CC BY 3.0 | https://poly.pizza/m/i45v5trpyR |

- **Se generan en la app:** gabinete, placa madre, fuente, refrigeración y almacenamiento.
  - No se encontraron modelos libres que sirvan: los gabinetes gratuitos son cajas cerradas o ya traen piezas adentro.
- **Créditos en la app:** la pantalla muestra "Créditos de los modelos 3D" cuando la escena usa un modelo. CC BY exige nombrar la obra, el autor, la licencia y la fuente.
- **Si se cambia un modelo,** hay que actualizar también esta tabla.

## Cómo agregar un modelo

### 1. Revisar la licencia
- **Se aceptan:** CC0, CC BY 3.0 o 4.0, o un modelo propio (hecho o comprado por NEXUS, con derecho de uso).
- **No se aceptan:** "solo uso personal", "no comercial" (NC) ni "sin derivados" (ND).
  - ND no sirve porque la app escala y recolorea el modelo.
- **Anotar** el título, el autor y el enlace a la página del modelo.

### 2. Preparar el archivo
- **Formato:** glTF binario (`.glb`), máximo 5 MiB. Lo ideal es menos de 1 MiB, porque se descarga en el teléfono.
- **Reducir el tamaño:**
  ```sh
  npx @gltf-transform/cli optimize entrada.glb salida.glb --compress meshopt
  ```
  El visor lee la compresión meshopt.
- **Gabinetes:** deben venir **abiertos**, sin el panel lateral, porque si no tapan el interior.

### 3. Orientación de la categoría
El visor escala el modelo sin deformarlo y lo ubica en su lugar. Para eso, el modelo debe quedar así, mirando a la cámara:

| Categoría | Orientación esperada |
|---|---|
| Gráfica | Largo en X, con el soporte metálico en **+X**. Alto de la tarjeta en Y, con el conector PCIe abajo. Grosor en Z. |
| RAM | Largo del módulo en X y alto en Y, con los contactos abajo. Grosor en Z. |
| CPU, M.2 y placa madre | Cara de arriba mirando a **+Z**. |

- **Si el modelo viene girado,** no hace falta editarlo en Blender. Se guarda la corrección en `rotation_deg`, en grados (X, Y, Z).
  - Por ejemplo, la gráfica actual trae el soporte en -X, por eso tiene `{0,180,0}`.
- **Para comprobar la orientación,** sirve la escena de ejemplo del visor (`tool/viewer/README.md`).

### 4. Subirlo y registrarlo

**En local** (`backend/supabase`):
1. Copiar el archivo en `models/generic/` o en `models/products/`.
2. Agregar su fila en `seed.sql` (tabla `component_models`).
3. Correr `npx supabase db reset`. Así se suben los archivos y se carga la fila.

**En producción:**
1. Subir el archivo al bucket `component-models`, desde Supabase Studio o con la CLI.
2. Insertar la fila en `component_models` como administrador.

Un ejemplo de fila para el modelo de un producto:
```sql
insert into public.component_models
  (category_code, product_id, file_path, rotation_deg, title, author, license, source_url)
values ('gpu', 'rtx-5080', 'products/rtx-5080.glb', '{0,0,0}', 'RTX 5080', 'Autor', 'CC-BY-4.0',
        'https://...');
```

**La base de datos rechaza:**
- un segundo modelo activo para el mismo producto, o un segundo genérico para la misma categoría;
- un producto de otra categoría;
- un archivo que no sea `.glb`;
- una licencia CC BY sin `source_url`.

**Para reemplazar un modelo:** desactivar el anterior (`is_active = false`) e insertar el nuevo. Ambos cambios quedan en la bitácora.

**Modelos genéricos que el visor no usa:** el de gabinete (taparía el interior), el de almacenamiento (un M.2 no se parece a un disco) y el de refrigeración (puede ser de aire o líquida). En esas categorías solo se usan modelos del producto exacto.
