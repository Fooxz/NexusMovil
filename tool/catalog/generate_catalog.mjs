// Genera el catálogo grande de desarrollo: unas 800 piezas con sus atributos
// tipados y ofertas, para probar la app, el PC Builder y el asistente con
// volumen. Es determinista (misma semilla, mismo archivo).
//
//   node tool/catalog/generate_catalog.mjs
//
// Escribe backend/supabase/seeds/catalog_generated.sql, que `supabase db reset`
// carga después de seed.sql (config.toml, [db.seed]). Los nombres siguen las
// líneas reales de cada marca, pero no todas las combinaciones existen en el
// mercado; las especificaciones son aproximadas y los precios, de ejemplo.
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const seedPath = join(root, 'backend', 'supabase', 'seed.sql');
const outPath = join(root, 'backend', 'supabase', 'seeds', 'catalog_generated.sql');

// --- Utilidades ----------------------------------------------------------

/** Generador pseudoaleatorio con semilla (mulberry32). */
function random(seed) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
const rand = random(20261027);
const between = (min, max) => min + Math.floor(rand() * (max - min + 1));
const pick = (list) => list[Math.floor(rand() * list.length)];
const chance = (p) => rand() < p;
function sample(list, count) {
  const copy = [...list];
  const out = [];
  while (copy.length && out.length < count) out.push(copy.splice(Math.floor(rand() * copy.length), 1)[0]);
  return out;
}

const slug = (text) =>
  text.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase()
    .replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '');

/** Precio en pesos con terminación comercial (…9.900), ±6 % de variación. */
function price(pesos) {
  const varied = pesos * (0.94 + rand() * 0.12);
  return Math.max(1, Math.round(varied / 10000)) * 10000 - 100;
}

const sql = (value) => {
  if (value === null || value === undefined) return 'null';
  if (typeof value === 'number') return String(value);
  if (typeof value === 'boolean') return value ? 'true' : 'false';
  if (Array.isArray(value)) return `array[${value.map(sql).join(', ')}]::text[]`;
  return `'${String(value).replace(/'/g, "''")}'`;
};

// Ids que ya usa seed.sql: no se repiten.
const existingIds = new Set(
  [...readFileSync(seedPath, 'utf8').matchAll(/^\s*\('([a-z0-9][a-z0-9-]*)', '/gm)].map((m) => m[1]),
);

// --- Plantillas de atributos (etiquetas para la ficha técnica) ------------

const labels = {
  socket: 'SOCKET', cores: 'NÚCLEOS', threads: 'HILOS', base_clock_ghz: 'FRECUENCIA BASE',
  boost_clock_ghz: 'FRECUENCIA TURBO', tdp_w: 'CONSUMO (TDP)', integrated_graphics: 'GRÁFICOS INTEGRADOS',
  chipset: 'CHIPSET', form_factor: 'FORMATO', ram_type: 'TIPO DE MEMORIA', ram_slots: 'RANURAS DE MEMORIA',
  max_ram_gb: 'MEMORIA MÁXIMA', m2_slots: 'RANURAS M.2', capacity_gb: 'CAPACIDAD', modules: 'MÓDULOS',
  speed_mts: 'VELOCIDAD', vram_gb: 'MEMORIA DE VIDEO', length_mm: 'LARGO', recommended_psu_w: 'FUENTE RECOMENDADA',
  storage_type: 'TIPO', interface: 'INTERFAZ', wattage_w: 'POTENCIA', efficiency: 'CERTIFICACIÓN',
  modularity: 'MODULARIDAD', supported_form_factors: 'FORMATOS DE PLACA', max_gpu_length_mm: 'GRÁFICA MÁXIMA',
  max_cooler_height_mm: 'DISIPADOR MÁXIMO', radiator_support_mm: 'RADIADORES', cooling_type: 'TIPO',
  supported_sockets: 'SOCKETS', radiator_mm: 'RADIADOR', height_mm: 'ALTURA', tdp_rating_w: 'DISIPACIÓN MÁXIMA',
};
const units = {
  base_clock_ghz: ' GHz', boost_clock_ghz: ' GHz', tdp_w: ' W', max_ram_gb: ' GB', capacity_gb: ' GB',
  speed_mts: ' MT/s', vram_gb: ' GB', length_mm: ' mm', recommended_psu_w: ' W', wattage_w: ' W',
  max_gpu_length_mm: ' mm', max_cooler_height_mm: ' mm', radiator_mm: ' mm', height_mm: ' mm', tdp_rating_w: ' W',
};
const display = (key, value) => {
  if (typeof value === 'boolean') return value ? 'Sí' : 'No';
  if (Array.isArray(value)) return value.join(', ') + (key === 'radiator_support_mm' ? ' mm' : '');
  if (key === 'capacity_gb' && value >= 1000) return `${value / 1000} TB`;
  if (key === 'modularity') return { full: 'Modular', semi: 'Semimodular', none: 'No modular' }[value];
  if (key === 'cooling_type') return value === 'air' ? 'Aire' : 'Líquida';
  return `${value}${units[key] ?? ''}`;
};

// --- Datos por tipo de pieza ---------------------------------------------

const products = [];
function add(category, { name, brand, model, summary, quickSpecs, attributes, pesos }) {
  const id = slug(name);
  if (existingIds.has(id) || products.some((p) => p.id === id)) return;
  products.push({
    id, name, brand, model, category, summary, quickSpecs, attributes, pesos,
    specs: Object.entries(attributes).map(([key, value]) => ({ label: labels[key], value: display(key, value) })),
  });
}

// Procesadores: [marca, modelo, socket, núcleos, hilos, base, turbo, TDP, gráficos, precio]
const cpus = [
  ['AMD', 'Ryzen 5 7500F', 'AM5', 6, 12, 3.7, 5.0, 65, false, 579900],
  ['AMD', 'Ryzen 5 7600', 'AM5', 6, 12, 3.8, 5.1, 65, true, 749900],
  ['AMD', 'Ryzen 5 7600X', 'AM5', 6, 12, 4.7, 5.3, 105, true, 829900],
  ['AMD', 'Ryzen 5 8500G', 'AM5', 6, 12, 3.5, 5.0, 65, true, 699900],
  ['AMD', 'Ryzen 5 9600', 'AM5', 6, 12, 3.8, 5.2, 65, true, 899900],
  ['AMD', 'Ryzen 5 9600X', 'AM5', 6, 12, 3.9, 5.4, 65, true, 949900],
  ['AMD', 'Ryzen 7 7700', 'AM5', 8, 16, 3.8, 5.3, 65, true, 1149900],
  ['AMD', 'Ryzen 7 7700X', 'AM5', 8, 16, 4.5, 5.4, 105, true, 1199900],
  ['AMD', 'Ryzen 7 7800X3D', 'AM5', 8, 16, 4.2, 5.0, 120, true, 1799900],
  ['AMD', 'Ryzen 7 8700G', 'AM5', 8, 16, 4.2, 5.1, 65, true, 1249900],
  ['AMD', 'Ryzen 7 9700X', 'AM5', 8, 16, 3.8, 5.5, 65, true, 1399900],
  ['AMD', 'Ryzen 7 9800X3D', 'AM5', 8, 16, 4.7, 5.2, 120, true, 2299900],
  ['AMD', 'Ryzen 9 7900', 'AM5', 12, 24, 3.7, 5.4, 65, true, 1699900],
  ['AMD', 'Ryzen 9 7900X', 'AM5', 12, 24, 4.7, 5.6, 170, true, 1749900],
  ['AMD', 'Ryzen 9 7950X', 'AM5', 16, 32, 4.5, 5.7, 170, true, 2399900],
  ['AMD', 'Ryzen 9 9900X', 'AM5', 12, 24, 4.4, 5.6, 120, true, 2099900],
  ['AMD', 'Ryzen 9 9950X3D', 'AM5', 16, 32, 4.3, 5.7, 170, true, 3299900],
  ['AMD', 'Ryzen 3 4100', 'AM4', 4, 8, 3.8, 4.0, 65, false, 299900],
  ['AMD', 'Ryzen 5 5500', 'AM4', 6, 12, 3.6, 4.2, 65, false, 379900],
  ['AMD', 'Ryzen 5 5600', 'AM4', 6, 12, 3.5, 4.4, 65, false, 459900],
  ['AMD', 'Ryzen 5 5600X', 'AM4', 6, 12, 3.7, 4.6, 65, false, 529900],
  ['AMD', 'Ryzen 5 5600G', 'AM4', 6, 12, 3.9, 4.4, 65, true, 539900],
  ['AMD', 'Ryzen 7 5700G', 'AM4', 8, 16, 3.8, 4.6, 65, true, 749900],
  ['AMD', 'Ryzen 7 5700X', 'AM4', 8, 16, 3.4, 4.6, 65, false, 699900],
  ['AMD', 'Ryzen 7 5700X3D', 'AM4', 8, 16, 3.0, 4.1, 105, false, 1049900],
  ['AMD', 'Ryzen 7 5800X', 'AM4', 8, 16, 3.8, 4.7, 105, false, 849900],
  ['AMD', 'Ryzen 7 5800X3D', 'AM4', 8, 16, 3.4, 4.5, 105, false, 1399900],
  ['AMD', 'Ryzen 9 5900X', 'AM4', 12, 24, 3.7, 4.8, 105, false, 1299900],
  ['AMD', 'Ryzen 9 5950X', 'AM4', 16, 32, 3.4, 4.9, 105, false, 1799900],
  ['Intel', 'Core i3-12100', 'LGA1700', 4, 8, 3.3, 4.3, 60, true, 449900],
  ['Intel', 'Core i3-12100F', 'LGA1700', 4, 8, 3.3, 4.3, 58, false, 379900],
  ['Intel', 'Core i3-14100', 'LGA1700', 4, 8, 3.5, 4.7, 60, true, 549900],
  ['Intel', 'Core i3-14100F', 'LGA1700', 4, 8, 3.5, 4.7, 58, false, 469900],
  ['Intel', 'Core i5-12400', 'LGA1700', 6, 12, 2.5, 4.4, 65, true, 649900],
  ['Intel', 'Core i5-12400F', 'LGA1700', 6, 12, 2.5, 4.4, 65, false, 529900],
  ['Intel', 'Core i5-13400', 'LGA1700', 10, 16, 2.5, 4.6, 65, true, 799900],
  ['Intel', 'Core i5-13400F', 'LGA1700', 10, 16, 2.5, 4.6, 65, false, 689900],
  ['Intel', 'Core i5-13600K', 'LGA1700', 14, 20, 3.5, 5.1, 125, true, 1199900],
  ['Intel', 'Core i5-14400F', 'LGA1700', 10, 16, 2.5, 4.7, 65, false, 749900],
  ['Intel', 'Core i5-14500', 'LGA1700', 14, 20, 2.6, 5.0, 65, true, 1049900],
  ['Intel', 'Core i5-14600K', 'LGA1700', 14, 20, 3.5, 5.3, 125, true, 1349900],
  ['Intel', 'Core i5-14600KF', 'LGA1700', 14, 20, 3.5, 5.3, 125, false, 1249900],
  ['Intel', 'Core i7-12700K', 'LGA1700', 12, 20, 3.6, 5.0, 125, true, 1399900],
  ['Intel', 'Core i7-13700K', 'LGA1700', 16, 24, 3.4, 5.4, 125, true, 1799900],
  ['Intel', 'Core i7-14700', 'LGA1700', 20, 28, 2.1, 5.4, 65, true, 1899900],
  ['Intel', 'Core i7-14700K', 'LGA1700', 20, 28, 3.4, 5.6, 125, true, 2049900],
  ['Intel', 'Core i7-14700KF', 'LGA1700', 20, 28, 3.4, 5.6, 125, false, 1949900],
  ['Intel', 'Core i9-13900K', 'LGA1700', 24, 32, 3.0, 5.8, 125, true, 2599900],
  ['Intel', 'Core i9-14900K', 'LGA1700', 24, 32, 3.2, 6.0, 125, true, 2899900],
  ['Intel', 'Core i9-14900KF', 'LGA1700', 24, 32, 3.2, 6.0, 125, false, 2799900],
  ['Intel', 'Core Ultra 5 225', 'LGA1851', 10, 10, 3.3, 4.9, 65, true, 1049900],
  ['Intel', 'Core Ultra 5 225F', 'LGA1851', 10, 10, 3.3, 4.9, 65, false, 949900],
  ['Intel', 'Core Ultra 5 245K', 'LGA1851', 14, 14, 4.2, 5.2, 125, true, 1399900],
  ['Intel', 'Core Ultra 5 245KF', 'LGA1851', 14, 14, 4.2, 5.2, 125, false, 1299900],
  ['Intel', 'Core Ultra 7 265', 'LGA1851', 20, 20, 2.4, 5.3, 65, true, 1749900],
  ['Intel', 'Core Ultra 7 265KF', 'LGA1851', 20, 20, 3.9, 5.5, 125, false, 1799900],
  ['Intel', 'Core Ultra 9 285', 'LGA1851', 24, 24, 2.5, 5.6, 65, true, 2499900],
  ['Intel', 'Core Ultra 9 285K', 'LGA1851', 24, 24, 3.7, 5.7, 125, true, 2799900],
];
for (const [brand, model, socket, cores, threads, base, boost, tdp, igpu, pesos] of cpus) {
  const name = `${brand} ${model}`;
  add('cpu', {
    name, brand, model,
    summary: `${cores} núcleos · ${boost.toFixed(1)} GHz · ${socket}${igpu ? ' · Gráficos integrados' : ''}`,
    quickSpecs: [socket, `${cores} NÚCLEOS`, `${tdp}W`, ...(igpu ? ['GRÁFICOS INTEGRADOS'] : [])],
    attributes: {
      socket, cores, threads, base_clock_ghz: base, boost_clock_ghz: boost, tdp_w: tdp, integrated_graphics: igpu,
    },
    pesos,
  });
}

// Placas madre: chipsets y líneas de cada marca.
const chipsets = [
  { chip: 'A520', socket: 'AM4', ram: ['DDR4'], tier: 1, pesos: 349900 },
  { chip: 'B550', socket: 'AM4', ram: ['DDR4'], tier: 2, pesos: 549900 },
  { chip: 'X570', socket: 'AM4', ram: ['DDR4'], tier: 3, pesos: 899900 },
  { chip: 'A620', socket: 'AM5', ram: ['DDR5'], tier: 1, pesos: 449900 },
  { chip: 'B650', socket: 'AM5', ram: ['DDR5'], tier: 2, pesos: 699900 },
  { chip: 'B850', socket: 'AM5', ram: ['DDR5'], tier: 2, pesos: 849900 },
  { chip: 'B650E', socket: 'AM5', ram: ['DDR5'], tier: 3, pesos: 949900 },
  { chip: 'X870', socket: 'AM5', ram: ['DDR5'], tier: 3, pesos: 1199900 },
  { chip: 'X670E', socket: 'AM5', ram: ['DDR5'], tier: 4, pesos: 1399900 },
  { chip: 'X870E', socket: 'AM5', ram: ['DDR5'], tier: 4, pesos: 1599900 },
  { chip: 'H610', socket: 'LGA1700', ram: ['DDR4', 'DDR5'], tier: 1, pesos: 379900 },
  { chip: 'B760', socket: 'LGA1700', ram: ['DDR4', 'DDR5'], tier: 2, pesos: 599900 },
  { chip: 'Z790', socket: 'LGA1700', ram: ['DDR5'], tier: 3, pesos: 1099900 },
  { chip: 'B860', socket: 'LGA1851', ram: ['DDR5'], tier: 2, pesos: 799900 },
  { chip: 'Z890', socket: 'LGA1851', ram: ['DDR5'], tier: 3, pesos: 1299900 },
];
// {c} es el chipset. ff: formato; tiers: gamas de chipset de la línea; k: factor de precio.
const boardLines = [
  ['ASUS', 'PRIME {c}M-A', 'microATX', [1, 2], 1.0],
  ['ASUS', 'PRIME {c}-PLUS', 'ATX', [1, 2, 3], 1.05],
  ['ASUS', 'TUF GAMING {c}M-PLUS WIFI', 'microATX', [2, 3], 1.15],
  ['ASUS', 'TUF GAMING {c}-PLUS WIFI', 'ATX', [2, 3], 1.2],
  ['ASUS', 'ROG STRIX {c}-I GAMING WIFI', 'miniITX', [2, 3, 4], 1.45],
  ['ASUS', 'ROG STRIX {c}-F GAMING WIFI', 'ATX', [2, 3, 4], 1.4],
  ['MSI', 'PRO {c}M-A WIFI', 'microATX', [1, 2], 1.0],
  ['MSI', 'PRO {c}-P WIFI', 'ATX', [1, 2, 3], 1.05],
  ['MSI', 'MAG {c} TOMAHAWK WIFI', 'ATX', [2, 3], 1.25],
  ['MSI', 'MAG {c}M MORTAR WIFI', 'microATX', [2, 3], 1.2],
  ['MSI', 'MPG {c} CARBON WIFI', 'ATX', [3, 4], 1.5],
  ['Gigabyte', '{c}M DS3H', 'microATX', [1, 2], 0.95],
  ['Gigabyte', '{c}M GAMING X AX', 'microATX', [2, 3], 1.1],
  ['Gigabyte', '{c} AORUS ELITE AX', 'ATX', [2, 3, 4], 1.25],
  ['Gigabyte', '{c}I AORUS PRO AX', 'miniITX', [2, 3], 1.4],
  ['ASRock', '{c}M-HDV/M.2', 'microATX', [1], 0.9],
  ['ASRock', '{c}M Pro RS', 'microATX', [1, 2], 0.95],
  ['ASRock', '{c} Steel Legend WiFi', 'ATX', [2, 3], 1.15],
  ['ASRock', '{c} Taichi', 'ATX', [4], 1.8],
];
for (const set of chipsets) {
  for (const [brand, pattern, ff, tiers, k] of boardLines) {
    if (!tiers.includes(set.tier)) continue;
    // Los chipsets "E" no tienen versiones microATX con sufijo M.
    if (set.chip.endsWith('E') && pattern.includes('{c}M')) continue;
    const ramTypes = set.ram.length > 1 && set.tier <= 2 && ff !== 'miniITX' ? set.ram : [set.ram[set.ram.length - 1]];
    for (const ram of ramTypes) {
      const twin = set.ram.length > 1 && ram === 'DDR4';
      const model = pattern.replace('{c}', set.chip) + (twin ? ' D4' : '');
      const slots = ff === 'miniITX' || (set.tier === 1 && ff === 'microATX' && chance(0.6)) ? 2 : 4;
      const maxRam = ram === 'DDR4' ? (slots === 2 ? 64 : 128) : slots === 2 ? 96 : set.tier === 4 ? 256 : 192;
      const m2 = ff === 'miniITX' ? 2 : Math.min(5, set.tier + between(0, 1));
      add('motherboard', {
        name: `${brand} ${model}`, brand, model,
        summary: `${set.socket} · ${ram} · ${ff} · ${set.chip}`,
        quickSpecs: [set.socket, set.chip, ram, ff.toUpperCase(), ...(/WIFI|AX/i.test(model) ? ['WI-FI'] : [])],
        attributes: {
          socket: set.socket, chipset: set.chip, form_factor: ff, ram_type: ram, ram_slots: slots,
          max_ram_gb: maxRam, m2_slots: m2,
        },
        pesos: set.pesos * k * (twin ? 0.93 : 1) * (ff === 'miniITX' ? 1.1 : 1),
      });
    }
  }
}

// Memoria RAM: líneas, tipos y velocidades; capacidades del kit.
const ramLines = [
  ['Kingston', 'FURY Beast', 'DDR4', [3200, 3600], 1.0],
  ['Kingston', 'FURY Beast', 'DDR5', [5200, 5600, 6000], 1.0],
  ['Kingston', 'FURY Renegade', 'DDR5', [6400], 1.12],
  ['Corsair', 'Vengeance LPX', 'DDR4', [3200, 3600], 1.0],
  ['Corsair', 'Vengeance', 'DDR5', [5600, 6000, 6400], 1.03],
  ['Corsair', 'Vengeance RGB', 'DDR5', [6000, 6400], 1.12],
  ['G.Skill', 'Ripjaws V', 'DDR4', [3200, 3600], 0.98],
  ['G.Skill', 'Flare X5', 'DDR5', [6000], 1.04],
  ['G.Skill', 'Trident Z5 RGB', 'DDR5', [6000, 6400], 1.15],
  ['TeamGroup', 'T-Force Vulcan', 'DDR4', [3200], 0.94],
  ['TeamGroup', 'T-Force Vulcan', 'DDR5', [5600, 6000], 0.95],
  ['TeamGroup', 'T-Force Delta RGB', 'DDR5', [6000], 1.08],
  ['Crucial', 'Pro', 'DDR4', [3200], 0.96],
  ['Crucial', 'Pro', 'DDR5', [5600], 0.98],
  ['ADATA', 'XPG Lancer RGB', 'DDR5', [6000], 1.07],
  ['Patriot', 'Viper Venom', 'DDR5', [6000], 1.0],
];
const kits = {
  DDR4: [[8, 1], [16, 2], [32, 2], [64, 2]],
  DDR5: [[16, 2], [32, 2], [48, 2], [64, 2], [96, 2]],
};
// Ya están en seed.sql con otros ids.
const ramSkip = new Set(['Kingston FURY Beast DDR4 16 3200', 'Kingston FURY Beast DDR5 16 5600', 'Corsair Vengeance DDR5 32 6000']);
for (const [brand, line, type, speeds, k] of ramLines) {
  for (const speed of speeds) {
    for (const [capacity, modules] of sample(kits[type], between(2, 4))) {
      if (ramSkip.has(`${brand} ${line} ${type} ${capacity} ${speed}`)) continue;
      const perGb = type === 'DDR4' ? 10500 : 15000 * (1 + (speed - 5200) / 4000);
      const model = `${line} ${type} ${capacity}GB (${modules}x${capacity / modules}) ${speed}`;
      add('ram', {
        name: `${brand} ${model}`, brand, model,
        summary: `${capacity} GB · ${type} · ${speed} MT/s`,
        quickSpecs: [type, `${capacity}GB`, String(speed), ...(/RGB/.test(line) ? ['RGB'] : [])],
        attributes: { ram_type: type, capacity_gb: capacity, modules, speed_mts: speed },
        pesos: (capacity * perGb + 30000) * k,
      });
    }
  }
}

// Tarjetas gráficas: chips y ensambladores.
// [fabricante, chip, VRAM, TDP, fuente recomendada, largo base, precio]
const gpuChips = [
  ['NVIDIA', 'GeForce RTX 3050 6GB', 6, 70, 300, 175, 899900],
  ['NVIDIA', 'GeForce RTX 3060 12GB', 12, 170, 550, 230, 1249900],
  ['NVIDIA', 'GeForce RTX 4060', 8, 115, 550, 230, 1399900],
  ['NVIDIA', 'GeForce RTX 4060 Ti 8GB', 8, 160, 550, 245, 1799900],
  ['NVIDIA', 'GeForce RTX 4060 Ti 16GB', 16, 165, 550, 250, 2099900],
  ['NVIDIA', 'GeForce RTX 4070', 12, 200, 650, 265, 2699900],
  ['NVIDIA', 'GeForce RTX 4070 SUPER', 12, 220, 650, 270, 2999900],
  ['NVIDIA', 'GeForce RTX 4070 Ti SUPER', 16, 285, 700, 300, 3899900],
  ['NVIDIA', 'GeForce RTX 4080 SUPER', 16, 320, 750, 310, 5299900],
  ['NVIDIA', 'GeForce RTX 5060', 8, 145, 550, 240, 1499900],
  ['NVIDIA', 'GeForce RTX 5060 Ti 8GB', 8, 180, 600, 240, 1899900],
  ['NVIDIA', 'GeForce RTX 5060 Ti 16GB', 16, 180, 600, 245, 2199900],
  ['NVIDIA', 'GeForce RTX 5070', 12, 250, 650, 265, 2899900],
  ['NVIDIA', 'GeForce RTX 5070 Ti', 16, 300, 750, 300, 4199900],
  ['NVIDIA', 'GeForce RTX 5080', 16, 360, 850, 310, 6299900],
  ['NVIDIA', 'GeForce RTX 5090', 32, 575, 1000, 330, 10999900],
  ['AMD', 'Radeon RX 6600', 8, 132, 500, 220, 1049900],
  ['AMD', 'Radeon RX 7600', 8, 165, 550, 235, 1249900],
  ['AMD', 'Radeon RX 7600 XT', 16, 190, 600, 250, 1549900],
  ['AMD', 'Radeon RX 7700 XT', 12, 245, 700, 270, 2049900],
  ['AMD', 'Radeon RX 7800 XT', 16, 263, 700, 280, 2499900],
  ['AMD', 'Radeon RX 7900 GRE', 16, 260, 700, 280, 2799900],
  ['AMD', 'Radeon RX 7900 XT', 20, 315, 750, 300, 3499900],
  ['AMD', 'Radeon RX 7900 XTX', 24, 355, 800, 320, 4299900],
  ['AMD', 'Radeon RX 9060 XT 8GB', 8, 150, 500, 250, 1449900],
  ['AMD', 'Radeon RX 9060 XT 16GB', 16, 160, 550, 260, 1799900],
  ['AMD', 'Radeon RX 9070', 16, 220, 650, 280, 2899900],
  ['AMD', 'Radeon RX 9070 XT', 16, 304, 750, 300, 3399900],
  ['Intel', 'Arc A750', 8, 225, 600, 265, 999900],
  ['Intel', 'Arc B570', 10, 150, 500, 250, 1099900],
  ['Intel', 'Arc B580', 12, 190, 600, 255, 1349900],
];
// [marca, línea, mm extra de largo, factor de precio, compacta (solo chips de hasta 250 W)]
const gpuPartners = {
  NVIDIA: [
    ['ASUS', 'DUAL', 0, 1.02, true], ['ASUS', 'TUF GAMING OC', 30, 1.12, false],
    ['ASUS', 'ROG STRIX OC', 40, 1.25, false], ['MSI', 'VENTUS 2X', -10, 1.0, true],
    ['MSI', 'GAMING TRIO', 35, 1.12, false], ['Gigabyte', 'WINDFORCE', 15, 1.01, false],
    ['Gigabyte', 'GAMING OC', 35, 1.08, false], ['Gigabyte', 'AORUS MASTER', 50, 1.25, false],
    ['ZOTAC', 'Twin Edge', -15, 0.98, true], ['PNY', 'Verto', 10, 1.0, false], ['Palit', 'Dual', -5, 0.99, true],
  ],
  AMD: [
    ['Sapphire', 'PULSE', 10, 1.02, false], ['Sapphire', 'NITRO+', 40, 1.15, false],
    ['PowerColor', 'Hellhound', 25, 1.05, false], ['PowerColor', 'Red Devil', 45, 1.17, false],
    ['XFX', 'Swift', 20, 1.03, false], ['ASUS', 'TUF GAMING OC', 35, 1.12, false],
    ['Gigabyte', 'GAMING OC', 30, 1.08, false], ['ASRock', 'Challenger', 0, 0.99, true],
  ],
  Intel: [['ASRock', 'Challenger', 0, 1.0, true], ['Sparkle', 'Titan OC', 20, 1.04, false], ['Gigabyte', 'GAMING OC', 25, 1.06, false]],
};
for (const [vendor, chip, vram, tdp, psu, length, pesos] of gpuChips) {
  const partners = gpuPartners[vendor].filter((p) => !p[4] || tdp <= 250);
  for (const [brand, line, extra, k] of sample(partners, Math.min(partners.length, between(4, 6)))) {
    const model = `${line} ${chip}`;
    add('gpu', {
      name: `${brand} ${model}`, brand, model,
      summary: `${vram} GB · ${tdp} W · ${length + extra} mm`,
      quickSpecs: [chip.replace(/^(GeForce|Radeon) /, '').toUpperCase(), `${vram}GB`, `${tdp}W`],
      attributes: { chipset: chip, vram_gb: vram, tdp_w: tdp, length_mm: length + extra, recommended_psu_w: psu },
      pesos: pesos * k,
    });
  }
}

// Almacenamiento: [marca, línea, tipo, interfaz, capacidades en GB, factor de precio]
const storageLines = [
  ['Samsung', '990 EVO Plus', 'NVMe', 'PCIe4', [1000, 2000, 4000], 1.05],
  ['Samsung', '990 PRO', 'NVMe', 'PCIe4', [1000, 4000], 1.3],
  ['Samsung', '9100 PRO', 'NVMe', 'PCIe5', [1000, 2000, 4000], 1.8],
  ['Samsung', '870 EVO', 'SATA_SSD', 'SATA', [500, 1000, 2000, 4000], 1.1],
  ['WD', 'Blue SN580', 'NVMe', 'PCIe4', [500, 1000, 2000], 0.9],
  ['WD', 'BLACK SN850X', 'NVMe', 'PCIe4', [1000, 2000, 4000], 1.3],
  ['WD', 'Blue SA510', 'SATA_SSD', 'SATA', [500, 1000, 2000], 0.95],
  ['WD', 'Blue', 'HDD', 'SATA', [1000, 2000, 4000], 1.0],
  ['Kingston', 'NV3', 'NVMe', 'PCIe4', [500, 2000, 4000], 0.85],
  ['Kingston', 'KC3000', 'NVMe', 'PCIe4', [1000, 2000, 4000], 1.2],
  ['Kingston', 'FURY Renegade', 'NVMe', 'PCIe4', [1000, 2000, 4000], 1.3],
  ['Kingston', 'A400', 'SATA_SSD', 'SATA', [500, 1000], 0.85],
  ['Crucial', 'P3', 'NVMe', 'PCIe3', [500, 1000, 2000, 4000], 0.85],
  ['Crucial', 'P3 Plus', 'NVMe', 'PCIe4', [500, 1000, 2000, 4000], 0.9],
  ['Crucial', 'T500', 'NVMe', 'PCIe4', [500, 1000, 2000], 1.05],
  ['Crucial', 'T705', 'NVMe', 'PCIe5', [1000, 2000, 4000], 1.9],
  ['Crucial', 'MX500', 'SATA_SSD', 'SATA', [500, 1000, 2000], 1.0],
  ['ADATA', 'LEGEND 860', 'NVMe', 'PCIe4', [500, 1000, 2000], 0.88],
  ['Lexar', 'NM790', 'NVMe', 'PCIe4', [1000, 2000, 4000], 0.98],
  ['Lexar', 'NM620', 'NVMe', 'PCIe3', [500, 1000, 2000], 0.85],
  ['TeamGroup', 'MP44L', 'NVMe', 'PCIe4', [500, 1000, 2000], 0.85],
  ['Corsair', 'MP700 Elite', 'NVMe', 'PCIe5', [1000, 2000], 1.7],
  ['Seagate', 'BarraCuda', 'HDD', 'SATA', [1000, 2000, 4000, 8000], 0.95],
  ['Toshiba', 'P300', 'HDD', 'SATA', [1000, 2000, 4000], 0.95],
];
const storageBase = {
  NVMe: { 500: 219900, 1000: 329900, 2000: 589900, 4000: 1149900 },
  SATA_SSD: { 500: 189900, 1000: 299900, 2000: 549900, 4000: 1099900 },
  HDD: { 1000: 199900, 2000: 269900, 4000: 429900, 8000: 799900 },
};
const typeLabel = { NVMe: 'NVMe', SATA_SSD: 'SSD SATA', HDD: 'Disco duro' };
for (const [brand, line, type, iface, capacities, k] of storageLines) {
  for (const capacity of capacities) {
    const size = capacity >= 1000 ? `${capacity / 1000}TB` : `${capacity}GB`;
    const model = `${line} ${size}`;
    add('storage', {
      name: `${brand} ${model}`, brand, model,
      summary: `${typeLabel[type]} · ${iface === 'SATA' ? 'SATA' : iface.replace('PCIe', 'PCIe ') + '.0'} · ${size}`,
      quickSpecs: [type === 'SATA_SSD' ? 'SSD' : type.toUpperCase(), size, iface.toUpperCase()],
      attributes: { storage_type: type, capacity_gb: capacity, interface: iface },
      pesos: storageBase[type][capacity] * k,
    });
  }
}

// Fuentes: [marca, línea, certificación, modularidad, potencias, factor]
const psuLines = [
  ['Corsair', 'CX{w}', 'BRONZE', 'none', [550, 650, 750], 1.0],
  ['Corsair', 'RM{w}e', 'GOLD', 'full', [650, 850, 1000], 1.0],
  ['Corsair', 'RM{w}x', 'GOLD', 'full', [750, 1000, 1200], 1.08],
  ['Corsair', 'HX{w}i', 'PLATINUM', 'full', [1000, 1200, 1500], 1.05],
  ['EVGA', '{w} BR', 'BRONZE', 'none', [500, 700], 0.95],
  ['EVGA', 'SuperNOVA {w} GQ', 'GOLD', 'semi', [650, 750, 850], 0.97],
  ['Seasonic', 'FOCUS GX-{w}', 'GOLD', 'full', [650, 750, 850, 1000], 1.05],
  ['Seasonic', 'PRIME TX-{w}', 'TITANIUM', 'full', [850, 1000, 1300], 1.0],
  ['Cooler Master', 'MWE {w} Bronze V3', 'BRONZE', 'none', [500, 600, 750], 0.95],
  ['Cooler Master', 'MWE Gold {w} V2', 'GOLD', 'full', [650, 750, 850], 0.98],
  ['Thermaltake', 'Smart {w}W', '80PLUS', 'none', [500, 600, 700], 1.0],
  ['Thermaltake', 'Toughpower GF A3 {w}W', 'GOLD', 'full', [750, 850, 1050], 1.0],
  ['MSI', 'MAG A{w}BN', 'BRONZE', 'none', [550, 650, 750], 0.95],
  ['MSI', 'MAG A{w}GL', 'GOLD', 'full', [650, 750, 850], 1.0],
  ['be quiet!', 'Pure Power 12 M {w}W', 'GOLD', 'full', [550, 650, 750, 850, 1000], 1.05],
  ['XPG', 'CORE REACTOR II {w}W', 'GOLD', 'full', [650, 750, 850], 0.98],
  ['Gigabyte', 'UD{w}GM', 'GOLD', 'full', [750, 850, 1000], 0.97],
  ['Lian Li', 'EDGE {w}', 'PLATINUM', 'full', [1000, 1200], 1.1],
];
const perWatt = { '80PLUS': 300, BRONZE: 420, GOLD: 560, PLATINUM: 850, TITANIUM: 1350 };
for (const [brand, line, efficiency, modularity, watts, k] of psuLines) {
  for (const w of watts) {
    const model = line.replace('{w}', w);
    add('psu', {
      name: `${brand} ${model}`, brand, model,
      summary: `${w} W · 80 PLUS ${efficiency === '80PLUS' ? 'White' : efficiency[0] + efficiency.slice(1).toLowerCase()}` +
        (modularity === 'full' ? ' · Modular' : modularity === 'semi' ? ' · Semimodular' : ''),
      quickSpecs: [`${w}W`, efficiency === '80PLUS' ? '80 PLUS' : efficiency],
      attributes: { wattage_w: w, efficiency, modularity },
      pesos: (w * perWatt[efficiency] + 40000) * k,
    });
  }
}

// Gabinetes: [marca, modelo, formatos, gráfica máx., disipador máx., radiadores, precio, colores]
const ALL = ['EATX', 'ATX', 'microATX', 'miniITX'];
const ATX = ['ATX', 'microATX', 'miniITX'];
const MATX = ['microATX', 'miniITX'];
const ITX = ['miniITX'];
const R3 = ['240', '280', '360'];
const cases = [
  ['NZXT', 'H5 Flow', ATX, 365, 165, ['240', '280'], 449900, 2],
  ['NZXT', 'H6 Flow', ATX, 365, 163, R3, 599900, 2],
  ['NZXT', 'H7 Flow', ALL, 400, 185, R3, 699900, 2],
  ['NZXT', 'H9 Flow', ATX, 435, 165, R3, 799900, 2],
  ['Corsair', '4000D AIRFLOW', ATX, 360, 170, R3, 479900, 2],
  ['Corsair', '5000D AIRFLOW', ALL, 420, 170, R3, 749900, 2],
  ['Corsair', '3000D RGB AIRFLOW', ATX, 360, 170, R3, 499900, 2],
  ['Corsair', '2000D AIRFLOW', ITX, 365, 170, R3, 599900, 2],
  ['Lian Li', 'LANCOOL 216', ALL, 392, 180, R3, 499900, 2],
  ['Lian Li', 'LANCOOL 207', ATX, 375, 170, R3, 399900, 2],
  ['Lian Li', 'O11 Vision', ALL, 455, 167, R3, 749900, 2],
  ['Lian Li', 'A3-mATX', MATX, 415, 165, R3, 399900, 2],
  ['Fractal Design', 'North', ATX, 355, 170, R3, 699900, 2],
  ['Fractal Design', 'Pop Air', ATX, 405, 170, R3, 379900, 2],
  ['Fractal Design', 'Meshify 2 Compact', ATX, 360, 169, R3, 549900, 2],
  ['Fractal Design', 'Terra', ITX, 322, 77, [], 749900, 1],
  ['Cooler Master', 'MasterBox Q300L', MATX, 360, 159, ['120', '240'], 229900, 1],
  ['Cooler Master', 'MasterBox TD500 Mesh V2', ATX, 410, 165, R3, 399900, 2],
  ['Cooler Master', 'HAF 700', ALL, 490, 166, ['240', '280', '360', '420'], 1299900, 1],
  ['Thermaltake', 'S100 TG', MATX, 330, 165, ['120', '240'], 219900, 2],
  ['Thermaltake', 'View 270 TG ARGB', ATX, 400, 170, R3, 449900, 2],
  ['Montech', 'AIR 903 MAX', ALL, 400, 180, R3, 399900, 2],
  ['Montech', 'X3 MESH', ATX, 305, 160, ['240'], 229900, 2],
  ['DeepCool', 'CH560', ALL, 380, 175, R3, 429900, 2],
  ['DeepCool', 'CC560', ATX, 370, 163, ['240', '360'], 279900, 2],
  ['DeepCool', 'CH360', MATX, 320, 174, ['240', '360'], 349900, 2],
  ['Phanteks', 'XT PRO', ALL, 415, 184, R3, 349900, 2],
  ['be quiet!', 'Pure Base 500DX', ATX, 369, 190, R3, 599900, 2],
  ['Antec', 'NX200M', MATX, 300, 155, ['120', '240'], 199900, 1],
  ['Cougar', 'MX330-G AIR', ATX, 330, 165, ['240'], 229900, 1],
  ['HYTE', 'Y60', ATX, 375, 160, R3, 999900, 2],
  ['HYTE', 'Y40', ATX, 422, 180, R3, 749900, 2],
];
for (const [brand, model, forms, gpu, cooler, radiators, pesos, colors] of cases) {
  for (const color of ['Negro', 'Blanco'].slice(0, colors)) {
    const full = `${model} ${color}`;
    const top = forms.includes('EATX') ? 'E-ATX' : forms.includes('ATX') ? 'ATX' : forms.includes('microATX') ? 'microATX' : 'Mini-ITX';
    add('pcCase', {
      name: `${brand} ${full}`, brand, model: full,
      summary: `${top} · Gráfica hasta ${gpu} mm · ${color}`,
      quickSpecs: [top.toUpperCase(), `${gpu}MM`, color.toUpperCase()],
      attributes: {
        supported_form_factors: forms, max_gpu_length_mm: gpu, max_cooler_height_mm: cooler,
        ...(radiators.length ? { radiator_support_mm: radiators } : {}),
      },
      pesos: pesos * (color === 'Blanco' ? 1.04 : 1),
    });
  }
}

// Refrigeración por aire: [marca, modelo, altura, disipación, precio, sockets, variantes]
const S4 = ['AM4', 'AM5', 'LGA1700', 'LGA1851'];
const airCoolers = [
  ['DeepCool', 'AG400', 150, 220, 109900, S4, ['', 'ARGB']],
  ['DeepCool', 'AK500', 158, 240, 219900, S4, ['', 'WH']],
  ['DeepCool', 'AK620', 160, 260, 299900, S4, ['', 'WH']],
  ['DeepCool', 'AG620', 157, 260, 249900, S4, ['', 'ARGB']],
  ['Noctua', 'NH-D15 G2', 168, 250, 699900, S4, ['']],
  ['Noctua', 'NH-U12S redux', 158, 180, 299900, ['AM4', 'AM5', 'LGA1700'], ['']],
  ['Noctua', 'NH-L9a-AM5', 37, 95, 249900, ['AM4', 'AM5'], ['']],
  ['Thermalright', 'Peerless Assassin 120 SE', 155, 260, 179900, S4, ['', 'White', 'ARGB']],
  ['Thermalright', 'Phantom Spirit 120 SE', 154, 265, 199900, S4, ['', 'ARGB']],
  ['Thermalright', 'Assassin X 120 Refined SE', 148, 220, 99900, S4, ['', 'White']],
  ['be quiet!', 'Pure Rock 2', 155, 150, 189900, ['AM4', 'AM5', 'LGA1700'], ['', 'White']],
  ['be quiet!', 'Dark Rock 5', 161, 210, 399900, S4, ['']],
  ['be quiet!', 'Dark Rock Pro 5', 168, 270, 549900, S4, ['']],
  ['Cooler Master', 'Hyper 212 Black', 152, 180, 149900, ['AM4', 'AM5', 'LGA1700'], ['', 'ARGB']],
  ['Cooler Master', 'Hyper 622 Halo', 157, 220, 249900, S4, ['', 'White']],
  ['ID-COOLING', 'SE-224-XTS', 154, 220, 109900, ['AM4', 'AM5', 'LGA1700'], ['', 'White']],
  ['ARCTIC', 'Freezer 36', 159, 210, 139900, S4, ['', 'A-RGB']],
];
for (const [brand, model, height, rating, pesos, sockets, variants] of airCoolers) {
  for (const variant of variants) {
    const full = variant ? `${model} ${variant}` : model;
    add('cooling', {
      name: `${brand} ${full}`, brand, model: full,
      summary: `Aire · ${height} mm · hasta ${rating} W`,
      quickSpecs: ['AIRE', `${height}MM`, `${rating}W`],
      attributes: { cooling_type: 'air', supported_sockets: sockets, height_mm: height, tdp_rating_w: rating },
      pesos: pesos * (variant ? 1.08 : 1),
    });
  }
}

// Refrigeración líquida: [marca, línea ({r} = radiador), radiadores, precio de 240 mm, variantes]
const liquidCoolers = [
  ['ARCTIC', 'Liquid Freezer III Pro {r}', [240, 280, 360], 349900, ['', 'A-RGB']],
  ['NZXT', 'Kraken {r}', [240, 280, 360], 549900, ['', 'Blanco']],
  ['NZXT', 'Kraken Elite {r}', [240, 280], 799900, ['']],
  ['Corsair', 'iCUE LINK TITAN {r} RX RGB', [240, 360], 699900, ['']],
  ['Corsair', 'NAUTILUS {r} RS', [240, 360], 399900, ['', 'ARGB']],
  ['DeepCool', 'LE{r}', [240, 360], 299900, ['']],
  ['Lian Li', 'Galahad II Trinity {r}', [240, 360], 549900, ['', 'Blanco']],
  ['Cooler Master', 'MasterLiquid {r}L Core', [240, 360], 249900, ['', 'ARGB']],
  ['Thermalright', 'Frozen Notte {r}', [240, 360], 279900, ['', 'Blanco']],
  ['be quiet!', 'Pure Loop 2 {r}', [240, 280, 360], 449900, ['']],
];
for (const [brand, line, radiators, pesos, variants] of liquidCoolers) {
  for (const radiator of radiators) {
    for (const variant of variants) {
      const model = line.replace('{r}', radiator) + (variant ? ` ${variant}` : '');
      add('cooling', {
        name: `${brand} ${model}`, brand, model,
        summary: `Líquida · Radiador ${radiator} mm`,
        quickSpecs: ['LÍQUIDA', `${radiator}MM`],
        attributes: {
          cooling_type: 'liquid', supported_sockets: S4, radiator_mm: radiator,
          tdp_rating_w: radiator === 240 ? 250 : radiator === 280 ? 280 : 320,
        },
        pesos: pesos * (radiator === 240 ? 1 : radiator === 280 ? 1.12 : 1.25) * (variant ? 1.06 : 1),
      });
    }
  }
}

// --- Proveedores y ofertas -------------------------------------------------

const providers = [
  ['prov-tecnopartes', 'TP'], ['prov-mundopc', 'MP'],
  ['prov-clickpc', 'CK'], ['prov-megabytes', 'MB'], ['prov-hardzone', 'HZ'], ['prov-costapc', 'CP'],
];
const newProviders = [
  ['prov-clickpc', 'ClickPC Colombia S.A.S.', 'ClickPC', '900777888-4', 'ventas@clickpc.example'],
  ['prov-megabytes', 'MegaBytes Store S.A.S.', 'MegaBytes', '900888999-5', 'hola@megabytes.example'],
  ['prov-hardzone', 'HardZone Bogotá S.A.S.', 'HardZone', '901000111-6', 'pedidos@hardzone.example'],
  ['prov-costapc', 'Costa PC Barranquilla Ltda.', 'Costa PC', '901222333-7', 'info@costapc.example'],
];
const skuCount = Object.fromEntries(providers.map(([id]) => [id, 0]));
const offers = [];
for (const product of products) {
  const base = price(product.pesos);
  product.priceBase = base;
  const sellers = sample(providers, chance(0.3) ? 2 : 1);
  for (const [providerId, prefix] of sellers) {
    const offerPrice = sellers.length > 1 ? price(base) : base;
    const roll = rand();
    const stock = roll < 0.1 ? 0 : roll < 0.25 ? between(1, 5) : between(6, 60);
    const discounted = chance(0.15);
    const sku = `${prefix}-G${String(++skuCount[providerId]).padStart(4, '0')}`;
    offers.push({
      // Legible a propósito: el asistente copia estos ids entre herramientas.
      id: `off-${prefix.toLowerCase()}-${product.id}`, productId: product.id, providerId, sku,
      priceCents: offerPrice * 100,
      oldPriceCents: discounted ? price(offerPrice * (1.08 + rand() * 0.15)) * 100 : null,
      stock,
    });
  }
}
for (const offer of offers) {
  if (offer.oldPriceCents !== null && offer.oldPriceCents <= offer.priceCents) offer.oldPriceCents = null;
}

// --- SQL -------------------------------------------------------------------

const lines = [];
lines.push(
  '-- GENERADO por tool/catalog/generate_catalog.mjs: no editar a mano.',
  '-- Catálogo grande de desarrollo: piezas con atributos tipados y ofertas.',
  '-- Los nombres siguen líneas reales de cada marca, pero no todas las',
  '-- combinaciones existen; especificaciones aproximadas y precios de ejemplo.',
  `-- ${products.length} productos y ${offers.length} ofertas.`,
  '',
  'insert into public.providers (id, legal_name, display_name, tax_id, contact_email, status) values',
  newProviders.map((p) => `  (${p.map(sql).join(', ')}, 'active')`).join(',\n') + ';',
  '',
);

const chunk = (list, size) => Array.from({ length: Math.ceil(list.length / size) }, (_, i) => list.slice(i * size, i * size + size));

for (const group of chunk(products, 200)) {
  lines.push('insert into public.products (id, name, brand, model, category_code, summary, quick_specs, specs) values');
  lines.push(group.map((p) =>
    `  (${[p.id, p.name, p.brand, p.model, p.category, p.summary].map(sql).join(', ')}, ` +
    `${sql(p.quickSpecs)}, ${sql(JSON.stringify(p.specs))})`).join(',\n') + ';', '');
}

const attributeRows = products.flatMap((p) =>
  Object.entries(p.attributes).map(([key, value]) => {
    const num = typeof value === 'number' ? value : null;
    const txt = typeof value === 'string' ? value : null;
    const flag = typeof value === 'boolean' ? value : null;
    const list = Array.isArray(value) ? value : null;
    return `  (${sql(p.id)}, ${sql(key)}, ${sql(num)}::numeric, ${sql(txt)}, ${sql(flag)}::boolean, ${list ? sql(list) : 'null::text[]'})`;
  }));
for (const group of chunk(attributeRows, 1000)) {
  lines.push(
    'insert into public.product_attributes (product_id, attribute_id, value_number, value_text, value_bool, value_list)',
    'select v.product_id, d.id, v.num, v.txt, v.flag, v.list',
    'from (values',
    group.join(',\n'),
    ') as v (product_id, key, num, txt, flag, list)',
    'join public.products p on p.id = v.product_id',
    'join public.attribute_definitions d on d.category_code = p.category_code and d.key = v.key;',
    '',
  );
}

for (const group of chunk(offers, 300)) {
  lines.push('insert into public.offers');
  lines.push('  (id, product_id, provider_id, external_sku, price_cents, old_price_cents, stock_units, status, stock_synced_at)');
  lines.push('values');
  lines.push(group.map((o) =>
    `  (${[o.id, o.productId, o.providerId, o.sku, o.priceCents, o.oldPriceCents, o.stock].map(sql).join(', ')}, 'published', now())`)
    .join(',\n') + ';', '');
}

mkdirSync(dirname(outPath), { recursive: true });
writeFileSync(outPath, lines.join('\n'));

const byCategory = products.reduce((acc, p) => ({ ...acc, [p.category]: (acc[p.category] ?? 0) + 1 }), {});
console.log(`${products.length} productos, ${offers.length} ofertas, ${attributeRows.length} atributos`);
console.log(byCategory);
