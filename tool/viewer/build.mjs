// Empaqueta el visor en un único HTML sin imports: el WebView lo abre desde
// los assets de la app (file://), donde los módulos ES no cargan.
import { build } from 'esbuild';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const output = join(here, '..', '..', 'assets', 'viewer', 'viewer.html');

const result = await build({
  entryPoints: [join(here, 'src', 'viewer.js')],
  bundle: true,
  minify: true,
  format: 'iife',
  target: ['es2020'],
  write: false,
  legalComments: 'none',
});
const script = result.outputFiles[0].text.replaceAll('</script', '<\\/script');
const template = await readFile(join(here, 'src', 'viewer.html'), 'utf8');
const marker = '<!-- VIEWER_SCRIPT -->';
if (!template.includes(marker)) throw new Error(`Falta ${marker} en viewer.html`);

await mkdir(dirname(output), { recursive: true });
// Con un callback, el reemplazo no interpreta los `$` del código empaquetado.
await writeFile(output, template.replace(marker, () => `<script>${script}</script>`));
console.log(`viewer.html: ${(script.length / 1024).toFixed(0)} KB de script`);
