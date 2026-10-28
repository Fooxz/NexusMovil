# NEXUS: plan de implementación (app cliente Flutter + backend Supabase)

## Contexto

La versión vigente del análisis está en [`docs/REQUISITOS.md`](REQUISITOS.md). El cambio de alcance del 2026-10-27 prevalece sobre la versión 2 original: el catálogo incluye **solo piezas**, no computadores armados. El asistente ayuda a escoger piezas compatibles según uso y presupuesto.
- se elimina el comparador de celulares;
- el **asistente de recomendación** pasa a ser el núcleo del producto;
- los proveedores publican **por API**.

Estado actual del repo:
- Riverpod 3.4.3, organizada por feature (`domain`/`data`/`presentation`).
- Catálogo, cuentas, perfil, carrito, PC Builder, asistente y checkout con implementaciones conectadas al backend y repositorios mock donde corresponde.
- Las fases 0 a 8 están implementadas; el cambio a solo piezas y el catálogo grande de desarrollo también están hechos. Las fases 9 a 12 siguen en la hoja de ruta.
- `docs/ARQUITECTURA.md`, `docs/API_CONTRATO.md` y `REGLAS_RENDIMIENTO.md` describen decisiones y requisitos técnicos; cada documento debe mantenerse alineado con el estado del código.

Decisiones tomadas con el usuario:
- La app Flutter cubre **tres roles** (cambio del 2026-10-27): el cliente (HU-001 a HU-014), la tienda (publica sus productos sin aprobación) y el administrador (crea y habilita tiendas). Antes cubría solo al cliente; ver "Roles y marketplace por tienda".
- Construimos también el backend, con **Supabase**, en `backend/` dentro de este repo.
- El **PC Builder se mantiene** en la v1.

Elijo Supabase en lugar de Firebase porque el dominio es relacional (órdenes, sub-órdenes, comisiones, reglas versionadas, auditoría). Además, PostgreSQL da `BIGINT` para los centavos, RLS para aislar los datos (RNF-002), triggers para la bitácora (RNF-030) y `pg_cron` para la sincronización y las liquidaciones. Las Edge Functions (Deno/TypeScript) alojan la lógica que no debe correr en el móvil.

## Resumen del alcance (módulos)

| Módulo | Qué incluye | Prioridad | Dónde vive |
|---|---|---|---|
| Cuentas y cumplimiento | Registro con términos y consentimiento, login, recuperación, perfil y direcciones (RF-001 a 007) | Must | App + Supabase Auth |
| Catálogo | Piezas por tipo (los armados salieron el 2026-10-27), plantillas de atributos tipados, varias ofertas por producto, imágenes, búsqueda y filtros (RF-012 a 016, RF-032 a 035) | Must | App + BD |
| Asistente | Necesidad en lenguaje natural, repreguntas, configuración completa por piezas o piezas sueltas para mejorar un equipo, con justificación por atributos reales, sin compra automática (RF-036 a 045); entrada por voz y llenado del PC Builder (RF-089) | Must (diferenciador) | App + Edge Function + LLM |
| PC Builder | Slots por tipo de pieza, motor de reglas determinista y versionado, faltantes, sugerencias, total y paso al carrito (RF-046 a 052); visor 3D con un modelo por componente (RF-090) | Must (visor: Should) | App + BD + Storage |
| Comercio | Carrito persistente, checkout con revalidación de precio y stock, pasarela, sub-órdenes por proveedor, descuento de stock, seguimiento (RF-053 a 070) | Must | App + Edge Functions |
| Comisiones y liquidación | Comisión por proveedor o producto con vigencia (prevalece la del producto, S-05), snapshot por ítem, liquidaciones (RF-071 a 079) | Must | Solo backend |
| Integración de proveedores | API keys, upsert idempotente por SKU externo, validación contra plantilla y categoría, rechazos detallados, logs, inventario desactualizado, webhooks de órdenes (RF-018 a 031, RF-062, 063) | Must | Solo backend |
| Administración y auditoría | Aprobación de proveedores, comisiones, reglas, monitoreo, bitácora (HU-022 a 033) | Must/Should | Backend + Supabase Studio (sin UI propia en v1) |

Fuera del alcance: promociones, celulares y comparador, y compras autónomas del asistente (RF-086 a 088). Las tiendas y los administradores usan la misma app (no hay apps aparte).

## Estructura de carpetas objetivo

Se mantiene la regla de `ARQUITECTURA.md`: las carpetas se crean en la fase que las usa, no antes.

```text
prueba01/                          # raíz del repo git
├── lib/
│   ├── main.dart / routes.dart
│   ├── core/
│   │   ├── config/env.dart        # SUPABASE_URL/SUPABASE_PUBLISHABLE_KEY
│   │   ├── network/supabase_providers.dart
│   │   ├── errors/app_failure.dart
│   │   └── utils/format_price.dart   (existe)
│   ├── theme/  widgets/           (existen; se reutilizan)
│   ├── screens/home, screens/shell   (inicio y navegación)
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
│       ├── seed.sql               # datos de desarrollo (los 6 productos mock + piezas de varias gamas)
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

### Fase 6: PC Builder y motor de compatibilidad (paso 7) — hecha
- Tablas `builder_slots`, `compat_rules` y `compat_rule_versions` (versionadas, con quién y cuándo, y una sola versión activa; RF-050).
- Motor determinista (RN-013) en **PostgreSQL**, con las RPC `validate_build` y `get_builder_candidates`. Reglas iniciales:
  - socket CPU–placa y CPU–disipador;
  - tipo, módulos y capacidad de RAM frente a la placa;
  - formato placa–gabinete;
  - largo de la GPU y altura del disipador frente al gabinete;
  - potencia de la fuente;
  - salida de video.
- **Cambio frente al plan original:** el motor iba a ser una Edge Function en TypeScript probada con `deno test`. Se hizo en SQL para que las reglas, los datos y la evaluación vivan juntos, para probarlo con pgTAP sin instalar Deno y para que el asistente reutilice la misma RPC.
- Flutter: `features/pc_builder` con estado fuera del árbol de widgets, selector de piezas con compatibilidad y causa, y paso de la configuración al carrito (RF-051). No se creó `PcPartSpec`: la app no necesita los atributos tipados, porque el backend evalúa. El ícono fijo que hacía de visor 3D se retiró; el visor real es la fase 6.1.

### Fase 6.1: visor 3D de la configuración (RF-090) — hecha
Objetivo: ver cómo se vería el computador con las piezas elegidas, ya sea a mano o por el asistente.
- **Modelos:** archivos `.glb` en el bucket público `component-models` de Storage. La tabla `component_models` guarda el modelo de un producto o el genérico de su categoría, con su licencia y autor. Los datos de la escena los entrega la RPC `get_build_scene`.
  - Hay tres modelos genéricos, con licencia libre y descargados de Poly Pizza: CPU, RAM y gráfica.
  - Gabinete, placa, fuente, refrigeración y almacenamiento se generan en el visor con las medidas reales de los atributos. Cómo agregar modelos: `backend/MODELOS_3D.md`.
- **Ensamblado:** `scene_layout.dart` (Dart puro, con pruebas) define una caja en milímetros para cada pieza.
  - Se basa en el formato de la placa (socket, ranuras de RAM, PCIe, M.2) y en los atributos: largo de la GPU, módulos de RAM, altura del disipador, radiador y tipo de almacenamiento.
  - El visor escala cada modelo sin deformarlo hasta que quepa en su caja, y lo alinea.
- **Render:** three.js empaquetado en un único HTML (`tool/viewer` → `assets/viewer/viewer.html`).
  - En Android e iOS va en un WebView (`webview_flutter`) y en la web en un iframe.
  - En escritorio no hay visor; la pantalla lo explica.
- **En la app:**
  - el visor va arriba del armador; se puede girar y acercar;
  - las piezas con incompatibilidades se marcan en rosa;
  - tocar una pieza abre su selector;
  - un botón muestra los créditos de los modelos.
- **Cambios frente al diseño inicial:**
  - Los puntos de montaje iban a ser nodos dentro de cada modelo, hechos en Blender. Los modelos gratuitos no los traen, así que la posición sale de `scene_layout.dart` y cada modelo solo guarda una rotación de corrección.
  - `flutter_scene` se descartó porque exige el canal master de Flutter.
- **Pruebas:**
  - pgTAP de la tabla y la RPC;
  - pruebas del cálculo de la escena, del JSON y del widget con un visor falso;
  - integración, que incluye la descarga del `.glb`;
  - revisión del render con capturas de Chrome sin interfaz.
  - Falta medir en un teléfono físico (R9).

### Fase 7: asistente de recomendación — hecha
- **Edge Function `assistant`** (TypeScript, `backend/supabase/functions/assistant`) con **Google Gemini** (decisión del equipo, 2026-10-19) y llamadas a funciones.
  - **Herramientas de consulta:**
    - `search_catalog`;
    - `list_compatible_parts`, varias categorías por llamada;
    - `validate_build`, el motor SQL de la fase 6.
  - **Herramientas que cierran el turno:** `ask_user`, `recommend` y `no_match`. El modelo siempre termina con una de ellas, así que la respuesta llega como datos que se pueden validar.
  - **La clave vive solo en el servidor:** `GEMINI_API_KEY` en `backend/supabase/functions/.env` (ignorado por git) o en `supabase secrets set`.
- **El servidor revalida antes de responder** (RF-041, RN-015): cada producto debe existir, estar publicado y tener stock, y la configuración debe ser válida y comprable. Si no, se le pide al modelo que corrija (hasta 2 veces) y lo que no sirve se descarta.
- **Conversación:** se repregunta si falta el uso o el presupuesto (RF-037). Se prefieren los armados; si ninguno sirve, se arma una configuración de piezas (RF-040).
- **Trazabilidad:** tabla `assistant_interactions` con la pregunta, la respuesta, los productos, el modelo, las herramientas usadas y la latencia (RF-043, RNF-034). Guarda un hash del cliente, no la IP.
- **Seguridad y costo:**
  - Límite de 20 preguntas cada 10 minutos por cliente.
  - El contexto se limita al catálogo público, sin datos de otros usuarios (RNF-009).
  - Las instrucciones del sistema ignoran los intentos de cambiar las reglas.
- **Degradación (RNF-018):**
  - un reintento ante errores 5xx o conexiones cortadas;
  - una cadena de modelos, porque cada uno tiene su propia cuota gratuita (`gemini-3.5-flash` solo permite 20 llamadas al día);
  - si ninguno responde, un `503` que la app muestra con atajos al catálogo y al PC Builder.
- **Flutter** (`features/assistant`):
  - pestaña ASISTENTE en el centro de la barra;
  - chat con sugerencias y aviso de contenido generado (RNF-025);
  - tarjetas de producto con motivo, "Ver detalle" y "Agregar" (RF-042);
  - la configuración por piezas con "Ver en el PC Builder (3D)", que la carga en el armador y en el visor (RF-089). Nunca compra sola (RF-088).
- **Voz (RF-089):** `speech_to_text`, en español de Colombia si el dispositivo lo tiene. El texto queda en el campo para que el cliente lo revise antes de enviarlo.
  - El reconocedor es el del sistema (Android, iOS o el navegador) y puede usar servicios de Google o Apple según la configuración del teléfono.
  - NEXUS no recibe ni guarda el audio.
- **Pruebas:**
  - núcleo de la función con `node --test`, con modelo y RPC falsos;
  - pgTAP;
  - JSON, controlador y pantalla en Flutter;
  - integración contra la función. La que llama a Gemini es opcional (`ASSISTANT_LIVE=true`) porque gasta cuota.
  - El flujo completo se revisó en la app web: pregunta, presupuesto, configuración, PC Builder y 3D.
- **Visualizar en 3D un armado recomendado** (RF-090), **retirado el 2026-10-27** con los armados: tabla `prebuilt_components` y RPC `get_prebuilt_scene`. Muestra sus componentes en las secciones del PC Builder y en la vista 3D, sin tocar la configuración del cliente. El armado se compra completo.
- **Cambio frente al plan:** no hay una herramienta `get_product_attributes` separada. Las búsquedas ya traen los atributos legibles (RPC `get_product_attributes`), así se ahorran llamadas al modelo.

### Fase 8: checkout, pagos y comisión — hecha
- **Decisiones del negocio (2026-10-24):**
  - pasarela **Wompi**, en COP y en modo de pruebas;
  - los precios del catálogo ya incluyen el **IVA del 19 %**;
  - la comisión se calcula sobre el valor sin IVA.
- **Tablas** (migración `20261024010000_checkout.sql`, ver `docs/MODELO_DATOS.md`):
  - `payments` (intento de pago con la foto del carrito) y `payment_events` (cada aviso y consulta);
  - `orders`, `sub_orders` (una por proveedor, S-06) y `order_items` (precio, cantidad, base sin IVA, % y regla de comisión y neto; RN-026);
  - `commission_rules` (proveedor o producto, con vigencia; prevalece la del producto, S-05).
- **RPC:**
  - `start_checkout` revalida el precio y el stock (RF-055);
  - `get_checkout_status` da el estado del pago;
  - `apply_payment_event`, solo para el rol de servicio, aplica el resultado de la pasarela de forma idempotente (RNF-020). Crea la orden solo con el pago aprobado (RN-025), descuenta el stock (RF-066) y calcula la comisión (RF-074). Los pendientes y rechazados no crean órdenes (RF-059).
- **Edge Functions** (`backend/supabase/functions`):
  - `checkout`: crea el intento y firma la URL del Web Checkout con el secreto de integridad. Al volver, consulta la transacción en Wompi y aplica el resultado, así el pago se confirma aunque el webhook se demore o no llegue (en local nunca llega).
  - `payment-webhook`: verifica la firma de los eventos de Wompi y aplica el resultado.
  - Código común en `_shared/` (`wompi.ts` y `http.ts`).
  - Las llaves solo viven en el servidor: `functions/.env` o `supabase secrets set`.
- **Flutter** (`features/checkout`):
  - dirección guardada, contacto y facturación prellenados con el perfil;
  - resumen por proveedor y pago;
  - resultado: orden aprobada con sus sub-órdenes, pago pendiente con "consultar de nuevo", o rechazo con "intentar de nuevo".
  - Si el total o el stock cambiaron, se avisa y se recarga el carrito.
- **Cambio frente al plan: sin deep link.** En Android e iOS, Wompi se abre en un WebView dentro de la app, que intercepta la página de regreso (`redirectUrl?id=...`). Así no hace falta registrar un esquema propio ni App Links. En web y escritorio se abre en el navegador y el cliente vuelve a consultar.
- **Sin backend,** la app simula la pasarela con un diálogo que aprueba o rechaza.
- **Pruebas:**
  - pgTAP (41);
  - firmas, función y webhook con `node --test` (20), con el ejemplo de firma de la documentación de Wompi;
  - JSON, repositorio y pantalla en Flutter;
  - recorrido local completo con llaves falsas y webhook firmado.
- **Pendiente:**
  - probar con llaves reales del sandbox de Wompi y registrar la URL de eventos en su dashboard (ver `backend/README.md`);
  - reservar stock durante el pago (RF-067, Could).

### Cambio de alcance: solo piezas (2026-10-27) — hecho
- **Decisión del equipo:** NEXUS vende solo piezas de computador. Con equipos cerrados el asistente solo elegía entre unos pocos; con piezas ayuda a escoger cada componente según el uso, el presupuesto y la compatibilidad.
- **Backend:** migración `20261027010000_parts_only.sql`. Borra los armados, la categoría `prebuiltPc`, `prebuilt_components` y `get_prebuilt_scene`, y agrega la restricción `categories_parts_only`. El filtro `family` solo admite `part` (API_CONTRATO v0.11, cierra D8).
- **Seed:** 14 piezas de gama de entrada y media reemplazan a los 3 armados, para que el asistente pueda armar equipos de oficina y de gaming de distintos presupuestos.
- **Asistente:** arma un computador completo por piezas (validado por el motor) o recomienda piezas sueltas para mejorar un equipo, teniendo en cuenta las piezas que el cliente dice tener. Si piden un armado, explica que NEXUS vende piezas y ofrece armarlo.
- **Flutter:** sin familias ni categoría de armados en el catálogo (chips "Todo" + tipos de pieza), sin "Visualizar en 3D" de armados, sugerencias del asistente y textos de Inicio actualizados.
- **Pendiente:**
  - aplicar la migración en la nube (`db push`, con confirmación) y cargar ahí las piezas nuevas;
  - `docs/REQUISITOS.md`: ya se actualizaron las reglas, requisitos y criterios principales (marca **[Alcance 2026-10]**) y una nota al inicio dice que la decisión prevalece; conviene que el equipo revise las preguntas abiertas y los riesgos que todavía mencionan armados;
  - el texto legal 1.0 (borrador) todavía dice "computadores armados y piezas": se corrige cuando se redacte la versión definitiva, porque cambiarlo exige una versión nueva que los usuarios vuelven a aceptar.

### Catálogo grande de desarrollo (2026-10-27) — hecho
- **760 piezas y 6 proveedores** en local: `tool/catalog/generate_catalog.mjs` genera `backend/supabase/seeds/catalog_generated.sql` (determinista), que el reset carga después de `seed.sql`.
- **PC Builder con volumen** (API_CONTRATO v0.12): `get_builder_candidates` filtra por texto y precio máximo, ordena por precio y pagina, y el selector tiene buscador, orden y "Ver más". Antes solo se veían las 30 piezas compatibles más baratas.
- **Asistente:** `list_compatible_parts` pasa a la base el presupuesto de cada tipo (`budgets`) y el orden, y las instrucciones dan una guía para repartir el presupuesto. Los ids de oferta generados son legibles (`off-tp-<producto>`), porque con ids opacos el modelo inventaba alguno.
- **Pendiente:** cargar el catálogo en la nube (con confirmación) y, si se quiere, imágenes reales por producto.

### Roles y marketplace por tienda (2026-10-27) — hecho en local, pendiente en la nube
- **Decisiones del equipo:**
  - tres roles exclusivos: cliente, tienda y administrador. Solo los clientes compran;
  - las cuentas de tienda las crea un administrador después de verificar que la tienda existe, con una **contraseña temporal aleatoria** que se cambia en el primer ingreso, junto con la aceptación de los documentos vigentes;
  - las tiendas publican **sin aprobación**: validaciones automáticas, control de duplicados y un límite diario;
  - **una tarjeta por tienda** en el catálogo, aunque el producto sea el mismo; la ficha técnica es compartida y cada tienda es dueña de su oferta;
  - descuento = precio anterior, sin fechas de vigencia;
  - el nombre visible de la tienda no es único (dos negocios pueden llamarse igual): el administrador confirma si se parece a otro;
  - el PC Builder y el asistente siguen con la mejor oferta por producto;
  - el historial de pedidos del cliente sigue en la fase 9.
- **Backend:** migraciones `20261027030000` a `20261027050000` (ver `docs/MODELO_DATOS.md`) y la Edge Function `admin-providers` (API_CONTRATO, partes 6 a 8).
- **Flutter:** `features/account` (rol, primer ingreso, pestaña CUENTA), `RoleHome` y los shells por rol, catálogo por oferta con filtro por tienda, `features/provider_portal` (con `image_picker`) y `features/admin`.
- **Pruebas** (todas en local):
  - pgTAP: 369 (las 194 existentes sin cambios y 175 nuevas);
  - `node --test`: 21 de `admin-providers` y las 41 existentes;
  - prueba de migración sobre datos existentes (`backend/supabase/upgrade_check/`): OK en 51 comprobaciones;
  - `flutter test`: 313 (las existentes, con ajustes donde la interfaz cambió, y las nuevas de las cuatro etapas);
  - integración contra Supabase local: 22, incluido el flujo completo administrador → tienda → catálogo;
  - verificaciones de punta a punta con Auth, Storage y la Edge Function reales.
- **Pendiente:**
  - aplicar las migraciones en la nube (`db push --dry-run` y después `db push`) y desplegar `admin-providers`, **con autorización**;
  - antes, confirmar en la nube con una consulta de solo lectura que la clave contra duplicados no choca con los datos;
  - habilitar el primer administrador por SQL (`backend/README.md`);
  - el texto legal sigue siendo el borrador 1.0, el mismo para clientes y tiendas.

### Fase 9: órdenes y seguimiento
- `order_status_history` con transiciones válidas forzadas por trigger (RN-029).
- Flutter: `features/orders` con historial, detalle por sub-orden, transportadora y guía (RF-069), y estado en vivo con Supabase Realtime.
- Notificaciones push con FCM, nivel Should (RF-065), al final de la fase si alcanza el tiempo.

### Fase 10: API de proveedores e integración
- Las validaciones de las publicaciones ya existen (`private.validate_product_input`, `validate_offer_input`, `check_duplicates`, migración `20261027050000`): la API las reutiliza para que la app y la API apliquen las mismas reglas.
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

### Fase 11: operación administrativa
- **Ya hecho con los roles (2026-10-27):** el rol administrador, crear tiendas con su cuenta, habilitar y suspender (que oculta las ofertas) y editar sus datos, desde la app.
- RPCs `security definer` restringidas al rol admin:
  - rechazar solicitudes de proveedores (RF-009), si se vuelve a abrir el registro de tiendas;
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
- porcentaje de comisión por defecto (10 %) y máximo (30 %), S-07 y RN-024 (fase 8). Ya decidido: Wompi como pasarela y comisión sobre el valor sin IVA;
- costo de envío: se asume sin costo adicional para el cliente (fase 8);
- política de fallo de la API y latencia (fase 10);
- jurisdicción: se asume Colombia, Ley 1581 y Ley 1480 (fases 4 y 8);
- si las piezas incluyen periféricos: se asume que no (S-10, fase 2).

## Verificación

- **Por fase:** `dart analyze`, `flutter test` (se mantiene el patrón de `test/support/*`), `supabase db reset && supabase test db` (pgTAP) y `deno test backend/supabase/functions`.
- **End-to-end al cerrar las fases 3, 6, 7 y 8:** `supabase start` → `flutter run --dart-define=SUPABASE_URL=... ` en el emulador Android (`10.0.2.2`).
  - Recorrido: buscar → asistente → PC Builder → carrito → pago en sandbox → orden visible con su sub-orden.
- **Fase 10:** `curl` contra `provider-api` con un lote que mezcla productos válidos, de una categoría fuera del alcance y reenviados con el mismo SKU. Se verifica el rechazo detallado, que no se creen duplicados y que el cambio aparezca en el catálogo.
