# Backend de NEXUS (Supabase)

Backend de la app móvil: PostgreSQL con RLS, Auth y Edge Functions (Deno/TypeScript).
El contrato con la app está en [../docs/API_CONTRATO.md](../docs/API_CONTRATO.md) y la hoja de ruta en
[../docs/PLAN_IMPLEMENTACION.md](../docs/PLAN_IMPLEMENTACION.md).

## Requisitos

- **Docker Desktop** en ejecución (Supabase local corre en contenedores).
- **Supabase CLI.** No hace falta instalarla: los comandos de abajo usan `npx supabase`, que la descarga
  (proyecto creado con la versión 2.121.0). También se puede instalar con `scoop install supabase`.
- **Deno 2**: solo para probar las Edge Functions, desde la fase 6.

## Levantar el entorno local

Todos los comandos se ejecutan desde `backend/`:

```powershell
npx supabase start     # primera vez: descarga las imágenes de Docker (varios minutos)
npx supabase status    # muestra la URL de la API, la Publishable key y el Studio
```

| Servicio | URL local |
|---|---|
| API (REST, Auth, Functions) | `http://127.0.0.1:54321` |
| Studio (administración) | `http://127.0.0.1:54323` |
| PostgreSQL | `postgresql://postgres:postgres@127.0.0.1:54322/postgres` |
| Correos de prueba (Inbucket) | `http://127.0.0.1:54324` |

Para apagar: `npx supabase stop`.

## Conectar la app

La URL depende de dónde corre la app, así que hay un archivo por destino. Todos están en `.gitignore`:

| Dónde corre la app | Archivo (copiar de) | `SUPABASE_URL` |
|---|---|---|
| Chrome o Windows | `env.json` (`env.example.json`) | `http://127.0.0.1:54321` |
| Emulador de Android | `env.android.json` (`env.android.example.json`) | `http://10.0.2.2:54321` |
| Celular físico | uno propio, por ejemplo `env.device.json` | `http://<IP del PC en la red local>:54321` |

`10.0.2.2` solo existe dentro del emulador de Android, donde apunta al PC. En Chrome produce
`ERR_CONNECTION_TIMED_OUT`.

1. Copiar el ejemplo que corresponda.
2. Poner en `SUPABASE_PUBLISHABLE_KEY` la *Publishable key* que muestra `npx supabase status` (en `backend/`).
3. Ejecutar, por ejemplo: `flutter run -d chrome --dart-define-from-file=env.json`.

En VS Code, `.vscode/launch.json` trae una configuración para cada caso: Chrome/Windows, emulador de Android y
sin backend.

Sin archivo de entorno la app arranca igual y usa los repositorios mock. En modo debug, la consola avisa si la
clave sigue siendo la de ejemplo o si se usa `10.0.2.2` fuera de Android.

**Los comandos `npx supabase ...` se ejecutan desde `backend/`.** Desde la raíz, la CLI no encuentra
`supabase/config.toml` e intenta crear otro proyecto (`prueba01`) en los mismos puertos. Para ejecutarlos desde la
raíz, agregar `--workdir backend`.

**Nunca** poner la `service_role` key ni otros secretos en `env.json` ni en el código de la app: van solo
en las Edge Functions (`npx supabase secrets set`).

## Cuentas y correos en local

- Los correos que manda Supabase Auth, como el código de recuperación, no salen a internet: se ven en
  **Mailpit**, `http://127.0.0.1:54324`.
- Las contraseñas exigen 8 caracteres con letras y números. La confirmación de correo está desactivada en local,
  así que al registrarse la sesión queda abierta de inmediato.
- Después de cambiar la sección `[auth]` de `config.toml` o algo en `supabase/templates/`, reiniciar para
  asegurarse de que se apliquen: `npx supabase stop` y luego `npx supabase start`.

## Base de datos

```powershell
npx supabase migration new <nombre>   # crea supabase/migrations/<fecha>_<nombre>.sql
npx supabase db reset                 # recrea la BD local: migraciones + seed.sql
npx supabase test db                  # pruebas pgTAP de supabase/tests/
```

Las migraciones son la única fuente del esquema: no se cambian tablas a mano desde Studio.

## Estructura

```text
backend/supabase/
├── config.toml      # configuración del entorno local
├── migrations/      # esquema versionado (ver docs/MODELO_DATOS.md)
├── seed.sql         # datos de desarrollo
├── tests/           # pruebas pgTAP
└── functions/       # Edge Functions (fase 6 en adelante)
```

Las carpetas se crean en la fase que las usa. El modelo de datos está descrito en
[../docs/MODELO_DATOS.md](../docs/MODELO_DATOS.md).

Antes de dar por terminada una fase con cambios de base de datos:

```powershell
npx supabase db reset
npx supabase db lint --local --level warning   # sin hallazgos
npx supabase test db                            # pgTAP en verde
```

## Probar la API a mano

```powershell
$key = (npx supabase status -o json | ConvertFrom-Json).PUBLISHABLE_KEY
Invoke-RestMethod -Method Post -Uri http://127.0.0.1:54321/rest/v1/rpc/get_products `
  -Headers @{ apikey = $key } -ContentType 'application/json' `
  -Body '{"page":0,"page_size":5,"family":"part"}'
```

Las búsquedas con tildes necesitan el cuerpo en UTF-8. En Git Bash, los argumentos de `curl` con tildes
no llegan así. En PowerShell, enviar los bytes:

```powershell
Invoke-RestMethod -Method Post -Uri http://127.0.0.1:54321/rest/v1/rpc/get_products `
  -Headers @{ apikey = $key } -ContentType 'application/json; charset=utf-8' `
  -Body ([Text.Encoding]::UTF8.GetBytes('{"search":"refrigeración"}'))
```
