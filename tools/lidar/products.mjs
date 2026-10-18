// Step 2: grids -> DSM GeoTIFF/PNG, building_heights.csv, tree points CSV, canopy PNG.
// usage: node products.mjs <griddir> <repo>
import fs from 'fs';
import path from 'path';
import zlib from 'zlib';
import proj4 from 'proj4';
import { writeArrayBuffer } from 'geotiff';

const [gdir, repo] = process.argv.slice(2);
const g = JSON.parse(fs.readFileSync(path.join(gdir, 'grid.json')));
const load = (n) => new Float32Array(fs.readFileSync(path.join(gdir, n + '.f32')).buffer.slice(0));
const { X0, Y1, W, H } = g;
const dsm = load('dsm'), gnd = load('gnd'), veg = load('veg'), bld = load('bld');
const MGA = '+proj=utm +zone=56 +south +ellps=GRS80 +towgs84=0,0,0 +units=m +no_defs';
const toMGA = (lon, lat) => proj4('EPSG:4326', MGA, [lon, lat]);
const toLL = (e, n) => proj4(MGA, 'EPSG:4326', [e, n]);
const C = toMGA(153.0855133, -27.4436709);   // Riverlight centre
const ELEV = path.join(repo, 'reference/elevation');
const BIG = path.join(ELEV, 'lidar_2019');

// Fill gaps by repeated averaging of known neighbours (ground under buildings, DSM holes)
function fill(src, maxIter = 400) {
  const a = Float32Array.from(src);
  for (let it = 0; it < maxIter; it++) {
    const b = Float32Array.from(a); let left = 0;
    for (let r = 0; r < H; r++) for (let c = 0; c < W; c++) {
      const k = r * W + c; if (!isNaN(a[k])) continue;
      let s = 0, m = 0;
      for (const [dr, dc] of [[-1, 0], [1, 0], [0, -1], [0, 1], [-1, -1], [1, 1], [-1, 1], [1, -1]]) {
        const rr = r + dr, cc = c + dc;
        if (rr < 0 || cc < 0 || rr >= H || cc >= W) continue;
        const v = a[rr * W + cc]; if (!isNaN(v)) { s += v; m++; }
      }
      if (m >= 2 || (m && it > 50)) b[k] = s / m; else left++;
    }
    a.set(b); if (!left) break;
  }
  return a;
}
const gndF = fill(gnd);
// DSM holes: only small ones (a few cells), else stay empty
const dsmF = fill(dsm, 3);
console.log('ground empty cells', gnd.filter(isNaN).length, 'dsm empty', dsm.filter(isNaN).length, '->', dsmF.filter(isNaN).length);

// --- DSM in the same 1500 m box as the DEM (E 507700.., N ..6965170)
const BX = 507700, BY = 6965170, BW = 1500;
const box = new Float32Array(BW * BW).fill(NaN);
for (let r = 0; r < H; r++) for (let c = 0; c < W; c++) {
  const br = (BY - Y1) + r, bc = (X0 - BX) + c;
  if (br >= 0 && bc >= 0 && br < BW && bc < BW) box[br * BW + bc] = dsmF[r * W + c];
}
const geoKeys = { GTModelTypeGeoKey: 1, GTRasterTypeGeoKey: 1, ProjectedCSTypeGeoKey: 28356, ProjLinearUnitsGeoKey: 9001, GeographicTypeGeoKey: 4283 };
const tif = await writeArrayBuffer(box, { width: BW, height: BW, ...geoKeys, ModelPixelScale: [1, 1, 0], ModelTiepoint: [0, 0, 0, BX, BY, 0], GDAL_NODATA: 'nan' });
fs.writeFileSync(path.join(BIG, 'qld_dsm_2019_1m_1500m_mga56.tif'), Buffer.from(tif));

function png16(file, w, h, val) {   // greyscale 16-bit
  const raw = Buffer.alloc((w * 2 + 1) * h);
  for (let r = 0; r < h; r++) { raw[r * (w * 2 + 1)] = 0; for (let c = 0; c < w; c++) raw.writeUInt16BE(val(r, c), r * (w * 2 + 1) + 1 + c * 2); }
  writePng(file, w, h, 16, raw);
}
function png8(file, w, h, val) {
  const raw = Buffer.alloc((w + 1) * h);
  for (let r = 0; r < h; r++) for (let c = 0; c < w; c++) raw[r * (w + 1) + 1 + c] = val(r, c);
  writePng(file, w, h, 8, raw);
}
function writePng(file, w, h, depth, raw) {
  const crcT = []; for (let n = 0; n < 256; n++) { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; crcT[n] = c >>> 0; }
  const crc = (b) => { let c = 0xffffffff; for (const x of b) c = crcT[(c ^ x) & 255] ^ (c >>> 8); return (c ^ 0xffffffff) >>> 0; };
  const chunk = (t, d) => { const l = Buffer.alloc(4); l.writeUInt32BE(d.length); const td = Buffer.concat([Buffer.from(t), d]); const cb = Buffer.alloc(4); cb.writeUInt32BE(crc(td)); return Buffer.concat([l, td, cb]); };
  const ih = Buffer.alloc(13); ih.writeUInt32BE(w, 0); ih.writeUInt32BE(h, 4); ih[8] = depth; ih[9] = 0; ih[10] = 0; ih[11] = 0; ih[12] = 0;
  fs.writeFileSync(file, Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', ih), chunk('IDAT', zlib.deflateSync(raw, { level: 9 })), chunk('IEND', Buffer.alloc(0))]));
}
// 2 m, 750 px, max of each 2x2 (keeps thin roofs/poles). Height = px / 500 - 20. 0 = no data.
png16(path.join(ELEV, 'dsm_2019_2m_750px_u16.png'), 750, 750, (r, c) => {
  let m = NaN; for (const [a, b] of [[0, 0], [0, 1], [1, 0], [1, 1]]) { const v = box[(r * 2 + a) * BW + c * 2 + b]; if (!(m >= v)) m = isNaN(v) ? m : v; }
  return isNaN(m) ? 0 : Math.max(1, Math.min(65535, Math.round((m + 20) * 500)));
});

// --- OSM building heights
const bj = JSON.parse(fs.readFileSync(path.join(repo, 'reference/osm/osm_buildings.geojson')));
const inRings = (x, y, rings) => { let ins = false; for (const ring of rings) for (let i = 0, j = ring.length - 1; i < ring.length; j = i++) { const [xi, yi] = ring[i], [xj, yj] = ring[j]; if ((yi > y) !== (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) ins = !ins; } return ins; };
const bmask = new Uint8Array(W * H);
const q = (arr, p) => { const s = arr.slice().sort((a, b) => a - b); return s[Math.min(s.length - 1, Math.floor(p * (s.length - 1) + 0.5))]; };
const rows = [];
for (const f of bj.features) {
  const gm = f.geometry; if (!gm) continue;
  const polys = gm.type === 'Polygon' ? [gm.coordinates] : gm.type === 'MultiPolygon' ? gm.coordinates : [];
  if (!polys.length) continue;
  const rings = polys.flat().map((ring) => ring.map(([lon, lat]) => toMGA(lon, lat)));
  const outer = polys.map((p) => p[0]).flat().map(([lon, lat]) => toMGA(lon, lat));
  const ce = outer.reduce((s, p) => s + p[0], 0) / outer.length, cn = outer.reduce((s, p) => s + p[1], 0) / outer.length;
  const dist = Math.hypot(ce - C[0], cn - C[1]);
  if (dist > 1500) continue;
  const xs = outer.map((p) => p[0]), ys = outer.map((p) => p[1]);
  const cells = [];
  let inTile = 0, total = 0;
  for (let y = Math.floor(Math.min(...ys)); y <= Math.ceil(Math.max(...ys)); y++) for (let x = Math.floor(Math.min(...xs)); x <= Math.ceil(Math.max(...xs)); x++) {
    if (!inRings(x + 0.5, y + 0.5, rings)) continue;
    total++;
    const c = x - X0, r = Y1 - 1 - y;
    if (c < 0 || r < 0 || c >= W || r >= H) continue;
    inTile++; cells.push(r * W + c); bmask[r * W + c] = 1;
  }
  if (!total) { const c = Math.floor(ce) - X0, r = Y1 - 1 - Math.floor(cn); total = 1; if (c >= 0 && r >= 0 && c < W && r < H) { cells.push(r * W + c); inTile = 1; } }
  const p = f.properties || {};
  const name = (p.name || '').replace(/"/g, "'");
  const sd = p.start_date || '';
  const notes = [];
  let height = '', roof = '', ground = '';
  const ds = cells.map((k) => dsmF[k]).filter((v) => !isNaN(v));
  if (inTile < total * 0.5 || ds.length < Math.max(1, cells.length * 0.5)) notes.push('outside 2019 LiDAR tile');
  else {
    roof = q(ds, 0.9); ground = q(cells.map((k) => gndF[k]), 0.5);
    height = roof - ground;
    if (height < 2.5) notes.push('nothing tall here in 2019: may postdate the capture');
  }
  if (sd && parseInt(sd) > 2019) notes.push(`OSM start_date ${sd} postdates the 2019 capture`);
  rows.push({ id: f.id || p.id, name, building: p.building || '', levels: p['building:levels'] || '', osm_height: p.height || '', dist: dist.toFixed(0), cells: total,
    ground: ground === '' ? '' : ground.toFixed(2), roof: roof === '' ? '' : roof.toFixed(2), height: height === '' ? '' : height.toFixed(2), note: notes.join('; ') });
}
rows.sort((a, b) => (parseFloat(b.height) || -99) - (parseFloat(a.height) || -99));
const hdr = 'osm_id,name,building,osm_levels,osm_height_m,dist_from_riverlight_m,footprint_m2,ground_median_ahd_m,roof_p90_ahd_m,height_above_ground_m,note';
fs.writeFileSync(path.join(ELEV, 'building_heights.csv'), [hdr, ...rows.map((r) => [r.id, `"${r.name}"`, r.building, r.levels, r.osm_height, r.dist, r.cells, r.ground, r.roof, r.height, `"${r.note}"`].join(','))].join('\n') + '\n');
console.log('buildings', rows.length, 'measured', rows.filter((r) => r.height !== '').length);
console.log(rows.slice(0, 12).map((r) => `${r.height} ${r.name || r.id} lv${r.levels}`).join('\n'));
console.log('Riverlight:', rows.filter((r) => /riverlight/i.test(r.name)).map((r) => `${r.name} ${r.height} m (roof ${r.roof})`).join('\n'));

// --- canopy height + tree tops, outside buildings (OSM footprints + class-6 points, grown 1 m)
const notB = (k) => !bmask[k] && isNaN(bld[k]);
const chm = new Float32Array(W * H).fill(0);
for (let k = 0; k < W * H; k++) {
  if (isNaN(veg[k])) continue;
  const r = (k / W) | 0, c = k % W; let ok = true;
  for (let dr = -1; dr <= 1 && ok; dr++) for (let dc = -1; dc <= 1; dc++) { const rr = r + dr, cc = c + dc; if (rr >= 0 && cc >= 0 && rr < H && cc < W && !notB(rr * W + cc)) { ok = false; break; } }
  if (ok) chm[k] = Math.max(0, veg[k] - gndF[k]);
}
png8(path.join(ELEV, 'canopy_height_2019_1m_u8.png'), W, H, (r, c) => Math.min(255, Math.round(chm[r * W + c] * 4)));
const trees = [];
const R = 2;
for (let r = R; r < H - R; r++) for (let c = R; c < W - R; c++) {
  const k = r * W + c, h = chm[k]; if (h <= 3) continue;
  let top = true;
  for (let dr = -R; dr <= R && top; dr++) for (let dc = -R; dc <= R; dc++) { if (!dr && !dc) continue; const v = chm[(r + dr) * W + c + dc]; if (v > h || (v === h && (dr < 0 || (dr === 0 && dc < 0)))) { top = false; break; } }
  if (!top) continue;
  const [lon, lat] = toLL(X0 + c + 0.5, Y1 - r - 0.5);
  trees.push([lon.toFixed(7), lat.toFixed(7), h.toFixed(1), gndF[k].toFixed(2)].join(','));
}
fs.writeFileSync(path.join(ELEV, 'tree_points_2019.csv'), 'lon,lat,height_above_ground_m,ground_ahd_m\n' + trees.join('\n') + '\n');
console.log('trees', trees.length);
