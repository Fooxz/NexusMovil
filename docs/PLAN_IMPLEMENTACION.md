# NEXUS: plan de implementación (app cliente Flutter + backend Supabase)

## Contexto

La versión 2 del análisis de requisitos (`NEXUS_Analisis_de_Requisitos.md`) cambia el enfoque del negocio:
- el catálogo queda en **solo computadores armados y piezas**;
- se elimina el comparador de celulares;
- el **asistente de recomendación** pasa a ser el núcleo del producto;
- los proveedores publican **por API**.

El repo ya tiene una app Flutter avanzada:
- Riverpod 3.4.3, organizada por feature (`domain`/`data`/`presentation`).
- Catálogo con repositorio mock, búsqueda con debounce, filtros y paginación con slivers. Los pasos 1 a 5C están hechos.
- Las pantallas de login, registro, carrito y PC Builder son solo visuales.
- La documentación existente sigue vigente: `docs/ARQUITECTURA.md`, `docs/API_CONTRATO.md` y `REGLAS_RENDIMIENTO.md`.

Decisiones tomadas con el usuario:
- La app Flutter cubre **solo al cliente** (HU-001 a HU-014).
- Construimos también el backend, con **Supabase**, en `backend/` dentro de este repo.
- El **PC Builder se mantiene** en la v1.

Elijo Supabase en lugar de Firebase porque el dominio es relacional (órdenes, sub-órdenes, comisiones, reglas versionadas, auditoría). Además, PostgreSQL da `BIGINT` para los centavos, RLS para aislar los datos (RNF-002), triggers para la bitácora (RNF-030) y `pg_cron` para la sincronización y las liquidaciones. Las Edge Functions (Deno/TypeScript) alojan la lógica que no debe correr en el móvil.

## Resumen del alcance (módulos)

| Módulo | Qué incluye | Prioridad | Dónde vive |
|---|---|---|---|
| Cuentas y cumplimiento | Registro con términos y consentimiento, login, recuperación, perfil y direcciones (RF-001 a 007) | Must | App + Supabase Auth |
| Catálogo | Dos familias (armado / pieza por tipo), plantillas de atributos tipados, varias ofertas por producto, imágenes, búsqueda y filtros (RF-012 a 016, RF-032 a 035) | Must | App + BD |
| Asistente | Necesidad en lenguaje natural, repreguntas, recomendación de armados con justificación por atributos reales, propuesta de piezas si ningún armado sirve, sin compra automática (RF-036 a 045) | Must (diferenciador) | App + Edge Function + LLM |
| PC Builder | Slots por tipo de pieza, motor de reglas determinista y versionado, faltantes, sugerencias, total y paso al carrito (RF-046 a 052) | Must | App + Edge Function + BD |
| Comercio | Carrito persistente, checkout con revalidación de precio y stock, pasarela, sub-órdenes por proveedor, descuento de stock, seguimiento (RF-053 a 070) | Must | App + Edge Functions |
| Comisiones y liquidación | Comisión por proveedor o producto con vigencia (prevalece la del producto, S-05), snapshot por ítem, liquidaciones (RF-071 a 079) | Must | Solo backend |
| Integración de proveedores | API keys, upsert idempotente por SKU externo, validación contra plantilla y categoría, rechazos detallados, logs, inventario desactualizado, webhooks de órdenes (RF-018 a 031, RF-062, 063) | Must | Solo backend |
| Administración y auditoría | Aprobación de proveedores, comisiones, reglas, monitoreo, bitácora (HU-022 a 033) | Must/Should | Backend + Supabase Studio (sin UI propia en v1) |

Fuera del alcance: promociones, celulares y comparador, compras autónomas del asistente (RF-086 a 088), y las apps de proveedor y de administrador.

## Estructura de carpetas objetivo

Se mantiene la regla de `ARQUITECTURA.md`: las carpetas se crean en la fase que las usa, no antes.

```text
prueba01/                          # raíz del repo git
├── lib/
│   ├── main.dart / routes.dart
│   ├── core/
│   │   ├── config/env.dart        # SUPABASE_URL/ANON_KEY vía --dart-define
│   │   ├── network/supabase_providers.dart
│   │   ├── errors/app_failure.dart
│   │   └── utils/format_price.dart   (existe)
│   ├── theme/  widgets/           (existen; se reutilizan)
│   ├── screens/home, screens/shell   (se quedan hasta tener lógica propia)
│   └── features/<feature>/{<feature>_providers.dart, domain/, data/, presentation/}
│       ├── catalog/     (existe)
│       ├── auth/        profile/   (direcciones, consentimientos)
│       ├── cart/        pc_builder/   assistant/
│       └── checkout/    orders/
├── test/                          # espeja lib/features (patrón actual con test/support)
├── backend/
│   ├── README.md                  # cómo levantar Supabase local
│   └── supabase/
│       ├── config.toml
│       ├── migrations/            # SQL versionado (CLI de Supabase)
│       ├── seed.sql               # datos de desarrollo (los 6 productos mock + armados)
│       ├── tests/                 # pgTAP: RLS, triggers, RPCs
│       └── functions/
│           ├── _shared/           # auth, errores, cliente BD, compat-engine.ts
│           ├── validate-build/    assistant/
│           ├── checkout/          payment-webhook/
│           └── provider-api/      provider-webhook-dispatch/
└── docs/
    ├── REQUISITOS.md              # copia del análisis v2 (fuente de verdad)
    ├── ARQUITECTURA.md  API_CONTRATO.md (app↔backend)
    ├── API_PROVEEDORES.md         # contrato público para proveedores (OpenAPI)
    └── MODELO_DATOS.md
```

Cambio de archivos: `analysis_options.yaml` excluye `backend/**`.

## Fases

Cada fase termina con `dart analyze` sin hallazgos (ver README: `flutter analyze` falla por la ruta con acento), `flutter test` en verde y, cuando toca el backend, `supabase db reset && supabase test db`. Además, la documentación se actualiza en la misma fase. Mantiene las reglas R1 a R10.

### Fase 0: alinear la documentación con el nuevo enfoque (sin código)
- Copiar el análisis a `docs/REQUISITOS.md`.
- `API_CONTRATO.md` v0.3:
  - quitar `phone` (RN-010);
  - agregar `family` (`prebuiltPc` | `part`), `imageUrl` (cierra D4) y `offers[]` (proveedor, precio, stockLevel; RF-014).
- Corregir el estado de 5C en `DOCUMENTACION_LIB.md`: ya está completo.
- Escribir este plan en `docs/` como hoja de ruta.

### Fase 1: base del backend y núcleo de la app
- `supabase init` en `backend/` y Supabase local con Docker, documentado en `backend/README.md`.
- Flutter:
  - agregar `supabase_flutter`;
  - crear `core/config/env.dart` con `--dart-define`, `core/network/supabase_providers.dart` y `core/errors/app_failure.dart`;
  - inicializar en `main.dart` sin cambiar la UI.
- Excluir `backend/` del analizador de Dart.

### Fase 2: modelo de datos del catálogo y auditoría (migraciones)
- Tablas:
  - `categories` (familia + tipo de pieza) y `attribute_definitions` (tipo, unidad, obligatoriedad);
  - `products` y `product_attributes` (EAV tipado, RNF-027) y `product_images`;
  - `providers` y `offers` (precio en centavos `BIGINT`, unidades, estado, `external_sku` único por proveedor).
- `audit_log` con trigger genérico de valores anterior y nuevo (RF-081, RNF-030).
- RLS: lectura pública solo de ofertas publicadas de proveedores activos (RF-015, RN-022).
- RPCs que respetan la forma del contrato: `get_products(page, page_size, search, family, category, ...)` → `{items,total,page,pageSize}`, más `get_product` y `get_related`.
- `seed.sql` con los productos del mock y varios armados.
- Pruebas pgTAP de RLS, del trigger y de la paginación estable.

### Fase 3: catálogo real en Flutter
- Ampliar `Product` (`lib/features/catalog/domain/product.dart`) con `family`, `imageUrl` y `offers`. Mantenerlo como dato de presentación: los atributos tipados irán en `PcPartSpec`.
- `data/supabase_product_repository.dart`: implementa `ProductRepository`, parsea con `compute` las páginas grandes (R5) y prueba la lectura con el fixture del contrato.
- El cambio de mock a real se hace solo en `catalog_providers.dart`.
- Filtros por familia, tipo de pieza, marca y precio, y orden (RF-033, cierra D5), reutilizando `CatalogController`.
- Imágenes con `cached_network_image` y `memCacheWidth` (R8).
- Ofertas por proveedor en el detalle (HU-005).

### Fase 4: autenticación, consentimiento y perfil
- `features/auth`: Supabase Auth (correo y contraseña), recuperación (RF-003) y sesión observable por provider.
- Registro con aceptación de términos guardada en `consents` (RF-007, RN-033). Se conectan las pantallas existentes de `screens/auth` con validación de `NexusTextField`.
- `features/profile`: datos y direcciones con validación (HU-003). RLS por `auth.uid()`.
- Guard de navegación: se puede navegar sin cuenta, pero el checkout exige sesión (RN-027). Aquí se evalúa adoptar `go_router` por los redirects y por el deep link de retorno del pago.

### Fase 5: carrito (paso 5D)
- Tablas `carts` y `cart_items`, persistentes para el usuario autenticado (RF-054); el carrito del invitado vive en memoria y se fusiona al iniciar sesión.
- `CartController` con totales derivados (R3). La cantidad va de 1 al máximo disponible, que da una RPC; así se cierra D7 sin exponer las unidades en el listado.
- Migrar `screens/cart` a `features/cart`.

### Fase 6: PC Builder y motor de compatibilidad (paso 7)
- Tablas `compat_rules` y `compat_rule_versions` (quién y cuándo, activación; RF-050), más los slots obligatorios por tipo.
- `functions/_shared/compat-engine.ts` es determinista (RN-013). Reglas iniciales:
  - socket CPU–placa;
  - tipo de RAM–placa;
  - factor de forma placa–gabinete;
  - potencia de la fuente frente a la suma de TDP con margen;
  - largo de la GPU frente al gabinete;
  - socket del disipador.
- `validate-build` devuelve incompatibilidades con la causa en lenguaje no técnico (RNF-023), las piezas faltantes y las sin stock, junto con alternativas compatibles (RF-049).
- Flutter: `features/pc_builder` con `PcPartSpec` y estado fuera del árbol de widgets, y paso de la configuración al carrito (RF-051). R9 en el visor.
- Pruebas: `deno test` del motor, más pruebas del controlador.

### Fase 7: asistente de recomendación
- Edge Function `assistant`: un LLM con herramientas sobre la BD (`search_catalog`, `get_product_attributes` y `validate_build`, que reutiliza el motor de la fase 6).
  - La clave del modelo vive solo en el servidor.
  - Al implementar se carga el skill `claude-api` para elegir el modelo y el patrón de uso de herramientas.
- Salida estructurada con `productIds` y una justificación por atributos.
  - El servidor revalida que cada producto exista, esté publicado y tenga stock antes de responder (RF-041, RN-015).
  - Se repregunta si falta el uso o el presupuesto (RF-037).
  - Si ningún armado sirve, se propone una configuración de piezas validada (RF-040).
- Tabla `assistant_interactions` para la trazabilidad (RF-043, RNF-034).
- Mitigación de la manipulación de instrucciones: el contexto se limita al catálogo y no hay datos de otros usuarios (RNF-009).
- Flutter: `features/assistant` con chat, tarjetas de recomendación que llevan al detalle, al PC Builder o al carrito (RF-042), aviso de contenido generado (RNF-025) y degradación si la IA cae (RNF-018).

### Fase 8: checkout, pagos y comisión
- Tablas `orders`, `sub_orders` (una por proveedor, S-06), `order_items` (snapshot de precio, cantidad, % de comisión y neto; RN-026), `payments` y `commission_rules` (proveedor o producto con vigencia; prevalece la del producto).
- Edge Function `checkout`:
  - revalida el precio y el stock (RF-055);
  - crea la intención de pago en la pasarela. La pasarela está **pendiente** de definir; propuesta: Wompi en sandbox, por COP.
- `payment-webhook`:
  - es idempotente por referencia (RNF-020);
  - crea la orden solo con el pago aprobado (RN-025);
  - descuenta el stock (RF-066) y calcula la comisión (RF-074);
  - registra los estados pendiente y rechazado sin crear órdenes (RF-059).
- Flutter: `features/checkout` con dirección, contacto, pago por redirect con deep link de retorno, y reintento si el pago es rechazado.

### Fase 9: órdenes y seguimiento
- `order_status_history` con transiciones válidas forzadas por trigger (RN-029).
- Flutter: `features/orders` con historial, detalle por sub-orden, transportadora y guía (RF-069), y estado en vivo con Supabase Realtime.
- Notificaciones push con FCM, nivel Should (RF-065), al final de la fase si alcanza el tiempo.

### Fase 10: API de proveedores e integración
- `provider-api` (versionada, `/v1`):
  - autenticación con API key hasheada en `provider_api_keys`, con rotación y revocación (RF-018, RNF-005);
  - rate limit por proveedor (RNF-006);
  - upsert por lotes idempotente por `external_sku` (RF-021 a 024);
  - validación contra `attribute_definitions` y las categorías permitidas, con rechazos detallados por ítem (RF-022);
  - pausa y retiro.
- Recepción de órdenes por webhook (`provider-webhook-dispatch` con reintentos; RF-062) y endpoints para confirmar, rechazar o despachar (RF-063).
- `integration_logs` (RF-025).
- Job `pg_cron` que marca como desactualizado el inventario sin sincronizar en más de 15 min y lo oculta de la compra (RF-027, RNF-015).
- Sandbox: un proyecto Supabase aparte. Documentación en `docs/API_PROVEEDORES.md` (OpenAPI).

### Fase 11: operación administrativa (sin UI propia)
- RPCs `security definer` restringidas al rol admin:
  - aprobar, rechazar o suspender proveedores (RF-009 a 011), donde suspender oculta las ofertas;
  - configurar comisiones con validación de rango (RN-024);
  - generar liquidaciones por periodo (RF-076; el momento de liberar el dinero está **pendiente**);
  - consultar la bitácora.
- El administrador las opera desde Supabase Studio o SQL. Un panel web queda para una versión futura.

### Fase 12: endurecimiento y salida
- Revisión de RLS y secretos.
- Medición en dispositivo físico con `flutter run --profile` (RNF-011 a 013).
- Accesibilidad, español, formato COP (RNF-021, RNF-024).
- Builds de Android e iOS (S-01).

## Pendientes del negocio que bloquean fases

Se avanza con estos supuestos provisionales y se marcan en el código cuando aplique:
- pasarela de pago y esquema de cobro (fase 8);
- rango de comisión y base de cálculo, S-07 (fase 8);
- política de fallo de la API y latencia (fase 10);
- jurisdicción: se asume Colombia, Ley 1581 y Ley 1480 (fases 4 y 8);
- si las piezas incluyen periféricos: se asume que no (S-10, fase 2).

## Verificación

- **Por fase:** `dart analyze`, `flutter test` (se mantiene el patrón de `test/support/*`), `supabase db reset && supabase test db` (pgTAP) y `deno test backend/supabase/functions`.
- **End-to-end al cerrar las fases 3, 6, 7 y 8:** `supabase start` → `flutter run --dart-define=SUPABASE_URL=... ` en el emulador Android (`10.0.2.2`).
  - Recorrido: buscar → asistente → PC Builder → carrito → pago en sandbox → orden visible con su sub-orden.
- **Fase 10:** `curl` contra `provider-api` con un lote que mezcla productos válidos, de una categoría fuera del alcance y reenviados con el mismo SKU. Se verifica el rechazo detallado, que no se creen duplicados y que el cambio aparezca en el catálogo.
