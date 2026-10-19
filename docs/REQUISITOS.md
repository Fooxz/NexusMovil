NEXUS – Análisis de requisitos · Versión 2 

# **NEXUS** 

## Análisis de requisitos 

Marketplace móvil de computadores armados y piezas de computador, con asistente inteligente de recomendación 

Versión 2 · 17 de octubre de 2026 · Incorpora el cambio de enfoque del negocio 

**Convenciones. [Inferida]** marca lo que no estaba en la descripción del negocio pero es razonablemente necesario. **[Pendiente]** marca lo que el negocio deja sin definir, con un supuesto provisional cuando fue necesario. **[Nuevo enfoque]** marca lo que se agregó o cambió por la nueva definición: solo computadores armados y piezas, asistente de recomendación como núcleo, y proveedores que publican por API. 

**Prioridad.** Se usa MoSCoW. Equivalencia con la escala anterior: Must = Alta, Should = Media, Could = Baja, Won't = fuera del alcance de esta versión. Los valores numéricos de los requisitos no funcionales son propuestas a validar. 

**Referencias.** Los códigos RN-xx entre paréntesis en las reglas de negocio remiten a las reglas de la primera versión del entendimiento del negocio, para conservar la trazabilidad con ella. 

### **Cambios de enfoque** 

Resumen de lo que cambió respecto al análisis anterior. Todo lo demás del negocio (comisión descontada al proveedor, pagos, órdenes, trazabilidad) se mantiene. 

|**Tema**|**Antes**|**Ahora**|
|---|---|---|
|Catálogo|Productos tecnológicos y electrónicos de distintas<br>categorías, incluidos celulares|Solo computadores armados y piezas de<br>computador|
|Comparador de<br>celulares|Incluido, con orientación de uso|Eliminado del alcance|
|Asistente inteligente|Orientaba hacia productos o configuraciones del<br>catálogo|Núcleo del producto: recomienda al cliente el<br>computador adecuado a sus necesidades (uso,<br>presupuesto, preferencias)|
|PC Builder|Incluido|Se mantiene, porque el nuevo enfoque no indica su<br>eliminación (por confirmar)|
|Carga del catálogo|Portal del proveedor o API|Los proveedores suben sus productos a través de la<br>API y llegan a la aplicación; portal o carga manual<br>solo como contingencia|
|Rol de NEXUS|Intermediario entre clientes y proveedores|Se confirma: NEXUS es intermediario, el proveedor<br>ofrece el producto y atiende el pedido|
|Comisión, pagos y<br>órdenes|La comisión se descuenta al proveedor y no se suma<br>al precio|Sin cambios|



Página 1 

NEXUS – Análisis de requisitos · Versión 2 

### **Análisis previo** 

#### **Procesos de negocio implícitos** 

|**Proceso implícito**|**Justificación**|**Origen**|
|---|---|---|
|Alta de cliente con aceptación de términos y<br>consentimiento de datos|El alcance menciona registro de clientes, pero no el<br>marco legal asociado|Inferida|
|Recuperación de acceso|Necesaria si hay autenticación|Inferida|
|Gestión de direcciones y datos de entrega|El proceso de compra y el de gestión de orden<br>requieren entrega|Inferida|
|Gestión de las dos familias del catálogo<br>(computadores armados y piezas) con categorías y<br>plantillas de atributos técnicos|Se necesitan atributos estructurados por función; el<br>nuevo alcance limita el catálogo a estas dos familias|Implícita**[Nuevo**<br>**enfoque]**|
|Administración y versionado de reglas de<br>compatibilidad|Las reglas de compatibilidad las define NEXUS|Implícita|
|Onboarding técnico del proveedor: credenciales,<br>pruebas y puesta en producción de la API|Los proveedores suben sus productos a través de la<br>API|Inferida**[Nuevo**<br>**enfoque]**|
|Recepción, validación y normalización de los<br>productos recibidos por API|El catálogo y el asistente dependen de datos<br>estructurados y confiables|Inferida**[Nuevo**<br>**enfoque]**|
|Tratamiento de fallas de integración con APIs|Los errores deben registrarse, pero no se define qué<br>hacer|Pendiente|
|Descuento de stock tras la venta y control de<br>sobreventa|La disponibilidad debe corresponder al inventario del<br>proveedor|Inferida|
|Pago rechazado, pendiente o abandonado|El proceso de compra solo describe el caso feliz|Inferida|
|Proveedor que no puede cumplir una orden ya<br>pagada (rechazo, reembolso)|El proveedor confirma disponibilidad después de la<br>venta|Inferida|
|Cancelación, devolución, retracto, garantía y<br>reembolso|Decisiones pendientes de definición del negocio|Pendiente|
|Conciliación de pagos y liquidación periódica a<br>proveedores|La liquidación al proveedor depende del esquema de<br>pagos|Implícita|
|Notificaciones transaccionales (push/correo)|NEXUS notifica al proveedor; el cliente necesita lo<br>mismo|Inferida|
|Atención al cliente y reclamos|Todo marketplace lo requiere|Inferida|
|Control de calidad y moderación del catálogo|El proveedor es responsable de la información, pero<br>NEXUS la publica|Inferida|
|Gestión de datos personales y de las<br>conversaciones con el asistente|Se manejan datos de clientes, pagos y necesidades<br>expresadas|Inferida|



#### **Entidades de negocio** 

|**Entidad**|**Origen**|**Observación**|
|---|---|---|
|Usuario, Proveedor, Producto, Oferta, Inventario,|Negocio|Núcleo del modelo. La entidad «Comparación» deja|
|Comisión, Orden, Pago, Configuración PC, Integración||i<br>de existir|
|Familia de producto: Computador armado y Pieza (con<br>i|Inferida**[Nuevo**|Las dos familias que componen el catálogo|
|tipo de pieza)|**enfoque]**||
|Categoría y Plantilla de atributos técnicos|Inferida|Soporta los datos estructurados|



Página 2 

NEXUS – Análisis de requisitos · Versión 2 

|**Entidad**|**Origen**|**Observación**|
|---|---|---|
|Atributo técnico (nombre, tipo, unidad)|Inferida|Base de búsqueda, recomendación y<br>compatibilidad|
|Identificador externo del proveedor (SKU) y mapeo al<br>catálogo|Inferida**[Nuevo**<br>**enfoque]**|Evita duplicados al recibir productos por API|
|Credencial de API y Registro de integración|Inferida**[Nuevo**<br>**enfoque]**|Acceso del proveedor y trazabilidad de operaciones|
|Regla de compatibilidad (versionada)|Inferida|Soporta el PC Builder|
|Carrito e ítem de carrito|Inferida|Proceso de compra|
|Ítem de orden / sub-orden por proveedor|Inferida|Órdenes con varios proveedores|
|Dirección de entrega|Inferida|Gestión de orden|
|Envío/Entrega (transportadora, guía, estado)|Inferida|Logística pendiente|
|Liquidación (periodo, órdenes, neto)|Inferida|Cálculo y liquidación de comisión|
|Notificación|Inferida|Cliente y proveedor|
|Interacción del asistente y Perfil de necesidades (uso,<br>presupuesto, preferencias)|Inferida**[Nuevo**<br>**enfoque]**|Trazabilidad de recomendaciones|
|Devolución/Reclamación/Reembolso|Inferida|Decisiones pendientes|
|Bitácora de auditoría|Negocio|Detallada por inferencia|
|Rol y Permiso|Inferida|Clientes, proveedores y administradores|
|Promoción/Descuento|Pendiente|Fuera de esta versión|



#### **Eventos, validaciones y restricciones** 

**Eventos clave:** solicitud de registro de proveedor, proveedor aprobado/rechazado/suspendido, credenciales de API emitidas, producto recibido por API (aceptado o rechazado), producto publicado/pausado/retirado, stock actualizado, integración exitosa/fallida, precio modificado, recomendación del asistente emitida, carrito modificado, compra confirmada, pago aprobado/rechazado/pendiente, orden creada, orden confirmada o rechazada por el proveedor, orden despachada/entregada/cancelada, comisión calculada, liquidación generada/ejecutada, configuración PC validada. 

###### **Validaciones:** 

- Esquema de la API, datos mínimos y atributos obligatorios por categoría antes de publicar. 

- Categoría permitida: solo computadores armados y piezas de computador. 

- Precio mayor que cero y stock no negativo. 

- Porcentaje de comisión dentro del rango permitido. 

- Unicidad del identificador de acceso y del identificador externo del producto por proveedor. 

- Disponibilidad y vigencia de precio antes del pago. 

- Cantidad en carrito menor o igual al stock. 

- Compatibilidad y componentes obligatorios en el PC Builder. 

- Que los productos recomendados por el asistente existan, estén publicados y disponibles. 

- Respuesta de la pasarela antes de generar la orden. 

###### **Restricciones del negocio:** 

- El precio lo fija el proveedor, y la comisión no se suma al precio. 

Página 3 

NEXUS – Análisis de requisitos · Versión 2 

- NEXUS es intermediario: no es el vendedor ni mantiene inventario propio. 

- Los productos llegan a NEXUS por la API del proveedor. 

- La compatibilidad no puede depender solo de IA generativa. 

- El asistente no inventa características ni disponibilidad. 

- Las descripciones y recomendaciones se basan en atributos reales almacenados. 

- La decisión final de compra es del cliente. 

- El catálogo se limita a computadores armados y piezas; no hay celulares ni comparador de celulares. 

- El canal es una aplicación móvil. 

#### **Flujos principales y alternativos** 

|**Flujo**|**Principal**|**Alternativos / excepciones**|
|---|---|---|
|Registro de proveedor|Solicita, envía datos, NEXUS valida, se configuran<br>acceso y comisión|Datos incompletos (corrección), rechazo,<br>suspensión posterior|
|Publicación y<br>sincronización por API<br>**[Nuevo enfoque]**|El proveedor envía (o NEXUS consulta) productos,<br>precios, atributos y stock por API; NEXUS valida,<br>normaliza y publica|Credenciales inválidas, producto fuera de categorías<br>permitidas, datos incompletos (rechazo con detalle),<br>reenvío duplicado, API caída, producto retirado|
|Búsqueda|Texto, filtros por tipo de producto y atributos,<br>detalle|Sin resultados, producto agotado, oferta pausada|
|Asistente**[Nuevo**<br>**enfoque]**|El cliente describe su necesidad, el asistente<br>pregunta si falta información, consulta el catálogo y<br>recomienda computadores armados con explicación|Información insuficiente (repregunta), ningún<br>armado cumple (propone configuración de piezas o<br>lo informa), presupuesto inviable, producto que<br>dejó de estar disponible (se revalida), falla del<br>servicio de IA|
|PC Builder|Selección de piezas, validación, descripción, carrito|Incompatibilidad (explicación y alternativas),<br>faltantes, pieza sin stock, reglas no definidas|
|Compra|Carrito, verificación de disponibilidad, datos, pago,<br>orden, notificación al proveedor|Stock agotado en checkout, cambio de precio, pago<br>rechazado o pendiente, abandono, orden con varios<br>proveedores|
|Gestión de orden|El proveedor confirma, prepara y despacha (por API<br>o portal); NEXUS actualiza el estado|Proveedor rechaza o no responde, cancelación,<br>devolución, reembolso|
|Comisión y liquidación|Se identifica la comisión, se calcula el neto, se<br>registra y se liquida|Conflicto de comisiones, ajuste por devolución,<br>diferencia en la conciliación|



#### **Funcionalidades faltantes propuestas** 

###### Todas son **[Inferida]** . 

|**Funcionalidad**|**Justificación**|**MoSCoW**|
|---|---|---|
|Recuperación de credenciales|Sin ella el acceso queda bloqueado|Must|
|Gestión de perfil y direcciones|Requisito de entrega|Must|
|Aceptación de términos y consentimiento de datos|Cumplimiento normativo|Must|
|Manejo de pago rechazado, pendiente o abandonado|Evita órdenes inconsistentes|Must|
|Descuento de inventario tras la venta|Evita sobreventa entre sincronizaciones|Must|
|Validación y normalización de los productos recibidos<br>por API, rechazando categorías fuera del alcance**[Nuevo**<br>**enfoque]**|El catálogo debe ser confiable para el asistente|Must|



Página 4 

NEXUS – Análisis de requisitos · Versión 2 

|**Funcionalidad**|**Justificación**|**MoSCoW**|
|---|---|---|
|Credenciales de API por proveedor, documentación y<br>entorno de pruebas (sandbox)**[Nuevo enfoque]**|Sin ellos los proveedores no pueden integrarse|Must / Should|
|Imágenes de producto|Un catálogo sin imágenes no es utilizable|Must|
|Propuesta de configuración de piezas por el asistente<br>cuando ningún armado sirve**[Nuevo enfoque]**|Conecta el asistente con el PC Builder|Should|
|Notificaciones transaccionales|Seguimiento de órdenes|Should|
|Cancelación, devolución y reembolso|Obligaciones de comercio electrónico|Should|
|Conciliación de pagos|Control financiero|Should|
|Portal o carga manual/masiva de catálogo como<br>contingencia|Respaldo para proveedores cuya API falle o aún no<br>exista|Could|
|Moderación del catálogo|Calidad de datos|Could|
|Reserva temporal de stock durante el checkout|Reduce conflictos de stock|Could|
|Guardar configuraciones, favoritos y reseñas|Retención de clientes|Could|
|Reportes y tableros|Operación del negocio|Could|
|Integración con operador logístico|Actor potencial|Could|



### **Resumen de la solución** 

NEXUS es una aplicación móvil de comercio electrónico tipo marketplace especializada en computadores armados y piezas de computador. Actúa como intermediario entre clientes y proveedores: los proveedores publican sus productos, precios e inventario a través de la API de integración y estos llegan a la aplicación. NEXUS gestiona la compra, las órdenes y el cálculo de su comisión, que se descuenta del valor que corresponde al proveedor y no se suma al precio del cliente. 

Su diferencial es un asistente inteligente que, a partir de las necesidades del cliente (uso, presupuesto, preferencias), le recomienda el computador adecuado del catálogo. Lo complementan un PC Builder con validación de compatibilidad por reglas técnicas y descripciones funcionales de los equipos. Todo depende de la calidad y actualización de los datos que llegan por API, por lo que la integración con proveedores es crítica. 

### **Actores identificados** 

|**Actor**|**Descripción**|
|---|---|
|Cliente|Consulta el catálogo, recibe recomendaciones, configura, compra y hace seguimiento de sus<br>órdenes|
|Proveedor|Empresa o comerciante que envía sus computadores armados y piezas por API, mantiene<br>precios e inventario y atiende las órdenes|
|Administrador NEXUS|Opera la plataforma: proveedores, catálogo, comisiones, órdenes, integraciones y reglas|
|Pasarela/servicio de pagos|Sistema externo que procesa pagos y reporta resultados|
|API/servicio de integración del<br>proveedor|Canal principal por el que el proveedor envía productos, precios, atributos y stock, y recibe<br>órdenes|
|Servicio de logística|Actor externo potencial para recolección y entrega|
|Servicio de IA generativa**[Inferida]**|Proveedor del modelo que soporta al asistente y las descripciones|
|Servicio de notificaciones**[Inferida]**|Canal de envío de mensajes push y correo|



Página 5 

NEXUS – Análisis de requisitos · Versión 2 

|**Actor**|**Descripción**|
|---|---|
|Motor de reglas de NEXUS (actor de<br>sistema)|Valida compatibilidad y resuelve la comisión aplicable|



### **Historias de usuario** 

##### HU-001 – Registro de cliente 

**Como** cliente · **Quiero** crear una cuenta aceptando los términos y la política de datos · **Para** poder comprar y recibir recomendaciones personalizadas 

###### **Criterios de aceptación** 

- Dado que no tengo cuenta, cuando envío mis datos válidos y acepto los términos, entonces se crea mi cuenta y puedo iniciar sesión. 

- Dado que el identificador ya existe, cuando intento registrarme, entonces el sistema lo rechaza con un mensaje claro. 

- Dado que no acepto los términos, cuando intento registrarme, entonces no se crea la cuenta. 

**Prioridad:** Must (Alta) 

HU-002 – Inicio de sesión y recuperación de acceso 

**Como** cliente · **Quiero** autenticarme y recuperar mi acceso si lo pierdo **[Inferida]** (recuperación) · **Para** acceder de forma segura a mis compras 

###### **Criterios de aceptación** 

- Dado que tengo cuenta activa, cuando ingreso credenciales correctas, entonces accedo a mi sesión. 

- Dado que olvidé mis credenciales, cuando solicito recuperarlas, entonces recibo un mecanismo seguro de restablecimiento. 

- Dado que no estoy autenticado, cuando intento comprar, entonces el sistema me solicita autenticarme. 

**Prioridad:** Must (Alta) 

HU-003 – Gestión de perfil y direcciones de entrega **[Inferida]** 

**Como** cliente · **Quiero** administrar mis datos y direcciones · **Para** agilizar mis compras 

###### **Criterios de aceptación** 

- Dado que estoy autenticado, cuando agrego o edito una dirección válida, entonces queda disponible en el checkout. 

- Dado que una dirección es inválida o incompleta, cuando intento guardarla, entonces se muestran los campos a corregir. 

**Prioridad:** Must (Alta) 

HU-004 – Búsqueda y filtrado de computadores y piezas 

**Como** cliente · **Quiero** buscar y filtrar el catálogo por texto, tipo (computador armado o pieza), tipo de pieza, marca, precio y atributos técnicos · **Para** encontrar productos que se ajusten a lo que necesito 

###### **Criterios de aceptación** 

- Dado que existen productos publicados, cuando busco un término, entonces veo los productos coincidentes con precio y disponibilidad vigentes. 

- Dado que aplico filtros, cuando confirmo, entonces solo se listan productos que cumplen todos los criterios. 

Página 6 

NEXUS – Análisis de requisitos · Versión 2 

- Dado que busco piezas, cuando filtro por tipo de pieza (por ejemplo, procesador o memoria), entonces solo veo piezas de ese tipo. 

- Dado que no hay coincidencias, cuando termina la búsqueda, entonces se muestra un mensaje de sin resultados con sugerencias. 

###### **Prioridad:** Must (Alta) 

##### HU-005 – Consulta de detalle de producto 

**Como** cliente · **Quiero** ver especificaciones, precio, disponibilidad y proveedor de un producto · **Para** decidir con información suficiente 

###### **Criterios de aceptación** 

- Dado que selecciono un producto, cuando abro su detalle, entonces veo sus atributos técnicos, precio y estado de disponibilidad. 

- Dado que hay varias ofertas del mismo producto, cuando consulto el detalle, entonces veo cada oferta con su proveedor y precio. 

- Dado que el producto está agotado, cuando abro el detalle, entonces se indica y no se permite agregarlo al carrito. 

**Prioridad:** Must (Alta) 

HU-006 – Recomendación de un computador adecuado con el asistente **[Nuevo enfoque]** 

**Como** cliente · **Quiero** describir en lenguaje natural para qué necesito el computador (uso, presupuesto, preferencias, nivel técnico) · **Para** recibir recomendaciones de computadores adecuados del catálogo, con explicación 

###### **Criterios de aceptación** 

- Dado que describo mi necesidad, cuando el asistente la interpreta, entonces recomienda uno o más computadores armados del catálogo con una justificación basada en atributos reales (procesador, memoria, almacenamiento, gráficos, etc.). 

- Dado que falta información relevante (por ejemplo, presupuesto o tipo de uso), cuando el asistente no puede recomendar con criterio, entonces me hace preguntas de aclaración en lugar de suponer. 

- Dado que ningún computador armado cumple mi necesidad o presupuesto, cuando el asistente lo detecta, entonces me lo informa y, si es posible, propone una configuración de piezas validada por el motor de compatibilidad **[Inferida]** . 

- Dado que recibo una recomendación, cuando la reviso, entonces veo precio, disponibilidad y proveedor vigentes, y puedo abrir el producto, llevarlo al carrito o ajustarlo en el PC Builder, sin que se ejecute ninguna compra automática. 

- Dado que el servicio de IA no está disponible, cuando uso el asistente, entonces el catálogo y la compra siguen operando y se muestra un mensaje de indisponibilidad. 

**Prioridad:** Must (Alta). El asistente sube de Should a Must porque es el diferenciador central del nuevo enfoque. Ver supuesto S-16 y riesgo R-06. 

##### HU-007 – Descripción funcional de un computador 

**Como** cliente · **Quiero** una explicación de los usos posibles de un computador armado o de mi configuración · **Para** saber si responde a mi necesidad 

###### **Criterios de aceptación** 

- Dado que consulto un computador armado o una configuración válida, cuando solicito la descripción, entonces se generan usos posibles basados en atributos reales de sus componentes. 

- Dado que la configuración es inválida, cuando solicito la descripción, entonces no se genera y se informa el motivo. 

Página 7 

NEXUS – Análisis de requisitos · Versión 2 

###### **Prioridad:** Should (Media) 

##### HU-008 – Armar un PC con piezas y validar su compatibilidad 

**Como** cliente · **Quiero** seleccionar piezas y que el sistema valide si son compatibles · **Para** comprar una configuración funcional sin conocimientos técnicos 

###### **Criterios de aceptación** 

- Dado que selecciono piezas, cuando el motor de reglas las evalúa, entonces se muestra el resultado de compatibilidad. 

- Dado que hay una incompatibilidad, cuando se detecta, entonces se indica cuáles piezas la causan y por qué. 

- Dado que faltan piezas obligatorias, cuando valido, entonces se informa cuáles faltan. 

- Dado que una pieza seleccionada no tiene stock, cuando valido, entonces se me informa y se sugieren alternativas compatibles. 

- Dado que la configuración es válida, cuando la acepto, entonces puedo agregar todas sus piezas al carrito con el precio total. 

###### **Prioridad:** Must (Alta) 

##### HU-009 – Gestión del carrito 

**Como** cliente · **Quiero** agregar, modificar y quitar productos del carrito · **Para** preparar mi compra 

###### **Criterios de aceptación** 

- Dado un producto disponible, cuando lo agrego, entonces aparece en el carrito con cantidad, precio y subtotal. 

- Dado que la cantidad excede el stock, cuando intento aumentarla, entonces el sistema lo impide y muestra el máximo disponible. 

- Dado que cierro la aplicación, cuando regreso autenticado, entonces mi carrito se conserva **[Inferida]** . 

**Prioridad:** Must (Alta) 

##### HU-010 – Confirmación de compra y pago 

**Como** cliente · **Quiero** confirmar mi compra y pagar · **Para** recibir los productos 

###### **Criterios de aceptación** 

- Dado que inicio el checkout, cuando el sistema verifica disponibilidad y precio vigente, entonces solo avanzo si todo es válido. 

- Dado que el pago es aprobado, cuando la pasarela confirma, entonces se genera la orden y se descuenta el inventario. 

- Dado que el pago es rechazado, cuando la pasarela responde, entonces no se genera la orden, se informa el motivo y puedo reintentar **[Inferida]** . 

- Dado que el pago queda pendiente, cuando no hay confirmación inmediata, entonces la orden permanece en un estado de espera hasta recibir el resultado **[Inferida]** . 

###### **Prioridad:** Must (Alta) 

##### HU-011 – Seguimiento de órdenes 

**Como** cliente · **Quiero** consultar el estado de mis órdenes y recibir avisos de cambios · **Para** saber cuándo llegará mi pedido 

###### **Criterios de aceptación** 

- Dado que tengo órdenes, cuando abro mi historial, entonces veo cada orden con productos, valores y estado. 

- Dado que cambia el estado de una orden, cuando se actualiza, entonces recibo una notificación **[Inferida]** . 

- Dado que hay datos de envío, cuando consulto la orden, entonces veo transportadora y guía si existen. 

Página 8 

NEXUS – Análisis de requisitos · Versión 2 

**Prioridad:** Must (Alta). Las notificaciones y la integración logística son Should/Could. 

##### HU-012 – Compra con productos de varios proveedores **[Pendiente]** 

**Como** cliente · **Quiero** comprar productos de distintos proveedores en un solo pago · **Para** completar mi compra en un único proceso 

###### **Criterios de aceptación** 

- Dado un carrito con productos de varios proveedores, cuando confirmo y pago, entonces se generan subórdenes por proveedor (S-06). 

- Dado que cada sub-orden tiene su propio avance, cuando consulto, entonces veo el estado de cada una por separado. 

- Dado que un proveedor rechaza su parte, cuando ocurre, entonces solo se gestiona esa sub-orden y se ajusta el reembolso correspondiente. 

**Prioridad:** Must (Alta). Bloquea el diseño de órdenes, pagos y liquidación. Es muy probable en este negocio, porque un cliente que arma su PC con piezas compra a varios proveedores. 

HU-013 – Cancelación, devolución y reembolso **[Inferida] [Pendiente]** 

**Como** cliente · **Quiero** solicitar la cancelación o devolución de una compra · **Para** ejercer mis derechos como consumidor 

###### **Criterios de aceptación** 

- Dado que mi orden cumple las condiciones de la política vigente, cuando solicito cancelar o devolver, entonces se registra la solicitud y su estado. 

- Dado que se aprueba el reembolso, cuando se procesa, entonces se ajustan la comisión y la liquidación del proveedor. 

**Prioridad:** Should (Media). El alcance depende de decisiones legales pendientes. 

HU-014 – Favoritos, configuraciones guardadas y reseñas **[Inferida]** 

**Como** cliente · **Quiero** guardar productos y configuraciones y opinar sobre lo comprado · **Para** retomar mi decisión y ayudar a otros 

###### **Criterios de aceptación** 

- Dado que estoy autenticado, cuando guardo un producto o configuración, entonces puedo recuperarlo después. 

- Dado que compré un producto, cuando lo califico, entonces la reseña queda asociada a ese producto. 

**Prioridad:** Could (Baja) 

##### HU-015 – Solicitud de registro como proveedor 

**Como** proveedor · **Quiero** solicitar mi incorporación a NEXUS con mis datos comerciales · **Para** vender mis productos 

###### **Criterios de aceptación** 

- Dado que envío datos completos, cuando registro la solicitud, entonces queda en estado «pendiente de validación». 

- Dado que faltan datos obligatorios, cuando intento enviar, entonces se indican los campos faltantes. 

- Dado que no estoy aprobado, cuando intento publicar productos, entonces el sistema lo impide. 

**Prioridad:** Must (Alta) 

##### HU-016 – Publicación y actualización de productos por API **[Nuevo enfoque]** 

**Como** proveedor · **Quiero** enviar mis computadores armados y piezas, con precios y atributos, a través de la API · **Para** que lleguen automáticamente a la aplicación sin cargarlos uno a uno 

Página 9 

NEXUS – Análisis de requisitos · Versión 2 

###### **Criterios de aceptación** 

- Dado que mi integración está activa, cuando envío un producto válido, entonces se publica en el catálogo con su precio, atributos y stock. 

- Dado que el producto no cumple el esquema, no trae los atributos obligatorios o pertenece a una categoría fuera del alcance, cuando lo envío, entonces NEXUS lo rechaza y me devuelve el detalle de los errores. 

- Dado que reenvío un producto con el mismo identificador, cuando se procesa, entonces se actualiza sin crear duplicados. 

- Dado que cambio un precio, o pauso o retiro un producto por API, cuando NEXUS lo procesa, entonces el cambio rige para nuevas compras y queda registrado. 

###### **Prioridad:** Must (Alta) 

HU-017 – Configuración de la integración por API 

**Como** proveedor · **Quiero** obtener mis credenciales, probar mi conexión y activarla · **Para** mantener mi catálogo e inventario sincronizados automáticamente 

###### **Criterios de aceptación** 

- Dado que solicito acceso, cuando NEXUS aprueba mi integración, entonces recibo credenciales y documentación de la API, y puedo probar en un entorno de pruebas. 

- Dado que la sincronización corre, cuando finaliza, entonces se registra fecha, resultado y errores. 

- Dado que mis credenciales se guardan, cuando alguien consulta la configuración, entonces no se muestran en claro. 

###### **Prioridad:** Must (Alta) 

##### HU-018 – Gestión de inventario 

**Como** proveedor · **Quiero** mantener mi stock actualizado por API, y manualmente si mi API no está disponible **[Inferida]** · **Para** evitar vender productos que no tengo 

###### **Criterios de aceptación** 

- Dado que actualizo stock, cuando se procesa el cambio, entonces la disponibilidad mostrada cambia y queda registrada con fecha y hora. 

- Dado que el stock llega a cero, cuando se actualiza, entonces el producto se muestra como agotado y no es comprable. 

- Dado que mi API falla, cuando se aplica la política definida, entonces el inventario se marca como desactualizado **[Pendiente]** . 

###### **Prioridad:** Must (Alta) 

HU-019 – Gestión de catálogo por portal o carga masiva (contingencia) **[Inferida]** 

**Como** proveedor · **Quiero** cargar o editar mi catálogo desde un portal o con un archivo si mi API falla o aún no existe · **Para** no quedar fuera del marketplace 

###### **Criterios de aceptación** 

- Dado un archivo con el formato definido, cuando lo cargo, entonces se crean o actualizan los productos válidos. 

• Dado que hay filas con errores, cuando termina la carga, entonces recibo un reporte de rechazos por fila. **Prioridad:** Could (Baja). El nuevo enfoque define la API como vía principal; esta alternativa se mantiene como respaldo y se baja de prioridad. 

HU-020 – Recepción y gestión de órdenes (por API o portal) 

**Como** proveedor · **Quiero** recibir las órdenes, confirmarlas o rechazarlas y actualizar su estado · **Para** cumplir con la entrega 

Página 10 

NEXUS – Análisis de requisitos · Versión 2 

###### **Criterios de aceptación** 

- Dado que se genera una orden con mis productos, cuando se crea, entonces recibo una notificación con su detalle por API o en el portal. 

- Dado que confirmo la orden, cuando la despacho, entonces registro el estado y los datos de envío. 

- Dado que no puedo cumplir, cuando rechazo la orden, entonces indico la causa y se activa el reembolso o la gestión definida. 

**Prioridad:** Must (Alta) 

HU-021 – Consulta de ventas, comisiones y liquidaciones 

**Como** proveedor · **Quiero** ver mis ventas, la comisión retenida y lo que me corresponde · **Para** verificar mis ingresos 

###### **Criterios de aceptación** 

   - Dado que tengo ventas, cuando consulto, entonces veo por venta el valor, el porcentaje de comisión y el neto. 

- Dado que existe una liquidación, cuando la consulto, entonces veo las órdenes incluidas y su estado. 

- **Prioridad:** Should (Media) 

##### HU-022 – Evaluación y aprobación de proveedores 

**Como** administrador · **Quiero** revisar solicitudes y aprobar, rechazar o pedir correcciones · **Para** garantizar la calidad de quienes venden 

###### **Criterios de aceptación** 

- Dado que hay una solicitud pendiente, cuando la reviso, entonces puedo aprobarla, rechazarla o devolverla con un motivo. 

- Dado que apruebo a un proveedor, cuando confirmo, entonces defino sus condiciones comerciales y su comisión. 

- Dado que suspendo a un proveedor, cuando confirmo, entonces sus ofertas dejan de mostrarse **[Inferida]** . 

**Prioridad:** Must (Alta) 

##### HU-023 – Configuración de comisiones 

**Como** administrador · **Quiero** definir comisiones por proveedor y por producto con vigencia · **Para** aplicar las condiciones comerciales acordadas 

###### **Criterios de aceptación** 

- Dado que defino una comisión general y otra específica, cuando se calcula una venta, entonces se aplica la regla de prioridad definida (S-05). 

- Dado que ingreso un porcentaje fuera del rango permitido, cuando intento guardar, entonces se rechaza. 

- Dado que modifico una comisión, cuando guardo, entonces no cambian las órdenes ya generadas y el cambio queda en la bitácora. 

###### **Prioridad:** Must (Alta) 

##### HU-024 – Administración de categorías y atributos técnicos 

**Como** administrador · **Quiero** definir las familias del catálogo (computador armado y piezas por tipo) y sus plantillas de atributos técnicos · **Para** asegurar datos utilizables por la búsqueda, el asistente y el PC Builder 

###### **Criterios de aceptación** 

- Dado que creo una categoría, cuando defino sus atributos con tipo, unidad y obligatoriedad, entonces los proveedores deben cumplirlos al enviar productos por API. 

- Dado que agrego un nuevo tipo de pieza, cuando lo activo, entonces no requiere cambios de código. 

Página 11 

NEXUS – Análisis de requisitos · Versión 2 

- Dado que un proveedor envía un producto de una categoría no definida, cuando se procesa, entonces es rechazado. 

**Prioridad:** Must (Alta) 

HU-025 – Administración de reglas de compatibilidad de PC 

**Como** administrador · **Quiero** crear, modificar y activar reglas de compatibilidad con control de versiones · **Para** que el PC Builder valide de forma confiable 

###### **Criterios de aceptación** 

   - Dado que defino una regla, cuando la activo, entonces el PC Builder la aplica en nuevas validaciones. 

- Dado que modifico una regla, cuando guardo, entonces queda versionada y registrada con quién y cuándo. 

- **Prioridad:** Must (Alta) 

##### HU-026 – Cálculo y registro de comisión por venta 

**Como** administrador · **Quiero** que el sistema calcule y conserve la comisión de cada venta · **Para** liquidar correctamente y tener trazabilidad 

###### **Criterios de aceptación** 

- Dado que se confirma una venta, cuando se genera la orden, entonces se calcula la comisión y el neto del proveedor sin alterar el precio del cliente. 

- Dado que se registra el cálculo, cuando lo consulto, entonces veo base, porcentaje aplicado, comisión y neto. 

- Dado que cambia la comisión después, cuando consulto una orden anterior, entonces conserva los valores originales. 

**Prioridad:** Must (Alta) 

##### HU-027 – Liquidación a proveedores 

**Como** administrador · **Quiero** generar y registrar liquidaciones a proveedores · **Para** pagarles lo que les corresponde 

###### **Criterios de aceptación** 

   - Dado un periodo, cuando genero la liquidación, entonces incluye solo ventas confirmadas y no reembolsadas. 

   - Dado que hay devoluciones, cuando liquido, entonces se aplican los ajustes de comisión y neto **[Inferida]** . 

- Dado que existen diferencias con la pasarela, cuando concilio, entonces se señalan para revisión **[Inferida]** . 

- **Prioridad:** Must (Alta). El momento de liberación del dinero está **[Pendiente]** . 

##### HU-028 – Supervisión de órdenes y pagos 

**Como** administrador · **Quiero** consultar y filtrar órdenes, pagos y su estado · **Para** detectar y resolver problemas operativos 

###### **Criterios de aceptación** 

- Dado que hay órdenes, cuando filtro por estado, proveedor o fecha, entonces veo el listado y el detalle de pago y comisión. 

- Dado que una orden está estancada, cuando la identifico, entonces puedo ver su historial de estados. 

**Prioridad:** Must (Alta) 

##### HU-029 – Monitoreo de integraciones 

**Como** administrador · **Quiero** ver el estado de las integraciones, los errores y los productos rechazados por proveedor · **Para** asegurar que el catálogo sea confiable 

Página 12 

NEXUS – Análisis de requisitos · Versión 2 

###### **Criterios de aceptación** 

- Dado que hay integraciones activas, cuando consulto, entonces veo última sincronización, estado, errores y productos rechazados por proveedor. 

- Dado que ocurren fallos repetidos, cuando se supera el umbral definido, entonces se notifica al administrador y se marca el inventario como desactualizado **[Inferida]** . 

**Prioridad:** Must (Alta) 

##### HU-030 – Gestión de usuarios y roles 

**Como** administrador · **Quiero** administrar cuentas y permisos · **Para** controlar el acceso a la plataforma 

###### **Criterios de aceptación** 

- Dado que existe un usuario, cuando lo suspendo, entonces no puede iniciar sesión. 

- Dado que un rol no tiene permiso, cuando intenta una función restringida, entonces el sistema la deniega. 

**Prioridad:** Should (Media). El control de acceso por rol es Must (RF-005). 

##### HU-031 – Consulta de auditoría 

**Como** administrador · **Quiero** consultar el historial de cambios relevantes · **Para** investigar incidentes y cumplir con trazabilidad 

###### **Criterios de aceptación** 

- Dado un cambio de precio, stock, comisión, regla, orden o pago, cuando ocurre, entonces se registra el actor, la fecha y los valores anterior y nuevo. 

- Dado que consulto la bitácora, cuando filtro por entidad o fecha, entonces veo los eventos correspondientes. 

**Prioridad:** Must (Alta) 

##### HU-032 – Reportes operativos **[Inferida]** 

**Como** administrador · **Quiero** ver reportes de ventas, comisiones e integraciones · **Para** tomar decisiones de negocio 

###### **Criterios de aceptación** 

- Dado un periodo, cuando genero un reporte, entonces obtengo ventas, comisiones y órdenes por proveedor. 

**Prioridad:** Could (Baja) 

##### HU-033 – Moderación del catálogo **[Inferida]** 

**Como** administrador · **Quiero** revisar o retirar productos con información deficiente · **Para** mantener la calidad del catálogo 

###### **Criterios de aceptación** 

- Dado un producto reportado o con datos dudosos, cuando lo despublico, entonces deja de mostrarse y el proveedor es notificado con el motivo. 

**Prioridad:** Could (Baja) 

### **Requerimientos funcionales** 

|**ID**|**Requerimiento**|**MoSCoW**|
|---|---|---|
|**Cuentas, a**|**cceso y cumplimiento**||
|RF-001|Permitir el registro de clientes y validar la unicidad del identificador de acceso|Must|
|RF-002|Validar la identidad del usuario mediante autenticación antes de acciones transaccionales|Must|
|RF-003|Permitir el restablecimiento de credenciales**[Inferida]**|Must|



Página 13 

NEXUS – Análisis de requisitos · Versión 2 

|**ID**|**Requerimiento**|**MoSCoW**|
|---|---|---|
|RF-004|Permitir consultar y actualizar el perfil y gestionar direcciones de entrega**[Inferida]**|Must|
|RF-005|Validar los permisos por rol (cliente, proveedor, administrador) en cada función|Must|
|RF-006|Permitir al administrador crear, suspender y reactivar usuarios|Should|
|RF-007|Registrar la aceptación de términos y el consentimiento de tratamiento de datos**[Inferida]**|Must|
|**Proveedor**|**es**<br>i         ii||
|RF-008|Permitir al proveedor solicitar su registro con datos de identificación y comerciales|Must|
|RF-009|Permitir al administrador aprobar, rechazar o devolver solicitudes registrando el motivo|Must|
|RF-010|Permitir configurar las condiciones comerciales y la comisión inicial del proveedor al aprobarlo|Must|
|RF-011|Permitir suspender y reactivar proveedores, ocultando sus ofertas mientras estén suspendidos<br>**[Inferida]**|Should|
|**Catálogo d**|**e computadores armados y piezas**<br>i   i||
|RF-012|Permitir al administrador gestionar las familias y categorías del catálogo (computador armado y<br>tipos de pieza)**[Nuevo enfoque]**|Must|
|RF-013|Permitir definir por categoría una plantilla de atributos técnicos (tipo, unidad, obligatoriedad)|Must|
|RF-014|Permitir múltiples ofertas de distintos proveedores para un mismo producto (S-08)|Must|
|RF-015|Ocultar automáticamente ofertas pausadas, sin stock o de proveedores suspendidos|Must|
|RF-016|Permitir asociar imágenes a los productos, también por API**[Inferida]**|Must|
|RF-017|Permitir al administrador revisar y despublicar productos**[Inferida]**|Could|
|**Integració**|**n y publicación por API [Nuevo enfoque]**||
|RF-018|Emitir y gestionar credenciales de API por proveedor, con rotación y revocación**[Inferida]**|Must|
|RF-019|Proveer documentación versionada de la API y un entorno de pruebas (sandbox) para los<br>proveedores**[Inferida]**|Should|
|RF-020|Permitir configurar por proveedor la integración (endpoint, credenciales, modo de intercambio,<br>frecuencia) protegiendo las credenciales|Must|
|RF-021|Recibir mediante la API la creación, actualización, pausa y retiro de computadores armados y<br>piezas, con sus precios, atributos, imágenes y stock|Must|
|RF-022|Validar cada producto recibido (esquema, datos mínimos, atributos obligatorios, categoría<br>permitida, precio y stock válidos) y rechazar los inválidos devolviendo el detalle de los errores|Must|
|RF-023|Identificar los productos por su identificador externo del proveedor para evitar duplicados y<br>permitir reenvíos idempotentes**[Inferida]**|Must|
|RF-024|Normalizar y asociar cada producto recibido a la categoría y la plantilla de atributos de NEXUS<br>**[Inferida]**|Must|
|RF-025|Registrar cada operación de integración con fecha, resultado, registros afectados y errores|Must|
|RF-026|Permitir al administrador consultar el registro de integraciones y los productos rechazados por<br>proveedor|Must|
|RF-027|Notificar fallos de integración y marcar el inventario como desactualizado**[Inferida]**|Must|
|RF-028|Aplicar la política definida cuando la API del proveedor no esté disponible**[Pendiente]**|Must|
|RF-029|Permitir la actualización manual de inventario como contingencia**[Inferida]**|Should|
|RF-030|Permitir al proveedor crear, consultar, actualizar y pausar sus productos desde un portal, como<br>contingencia**[Inferida]**|Could|



Página 14 

NEXUS – Análisis de requisitos · Versión 2 

|**ID**|**Requerimiento**|**MoSCoW**|
|---|---|---|
|RF-031|Permitir la carga masiva de catálogo mediante archivo con reporte de errores por fila, como<br>contingencia**[Inferida]**|Could|
|**Búsqueda**|||
|RF-032|Permitir buscar productos por texto en nombre, marca, modelo y categoría|Must|
|RF-033|Permitir filtrar y ordenar por tipo de producto (computador armado o pieza), tipo de pieza, marca,<br>precio, disponibilidad y atributos técnicos**[Nuevo enfoque]**|Must|
|RF-034|Consultar el detalle de un producto con especificaciones, precio, disponibilidad y proveedor|Must|
|RF-035|Mostrar solo productos publicados e indicar los agotados|Must|
|**Asistente int**|**eligente de recomendación [Nuevo enfoque]**||
|RF-036|Permitir al cliente expresar en lenguaje natural su necesidad (uso, presupuesto, preferencias, nivel<br>técnico)|Must|
|RF-037|Solicitar al cliente la información faltante antes de recomendar|Must|
|RF-038|Recomendar computadores armados del catálogo adecuados a la necesidad, con una explicación<br>basada en atributos reales|Must|
|RF-039|Presentar alternativas con precio, disponibilidad y proveedor vigentes y las diferencias relevantes<br>entre ellas|Should|
|RF-040|Proponer, cuando ningún computador armado sirva, una configuración de piezas validada por el<br>motor de compatibilidad**[Inferida]**|Should|
|RF-041|Restringir al asistente a datos del catálogo y reglas del sistema, recomendar solo productos<br>publicados y disponibles, y declarar cuando no hay información suficiente. Condición de liberación<br>del asistente|Must|
|RF-042|Permitir ir desde una recomendación al producto, al PC Builder o al carrito sin ejecutar compras<br>automáticas|Should|
|RF-043|Registrar las interacciones del asistente para trazabilidad**[Inferida]**|Should|
|RF-044|Permitir escalar a atención humana cuando el asistente no pueda resolver**[Inferida]**|Could|
|RF-045|Generar la descripción funcional de un computador armado o de una configuración válida a partir<br>de atributos reales|Should|
|RF-089|Permitir expresar la necesidad al asistente por voz, además de por texto, y que el asistente llene<br>el PC Builder con la configuración propuesta**[Agregado por el equipo, 2026-10]**|Should|
|**PC Builder**|||
|RF-046|Permitir seleccionar piezas por tipo (procesador, placa base, memoria, almacenamiento, gráfica,<br>fuente, gabinete, refrigeración, etc.)|Must|
|RF-047|Validar la compatibilidad mediante un motor de reglas técnicas e informar la causa de cada<br>incompatibilidad|Must|
|RF-048|Detectar piezas obligatorias faltantes|Must|
|RF-049|Sugerir u ordenar piezas compatibles con las ya elegidas**[Inferida]**|Should|
|RF-050|Permitir al administrador crear, modificar, versionar y activar reglas de compatibilidad|Must|
|RF-051|Calcular el precio total y la disponibilidad de la configuración y permitir agregarla al carrito|Must|
|RF-052|Permitir guardar configuraciones**[Inferida]**|Could|
|RF-090|Mostrar una vista 3D de cómo se vería el computador con las piezas elegidas, o de un computador<br>armado con sus componentes por sección, a partir de un modelo 3D por componente**[Agregado por el equipo, 2026-10]**|Should|
|**Comercio**|||
|RF-053|Permitir agregar, modificar cantidad y eliminar ítems del carrito, y consultar subtotales|Must|
|RF-054|Conservar el carrito del cliente autenticado entre sesiones**[Inferida]**|Should|
|RF-055|Validar disponibilidad y vigencia del precio al iniciar y antes de confirmar la compra|Must|



Página 15 

NEXUS – Análisis de requisitos · Versión 2 

|**ID**|**Requerimiento**|**MoSCoW**|
|---|---|---|
|RF-056|Permitir confirmar la compra capturando dirección, datos de contacto/facturación y método de<br>pago|Must|
|RF-057|Integrar con la pasarela de pagos para procesar el pago y recibir su resultado|Must|
|RF-058|Registrar el pago con referencia, valor y estado para conciliación|Must|
|RF-059|Gestionar pagos rechazados, pendientes y abandonados sin generar órdenes inconsistentes<br>**[Inferida]**|Must|
|RF-060|Generar la orden con sus ítems, proveedores, valores, estado inicial y fecha|Must|
|RF-061|Dividir la compra en sub-órdenes por proveedor según la regla definida**[Pendiente]**|Must|
|RF-062|Notificar al proveedor las órdenes recibidas, por API (por ejemplo, webhook) o en el portal**[Nuevo**<br>**enfoque]**|Must|
|RF-063|Permitir al proveedor confirmar, rechazar con causa y actualizar el estado de preparación y<br>despacho, por API o en el portal**[Nuevo enfoque]**|Must|
|RF-064|Permitir al cliente consultar el historial, detalle y estado de sus órdenes|Must|
|RF-065|Notificar al cliente cambios relevantes de pago y orden**[Inferida]**|Should|
|RF-066|Descontar el inventario tras la venta hasta la siguiente sincronización**[Inferida]**|Must|
|RF-067|Reservar temporalmente el stock durante el checkout**[Inferida]**|Could|
|RF-068|Permitir solicitar y gestionar cancelaciones, devoluciones, retractos y reembolsos**[Inferida]**<br>**[Pendiente]**|Should|
|RF-069|Registrar y mostrar los datos de envío (transportadora, guía, estado)|Should|
|RF-070|Integrar con un operador logístico para cotización y seguimiento**[Inferida]** **[Pendiente]**|Could|
|**Comisione**|**s y liquidación**||
|RF-071|Permitir configurar la comisión por proveedor (porcentaje y vigencia)|Must|
|RF-072|Permitir configurar comisiones por producto como excepción, con vigencia|Must|
|RF-073|Determinar la comisión aplicable según la regla de prioridad definida**[Pendiente]**|Must|
|RF-074|Calcular por cada venta la comisión de NEXUS y el neto del proveedor sin modificar el precio al<br>cliente|Must|
|RF-075|Registrar en la operación el porcentaje, la base, la comisión y el neto aplicados, sin alteración<br>posterior|Must|
|RF-076|Generar liquidaciones por proveedor y periodo, y registrar su estado|Must|
|RF-077|Permitir al proveedor consultar sus ventas, comisiones y liquidaciones|Should|
|RF-078|Ajustar comisión y liquidación ante cancelaciones y devoluciones**[Inferida]**|Should|
|RF-079|Conciliar pagos contra la pasarela y señalar diferencias**[Inferida]**|Should|
|**Administra**|**ción y transversales**||
|RF-080|Permitir al administrador consultar y filtrar órdenes, pagos, productos, proveedores y comisiones|Must|
|RF-081|Registrar en bitácora los cambios en precios, inventario, comisiones, reglas, órdenes y estados de<br>pago, con actor, fecha y valores anterior/nuevo|Must|
|RF-082|Permitir consultar y filtrar la bitácora|Should|
|RF-083|Generar reportes de ventas, comisiones e integraciones**[Inferida]**|Could|
|RF-084|Permitir guardar productos favoritos**[Inferida]**|Could|
|RF-085|Permitir reseñas y calificaciones de productos comprados**[Inferida]**|Could|



Página 16 

NEXUS – Análisis de requisitos · Versión 2 

|**ID**|**Requerimiento**|**MoSCoW**|
|---|---|---|
|**Fuera de al**|**cance (Won't)**||
|RF-086|Gestionar promociones y descuentos. Fuera de alcance: decisión pendiente del negocio|Won't|
|RF-087|Comparador de celulares y venta de celulares u otras categorías distintas de computadores<br>armados y piezas. Eliminado del alcance**[Nuevo enfoque]**|Won't|
|RF-088|Ejecutar compras de forma autónoma desde el asistente. Contradice que la decisión final es del<br>cliente|Won't|



### **Requerimientos no funcionales** 

#### **Seguridad** 

|**ID**|**Requerimiento**|**MoSCoW**|
|---|---|---|
|RNF-001|Autenticar con almacenamiento seguro de credenciales y sesiones con expiración.|Must|
|RNF-002|Aplicar control de acceso por rol y aislar los datos de cada proveedor.|Must|
|RNF-003|Cifrar en tránsito y en reposo los datos personales y las credenciales de integración.|Must|
|RNF-004|No almacenar datos de tarjeta en NEXUS; delegarlos a la pasarela.|Must|
|RNF-005|Gestionar las credenciales de API de proveedores como secretos, nunca visibles en claro, con<br>rotación y revocación.**[Nuevo enfoque]**|Must|
|RNF-006|Autenticar cada llamada a la API del proveedor y limitar la tasa de peticiones por proveedor.<br>**[Nuevo enfoque]**|Must|
|RNF-007|Validar entradas y protegerse de riesgos habituales de aplicaciones móviles y APIs.|Must|
|RNF-008|Cumplir la normativa de protección de datos personales de la jurisdicción: consentimiento,<br>acceso, rectificación y supresión.|Must|
|RNF-009|Proteger al asistente de la manipulación de instrucciones y de fugas de datos entre clientes y<br>proveedores.|Should|
|RNF-010|Ofrecer autenticación reforzada para administradores y proveedores.|Should|



#### **Rendimiento** 

|**ID**|**Requerimiento**|**MoSCoW**|
|---|---|---|
|RNF-011|Búsqueda y listados en menos de 2 s (percentil 95) en condiciones normales.|Should|
|RNF-012|Validación de compatibilidad de PC en menos de 2 s (percentil 95).|Should|
|RNF-013|Primera respuesta del asistente en menos de 8 s, con indicador de progreso.|Should|
|RNF-014|Imágenes y datos optimizados para redes móviles.|Should|
|RNF-015|Latencia máxima entre un cambio en el proveedor (precio o stock) y su reflejo en la aplicación por<br>definir; propuesta de 15 min.**[Nuevo enfoque]**|Must (definir)|
|RNF-016|Capacidad de la API para recibir cargas grandes de productos (lotes) sin degradar la aplicación.<br>**[Nuevo enfoque]**|Should|



Página 17 

NEXUS – Análisis de requisitos · Versión 2 

#### **Disponibilidad** 

|**ID**|**Requerimiento**|**MoSCoW**|
|---|---|---|
|RNF-017|Disponibilidad mensual objetivo de 99,5 %, con ventanas de mantenimiento comunicadas.|Should|
|RNF-018|Degradar de forma controlada ante fallos de APIs de proveedor, pasarela o servicio de IA, con<br>mensajes claros y sin caída del catálogo.|Must|
|RNF-019|Definir y probar respaldo y recuperación (RPO y RTO).|Should|
|RNF-020|Garantizar idempotencia y consistencia en pagos, órdenes y mensajes de la API ante reintentos y<br>notificaciones duplicadas.|Must|



#### **Usabilidad** 

|**ID**|**Requerimiento**|**MoSCoW**|
|---|---|---|
|RNF-021|Interfaz móvil para las plataformas definidas, con criterios de accesibilidad.|Should|
|RNF-022|Checkout con el mínimo de pasos y errores comprensibles.|Should|
|RNF-023|Explicar incompatibilidades y recomendaciones en lenguaje no técnico, pensado para clientes sin<br>conocimientos de hardware.**[Nuevo enfoque]**|Should|
|RNF-024|Interfaz en español, con moneda y formatos locales y preparada para otros idiomas.|Must|
|RNF-025|Indicar que las recomendaciones del asistente y las descripciones son informativas y generadas<br>automáticamente.|Should|



#### **Escalabilidad** 

|**ID**|**Requerimiento**|**MoSCoW**|
|---|---|---|
|RNF-026|Crecer en proveedores, productos y usuarios concurrentes sin rediseño (volúmenes por definir).|Should|
|RNF-027|Modelo de atributos extensible para nuevos tipos de pieza sin cambios de código.|Must|
|RNF-028|Integraciones desacopladas, con conectores o adaptadores por proveedor y API versionada.<br>**[Nuevo enfoque]**|Must|
|RNF-029|Procesar de forma asíncrona la recepción masiva de productos, las sincronizaciones y las<br>notificaciones.|Should|



#### **Auditoría y Trazabilidad** 

|**ID**|**Requerimiento**|**MoSCoW**|
|---|---|---|
|RNF-030|Bitácora de cambios relevantes protegida contra alteración.|Must|
|RNF-031|Retención de registros según normativa y política (plazo por definir).|Must|
|RNF-032|Trazabilidad completa del cálculo de comisión y de la liquidación.|Must|
|RNF-033|Registro, monitoreo y alertas de errores de integración, incluidos los productos rechazados y su<br>causa.|Should|
|RNF-034|Registro de las recomendaciones del asistente (consulta, datos usados, respuesta).|Should|



Página 18 

NEXUS – Análisis de requisitos · Versión 2 

#### **Cumplimiento normativo** 

|**ID**|**Requerimiento**|**MoSCoW**|
|---|---|---|
|RNF-035|Aplicar la normativa de comercio electrónico, protección al consumidor, impuestos y facturación|Must|
||de la jurisdicción de operación.**[Pendiente]**||



### **Reglas de negocio** 

|**ID**<br>RN-001|**Regla**<br>El precio mostrado al cliente es el precio final fijado por el proveedor (documento original, RN-01).|
|---|---|
|RN-002|NEXUS no suma su comisión al precio del cliente; la comisión se descuenta del valor de la venta que corresponde al<br>proveedor (RN-02).|
|RN-003|Por cada venta, NEXUS retiene el porcentaje configurado sobre el valor del producto vendido (RN-03).|
|RN-004|La comisión puede variar entre proveedores y entre productos (RN-04).|
|RN-005|Cuando coexistan una comisión general del proveedor y una específica del producto, rige la prioridad que NEXUS<br>defina.**[Pendiente]**Supuesto provisional: prevalece la del producto (S-05) (RN-05).|
|RN-006|El proveedor entrega el precio final con los conceptos tributarios que correspondan; NEXUS no lo modifica por su<br>comisión (RN-06).|
|RN-007|La disponibilidad mostrada debe corresponder, en lo posible, al inventario que el proveedor envía a NEXUS por API<br>(RN-07, RN-08).|
|RN-008|**[Nuevo enfoque]**Los productos, precios, atributos y stock llegan a NEXUS a través de la API del proveedor. Cualquier<br>otra vía (portal, carga manual o masiva) es una contingencia.|
|RN-009|**[Nuevo enfoque]**NEXUS actúa como intermediario: no es el vendedor del producto ni mantiene inventario propio; el<br>proveedor ofrece el producto y atiende el pedido.|
|RN-010|**[Nuevo enfoque]**El catálogo solo admite computadores armados y piezas de computador; los productos de otras<br>categorías se rechazan.|
|RN-011|Un producto solo se publica con datos mínimos y atributos técnicos obligatorios de su categoría (RN-09, proceso de<br>publicación).|
|RN-012|Los errores de integración y los productos rechazados deben quedar registrados.|
|RN-013|La compatibilidad entre piezas la determinan reglas técnicas definidas por NEXUS, no solo una respuesta de IA<br>generativa (RN-10).|
|RN-014|El asistente solo usa información del catálogo y reglas del sistema, no inventa características ni disponibilidad, y la<br>decisión final es del cliente (RN-11).|
|RN-015|**[Nuevo enfoque]** **[Inferida]**El asistente solo recomienda productos publicados, con oferta vigente y disponibles, y<br>revalida precio y disponibilidad antes de mostrarlos.|
|RN-016|Las descripciones de computadores y las recomendaciones se basan en características reales registradas (RN-13).|
|RN-017|Antes de confirmar una compra se verifica la disponibilidad del producto (RN-14).|
|RN-018|Debe definirse el tratamiento de las compras con varios proveedores.**[Pendiente]**Supuesto provisional: sub-órdenes<br>por proveedor (S-06) (RN-15).|
|RN-019|El proveedor es responsable de la exactitud de la información comercial y técnica de sus productos (RN-16).|
|RN-020|La comisión se registra con la operación para conservar la trazabilidad del cálculo y la liquidación (RN-17).|
|RN-021|NEXUS conserva registros de cambios relevantes en precios, inventario, comisiones, reglas, órdenes y pagos (RN-18).|
|RN-022|**[Inferida]**Solo proveedores aprobados y activos pueden publicar productos y recibir órdenes.|



Página 19 

NEXUS – Análisis de requisitos · Versión 2 

|**ID**|**Regla**|
|---|---|
|RN-023|**[Nuevo enfoque]** **[Inferida]**El proveedor responde por el ensamblaje y la compatibilidad de los computadores armados<br>que publica; NEXUS no los revalida con el motor de compatibilidad.|
|RN-024|**[Inferida]**El porcentaje de comisión debe estar dentro del rango definido por NEXUS.**[Pendiente]**|
|RN-025|**[Inferida]**Una orden se genera únicamente con pago confirmado (S-04).|
|RN-026|**[Inferida]**Cada ítem de orden conserva el precio, la cantidad y la comisión vigentes al momento de la compra; los<br>cambios posteriores no lo afectan.|
|RN-027|**[Inferida]**Solo un cliente autenticado puede confirmar una compra.|
|RN-028|**[Inferida]**La cantidad por ítem debe ser al menos 1 y no exceder el stock; un producto sin stock no puede comprarse.|
|RN-029|**[Inferida]**Los estados de una orden siguen transiciones válidas definidas, y cada cambio registra fecha y actor.|
|RN-030|**[Inferida]**Una liquidación solo incluye ventas con pago confirmado y no reembolsadas, en el momento que NEXUS<br>defina.**[Pendiente]**|
|RN-031|**[Inferida]**Una configuración de PC es válida solo si no tiene incompatibilidades ni piezas obligatorias faltantes.|
|RN-032|**[Inferida]**Los atributos técnicos usan tipos y unidades estandarizados por categoría, para que la búsqueda, el asistente<br>y el PC Builder puedan usarlos.|
|RN-033|**[Inferida]**El registro de un cliente requiere aceptar los términos y el tratamiento de datos.|
|RN-034|**[Inferida]**Cancelaciones, devoluciones, retractos y garantías se rigen por las políticas de NEXUS y la normativa<br>aplicable.**[Pendiente]**|



### **Matriz de trazabilidad** 

|**Historia de usuario**|**Requerimientos funcionales**|**Reglas de negocio**|
|---|---|---|
|HU-001 – Registro de cliente|RF-001, RF-007|RN-033|
|HU-002 – Inicio de sesión y recuperación<br>de acceso|RF-002, RF-003, RF-005|RN-027|
|HU-003 – Gestión de perfil y direcciones<br>de entrega|RF-004|RN-027|
|HU-004 – Búsqueda y filtrado de<br>computadores y piezas|RF-032, RF-033, RF-035|RN-007, RN-017, RN-010|
|HU-005 – Consulta de detalle de producto|RF-034, RF-014|RN-001, RN-007|
|HU-006 – Recomendación de un<br>computador adecuado con el asistente|RF-036, RF-037, RF-038, RF-040, RF-041, RF-039, RF-042,<br>RF-043, RF-044|RN-014, RN-015, RN-016|
|HU-007 – Descripción funcional de un<br>computador|RF-045|RN-016, RN-031|
|HU-008 – Armar un PC con piezas y<br>validar su compatibilidad|RF-046, RF-047, RF-048, RF-049, RF-051|RN-013, RN-031|
|HU-009 – Gestión del carrito|RF-053, RF-054|RN-028, RN-017|
|HU-010 – Confirmación de compra y pago|RF-055, RF-056, RF-057, RF-058, RF-059, RF-060, RF-066,<br>RF-067|RN-001, RN-006, RN-017,<br>RN-025, RN-026, RN-027|
|HU-011 – Seguimiento de órdenes|RF-064, RF-065, RF-069, RF-070|RN-029|
|HU-012 – Compra con productos de varios<br>proveedores|RF-061|RN-018, RN-026|



Página 20 

NEXUS – Análisis de requisitos · Versión 2 

|**Historia de usuario**|**Requerimientos funcionales**|**Reglas de negocio**|
|---|---|---|
|HU-013 – Cancelación, devolución y<br>reembolso|RF-068|RN-034|
|HU-014 – Favoritos, configuraciones<br>guardadas y reseñas|RF-052, RF-084, RF-085|RN-027|
|HU-015 – Solicitud de registro como<br>proveedor|RF-008|RN-022|
|HU-016 – Publicación y actualización de<br>productos por API|RF-021, RF-022, RF-023, RF-024, RF-015, RF-016|RN-008, RN-010, RN-011,<br>RN-019, RN-001, RN-032,<br>RN-009, RN-023|
|HU-017 – Configuración de la integración<br>por API|RF-018, RF-020, RF-025, RF-019|RN-007, RN-012, RN-008|
|HU-018 – Gestión de inventario|RF-029, RF-028, RF-027|RN-007|
|HU-019 – Gestión de catálogo por portal o<br>carga masiva (contingencia)|RF-030, RF-031|RN-011, RN-032|
|HU-020 – Recepción y gestión de órdenes<br>(por API o portal)|RF-062, RF-063|RN-026, RN-029|
|HU-021 – Consulta de ventas, comisiones<br>y liquidaciones|RF-077|RN-003, RN-020|
|HU-022 – Evaluación y aprobación de<br>proveedores|RF-009, RF-010, RF-011|RN-022|
|HU-023 – Configuración de comisiones|RF-071, RF-072, RF-073|RN-002, RN-003, RN-004,<br>RN-005, RN-024|
|HU-024 – Administración de categorías y<br>atributos técnicos|RF-012, RF-013|RN-011, RN-032, RN-010|
|HU-025 – Administración de reglas de<br>compatibilidad de PC|RF-050|RN-013, RN-021|
|HU-026 – Cálculo y registro de comisión<br>por venta|RF-074, RF-075|RN-002, RN-003, RN-020,<br>RN-026|
|HU-027 – Liquidación a proveedores|RF-076, RF-078, RF-079|RN-030|
|HU-028 – Supervisión de órdenes y pagos|RF-080|RN-025, RN-029|
|HU-029 – Monitoreo de integraciones|RF-026, RF-027, RF-028|RN-007, RN-012|
|HU-030 – Gestión de usuarios y roles|RF-006, RF-005|RN-022|
|HU-031 – Consulta de auditoría|RF-081, RF-082|RN-021, RN-029|
|HU-032 – Reportes operativos|RF-083|n/a|
|HU-033 – Moderación del catálogo|RF-017|RN-011, RN-019|



RF-086, RF-087, RF-088 son **Won't** , por lo que no tienen historia asociada. 

### **Supuestos identificados** 

- **S-01:** Aplicación móvil para Android e iOS. El alcance solo dice «aplicación móvil». 

- **S-02:** Un único idioma (español), una moneda y una jurisdicción de operación. 

- **S-03:** El cliente paga a NEXUS por un canal centralizado, y NEXUS liquida después el neto al proveedor. Se deduce de que la comisión se descuenta al proveedor. 

Página 21 

NEXUS – Análisis de requisitos · Versión 2 

- **S-04:** La orden se genera solo cuando el pago está confirmado. 

- **S-05:** Si hay comisión específica de producto y general del proveedor, prevalece la del producto. 

- **S-06:** Una compra con varios proveedores se divide en sub-órdenes con estado, entrega y liquidación independientes. 

- **S-07:** La comisión se calcula sobre el precio final del producto por la cantidad, excluyendo el envío. Si el precio incluye impuestos, la comisión los incluiría. 

- **S-08:** Un mismo producto del catálogo puede tener ofertas de varios proveedores. 

- **S-09:** Descuentos y promociones quedan fuera de esta versión. 

- **S-10: [Nuevo enfoque]** El catálogo se limita a dos familias: computadores armados (equipos completos vendidos por el proveedor) y piezas (componentes internos como procesador, placa base, memoria, almacenamiento, gráfica, fuente, gabinete y refrigeración). Periféricos y accesorios quedan fuera hasta confirmar. 

- **S-11: [Nuevo enfoque]** La API es la vía principal por la que los proveedores envían productos, precios, atributos, imágenes y stock. El portal y la carga masiva son contingencias de menor prioridad. 

- **S-12: [Nuevo enfoque]** NEXUS no almacena productos ni despacha: el proveedor responde por el producto y por el envío, mientras no se defina una operación logística distinta. 

- **S-13: [Nuevo enfoque]** Existe un portal mínimo para el proveedor (consulta de órdenes, ventas, liquidaciones y estado de la integración), porque no todos los proveedores integrarán el manejo de órdenes por API. 

- **S-14: [Nuevo enfoque]** El PC Builder se mantiene en el alcance: el cambio de enfoque no lo elimina. Se asume que complementa al asistente. Por confirmar. 

- **S-15: [Nuevo enfoque]** Los computadores armados se venden tal como los publica el proveedor; NEXUS no valida su compatibilidad interna. 

- **S-16: [Nuevo enfoque]** El asistente se apoya en un modelo generativo restringido a datos del catálogo, y la compatibilidad se resuelve con reglas deterministas. Sube a Must porque es el diferenciador central del negocio; depende de un servicio externo y de la calidad de los datos. 

- **S-17:** El asistente solo orienta y nunca ejecuta compras. 

- **S-18:** Los clientes son personas naturales y la facturación empresarial queda fuera. 

- **S-19:** El proveedor despacha y registra la guía, mientras no se defina la operación logística. 

### **Vacíos de información** 

- Porcentajes de comisión, rangos y vigencias permitidos. 

- Regla de prioridad entre comisión general y específica. 

- Base de cálculo de la comisión: impuestos, envío, descuentos. 

- Esquema de pagos (cobro centralizado o dividido) y momento de liberación al proveedor. 

- Responsable de facturación, garantías, devoluciones y retractos. 

- Tratamiento de órdenes con varios proveedores. 

- Responsabilidad y operación del envío, y costos de entrega. 

- Alcance exacto de la API: qué datos envía el proveedor (productos, precios, atributos, imágenes, stock), qué recibe de NEXUS (órdenes, estados), si funciona por envío (push), consulta (pull) o ambos, y el formato y los estándares de datos. **[Nuevo enfoque]** 

- Frecuencia, latencia y reintentos de la integración, y política si la API falla. 

- Quién prevalece en conflictos entre datos de la API y datos cargados manualmente. 

- Qué se considera «pieza»: si incluye periféricos y accesorios, o solo componentes internos. **[Nuevo enfoque]** 

Página 22 

NEXUS – Análisis de requisitos · Versión 2 

- Si los computadores armados incluyen portátiles, de escritorio o ambos, y si se aceptan equipos usados o reacondicionados. **[Nuevo enfoque]** 

- Formato estándar de atributos técnicos por tipo de pieza y para computadores armados. 

- Reglas completas de compatibilidad del PC Builder y su fuente de datos. 

- Criterios del asistente para recomendar (uso, presupuesto, rendimiento) y de la descripción funcional; si se usarán referencias de rendimiento (benchmarks) o solo especificaciones. 

- Si el PC Builder se mantiene en la primera versión. **[Nuevo enfoque]** 

- Manejo de descuentos y promociones. 

- Jurisdicción y regulación aplicable. Por ejemplo, si fuera Colombia, la protección de datos personales (Ley 1581 de 2012) y de consumidores (Ley 1480 de 2011) condicionan retractos, garantías y consentimiento. 

- Plataformas móviles objetivo, volúmenes esperados y métricas de rendimiento. 

- Roles internos de NEXUS (soporte, finanzas) distintos del administrador. 

- Proveedor del servicio de IA y política de uso de datos. 

### **Riesgos de interpretación** 

|**ID**|**Riesgo**|**Impacto**|**Mitigación**|
|---|---|---|---|
|R-01|«Valor del producto vendido» puede<br>entenderse con o sin impuestos y envío|Error económico y fiscal en<br>comisiones|Definir la base de cálculo por escrito<br>(S-07)|
|R-02|«La comisión se descuenta al proveedor»<br>supone que NEXUS recibe el dinero|Implicaciones legales, fiscales y<br>de flujo de fondos|Definir el esquema de pagos antes del<br>diseño|
|R-03|«Precio establecido por el proveedor» frente<br>a precios desactualizados por falta de<br>sincronización|Ventas a precio incorrecto|Validar el precio vigente al confirmar la<br>compra|
|R-04|**[Nuevo enfoque]**Todo el catálogo depende<br>de la API de los proveedores: si es inestable,<br>mal documentada o inexistente en un<br>proveedor, el catálogo queda incompleto o<br>desactualizado|Catálogo incompleto,<br>sobreventa y recomendaciones<br>erróneas del asistente|Definir la API temprano con<br>documentación y sandbox, política de<br>falla y contingencia por portal o carga<br>masiva|
|R-05|«Stock en la medida técnicamente posible»|Sobreventa|Descuento local de stock, política de falla<br>y, si es necesario, reserva|
|R-06|El asistente es ahora el diferenciador central<br>y se espera que «no invente»|Respuestas erróneas con<br>impacto reputacional y de<br>ventas|Restringir a datos del catálogo, validar<br>salidas, registrar interacciones y probar<br>con casos reales antes de liberar|
|R-07|**[Nuevo enfoque]**«Computador adecuado»,<br>«usos posibles» y «perfiles de uso» son<br>subjetivos, y los computadores armados se<br>describen de forma heterogénea (marketing<br>frente a especificaciones)|Recomendaciones que no<br>cumplen la expectativa del<br>cliente|Definir criterios de recomendación por<br>tipo de uso, exigir atributos mínimos y<br>mostrar aviso informativo|
|R-08|Subestimar el esfuerzo de las reglas de<br>compatibilidad|Retrasos o validaciones<br>incorrectas|Alcance inicial por tipo de pieza y<br>mantenimiento continuo|
|R-09|Calidad de los atributos técnicos aportados<br>por los proveedores|Falla en el asistente, el PC<br>Builder y la búsqueda|Plantillas obligatorias, validaciones al<br>recibir por API y moderación|
|R-10|**[Nuevo enfoque]**Quien arma su PC con<br>piezas compra casi siempre a varios<br>proveedores, con envíos separados y plazos<br>distintos|Mala experiencia de entrega y<br>reclamos|Resolver cuanto antes la regla de sub-<br>órdenes, costos de envío y comunicación<br>de plazos|



Página 23 

NEXUS – Análisis de requisitos · Versión 2 

|**ID**|**Riesgo**|**Impacto**|**Mitigación**|
|---|---|---|---|
|R-11|**[Nuevo enfoque]**Ambigüedad sobre qué es<br>una «pieza» y si se mantiene el PC Builder<br>tras el cambio de enfoque|Retrabajo en el modelo de<br>catálogo|Confirmar el alcance antes de definir<br>categorías y atributos|
|R-12|«Se coordina la entrega» no asigna<br>responsables|Conflictos postventa|Definir roles logísticos y de garantía|
|R-13|Si no se fija la jurisdicción, se asumirá una<br>por defecto|Retrabajo legal|Confirmarla antes de diseñar el checkout|



### **Preguntas para refinamiento** 

##### Alcance y catálogo **[Nuevo enfoque]** 

- ¿Las «piezas» incluyen periféricos y accesorios (teclado, monitor, mouse) o solo componentes internos? 

- ¿Los computadores armados son de escritorio, portátiles o ambos? ¿Se aceptan equipos usados o reacondicionados? 

- ¿Se mantiene el PC Builder en la primera versión, o el asistente lo reemplaza? 

- ¿Cuáles son los tipos de pieza iniciales? 

##### API e integración **[Nuevo enfoque]** 

- ¿Qué datos envía el proveedor por API (productos, precios, atributos, imágenes, stock) y cuáles recibe de NEXUS (órdenes, estados)? 

- ¿La integración es por envío del proveedor (push), por consulta de NEXUS (pull) o ambas, y con qué frecuencia? 

- ¿Qué se muestra al cliente cuando la sincronización falla? 

- ¿Habrá proveedores sin API desde el inicio? Si es así, ¿se necesita el portal o la carga masiva en la primera versión? 

##### Comisiones y dinero 

- ¿Cuál es el rango de comisión, y la comisión es porcentaje puro o puede incluir fijos o mínimos? 

- ¿La comisión se calcula sobre el precio con impuestos o sin ellos? 

- ¿Prevalece la comisión del producto sobre la del proveedor? 

- ¿NEXUS recibe el pago total y liquida después, o el pago se divide automáticamente? 

- ¿Cuándo se libera el dinero al proveedor: al despachar, al entregar o tras un plazo de garantía? 

##### Órdenes y logística 

- ¿Cómo debe tratarse una compra con varios proveedores en entrega, costos de envío y estados? 

- ¿Quién despacha y quién asume el costo y riesgo del envío? 

- ¿Qué pasa si un proveedor no confirma una orden pagada en un plazo definido? 

##### Postventa y legal 

- ¿Quién responde por garantías, devoluciones, retractos y facturación? 

- ¿En qué país y bajo qué normativa operará NEXUS? 

##### Asistente inteligente **[Nuevo enfoque]** 

- ¿Qué datos debe preguntar el asistente al cliente (uso, presupuesto, preferencias, experiencia)? 

Página 24 

NEXUS – Análisis de requisitos · Versión 2 

- ¿Qué criterios definen un computador adecuado para cada uso (gaming, ofimática, diseño, programación, etc.)? 

- ¿Se usarán referencias de rendimiento (benchmarks) o solo las especificaciones del proveedor? 

- ¿Debe el asistente poder armar una configuración de piezas cuando ningún computador armado sirva? 

- ¿Quién mantendrá las reglas de compatibilidad y con qué fuente técnica? 

##### Plataforma 

- ¿Android, iOS o ambos, y cuál es la fecha objetivo? 

- ¿Qué volúmenes se esperan (proveedores, productos, usuarios concurrentes)? 

- ¿Qué roles internos de NEXUS existen además del administrador? 

Página 25 

