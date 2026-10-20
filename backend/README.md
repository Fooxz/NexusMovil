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
| **Supabase en la nube** (cualquier dispositivo) | `env.cloud.json` (`env.cloud.example.json`) | `https://fzapwqaadxivadtlpthj.supabase.co` |
| Chrome o Windows | `env.json` (`env.example.json`) | `http://127.0.0.1:54321` |
| Emulador de Android | `env.android.json` (`env.android.example.json`) | `http://10.0.2.2:54321` |
| Celular físico por USB (recomendado) | `env.json`, después de `adb reverse tcp:54321 tcp:54321` | `http://127.0.0.1:54321` |
| Celular físico por Wi-Fi | uno propio, por ejemplo `env.device.json` | `http://<IP del PC en la red local>:54321` |

`10.0.2.2` solo existe dentro del emulador de Android, donde apunta al PC. En Chrome o en un celular físico produce
`ERR_CONNECTION_TIMED_OUT`: la app abre, pero sin datos.

**Celular por USB:** `adb reverse` hace que el puerto 54321 del celular llegue al PC por el cable, sin depender del
Wi-Fi ni del firewall. La configuración "NEXUS – Teléfono por USB" de VS Code lo ejecuta antes de lanzar
(`.vscode/tasks.json`). Hay que repetirlo si se desconecta el cable. A mano:

```powershell
& "$env:LOCALAPPDATAAndroidSdkplatform-toolsadb.exe" reverse tcp:54321 tcp:54321
flutter run -d <id del celular> --dart-define-from-file=env.json
```

**Celular por Wi-Fi:** usar la IP del PC (`ipconfig`). El firewall de Windows debe permitir conexiones entrantes
al puerto 54321 en la red privada.

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

## Proyecto en la nube (Proyecto_nexus)

Proyecto `fzapwqaadxivadtlpthj` (plan gratuito, us-east-1, Postgres 17). La CLI está vinculada con
`npx supabase link --project-ref fzapwqaadxivadtlpthj` (la referencia vive en `supabase/.temp`, ignorada por git).

**Cómo se subió (2026-10-19):**
1. `npx supabase db push`: las 10 migraciones, con los datos que traen (categorías, atributos, ranuras, reglas,
   documentos legales y configuración).
2. **Catálogo:** se exportó de local con `npx supabase db dump --local --data-only`, solo con las tablas
   `providers`, `products`, `product_attributes`, `product_images`, `offers`, `component_models` y
   `prebuilt_components`. Se importó con `npx supabase db query --linked -f` en una transacción. No se migraron
   las cuentas de prueba, `auth`, los carritos ni las bitácoras.
3. `npx supabase seed buckets --project-ref fzapwqaadxivadtlpthj`: el bucket `component-models` y sus `.glb`.
4. `npx supabase secrets set --env-file supabase/functions/.env` y
   `npx supabase functions deploy assistant --no-verify-jwt --use-api`.
5. **Autenticación:** se igualaron solo los ajustes que la app necesita: código de 6 dígitos, sin confirmar el
   correo, contraseña de 8+ con letras y números, MFA apagado. Se hizo con una configuración mínima aparte
   (`config push --workdir`), porque `config.toml` trae valores de desarrollo (`site_url` local, 1 s
   entre correos).

**Verificado:** el esquema `public` y `private` es idéntico al local (volcado completo sin diferencias: RLS,
políticas, funciones, triggers y permisos), y las RPC, Storage y la función responden desde fuera.

**Límites del plan gratuito:**
- **Correo:** sin SMTP propio, Supabase solo envía a los miembros de la organización y no deja cambiar las
  plantillas. Por eso la confirmación de correo está apagada y **la recuperación de contraseña no funciona en la
  nube**: la app espera un código y la plantilla de fábrica manda un enlace. Para activarla, configurar un SMTP en
  *Authentication → SMTP* y subir `supabase/templates/recovery.html`.
- **Pausa:** un proyecto gratuito sin actividad durante una semana se pausa; se reactiva desde el dashboard.

**Al agregar una migración:** `npx supabase db push --dry-run` y después `npx supabase db push`. Si cambia la
función: `npx supabase functions deploy assistant --no-verify-jwt --use-api`.

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
├── models/          # modelos 3D que se suben al bucket component-models (MODELOS_3D.md)
└── functions/
    ├── .env         # secretos locales (GEMINI_API_KEY); ignorado por git
    └── assistant/   # asistente de recomendación con Gemini (fase 7)
```

Las carpetas se crean en la fase que las usa. El modelo de datos está descrito en
[../docs/MODELO_DATOS.md](../docs/MODELO_DATOS.md).

Antes de dar por terminada una fase con cambios de base de datos:

```powershell
npx supabase db reset
npx supabase db lint --local --level warning   # sin hallazgos
npx supabase test db                            # pgTAP en verde
```

## Asistente (Edge Function, fase 7)

El asistente usa Gemini. La clave **solo** vive en el servidor:
- en local, en `supabase/functions/.env` como `GEMINI_API_KEY=...`, guardado sin BOM;
- en producción, con `npx supabase secrets set GEMINI_API_KEY=...`.

Nunca va en la app ni en `env.json`.

Para servir la función en local, desde `backend/`:

```powershell
npx supabase functions serve --env-file supabase/functions/.env
```

Queda en `http://127.0.0.1:54321/functions/v1/assistant` y recarga sola al cambiar el código.

**Pruebas del núcleo**, sin red ni Deno, con Node 22 o más reciente:

```powershell
node --test supabase/functions/assistant/core.test.ts
```

**Modelos y cuota:**
- El nivel gratuito de Gemini tiene una cuota **por modelo**, y `gemini-3.5-flash` solo permite 20 llamadas al día.
- Cada respuesta del asistente usa entre 1 y 8 llamadas.
- Por eso la función prueba los modelos en orden (`gemini-3.5-flash`, `gemini-3.5-flash-lite`, `gemini-3.1-flash-lite`): si uno responde 429, repite la respuesta con el siguiente.
- El orden se cambia con `GEMINI_MODELS=modelo1,modelo2` en el `.env`.
- Si ninguno responde, la app muestra que el asistente no está disponible y ofrece el catálogo y el PC Builder.

Cada pregunta queda en `assistant_interactions` (ver docs/MODELO_DATOS.md).

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
