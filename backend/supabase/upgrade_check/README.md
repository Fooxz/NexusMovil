# Prueba de migración (solo local)

Comprueba que las migraciones de roles, catálogo por oferta y publicaciones de tiendas
(`20261027030000` a `20261027050000`) se aplican sobre datos que ya existen sin cambiarlos. Simula la
nube: el catálogo cargado, clientes con consentimientos, direcciones, un carrito abierto y una compra
pagada.

No forma parte de `supabase test db` (está fuera de `tests/`) porque necesita aplicar las migraciones
**después** de cargar los datos. **Nunca** se ejecuta contra la nube: todos los comandos llevan `--local`
o van al contenedor local.

Desde `backend/`, con Supabase local en marcha:

```powershell
# 1. Base en la versión anterior a los roles, con el seed (el estado de la nube).
npx supabase db reset --local --version 20261027020000

# 2. Datos de clientes y foto del estado (en una transacción).
Get-Content -Raw supabase/upgrade_check/before.sql |
  docker exec -i supabase_db_nexus psql -U postgres -d postgres -1 -v ON_ERROR_STOP=1 -q

# 3. Las migraciones nuevas, sobre esos datos.
npx supabase migration up --local

# 4. Comparación: debe decir OK.
Get-Content -Raw supabase/upgrade_check/after.sql |
  docker exec -i supabase_db_nexus psql -U postgres -d postgres -v ON_ERROR_STOP=1 -q

# 5. Volver a la base de desarrollo normal.
npx supabase db reset --local
```

`supabase db query` no sirve aquí: ejecuta una sola sentencia por llamada.

## Qué compara

- **Lo que existía no cambia:** conteos y sumas de verificación de tiendas, productos, ofertas,
  atributos, imágenes, perfiles, consentimientos, direcciones, carrito, pagos y órdenes; los parámetros de
  `app_settings` que ya estaban; y las respuestas de `get_products`, `get_product`, `get_related`,
  `get_catalog_brands`, `get_builder_slots`, `get_builder_candidates`, `validate_build`,
  `get_build_scene`, `get_product_attributes`, `get_cart` y `get_checkout_status`.
- **Datos nuevos:** los perfiles existentes quedan como clientes; las tiendas existentes, sin cuenta y con
  su estado; `get_offers` trae una tarjeta por cada oferta visible; el catálogo existente no tiene tienda
  creadora; y el índice contra duplicados se pudo crear.

El nombre del contenedor (`supabase_db_nexus`) sale de `project_id` en `config.toml`.
