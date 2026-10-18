// Step 1: LAZ tile -> 1 m grids (DSM max, ground mean, veg max, building max), saved as raw Float32.
// usage: node grid.js <file.laz> <outdir>
const fs = require('fs');
const path = require('path');
const { createLazPerf } = require('laz-perf');

(async () => {
  const [laz, out] = process.argv.slice(2);
  const buf = fs.readFileSync(laz);
  const dv = new DataView(buf.buffer, buf.byteOffset, buf.byteLength);
  const sx = dv.getFloat64(131, true), sy = dv.getFloat64(139, true), sz = dv.getFloat64(147, true);
  const ox = dv.getFloat64(155, true), oy = dv.getFloat64(163, true), oz = dv.getFloat64(171, true);
  const minX = dv.getFloat64(187, true), minY = dv.getFloat64(203, true);
  const maxX = dv.getFloat64(179, true), maxY = dv.getFloat64(195, true);
  console.log('bounds', minX, minY, maxX, maxY);
  const LP = await createLazPerf();
  const z = new LP.LASZip();
  const fp = LP._malloc(buf.length);
  LP.HEAPU8.set(buf, fp);
  z.open(fp, buf.length);
  const n = z.getCount(), len = z.getPointLength(), fmt = z.getPointFormat();
  console.log('points', n, 'format', fmt, 'len', len);
  const dp = LP._malloc(len);
  const X0 = Math.floor(minX), Y1 = Math.ceil(maxY);
  const W = Math.ceil(maxX) - X0, H = Y1 - Math.floor(minY);
  const dsm = new Float32Array(W * H).fill(NaN);
  const veg = new Float32Array(W * H).fill(NaN);
  const bld = new Float32Array(W * H).fill(NaN);
  const gs = new Float64Array(W * H), gc = new Uint32Array(W * H);
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
    if (!(dsm[k] >= h)) dsm[k] = h;
    if (c === 2) { gs[k] += h; gc[k]++; }
    else if (c >= 3 && c <= 5) { if (!(veg[k] >= h)) veg[k] = h; }
    else if (c === 6) { if (!(bld[k] >= h)) bld[k] = h; }
  }
  console.log('classes', classes);
  const gnd = new Float32Array(W * H).fill(NaN);
  for (let k = 0; k < W * H; k++) if (gc[k]) gnd[k] = gs[k] / gc[k];
  fs.mkdirSync(out, { recursive: true });
  for (const [name, a] of Object.entries({ dsm, gnd, veg, bld }))
    fs.writeFileSync(path.join(out, name + '.f32'), Buffer.from(a.buffer));
  fs.writeFileSync(path.join(out, 'grid.json'), JSON.stringify({ X0, Y1, W, H }));
})();
