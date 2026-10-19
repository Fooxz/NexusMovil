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
├── migrations/      # fase 2 en adelante
├── seed.sql         # datos de desarrollo (fase 2)
├── tests/           # pgTAP (fase 2)
└── functions/       # Edge Functions (fase 6 en adelante)
```

Las carpetas se crean en la fase que las usa.
