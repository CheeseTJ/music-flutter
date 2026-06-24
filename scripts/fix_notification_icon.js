// One-shot: clean halo from any ic_stat_music_note.png in res/drawable-*
const fs = require('fs');
const path = require('path');
const { PNG } = require('pngjs');

const sizes = ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi'];
const base = path.join(__dirname, '..', 'android', 'app', 'src', 'main', 'res');

for (const s of sizes) {
  const p = path.join(base, `drawable-${s}`, 'ic_stat_music_note.png');
  if (!fs.existsSync(p)) {
    console.log(`skip ${p} (not found)`);
    continue;
  }
  const png = PNG.sync.read(fs.readFileSync(p));
  const { width, height, data } = png;
  let touched = 0;
  // The status bar icon must be a flat white silhouette on a fully
  // transparent background. Anti-aliased edges often get exported
  // with subtle white fringing; flatten that.
  for (let i = 0; i < data.length; i += 4) {
    const r = data[i], g = data[i + 1], b = data[i + 2], a = data[i + 3];
    if (a === 0) continue;
    // If pixel is not pure white, collapse to fully transparent.
    // (Status bar icons should be solid white at full alpha.)
    if (r < 250 || g < 250 || b < 250) {
      data[i + 3] = 0;
      touched++;
    }
  }
  fs.writeFileSync(p, PNG.sync.write(png));
  console.log(`cleaned ${touched} pixels in ${path.relative(process.cwd(), p)} (${width}x${height})`);
}
