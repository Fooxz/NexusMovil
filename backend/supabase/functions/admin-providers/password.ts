// Contraseñas temporales de las cuentas de tienda. Se generan solo en el
// servidor, se devuelven una vez al administrador y NEXUS no las guarda (Auth
// guarda su hash). La tienda debe cambiarla en su primer ingreso.

// Sin caracteres que se confunden al dictarla o copiarla (l, I, O, 0, 1).
const LOWER = 'abcdefghijkmnpqrstuvwxyz';
const UPPER = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
const DIGITS = '23456789';
const SYMBOLS = '!@#$%*-_+=?';
const ALL = LOWER + UPPER + DIGITS + SYMBOLS;

export const TEMPORARY_PASSWORD_LENGTH = 20;

/** Entero uniforme en [0, max), sin el sesgo del módulo. */
function randomIndex(max: number): number {
  const limit = Math.floor(0x100000000 / max) * max;
  const buffer = new Uint32Array(1);
  do {
    crypto.getRandomValues(buffer);
  } while (buffer[0] >= limit);
  return buffer[0] % max;
}

/**
 * Contraseña aleatoria con minúsculas, mayúsculas, números y símbolos: cumple
 * cualquier `password_requirements` de Supabase Auth.
 */
export function generateTemporaryPassword(length = TEMPORARY_PASSWORD_LENGTH): string {
  const pick = (set: string) => set[randomIndex(set.length)];
  const chars = [pick(LOWER), pick(UPPER), pick(DIGITS), pick(SYMBOLS)];
  while (chars.length < length) chars.push(pick(ALL));
  // Fisher-Yates: las cuatro clases no quedan siempre al principio.
  for (let i = chars.length - 1; i > 0; i--) {
    const j = randomIndex(i + 1);
    [chars[i], chars[j]] = [chars[j], chars[i]];
  }
  return chars.join('');
}
