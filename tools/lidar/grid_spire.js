// Spire / HSW / Story Bridge pass. One LAZ tile -> 1 m grids + sparse voxels for the hero boxes.
// usage: node grid_spire.js <file.laz> <outdir>      (needs npm laz-perf 0.0.6 on NODE_PATH)
// Grids (Float32, row 0 = north, NaN = empty): dsm (max of all but noise/water), gnd (mean of class 2),
// veg (max of 3-5), bld (max of 6), oth (max of every other kept class: bridges, wires, etc.)
// Voxels: every kept non-ground point inside a hero box -> unique voxel index (Int32 triplets ix, iy, iz).
const fs = require('fs');
const path = require('path');
const { createLazPerf } = require('laz-perf');

// MGA56 boxes: [E0, N0, Z0, E1, N1, Z1, voxel m]
const HERO = {
  bridge_hsw: [503150, 6961300, -10, 503950, 6962600, 110, 1.0],   // Story Bridge, HSW, Kangaroo Pt cliffs
  cathedral: [502890, 6962110, 0, 503040, 6962250, 80, 0.5],      // St John's Cathedral
  spire: [503000, 6962240, 0, 503090, 6962320, 160, 0.5],         // Spire itself (check the massing)
};

(async () => {
  const [laz, out] = process.argv.slice(2);
  const buf = fs.readFileSync(laz);
  const dv = new DataView(buf.buffer, buf.byteOffset, buf.byteLength);
  const sx = dv.getFloat64(131, true), sy = dv.getFloat64(139, true), sz = dv.getFloat64(147, true);
  const ox = dv.getFloat64(155, true), oy = dv.getFloat64(163, true), oz = dv.getFloat64(171, true);
  const maxX = dv.getFloat64(179, true), minX = dv.getFloat64(187, true);
  const maxY = dv.getFloat64(195, true), minY = dv.getFloat64(203, true);
  const LP = await createLazPerf();
  const z = new LP.LASZip();
  const fp = LP._malloc(buf.length);
  LP.HEAPU8.set(buf, fp);
  z.open(fp, buf.length);
  const n = z.getCount(), len = z.getPointLength(), fmt = z.getPointFormat();
  const dp = LP._malloc(len);
  const X0 = Math.floor(minX), Y1 = Math.ceil(maxY);
  const W = Math.ceil(maxX) - X0, H = Y1 - Math.floor(minY);
  const g = {};
  for (const k of ['dsm', 'veg', 'bld', 'oth']) g[k] = new Float32Array(W * H).fill(NaN);
  const gs = new Float64Array(W * H), gc = new Uint32Array(W * H);
  const vox = {};
  for (const k of Object.keys(HERO)) vox[k] = new Set();
  const classes = {};
  for (let i = 0; i < n; i++) {
    z.getPoint(dp);
    const p = new DataView(LP.HEAPU8.buffer, dp, len);
    const x = p.getInt32(0, true) * sx + ox, y = p.getInt32(4, true) * sy + oy, h = p.getInt32(8, true) * sz + oz;
    const c = fmt >= 6 ? p.getUint8(16) : (p.getUint8(15) & 31);
    classes[c] = (classes[c] || 0) + 1;
    if (c === 7 || c === 18 || c === 9) continue;   // noise, high noise, water
    const col = Math.floor(x - X0), row = Math.floor(Y1 - y);
    if (col < 0 || row < 0 || col >= W || row >= H) continue;
    const k = row * W + col;
    if (!(g.dsm[k] >= h)) g.dsm[k] = h;
    if (c === 2) { gs[k] += h; gc[k]++; continue; }
    const key = (c >= 3 && c <= 5) ? 'veg' : (c === 6 ? 'bld' : 'oth');
    if (!(g[key][k] >= h)) g[key][k] = h;
    if (c >= 3 && c <= 5) continue;                  // trees are not voxelised
    for (const [name, b] of Object.entries(HERO)) {
      if (x >= b[0] && x < b[3] && y >= b[1] && y < b[4] && h >= b[2] && h < b[5]) {
        const ix = Math.floor((x - b[0]) / b[6]), iy = Math.floor((y - b[1]) / b[6]), iz = Math.floor((h - b[2]) / b[6]);
        vox[name].add((ix * 4096 + iy) * 1024 + iz);
      }
    }
  }
  const gnd = new Float32Array(W * H).fill(NaN);
  for (let k = 0; k < W * H; k++) if (gc[k]) gnd[k] = gs[k] / gc[k];
  g.gnd = gnd;
  fs.mkdirSync(out, { recursive: true });
  for (const [name, a] of Object.entries(g)) fs.writeFileSync(path.join(out, name + '.f32'), Buffer.from(a.buffer));
  const vinfo = {};
  for (const [name, s] of Object.entries(vox)) {
    const a = new Int32Array(s.size * 3);
    let j = 0;
    for (const v of s) { a[j++] = Math.floor(v / (4096 * 1024)); a[j++] = Math.floor(v / 1024) % 4096; a[j++] = v % 1024; }
    fs.writeFileSync(path.join(out, 'vox_' + name + '.i32'), Buffer.from(a.buffer));
    vinfo[name] = s.size;
  }
  fs.writeFileSync(path.join(out, 'grid.json'), JSON.stringify({ X0, Y1, W, H, points: n, classes, voxels: vinfo, hero: HERO }));
  console.log(path.basename(laz), 'points', n, 'classes', JSON.stringify(classes), 'voxels', JSON.stringify(vinfo));
})();
