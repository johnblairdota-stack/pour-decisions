#!/usr/bin/env python3
"""The real lie of the land round Riverlight, for scripts/terrain.gd.

Reads the 2019 LiDAR bare-ground heightmap (reference/elevation, metres above
AHD) and the map data (data/riverlight_osm.json), and writes, in the game's
map frame (metres; x = west, z = north; origin Riverlight's centroid):

  data/terrain.bin   float32 heights, GRID x GRID nodes, CELL m apart, row by
                     row from z = -HALF (south) up, x = -HALF first in each row
  data/terrain.json  where the grid is, and what was pinned
  data/ground_3d.bin the map's ground (data/riverlight_osm.json "ground"),
                     cut along a STEP m grid so it can follow the heights
                     (see write_ground)

What it keeps put, so nothing else in the game moves:

  * game height = AHD - DATUM, so the riverwalk (3.5 to 4 m AHD) stays where
    the flat ground was, at about 0, and the river stays at Water.RIVER_Y
  * the site pad (and the bits of MacArthur Avenue and Angora Road the
    trucks use) at exactly 0, easing out to the real ground
  * the CityCat terminal's bank at 0, for the gangway
  * every street flat across, following a long smooth line along the
    ground (so crossings meet), the verges eased onto it
  * each building on a level pad (the median of the ground under it)
  * dry land never closer than 0.5 m above the river
  * out at the heightmap's edges, back to 0 (the flat world beyond)

    python3 tools/terrain_to_game.py     (needs numpy, scipy, Pillow, pyproj)

Elevation: (c) State of Queensland, CC BY 4.0 (reference/elevation/README.md).
"""
import json
import math
import os
import re
import struct

import numpy as np
from PIL import Image, ImageDraw
from pyproj import Transformer
from scipy import ndimage
from scipy.spatial import cKDTree

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEM = os.path.join(ROOT, "reference", "elevation", "heightmap_2m_750px_u16.png")
OSM = os.path.join(ROOT, "data", "riverlight_osm.json")
OUT_BIN = os.path.join(ROOT, "data", "terrain.bin")
OUT_JSON = os.path.join(ROOT, "data", "terrain.json")
OUT_GROUND = os.path.join(ROOT, "data", "ground_3d.bin")

# the heightmap: MGA zone 56, 2 m pixels, top-left corner, height = px / 1000 - 20
DEM_E0, DEM_N1, DEM_PX = 507700.0, 6965170.0, 2.0
# as tools/osm_to_game.py
LAT0, LON0 = -27.4436709, 153.0855133
TURN = -14.4
M_LAT = 110860.0
M_LON = 111320.0 * math.cos(math.radians(LAT0))

HALF = 800.0         # the grid reaches this far each way
CELL = 2.0
GRID = int(HALF * 2 / CELL) + 1
DATUM = 3.5          # AHD of the game's 0
RIVER_Y = -2.5       # scripts/water.gd
DRY_MIN = RIVER_Y + 0.5
EDGE_FADE = 140.0    # eased back to 0 over this, inside the heightmap's edge

# the site, as tools/osm_to_game.py SITE_CUT (x0, z0, x1, z1) and the truck
# road; flat 0 this far round it, then easing out
SITE = [(-45, -14, 50, 24), (-44.5, 21.1, 35.5, 30.1)]
SITE_FLAT = 40.0
SITE_EASE = 60.0
FERRY_FLAT, FERRY_EASE = 20.0, 25.0
ROAD_SMOOTH = 12.0   # m, the gaussian the streets' long line follows
ROAD_EDGE = 1.5      # past the road's own width, kerb and footpath on its level
ROAD_EASE = 6.0
PAD_EASE = 4.0
PARK_ZONE = 30.0     # round the 4x4 park's tracks and challenges: the ground
PARK_SMOOTH = 15.0   # smoothed out under them, so they keep their shape

STEP = 8.0           # the ground mesh is cut along this grid


def game_to_lonlat(x, z):
    e2, n2 = -x, z
    a = math.radians(-TURN)
    e = e2 * math.cos(a) + n2 * math.sin(a)
    n = -e2 * math.sin(a) + n2 * math.cos(a)
    return LON0 + e / M_LON, LAT0 + n / M_LAT


def smoothstep(t):
    t = np.clip(t, 0.0, 1.0)
    return t * t * (3 - 2 * t)


def node_xz():
    v = -HALF + np.arange(GRID) * CELL
    return np.meshgrid(v, v)      # X[row, col] = x at col, Z[row, col] = z at row


def sample_dem(X, Z):
    raw = np.array(Image.open(DEM)).astype(np.float64)
    dem = np.where(raw > 0, raw / 1000.0 - 20.0, np.nan)
    a = math.radians(-TURN)
    e2, n2 = -X, Z
    e = e2 * math.cos(a) + n2 * math.sin(a)
    n = -e2 * math.sin(a) + n2 * math.cos(a)
    lon = LON0 + e / M_LON
    lat = LAT0 + n / M_LAT
    tr = Transformer.from_crs("EPSG:4326", "EPSG:28356", always_xy=True)
    E, N = tr.transform(lon, lat)
    col = (E - DEM_E0) / DEM_PX - 0.5
    row = (DEM_N1 - N) / DEM_PX - 0.5
    h = ndimage.map_coordinates(np.nan_to_num(dem, nan=-999.0), [row, col], order=1, mode="constant", cval=-999.0)
    inside = (col >= 0) & (row >= 0) & (col <= dem.shape[1] - 1) & (row <= dem.shape[0] - 1)
    h = np.where(inside & (h > -100), h, np.nan)
    # how far inside the heightmap's edge each node is (m)
    edge = np.minimum.reduce([col, row, dem.shape[1] - 1 - col, dem.shape[0] - 1 - row]) * DEM_PX
    return h, edge


def raster(polys, fill=1):
    """Polygons (lists of (x, z)) onto the node grid."""
    im = Image.new("L", (GRID, GRID), 0)
    dr = ImageDraw.Draw(im)
    for p in polys:
        if len(p) >= 3:
            dr.polygon([((x + HALF) / CELL, (z + HALF) / CELL) for x, z in p], fill=fill)
    return np.array(im) > 0


def dist_outside(mask):
    """Metres from each node to the nearest node in `mask` (0 inside)."""
    return ndimage.distance_transform_edt(~mask) * CELL


def wet_mask(d):
    tris = []
    for g in d["ground"]:
        if g["kind"] in ("water", "drain"):
            t = g["tris"]
            for i in range(0, len(t) - 5, 6):
                tris.append([(t[i], t[i + 1]), (t[i + 2], t[i + 3]), (t[i + 4], t[i + 5])])
    return raster(tris)


def densify(pts, step):
    out = []
    for (x0, z0), (x1, z1) in zip(pts, pts[1:]):
        n = max(1, int(math.ceil(math.hypot(x1 - x0, z1 - z0) / step)))
        for k in range(n):
            out.append((x0 + (x1 - x0) * k / n, z0 + (z1 - z0) * k / n))
    out.append(tuple(pts[-1]))
    return out


def park_lines():
    """The 4x4 park's tracks and ways in (scripts/park4x4.gd TRACKS and
    FEATURES, scripts/park_ways.gd WAY_IN), read from the scripts."""
    out = []
    for name, start in (("park4x4.gd", "const TRACKS"), ("park_ways.gd", "const WAY_IN")):
        src = open(os.path.join(ROOT, "scripts", name)).read()
        block = src[src.index(start):]
        block = block[:block.index("\n}") if start.endswith("WAY_IN") else block.index("\n]")]
        for line in re.split(r"\],?\s*(?:#[^\n]*)?\n", block):
            pts = [(float(a), float(b)) for a, b in re.findall(r"Vector2\(([-\d.]+),\s*([-\d.]+)\)", line)]
            if len(pts) > 1:
                out.append(pts)
    src = open(os.path.join(ROOT, "scripts", "park4x4.gd")).read()
    for a, b in re.findall(r'\["(?:hill|bog|sand|moguls|logs)", Vector2\(([-\d.]+),\s*([-\d.]+)\)', src):
        out.append([(float(a), float(b)), (float(a) + 0.1, float(b))])
    return out


def blend(h, target, w):
    return h * (1.0 - w) + target * w


def build(d):
    X, Z = node_xz()
    raw, edge = sample_dem(X, Z)
    h = raw - DATUM
    have = ~np.isnan(h)
    wet = wet_mask(d)
    # the water's own nodes take the nearest dry ground (so a bridge or a bank
    # top over them sits at the bank's height), as do any holes
    dry = have & ~wet
    idx = ndimage.distance_transform_edt(~dry, return_distances=False, return_indices=True)
    h = h[idx[0], idx[1]]
    # (narrow ditches and pits filled: the drains that matter are water in
    # the map; and LiDAR ground still has kerbs and garden walls in it)
    h = ndimage.grey_closing(h, size=(5, 5))
    h = ndimage.gaussian_filter(h, 1.0)
    # back to 0 at the heightmap's edge
    h = blend(h, 0.0, 1.0 - smoothstep(edge / EDGE_FADE))

    # the 4x4 park: its tracks and challenges keep their shape on a smoothed
    # ground (scripts/park4x4.gd's heights go on top of this)
    lines = park_lines()
    im = Image.new("L", (GRID, GRID), 0)
    dr = ImageDraw.Draw(im)
    for ln in lines:
        dr.line([((x + HALF) / CELL, (z + HALF) / CELL) for x, z in ln], fill=1, width=3)
    zone = 1.0 - smoothstep((dist_outside(np.array(im) > 0) - PARK_ZONE) / 20.0)
    h = blend(h, ndimage.gaussian_filter(h, PARK_SMOOTH / CELL), zone)
    print("4x4 park: %d tracks and challenges" % len(lines))

    # buildings, the golf course's ponds and the sports fields on level pads
    pads = [b["pts"] for b in d["buildings"]] + [a["pts"] for a in d["areas"] if a["kind"] in ("golf_water", "pitch")]
    for p in pads:
        if len(p) < 3:
            continue
        xs = [q[0] for q in p]
        zs = [q[1] for q in p]
        if max(abs(min(xs)), abs(max(xs)), abs(min(zs)), abs(max(zs))) > HALF - PAD_EASE * 2:
            continue
        c0 = max(0, int((min(xs) + HALF) / CELL) - 6)
        c1 = min(GRID, int((max(xs) + HALF) / CELL) + 7)
        r0 = max(0, int((min(zs) + HALF) / CELL) - 6)
        r1 = min(GRID, int((max(zs) + HALF) / CELL) + 7)
        im = Image.new("L", (c1 - c0, r1 - r0), 0)
        ImageDraw.Draw(im).polygon([((x + HALF) / CELL - c0, (z + HALF) / CELL - r0) for x, z in p], fill=1)
        m = np.array(im) > 0
        if not m.any():
            continue
        sub = h[r0:r1, c0:c1]
        # (level with the ground just round it: under a big roof the LiDAR's
        # ground is guesswork)
        out = dist_outside(m)
        ring = (out > 1.0) & (out < 8.0)
        level = float(np.median(sub[ring] if ring.any() else sub[m]))
        w = 1.0 - smoothstep(out / PAD_EASE)
        h[r0:r1, c0:c1] = blend(sub, level, w)

    # the streets: flat across, along a long smooth line
    smooth = ndimage.gaussian_filter(h, ROAD_SMOOTH / CELL)
    pts, half = [], []
    for r in d["roads"] + [dict(a, bridge=False) for a in d["aisles"]]:
        if r.get("bridge") or len(r["pts"]) < 2:
            continue
        for q in densify(r["pts"], 1.0):
            pts.append(q)
            half.append(r["w"] / 2.0 + ROAD_EDGE)
    pts = np.array(pts)
    half = np.array(half)
    ins = (np.abs(pts[:, 0]) < HALF) & (np.abs(pts[:, 1]) < HALF)
    pts, half = pts[ins], half[ins]
    tree = cKDTree(pts)
    nodes = np.column_stack([X.ravel(), Z.ravel()])
    # (the widest corridor any road has, to look that far)
    reach = float(half.max()) + ROAD_EASE
    dist, near = tree.query(nodes, k=8, distance_upper_bound=reach)
    w = np.zeros(nodes.shape[0])
    tgt = np.zeros(nodes.shape[0])
    sm = ndimage.map_coordinates(smooth, [(pts[:, 1] + HALF) / CELL, (pts[:, 0] + HALF) / CELL], order=1)
    for k in range(dist.shape[1]):
        ok = np.isfinite(dist[:, k])
        j = near[ok, k]
        wk = 1.0 - smoothstep((dist[ok, k] - half[j]) / ROAD_EASE)
        better = wk > w[ok]
        sel = np.where(ok)[0][better]
        w[sel] = wk[better]
        tgt[sel] = sm[j[better]]
    h = blend(h, tgt.reshape(h.shape), w.reshape(h.shape))

    # the site pad and the CityCat's bank at 0
    site = np.zeros_like(h, dtype=bool)
    for x0, z0, x1, z1 in SITE:
        site |= (X >= x0) & (X <= x1) & (Z >= z0) & (Z <= z1)
    h = blend(h, 0.0, 1.0 - smoothstep((dist_outside(site) - SITE_FLAT) / SITE_EASE))
    for fe in d.get("ferry", []):
        ex, ez = fe["edge"]
        r = np.hypot(X - ex, Z - ez)
        h = blend(h, 0.0, 1.0 - smoothstep((r - FERRY_FLAT) / FERRY_EASE))

    low = (h < DRY_MIN) & ~wet
    print("dry nodes lifted to %.1f: %d (%.1f%%)" % (DRY_MIN, low.sum(), 100.0 * low.mean()))
    h = np.maximum(h, DRY_MIN)
    return X, Z, h, raw, wet


# ---------------------------------------------------------------- the ground

def height_at(h, x, z):
    c = (np.atleast_1d(np.asarray(x, dtype=float)) + HALF) / CELL
    r = (np.atleast_1d(np.asarray(z, dtype=float)) + HALF) / CELL
    return ndimage.map_coordinates(h, [r, c], order=1, mode="nearest")


def clip_poly(poly, axis, val, keep_less):
    out = []
    n = len(poly)
    for i in range(n):
        a = poly[i]
        b = poly[(i + 1) % n]
        ina = (a[axis] <= val) if keep_less else (a[axis] >= val)
        inb = (b[axis] <= val) if keep_less else (b[axis] >= val)
        if ina:
            out.append(a)
        if ina != inb:
            t = (val - a[axis]) / (b[axis] - a[axis])
            q = [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t]
            q[axis] = val     # (exactly on the line, so both sides agree)
            out.append(tuple(q))
    return out


def cut_tri(tri):
    """A triangle cut into pieces along the STEP grid (convex polygons)."""
    xs = [p[0] for p in tri]
    zs = [p[1] for p in tri]
    out = []
    for gx in range(int(math.floor(min(xs) / STEP)), int(math.floor(max(xs) / STEP)) + 1):
        col = clip_poly(clip_poly(tri, 0, gx * STEP, False), 0, (gx + 1) * STEP, True)
        if len(col) < 3:
            continue
        for gz in range(int(math.floor(min(zs) / STEP)), int(math.floor(max(zs) / STEP)) + 1):
            piece = clip_poly(clip_poly(col, 1, gz * STEP, False), 1, (gz + 1) * STEP, True)
            if len(piece) >= 3:
                out.append(piece)
    return out


def write_ground(d, h):
    """The map's dry ground, cut along the STEP grid where the heights reach,
    each corner at its height. Water stays flat (surrounds.gd lays it).

    Layout: uint32 kinds; per kind: uint8 name length, the name, uint32
    vertex count, then float32 x, y, z per vertex (triangles, unindexed)."""
    lim = HALF - 1.0
    kinds = []
    for g in d["ground"]:
        if g["kind"] in ("water", "drain"):
            continue
        t = g["tris"]
        verts = []
        for i in range(0, len(t) - 5, 6):
            tri = [(t[i], t[i + 1]), (t[i + 2], t[i + 3]), (t[i + 4], t[i + 5])]
            if max(max(abs(x), abs(z)) for x, z in tri) < lim:
                pieces = cut_tri(tri)
            else:
                pieces = [tri]
            for pc in pieces:
                # (the clip keeps the triangle's winding; fan each piece)
                for k in range(1, len(pc) - 1):
                    verts += [pc[0], pc[k], pc[k + 1]]
        if not verts:
            continue
        v = np.array(verts, dtype=np.float64)
        y = np.zeros(len(v))
        inner = (np.abs(v[:, 0]) < HALF) & (np.abs(v[:, 1]) < HALF)
        y[inner] = height_at(h, v[inner, 0], v[inner, 1])
        kinds.append((g["kind"], np.column_stack([v[:, 0], y, v[:, 1]]).astype(np.float32)))
    with open(OUT_GROUND, "wb") as f:
        f.write(struct.pack("<I", len(kinds)))
        total = 0
        for name, arr in kinds:
            nb = name.encode()
            f.write(struct.pack("<B", len(nb)) + nb + struct.pack("<I", len(arr)))
            f.write(arr.tobytes())
            total += len(arr) // 3
    return total


def report(X, Z, h, raw, wet):
    print("grid %d x %d, %.0f m cells" % (GRID, GRID, CELL))
    land = ~wet
    print("land heights: min %.2f  p5 %.2f  median %.2f  p95 %.2f  max %.2f" % tuple(
        np.percentile(h[land], [0, 5, 50, 95, 100])))
    for name, x, z in [("site", 0, 0), ("ferry bank", 112, -199), ("riverwalk W", -150, -60), ("golf", 250, 200)]:
        print("  %-12s %6.2f  (AHD %.2f)" % (name, float(height_at(h, x, z)[0]), float(height_at(np.nan_to_num(raw), x, z)[0])))
    gy, gx = np.gradient(h, CELL)
    s = np.hypot(gx, gy)
    print("slope p95 %.1f%%  max %.1f%%" % (np.percentile(s[land], 95) * 100, s[land].max() * 100))


def main():
    d = json.load(open(OSM))
    X, Z, h, raw, wet = build(d)
    report(X, Z, h, raw, wet)
    h.astype("<f4").tofile(OUT_BIN)
    json.dump({"source": "2019 LiDAR bare ground (c) State of Queensland, CC BY 4.0; tools/terrain_to_game.py",
               "half": HALF, "cell": CELL, "grid": GRID, "datum_ahd": DATUM, "step": STEP,
               "frame": "map frame of data/riverlight_osm.json; rows from z = -half, x = -half first"},
              open(OUT_JSON, "w"), indent=1)
    n = write_ground(d, h)
    print("ground: %d triangles, %.1f MB" % (n, os.path.getsize(OUT_GROUND) / 1e6))


if __name__ == "__main__":
    main()
