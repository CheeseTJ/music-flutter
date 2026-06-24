// Generate white-on-transparent notification icon from logo.png
// Android status bar icons MUST be white silhouette on transparent background
const fs = require('fs');
const path = require('path');
const { PNG } = require('pngjs');

const sizes = {
  'mdpi': 24,
  'hdpi': 36,
  'xhdpi': 48,
  'xxhdpi': 72,
  'xxxhdpi': 96,
};

const base = path.join(__dirname, '..', 'android', 'app', 'src', 'main', 'res');
const logoPath = path.join(__dirname, '..', 'assets', 'icons', 'logo.png');

if (!fs.existsSync(logoPath)) {
  console.error('logo.png not found at', logoPath);
  process.exit(1);
}

const logo = PNG.sync.read(fs.readFileSync(logoPath));
console.log(`Source logo: ${logo.width}x${logo.height}`);

// Simple nearest-neighbor resize
function resize(src, srcW, srcH, dstW, dstH) {
  const dst = Buffer.alloc(dstW * dstH * 4);
  for (let y = 0; y < dstH; y++) {
    for (let x = 0; x < dstW; x++) {
      const sx = Math.floor(x * srcW / dstW);
      const sy = Math.floor(y * srcH / dstH);
      const si = (sy * srcW + sx) * 4;
      const di = (y * dstW + x) * 4;
      // Convert to white silhouette: any opaque pixel becomes white
      const alpha = src[si + 3];
      if (alpha > 30) {
        dst[di] = 255;     // R
        dst[di + 1] = 255; // G
        dst[di + 2] = 255; // B
        dst[di + 3] = 255; // A
      } else {
        dst[di] = 0;
        dst[di + 1] = 0;
        dst[di + 2] = 0;
        dst[di + 3] = 0;
      }
    }
  }
  return { data: dst, width: dstW, height: dstH };
}

for (const [density, size] of Object.entries(sizes)) {
  const resized = resize(logo.data, logo.width, logo.height, size, size);
  const png = new PNG({ width: size, height: size });
  png.data = resized.data;

  const outDir = path.join(base, `drawable-${density}`);
  if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });
  const outPath = path.join(outDir, 'ic_stat_music_note.png');
  fs.writeFileSync(outPath, PNG.sync.write(png));
  console.log(`Generated ${outPath} (${size}x${size})`);
}

// Also generate default drawable
const defaultSize = 48;
const resized = resize(logo.data, logo.width, logo.height, defaultSize, defaultSize);
const png = new PNG({ width: defaultSize, height: defaultSize });
png.data = resized.data;
const defaultPath = path.join(base, 'drawable', 'ic_stat_music_note.png');
fs.writeFileSync(defaultPath, PNG.sync.write(png));
console.log(`Generated ${defaultPath} (${defaultSize}x${defaultSize})`);

console.log('Done! Notification icon generated as white-on-transparent silhouette.');
