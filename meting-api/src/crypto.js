// crypto.js — Pure JS crypto helpers for Cloudflare Workers
export const encoder = new TextEncoder();

function hexToBytes(hex) {
  const bytes = new Uint8Array(hex.length / 2);
  for (let i = 0; i < bytes.length; i++) bytes[i] = parseInt(hex.substr(i * 2, 2), 16);
  return bytes;
}
function bytesToHex(bytes) {
  return Array.from(bytes).map(b => b.toString(16).padStart(2, '0')).join('');
}

// Generate random ASCII string of given length
export function randomKey(len) {
  const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  const bytes = crypto.getRandomValues(new Uint8Array(len));
  let result = '';
  for (let i = 0; i < len; i++) result += chars[bytes[i] % chars.length];
  return result;
}

// Base64 encode bytes
export function base64(bytes) {
  let binary = '';
  for (let i = 0; i < bytes.length; i++) binary += String.fromCharCode(bytes[i]);
  return btoa(binary);
}

// AES-128-CBC encrypt — key is raw ASCII string
export async function aesEncrypt(text, keyStr, ivHex) {
  const keyBytes = encoder.encode(keyStr);
  const ivBytes = hexToBytes(ivHex);
  const dataBytes = encoder.encode(text);

  const key = await crypto.subtle.importKey('raw', keyBytes, { name: 'AES-CBC' }, false, ['encrypt']);
  const encrypted = await crypto.subtle.encrypt({ name: 'AES-CBC', iv: ivBytes }, key, dataBytes);
  return new Uint8Array(encrypted);
}

// BigInt RSA encrypt (for netease weapi)
export function rsaEncrypt(text, exponent, modulus) {
  text = text.split('').reverse().join('');
  const e = BigInt('0x' + exponent);
  const n = BigInt('0x' + modulus);
  let hex = '';
  for (let i = 0; i < text.length; i++) hex += text.charCodeAt(i).toString(16).padStart(2, '0');
  const m = BigInt('0x' + hex);
  const c = modPow(m, e, n);
  let result = c.toString(16);
  if (result.length < 256) result = result.padStart(256, '0');
  return result;
}

function modPow(base, exp, mod) {
  let result = 1n;
  base = base % mod;
  while (exp > 0n) {
    if (exp & 1n) result = (result * base) % mod;
    exp >>= 1n;
    base = (base * base) % mod;
  }
  return result;
}

// MD5 (pure JS, RFC1321)
export function md5(string) {
  function r(n, c) { return (n << c) | (n >>> (32 - c)); }
  function q(n, c) { return (n & c) | (~n & (4294967295 ^ c)); }
  function p(n, c) { return (n & (4294967295 ^ c)) | (~n & c); }
  function o(n, c) { return n ^ c; }
  function l(n, c) { return c ^ (n | ~c); }

  let x = Array.from({ length: (((string.length + 8) >> 6) + 1) * 16 }, (_, i) =>
    i < (string.length >> 2) ? string.charCodeAt(i * 4) | (string.charCodeAt(i * 4 + 1) << 8) | (string.charCodeAt(i * 4 + 2) << 16) | (string.charCodeAt(i * 4 + 3) << 24)
    : i === (string.length >> 2) ? (string.charCodeAt(i * 4) | (string.charCodeAt(i * 4 + 1) << 8) | (string.charCodeAt(i * 4 + 2) << 16) | 128) << ((string.length % 4) * 8)
    : 0
  );
  x[x.length - 2] = string.length * 8;

  let a = 1732584193, b = 4023233417, c = 2562383102, d = 271733878;
  for (let k = 0; k < x.length; k += 16) {
    let A = a, B = b, C = c, D = d;
    const fn = [q,q,q,p,p,p,p,q,q,q,p,p,o,q,l,p,q,q,p,q,o,q,l,l,l,p,p,q,p,q,q,p,o,l,o,o,o,o,o,l,o,q,o,q,o,q,q,q,q,q,q,l,q,l,o,o,l,q,q,l,q,q,l,q,q,o,q,q,q,q,l,q,o,l,o,q];
    const S = [7,12,17,22,5,9,14,20,4,11,16,23,6,10,15,21];
    for (let i = 0; i < 64; i++) {
      let fni = fn[i], si = S[fni], g = i < 16 ? i : i < 32 ? (5 * i + 1) % 16 : i < 48 ? (3 * i + 5) % 16 : (7 * i) % 16;
      let fval = fni === q ? q(B, C, D) : fni === p ? p(B, C, D) : fni === o ? B ^ C ^ D : l(B, C, D);
      let T = (A + fval + x[k + g] + Math.floor(Math.abs(Math.sin(i + 1)) * 4294967296)) >>> 0;
      let rotated = ((T << si) | (T >>> (32 - si))) >>> 0;
      A = D; D = C; C = B; B = (B + rotated) >>> 0;
    }
    a = (a + A) >>> 0; b = (b + B) >>> 0; c = (c + C) >>> 0; d = (d + D) >>> 0;
  }
  return [a,b,c,d].map(v => ('0000000' + v.toString(16)).slice(-8)).join('');
}
