// One-shot asset cleanup: removes white "halo" pixels on the
// transparent background of logo.png. The source PNG was exported
// with anti-aliased white edges that don't blend cleanly when the
// icon is placed on dark backgrounds. We treat any partially
// transparent pixel whose colour is near-white as fully transparent.
const fs = require('fs');
const path = require('path');
const { PNG } = require('pngjs');

const SRC = path.join(__dirname, '..', 'assets', 'icons', 'logo.png');
const OUT = SRC; // overwrite in place

const png = PNG.sync.read(fs.readFileSync(SRC));
const { width, height, data } = png;

// Per-pixel cleanup:
//   - If alpha > 0 but the RGB is "whitish" (i.e. r,g,b all close to
//     255), we drop the alpha to 0. This kills the white halo
//     produced by the source export.
//   - For partially transparent pixels that have a non-white colour
//     (the real, intentional antialiasing of the icon), we keep
//     them as-is.
const WHITE_MIN = 200; // r,g,b >= 200 counts as "white-ish" halo
let touched = 0;
for (let i = 0; i < data.length; i += 4) {
  const r = data[i], g = data[i + 1], b = data[i + 2], a = data[i + 3];
  if (a === 0) continue;                       // already transparent
  if (r >= WHITE_MIN && g >= WHITE_MIN && b >= WHITE_MIN) {
    // Pure / near-white pixel — flatten alpha. The image has no
    // legitimate white content (logo is on a transparent
    // background), so this is always halo material.
    if (a < 255 || !(r === 255 && g === 255 && b === 255)) {
      data[i + 3] = 0;
      touched++;
    }
  }
}

fs.writeFileSync(OUT, PNG.sync.write(png));
console.log(`Cleaned ${touched} halo pixels in ${path.relative(process.cwd(), OUT)} (${width}x${height})`);
