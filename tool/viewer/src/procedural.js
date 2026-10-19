// Piezas generadas con geometría simple, a su tamaño real en milímetros.
// Se usan cuando la categoría no tiene modelo .glb o el archivo no carga.
// Cada pieza queda centrada en el origen y ya orientada en el mundo:
// X = fondo del gabinete (frente en -X), Y = alto, Z = ancho (vidrio en +Z).
import * as THREE from 'three';

const standard = (color, extra = {}) =>
  new THREE.MeshStandardMaterial({ color, roughness: 0.6, metalness: 0.2, ...extra });

const M = {
  chassis: standard(0x15181d, { metalness: 0.55, roughness: 0.45 }),
  backPanel: standard(0x0d1013, { metalness: 0.3, roughness: 0.7 }),
  chassisMesh: standard(0x1a1e24, {
    metalness: 0.4, roughness: 0.6, transparent: true, opacity: 0.35, depthWrite: false,
  }),
  glass: new THREE.MeshStandardMaterial({
    color: 0xd6f3ff, transparent: true, opacity: 0.035, roughness: 0.05, depthWrite: false,
  }),
  panel: standard(0x232830, { metalness: 0.5, roughness: 0.4 }),
  pcb: standard(0x2a323d, { roughness: 0.75 }),
  pcbGreen: standard(0x0f5a2a, { roughness: 0.7 }),
  slot: standard(0x2c333b),
  metal: standard(0xb9c1c9, { metalness: 0.85, roughness: 0.3 }),
  dark: standard(0x111418, { roughness: 0.5 }),
  shroud: standard(0x2a2f36, { metalness: 0.5, roughness: 0.35 }),
  accent: standard(0x3ee6e0, { emissive: 0x3ee6e0, emissiveIntensity: 0.9 }),
  accentDim: standard(0x2bb8b3, { emissive: 0x2bb8b3, emissiveIntensity: 0.35 }),
  edges: new THREE.LineBasicMaterial({ color: 0x3ee6e0, transparent: true, opacity: 0.4 }),
  ghostEdges: new THREE.LineBasicMaterial({ color: 0x3ee6e0, transparent: true, opacity: 0.18 }),
};

const noPick = (object) => {
  object.raycast = () => {};
  return object;
};

function box(w, h, d, material, x = 0, y = 0, z = 0) {
  const mesh = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), material);
  mesh.position.set(x, y, z);
  return mesh;
}

/** Cilindro con el eje en [axis] ('x', 'y' o 'z'). */
function cylinder(radius, length, material, axis, x = 0, y = 0, z = 0) {
  const mesh = new THREE.Mesh(new THREE.CylinderGeometry(radius, radius, length, 32), material);
  if (axis === 'x') mesh.rotation.z = Math.PI / 2;
  if (axis === 'z') mesh.rotation.x = Math.PI / 2;
  mesh.position.set(x, y, z);
  return mesh;
}

/** Aro de ventilador mirando hacia [axis]. */
function ring(radius, material, axis, x = 0, y = 0, z = 0) {
  const mesh = new THREE.Mesh(new THREE.TorusGeometry(radius, 2.5, 8, 48), material);
  if (axis === 'x') mesh.rotation.y = Math.PI / 2;
  if (axis === 'y') mesh.rotation.x = Math.PI / 2;
  mesh.position.set(x, y, z);
  return mesh;
}

function fan(size, axis, x, y, z) {
  const group = new THREE.Group();
  const r = size / 2 - 6;
  group.add(cylinder(r, 6, M.dark, axis));
  group.add(cylinder(r * 0.3, 8, M.shroud, axis));
  group.add(ring(r, M.accentDim, axis));
  group.position.set(x, y, z);
  return group;
}

function pcCase([D, H, W], node) {
  const group = new THREE.Group();
  const edges = new THREE.LineSegments(
    new THREE.EdgesGeometry(new THREE.BoxGeometry(D, H, W)),
    node.state === 'ghost' ? M.ghostEdges : M.edges,
  );
  group.add(noPick(edges));
  if (node.state === 'ghost') return group;

  const t = 4;
  group.add(box(D, H, t, M.backPanel, 0, 0, -W / 2 + t / 2)); // lado de la placa
  group.add(box(D, t, W, M.chassis, 0, -H / 2 + t / 2, 0)); // piso
  group.add(box(t, H, W, M.chassis, D / 2 - t / 2, 0, 0)); // trasera
  // Frente y techo de malla: no tapan el interior desde la cámara.
  group.add(box(t, H, W, M.chassisMesh, -D / 2 + t / 2, 0, 0));
  group.add(box(D, t, W, M.chassisMesh, 0, H / 2 - t / 2, 0));
  group.add(noPick(box(D, H, 1, M.glass, 0, 0, W / 2 - 0.5)));

  const fanSize = Math.min(120, W - 30, (H - 60) / 3);
  for (let i = 0; i < 3; i++) {
    const y = H / 2 - 50 - fanSize / 2 - i * (fanSize + 8);
    if (y - fanSize / 2 < -H / 2 + 20) break;
    group.add(fan(fanSize, 'x', -D / 2 + t + 14, y, 0));
  }
  return group;
}

// La caja de la placa incluye lo que sobresale; la placa va al fondo (-Z).
function motherboard([w, h, d], node) {
  const p = node.params || {};
  const group = new THREE.Group();
  const at = (u, v) => [w / 2 - u, h / 2 - v];
  const t = 3;
  const front = -d / 2 + t;
  group.add(box(w, h, t, M.pcb, 0, 0, -d / 2 + t / 2));
  const outline = new THREE.LineSegments(new THREE.EdgesGeometry(new THREE.BoxGeometry(w, h, t)), M.edges);
  outline.position.z = -d / 2 + t / 2;
  group.add(noPick(outline));

  const [sx, sy] = at(...(p.socket || [100, 90]));
  group.add(box(56, 56, 2, M.slot, sx, sy, front + 1));
  // Disipadores de los VRM, arriba y detrás del socket.
  group.add(box(80, 18, 22, M.shroud, sx, Math.min(sy + 52, h / 2 - 12), front + 11));
  group.add(box(20, 70, 22, M.shroud, Math.min(sx + 52, w / 2 - 34), sy + 8, front + 11));
  // Cubierta de los puertos traseros.
  const ioHeight = Math.min(150, h * 0.5);
  const [ix, iy] = at(12, ioHeight / 2);
  group.add(box(24, ioHeight, 36, M.dark, ix, iy, front + 18));
  group.add(box(2, ioHeight * 0.8, 2, M.accent, ix - 12, iy, front + 30));

  for (const u of p.dimms || []) {
    const [dx, dy] = at(u, p.dimmV || 95);
    group.add(box(6, 138, 7, M.slot, dx, dy, front + 3.5));
  }
  for (const v of p.pcie || []) {
    const [px, py] = at(60, v);
    group.add(box(90, 7, 9, M.slot, px, py, front + 4.5));
  }
  const [cx, cy] = at(w * 0.72, h * 0.75);
  group.add(box(45, 45, 10, M.shroud, cx, cy, front + 5));
  return group;
}

function cpu([w, h, d]) {
  const group = new THREE.Group();
  group.add(box(w, h, d * 0.4, M.pcbGreen, 0, 0, -d * 0.3));
  group.add(box(w * 0.8, h * 0.8, d * 0.6, M.metal, 0, 0, d * 0.2));
  return group;
}

function ram([x, y, z]) {
  const group = new THREE.Group();
  group.add(box(1.5, y, z - 3, M.pcbGreen, 0, 0, -1.5));
  group.add(box(2.5, y, z - 3, M.shroud, -x / 2 + 1.25, 0, -1.5));
  group.add(box(2.5, y, z - 3, M.shroud, x / 2 - 1.25, 0, -1.5));
  group.add(box(x, y, 3, M.accent, 0, 0, z / 2 - 1.5));
  return group;
}

function gpu([len, thick, height]) {
  const group = new THREE.Group();
  group.add(box(len - 4, thick - 6, height, M.shroud, -2, -1, 0));
  group.add(box(len - 4, 2, height, M.panel, -2, thick / 2 - 1, 0)); // placa trasera
  group.add(box(2, thick, height, M.metal, len / 2 - 1, 0, 0)); // soporte
  group.add(box(len * 0.55, thick * 0.3, 2, M.accent, -len * 0.15, -2, height / 2));
  const fans = len >= 270 ? 3 : 2;
  const size = Math.min(height - 16, (len - 30) / fans - 6);
  for (let i = 0; i < fans; i++) {
    const x = -len / 2 + 15 + (len - 30) * (i + 0.5) / fans;
    group.add(fan(size, 'y', x, -thick / 2 + 1, 0));
  }
  return group;
}

function airCooler([x, y, h]) {
  const group = new THREE.Group();
  group.add(box(40, 40, 8, M.metal, 0, 0, -h / 2 + 4));
  for (const dy of [-27, -9, 9, 27]) {
    group.add(cylinder(3, h - 14, M.metal, 'z', 4, dy, 4));
  }
  const finCount = Math.max(8, Math.floor((h - 40) / 3.5));
  const fins = new THREE.InstancedMesh(new THREE.BoxGeometry(x - 30, y, 0.8), M.metal, finCount);
  const matrix = new THREE.Matrix4();
  for (let i = 0; i < finCount; i++) {
    const z = -h / 2 + 34 + (i * (h - 37)) / (finCount - 1);
    fins.setMatrixAt(i, matrix.makeTranslation(15, 0, z));
  }
  group.add(fins);
  const fanSize = Math.min(y, h - 30);
  group.add(box(25, fanSize, fanSize, M.dark, -x / 2 + 12.5, 0, h / 2 - fanSize / 2));
  group.add(fan(fanSize, 'x', -x / 2 + 12.5, 0, h / 2 - fanSize / 2));
  return group;
}

function pump([w, , d]) {
  const group = new THREE.Group();
  group.add(cylinder(w / 2, d, M.dark, 'z'));
  group.add(ring(w / 2 - 6, M.accent, 'z', 0, 0, d / 2));
  return group;
}

function radiator([len, thick, depth]) {
  const group = new THREE.Group();
  group.add(box(len, thick / 2, depth, M.dark, 0, thick / 4, 0));
  const fans = Math.max(1, Math.round(len / 120));
  const size = Math.min(depth - 2, len / fans - 2);
  for (let i = 0; i < fans; i++) {
    const x = -len / 2 + (len * (i + 0.5)) / fans;
    group.add(box(size, thick / 2, size, M.shroud, x, -thick / 4, 0));
    group.add(fan(size, 'y', x, -thick / 2 + 3, 0));
  }
  return group;
}

function psu([x, y, z]) {
  const group = new THREE.Group();
  group.add(box(x, y, z, M.chassis));
  group.add(box(x * 0.6, y * 0.45, 1, M.panel, 0, 0, z / 2 + 0.5));
  group.add(box(x, 2, 1, M.accent, 0, y / 2 - 8, z / 2 + 0.6));
  return group;
}

function m2([x, y, z]) {
  const group = new THREE.Group();
  group.add(box(x, y, z * 0.4, M.pcbGreen, 0, 0, -z * 0.3));
  group.add(box(x * 0.3, y * 0.7, z * 0.6, M.dark, -x * 0.2, 0, z * 0.2));
  group.add(box(x * 0.3, y * 0.7, z * 0.6, M.dark, x * 0.2, 0, z * 0.2));
  return group;
}

function drive([x, y, z]) {
  const group = new THREE.Group();
  group.add(box(x, y, z, M.panel));
  group.add(box(x * 0.7, 1, z * 0.12, M.accentDim, 0, y / 2 + 0.5, z * 0.3));
  return group;
}

const builders = {
  case: pcCase, motherboard, cpu, ram, gpu, airCooler, pump, radiator, psu, m2,
  ssd25: drive, hdd35: drive,
};

/** Pieza generada para [node], o una caja si el tipo no se conoce. */
export function buildProcedural(node) {
  const build = builders[node.kind];
  const object = build ? build(node.size, node) : box(...node.size, M.panel);
  object.userData.procedural = true;
  return object;
}
