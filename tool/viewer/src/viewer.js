// Visor 3D del PC Builder (RF-090). Flutter calcula dónde va cada pieza
// (lib/features/pc_builder/presentation/viewer/scene_layout.dart) y envía la
// escena; aquí solo se cargan los modelos, se ajustan a su caja y se dibuja.
//
// Mensajes de Flutter: {type: 'scene', case: {size}, nodes: [...]}
// Mensajes a Flutter: ready, loaded {failed}, tap {part}, error {message}
import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { MeshoptDecoder } from 'three/addons/libs/meshopt_decoder.module.js';
import { onMessage, send } from './bridge.js';
import { buildProcedural } from './procedural.js';

const STATE_COLORS = { error: 0xff4d6d, selected: 0x3ee6e0 };
const TAP_TOLERANCE_PX = 6;

let renderer;
try {
  renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true, powerPreference: 'low-power' });
} catch (error) {
  send({ type: 'error', message: 'webgl' });
  throw error;
}
renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
renderer.setClearColor(0x000000, 0);
document.body.appendChild(renderer.domElement);
renderer.domElement.addEventListener('webglcontextlost', () => send({ type: 'error', message: 'webgl' }));

const scene = new THREE.Scene();
scene.add(new THREE.HemisphereLight(0xe8f4ff, 0x30363f, 2.4));
const key = new THREE.DirectionalLight(0xffffff, 2.8);
key.position.set(-400, 700, 900);
scene.add(key);
const rim = new THREE.DirectionalLight(0x3ee6e0, 0.8);
rim.position.set(500, 200, -600);
scene.add(rim);
const fill = new THREE.DirectionalLight(0xffffff, 1.2);
fill.position.set(200, -100, 900);
scene.add(fill);

const camera = new THREE.PerspectiveCamera(35, 1, 10, 8000);
camera.position.set(-520, 330, 820);
const controls = new OrbitControls(camera, renderer.domElement);
controls.enablePan = false;
controls.addEventListener('change', requestRender);

// Se dibuja solo cuando algo cambia: sin bucle de animación, el visor no
// gasta batería mientras nadie lo toca (R9).
let frame = 0;
function requestRender() {
  if (frame) return;
  frame = requestAnimationFrame(() => {
    frame = 0;
    renderer.render(scene, camera);
  });
}

function resize() {
  const width = window.innerWidth;
  const height = window.innerHeight;
  if (!width || !height) return;
  renderer.setSize(width, height, false);
  camera.aspect = width / height;
  camera.updateProjectionMatrix();
  requestRender();
}
window.addEventListener('resize', resize);
resize();

/** Encuadra el gabinete entero desde adelante a la izquierda, por el vidrio. */
function fitCamera([d, h, w]) {
  const radius = 0.5 * Math.hypot(d, h, w);
  const vertical = THREE.MathUtils.degToRad(camera.fov);
  const horizontal = 2 * Math.atan(Math.tan(vertical / 2) * camera.aspect);
  const distance = (radius / Math.sin(Math.min(vertical, horizontal) / 2)) * 0.9;
  camera.position.copy(new THREE.Vector3(-0.4, 0.32, 0.86).normalize().multiplyScalar(distance));
  controls.target.set(0, 0, 0);
  controls.minDistance = radius * 0.8;
  controls.maxDistance = distance * 2;
  controls.update();
}

const loader = new GLTFLoader();
loader.setMeshoptDecoder(MeshoptDecoder);
const models = new Map();

function loadModel(url) {
  if (!models.has(url)) {
    const loading = loader.loadAsync(url).then((gltf) => gltf.scene);
    loading.catch(() => models.delete(url)); // se reintenta en la próxima escena
    models.set(url, loading);
  }
  return models.get(url);
}

const toRadians = (degrees = [0, 0, 0]) => degrees.map((d) => THREE.MathUtils.degToRad(d));

/**
 * Coloca un modelo descargado en la caja de su nodo: aplica la rotación del
 * modelo (para dejarlo en la orientación de su categoría) y la de la ranura,
 * lo escala sin deformarlo hasta que quepa y lo alinea según `align`.
 */
function placeModel(object, node) {
  const inner = new THREE.Group();
  inner.add(object);
  inner.rotation.set(...toRadians(node.modelRotation));
  const holder = new THREE.Group();
  const oriented = new THREE.Group();
  oriented.add(inner);
  oriented.rotation.set(...toRadians(node.rotation));
  holder.add(oriented);

  holder.updateMatrixWorld(true);
  const bounds = new THREE.Box3().setFromObject(holder);
  const size = bounds.getSize(new THREE.Vector3());
  let scale = Infinity;
  for (let axis = 0; axis < 3; axis++) {
    const extent = size.getComponent(axis);
    if (extent > 1e-6) scale = Math.min(scale, node.size[axis] / extent);
  }
  holder.scale.setScalar(Number.isFinite(scale) ? scale : 1);

  holder.updateMatrixWorld(true);
  bounds.setFromObject(holder);
  const offset = [0, 1, 2].map((axis) => {
    const half = node.size[axis] / 2;
    const min = bounds.min.getComponent(axis);
    const max = bounds.max.getComponent(axis);
    switch ((node.align || [])[axis]) {
      case 'min': return node.center[axis] - half - min;
      case 'max': return node.center[axis] + half - max;
      default: return node.center[axis] - (min + max) / 2;
    }
  });
  holder.position.set(...offset);
  return holder;
}

function placeProcedural(object, node) {
  object.position.set(...node.center);
  return object;
}

/** Colorea la pieza según su estado; del gabinete, solo los bordes. */
function tint(object, state, edgesOnly) {
  const color = STATE_COLORS[state];
  if (color === undefined) return;
  const tinted = (material) => {
    const copy = material.clone();
    if (copy.emissive) {
      copy.emissive = new THREE.Color(color);
      copy.emissiveIntensity = 0.5;
    } else if (copy.color) {
      copy.color.lerp(new THREE.Color(color), 0.5);
    }
    copy.userData.owned = true;
    return copy;
  };
  object.traverse((child) => {
    if (child.isLineSegments) {
      child.material = child.material.clone();
      child.material.color = new THREE.Color(color);
      child.material.opacity = 0.9;
      child.material.userData.owned = true;
      return;
    }
    // El vidrio y la malla teñidos taparían todo el interior.
    if (edgesOnly || !child.isMesh || child.material.transparent) return;
    child.material = Array.isArray(child.material)
      ? child.material.map(tinted)
      : tinted(child.material);
  });
}

/** Libera lo que creó esta escena; los modelos en caché se conservan. */
function dispose(root) {
  root.traverse((child) => {
    if (!child.isMesh && !child.isLineSegments) return;
    let procedural = false;
    for (let node = child; node; node = node.parent) {
      if (node.userData.procedural) procedural = true;
    }
    if (procedural) child.geometry.dispose();
    const materials = Array.isArray(child.material) ? child.material : [child.material];
    for (const material of materials) if (material.userData.owned) material.dispose();
  });
}

let root = null;
let version = 0;
let framed = false;

async function showScene(message) {
  const current = ++version;
  const group = new THREE.Group();
  const failed = new Set();

  await Promise.all(message.nodes.map(async (node) => {
    let object = null;
    if (node.url) {
      try {
        object = placeModel((await loadModel(node.url)).clone(true), node);
      } catch {
        failed.add(node.part);
      }
    }
    object ??= placeProcedural(buildProcedural(node), node);
    tint(object, node.state, node.kind === 'case');
    object.userData.part = node.part;
    group.add(object);
  }));

  if (current !== version) {
    dispose(group);
    return;
  }
  if (root) {
    scene.remove(root);
    dispose(root);
  }
  root = group;
  scene.add(root);
  if (!framed) {
    fitCamera(message.case.size);
    framed = true;
  }
  requestRender();
  send({ type: 'loaded', failed: [...failed] });
}

// Un toque sin arrastrar sobre una pieza avisa a Flutter cuál fue.
const raycaster = new THREE.Raycaster();
let pointerDown = null;
renderer.domElement.addEventListener('pointerdown', (event) => {
  pointerDown = { x: event.clientX, y: event.clientY };
});
renderer.domElement.addEventListener('pointerup', (event) => {
  const start = pointerDown;
  pointerDown = null;
  if (!start || !root) return;
  if (Math.hypot(event.clientX - start.x, event.clientY - start.y) > TAP_TOLERANCE_PX) return;
  const rect = renderer.domElement.getBoundingClientRect();
  raycaster.setFromCamera(new THREE.Vector2(
    ((event.clientX - rect.left) / rect.width) * 2 - 1,
    -((event.clientY - rect.top) / rect.height) * 2 + 1,
  ), camera);
  for (const hit of raycaster.intersectObject(root, true)) {
    for (let node = hit.object; node; node = node.parent) {
      if (node.userData.part) {
        send({ type: 'tap', part: node.userData.part });
        return;
      }
    }
  }
});

onMessage((message) => {
  if (message.type === 'scene') {
    showScene(message).catch((error) => send({ type: 'error', message: String(error) }));
  }
});

// Para revisar el visor sin la app: viewer.html#scene=<JSON codificado>.
if (location.hash.startsWith('#scene=')) {
  window.nexusViewer.receive(decodeURIComponent(location.hash.slice('#scene='.length)));
}

send({ type: 'ready' });
