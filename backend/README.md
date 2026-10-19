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

1. En la raíz de la app, copiar `env.example.json` como `env.json` (está en `.gitignore`).
2. Poner en `SUPABASE_PUBLISHABLE_KEY` la *Publishable key* que muestra `npx supabase status`.
3. Ajustar `SUPABASE_URL` según dónde corre la app:
   - Emulador de Android: `http://10.0.2.2:54321` (en el emulador, `localhost` es el propio emulador).
   - Celular físico: `http://<IP del PC en la red local>:54321`.
   - Windows o Chrome: `http://127.0.0.1:54321`.
4. Ejecutar: `flutter run --dart-define-from-file=env.json`.

Sin `env.json` la app arranca igual y usa los repositorios mock.

**Nunca** poner la `service_role` key ni otros secretos en `env.json` ni en el código de la app: van solo
en las Edge Functions (`npx supabase secrets set`).

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
