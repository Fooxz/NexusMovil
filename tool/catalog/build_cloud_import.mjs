// Une seed.sql y seeds/*.sql en un solo archivo para cargar el inventario en
// la nube sin pisar lo que ya existe: cada insert termina en
// `on conflict do nothing` y todo va en una transacción. Se puede repetir.
//
//   node tool/catalog/build_cloud_import.mjs <archivo de salida>
//   npx supabase db query --linked -f <archivo de salida>   (desde backend/)
import { readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const out = process.argv[2];
if (!out) {
  console.error('Uso: node tool/catalog/build_cloud_import.mjs <archivo de salida>');
  process.exit(1);
}

const supabase = join(dirname(fileURLToPath(import.meta.url)), '..', '..', 'backend', 'supabase');
const seeds = join(supabase, 'seeds');
const files = [
  join(supabase, 'seed.sql'),
  ...readdirSync(seeds).filter((name) => name.endsWith('.sql')).sort().map((name) => join(seeds, name)),
];

const statements = [];
for (const file of files) {
  let current = [];
  for (const line of readFileSync(file, 'utf8').replace(/\r\n/g, '\n').split('\n')) {
    const comment = line.trimStart().startsWith('--');
    if (current.length === 0 && (line.trim() === '' || comment)) continue;
    current.push(line);
    if (!comment && line.trimEnd().endsWith(';')) {
      const text = current.join('\n').trimEnd();
      if (!/^insert into/i.test(text)) throw new Error(`${file}: solo se esperan inserts:\n${text.slice(0, 120)}`);
      statements.push(`${text.slice(0, -1)}\non conflict do nothing;`);
      current = [];
    }
  }
  if (current.length) throw new Error(`${file}: sentencia sin terminar`);
}

writeFileSync(out,
  `-- Inventario de desarrollo para la nube: solo agrega lo que falta.\nbegin;\n\n${statements.join('\n\n')}\n\ncommit;\n`);
console.log(`${statements.length} sentencias de ${files.length} archivos en ${out}`);
