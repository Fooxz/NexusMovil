# Arquitectura

## Estructura por feature

```text
lib/
|-- main.dart
|-- core/                    # lo que usa cualquier feature (utils, red, errores)
|-- widgets/                 # widgets visuales compartidos (como hoy)
|-- theme/
`-- features/<nombre>/
    |-- <nombre>_providers.dart   # conecta repositorio, controladores
    |-- domain/                   # entidades, reglas, interfaz del repositorio
    |-- data/                     # repositorio mock y real, DTOs
    `-- presentation/             # pantallas y widgets de la feature
```

El código actual de `lib/screens/` no se mueve ahora. Cada feature se migra
cuando le toca: catálogo en 5B, carrito en 5D y PC Builder en 7. No se crean
carpetas vacías por adelantado.

## Regla de dependencias

- `domain` no importa Flutter ni Riverpod: es Dart puro.
- `data` importa `domain`.
- `presentation` importa `domain` y los providers.
- Solo `<nombre>_providers.dart` decide si se usa el repositorio mock o el real.

Así, las reglas de negocio se prueban sin widgets y cambiar el mock por el
backend requiere modificar un único archivo de providers.

## Reglas de uso de Riverpod

- Usar `Notifier` y `AsyncNotifier` con `NotifierProvider` y
  `AsyncNotifierProvider`; no usar `StateNotifier` ni `ChangeNotifier`, que son
  la API antigua.
- Usar `ref.watch` solo dentro de `build`. En callbacks como `onPressed`, usar
  `ref.read`: `watch` suscribe y reconstruye, mientras `read` consulta una vez.
- Observar solo lo necesario con `select`, por ejemplo
  `ref.watch(provider.select((s) => s.total))`, para evitar reconstrucciones
  ajenas al dato usado (R4).
- Un controlador nunca guarda ni toca widgets ni `BuildContext`; recibe datos y
  devuelve estado.
- Calcular valores derivados (totales, progreso y compatibilidad) en el
  controlador o en providers derivados, nunca dentro de `build` (R3).
- El estado es inmutable: crear una copia nueva al cambiarlo, sin mutar listas
  u objetos existentes.
- Definir los repositorios como `abstract class` en `domain`; los controladores
  dependen de esa abstracción, nunca de una implementación concreta.

## Decisiones tomadas

- **Riverpod:** permite reconstrucciones granulares y mantiene la lógica
  independiente de los widgets.
- **Sin generación de código:** menos herramientas y conceptos mientras se
  aprende Riverpod.
- **Sin `go_router` por ahora:** la navegación actual alcanza hasta el paso 6.
- **Sin `Navigator` anidado:** añade una complejidad que no se necesita.
