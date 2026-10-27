# NEXUS

Aplicación Flutter para un marketplace de piezas de computador. El alcance actual
es solo piezas (no se venden computadores armados). La app incluye catálogo,
cuentas y perfil, carrito, checkout con Wompi, asistente de recomendación y PC
Builder con visor 3D.

La app abre en Inicio y permite recorrer el catálogo sin iniciar sesión. Cuando
se configura Supabase, las funciones implementadas usan el backend; sin esa
configuración, la app usa repositorios mock en memoria. El asistente necesita
el backend incluso en desarrollo y, sin él, informa que no está disponible.

## Ejecutar y comprobar

```powershell
flutter pub get
flutter run
```

Para conectar la app al backend local (Supabase), seguir [backend/README.md](backend/README.md):

```powershell
flutter run --dart-define-from-file=env.json
```

```powershell
dart analyze
flutter test
```

`flutter test` salta las pruebas de `test/integration/`, que usan el Supabase local. Para correrlas, con el backend levantado y `npx supabase db reset` recién hecho:

```powershell
flutter test test/integration --dart-define-from-file=env.json
```

Aquí `env.json` debe tener `SUPABASE_URL` = `http://127.0.0.1:54321`.

Para inspección de rendimiento, usar un dispositivo físico y
`flutter run --profile`; Chrome sirve para revisar lógica y aspecto, no la
fluidez móvil. Las reglas están en [REGLAS_RENDIMIENTO.md](REGLAS_RENDIMIENTO.md).

## Documentación

- [Requisitos (análisis v2)](docs/REQUISITOS.md)
- [Plan de implementación por fases](docs/PLAN_IMPLEMENTACION.md)
- [Arquitectura](docs/ARQUITECTURA.md) y [contrato de API app–backend](docs/API_CONTRATO.md)
- [Documentación del código y estado funcional](DOCUMENTACION_LIB.md)
- [Reglas permanentes de rendimiento](REGLAS_RENDIMIENTO.md)
- [Modelo de datos del backend](docs/MODELO_DATOS.md) y [guía del backend local](backend/README.md)
- [Modelos 3D y sus licencias](backend/MODELOS_3D.md)
