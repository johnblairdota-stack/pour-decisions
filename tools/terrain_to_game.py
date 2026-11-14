#!/usr/bin/env python3
"""The real lie of the land round Riverlight, for scripts/terrain.gd.

Reads the bare-ground heightmaps (reference/elevation, metres above AHD: the
2019 LiDAR at 2 m round the site, QldDem at 10 m out 5 km and 30 m out 17 km)
and the map data (data/riverlight_osm.json, data/riverlight_skyline.json),
and writes, in the game's map frame (metres; x = west, z = north; origin
Riverlight's centroid), three grids one inside the other (LAYERS):

  near   2 m cells to 800 m each way    data/terrain.bin
  mid    5 m cells to 2.6 km            data/terrain_mid.bin
  far   40 m cells to 16 km             data/terrain_far.bin

  each   float32 heights, grid x grid nodes, cell m apart, row by row from
         z = -half (south) up, x = -half first in each row
  data/terrain.json  where the grids are, and what was pinned
  data/ground_3d.bin the map's ground (data/riverlight_osm.json "ground"),
                     cut along a grid so it can follow the heights
                     (see write_ground)

Each grid eases into the next one out over its last EDGE_FADE m and meets it
exactly at its edge, so scripts/terrain.gd asks the finest grid that reaches.

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
  * the far river (the skyline's water) under its banks too, and the far
    grid easing back to 0 at 16 km (the flat world beyond)

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
from shapely.geometry import Polygon
from shapely.ops import unary_union

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ELEV = os.path.join(ROOT, "reference", "elevation")
OSM = os.path.join(ROOT, "data", "riverlight_osm.json")
SKYLINE = os.path.join(ROOT, "data", "riverlight_skyline.json")
OUT_JSON = os.path.join(ROOT, "data", "terrain.json")
OUT_GROUND = os.path.join(ROOT, "data", "ground_3d.bin")

# the heightmaps, coarse to fine: file, MGA zone 56 top-left corner (E, N),
# pixel size, and how far in from its edge it eases over the one under it
DEMS = [
    ("qld_dem_30m_34km_mga56.tif", 491450.0, 6981420.0, 34000.0 / 1134.0, 0.0),
    ("qld_dem_10m_10km_mga56.tif", 503450.0, 6969420.0, 10.0, 600.0),
    ("heightmap_2m_750px_u16.png", 507700.0, 6965170.0, 2.0, 140.0),
]
# as tools/osm_to_game.py
LAT0, LON0 = -27.4436709, 153.0855133
TURN = -14.4
M_LAT = 110860.0
M_LON = 111320.0 * math.cos(math.radians(LAT0))

# the grids, outside in: name, how far each way, cell, file, and whether the
# map's streets and buildings are levelled into it
LAYERS = [
    ("far", 16000.0, 40.0, "terrain_far.bin", False),
    ("mid", 2600.0, 5.0, "terrain_mid.bin", True),
    ("near", 800.0, 2.0, "terrain.bin", True),
]
HALF = CELL = GRID = None    # the grid being worked on (use())
DATUM = 3.5          # AHD of the game's 0
RIVER_Y = -2.5       # scripts/water.gd
DRY_MIN = RIVER_Y + 0.5
EDGE_FADE = 140.0    # eased into the grid outside over this, inside each edge
EDGE_MEET = 30.0     # ...and over this, last, so they meet exactly
FAR_FADE = 2500.0    # the far grid back to 0 over this

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
PAD_GROUP = 10.0     # buildings closer than twice this share a pad
HILL = 2.0           # a pad's ground this much higher one side than the other is on a hill
MAX_SLOPE = 0.3    # banks no steeper than this (rise over run)
PARK_ZONE = 30.0     # round the 4x4 park's tracks and challenges: the ground
PARK_SMOOTH = 15.0   # smoothed out under them, so they keep their shape

FINE, FINE_R = 4.0, 320.0   # ...and this one within this square of the site
STEP = 8.0           # the ground mesh is cut along this grid
MID_STEP = 16.0      # ...and this past the near grid


def game_to_lonlat(x, z):
    e2, n2 = -x, z
    a = math.radians(-TURN)
    e = e2 * math.cos(a) + n2 * math.sin(a)
    n = -e2 * math.sin(a) + n2 * math.cos(a)
    return LON0 + e / M_LON, LAT0 + n / M_LAT


def smoothstep(t):
    t = np.clip(t, 0.0, 1.0)
    return t * t * (3 - 2 * t)


def use(half, cell):
    global HALF, CELL, GRID
    HALF, CELL = half, cell
    GRID = int(round(HALF * 2 / CELL)) + 1


def node_xz():
    v = -HALF + np.arange(GRID) * CELL
    return np.meshgrid(v, v)      # X[row, col] = x at col, Z[row, col] = z at row


def to_mga(X, Z):
    a = math.radians(-TURN)
    e2, n2 = -X, Z
    e = e2 * math.cos(a) + n2 * math.sin(a)
    n = -e2 * math.sin(a) + n2 * math.cos(a)
    tr = Transformer.from_crs("EPSG:4326", "EPSG:28356", always_xy=True)
    return tr.transform(LON0 + e / M_LON, LAT0 + n / M_LAT)


_dems = {}


def _dem(name):
    if name not in _dems:
        raw = np.array(Image.open(os.path.join(ELEV, name))).astype(np.float64)
        if name.endswith(".png"):
            _dems[name] = np.where(raw > 0, raw / 1000.0 - 20.0, np.nan)
        else:
            _dems[name] = np.where(raw > -1000.0, raw, np.nan)
    return _dems[name]


def sample_dem(X, Z, finest=2.0):
    """Metres AHD at each node: the finest heightmap there (no finer than
    `finest`), easing over the coarser one inside its edge. NaN off them all."""
    E, N = to_mga(X, Z)
    h = np.full(X.shape, np.nan)
    for name, e0, n1, px, fade in DEMS:
        if px < finest * 0.99:
            continue
        dem = _dem(name)
        col = (E - e0) / px - 0.5
        row = (n1 - N) / px - 0.5
        v = ndimage.map_coordinates(np.nan_to_num(dem, nan=-999.0), [row, col], order=1, mode="constant", cval=-999.0)
        ok = (col >= 0) & (row >= 0) & (col <= dem.shape[1] - 1) & (row <= dem.shape[0] - 1) & (v > -100)
        edge = np.minimum.reduce([col, row, dem.shape[1] - 1 - col, dem.shape[0] - 1 - row]) * px
        w = smoothstep(edge / fade) if fade > 0 else np.ones_like(edge)
        w = np.where(np.isnan(h), 1.0, w)
        h = np.where(ok, np.where(np.isnan(h), v, h * (1.0 - w) + v * w), h)
    return h


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


def wet_mask(d, sky):
    tris = [w for w in sky.get("water", [])]
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


def limit_slope(h, raise_low, locked=None):
    """Banks no steeper than MAX_SLOPE: the low side built up (raise_low) or
    the high side cut down to them; `locked` nodes stay as they are."""
    d = math.sqrt(2.0)
    plus = np.array([[0, 1, 0], [1, 0, 1], [0, 1, 0]], bool)
    cross = np.array([[1, 0, 1], [0, 0, 0], [1, 0, 1]], bool)
    for _ in range(60):
        if raise_low:
            nb = np.maximum(ndimage.grey_dilation(h, footprint=plus) - MAX_SLOPE * CELL,
                            ndimage.grey_dilation(h, footprint=cross) - MAX_SLOPE * CELL * d)
            nh = np.maximum(h, nb)
        else:
            nb = np.minimum(ndimage.grey_erosion(h, footprint=plus) + MAX_SLOPE * CELL,
                            ndimage.grey_erosion(h, footprint=cross) + MAX_SLOPE * CELL * d)
            nh = np.minimum(h, nb)
        if locked is not None:
            nh = np.where(locked, h, nh)
        if np.abs(nh - h).max() < 0.005:
            return nh
        h = nh
    return h


def inside(p, margin):
    return all(abs(x) < HALF - margin and abs(z) < HALF - margin for x, z in p)


def blend(h, target, w):
    return h * (1.0 - w) + target * w


def edge_dist(X, Z):
    return HALF - np.maximum(np.abs(X), np.abs(Z))


def build_far(d, sky):
    """The hills out to the horizon: the river and the bay under, the rest
    no lower than dry land by the river, easing back to 0 at the edge."""
    X, Z = node_xz()
    raw = sample_dem(X, Z, finest=10.0)
    h = raw - DATUM
    wet = wet_mask(d, sky)
    dry = ~np.isnan(h) & ~wet & (raw > 0.0)
    idx = ndimage.distance_transform_edt(~dry, return_distances=False, return_indices=True)
    h = ndimage.gaussian_filter(h[idx[0], idx[1]], 0.6)
    h = np.maximum(h, DRY_MIN)
    h = blend(h, 0.0, 1.0 - smoothstep(edge_dist(X, Z) / FAR_FADE))
    return X, Z, h, raw, wet


def road_points(d):
    """Every street's centre line, a point a metre, with how far its level
    reaches each side."""
    pts, half = [], []
    for r in d["roads"] + [dict(a, bridge=False) for a in d["aisles"]]:
        if r.get("bridge") or len(r["pts"]) < 2:
            continue
        for q in densify(r["pts"], 1.0):
            pts.append(q)
            half.append(r["w"] / 2.0 + ROAD_EDGE)
    return np.array(pts), np.array(half)


def pad_groups(d):
    """The buildings, the golf course's ponds and the sports fields, in
    groups that share a pad (closer than 2 x PAD_GROUP), worked out on the
    map so every grid has the same ones."""
    pads = [b["pts"] for b in d["buildings"]] + [a["pts"] for a in d["areas"] if a["kind"] in ("golf_water", "pitch")]
    pads = [p for p in pads if len(p) >= 3]
    blobs = unary_union([Polygon(p).buffer(PAD_GROUP) for p in pads])
    blobs = list(blobs.geoms) if hasattr(blobs, "geoms") else [blobs]
    groups = [[] for _ in blobs]
    for p in pads:
        c = Polygon(p).representative_point()
        for k, b in enumerate(blobs):
            if b.contains(c):
                groups[k].append(p)
                break
    return [g for g in groups if g]


def build(d, sky, under, shared):
    """`under`: the coarser grids' heights at this one's nodes, to ease into
    at its edge. `shared`: each street's long line and each pad's level, as
    the first grid built with streets found them (so where two grids meet
    they agree); filled in by that first one."""
    X, Z = node_xz()
    raw = sample_dem(X, Z, finest=CELL)
    h = raw - DATUM
    have = ~np.isnan(h)
    wet = wet_mask(d, sky)
    # the water's own nodes take the nearest dry ground (so a bridge or a bank
    # top over them sits at the bank's height), as do any holes
    # (and so do spots the heightmap has down at the river bed that the map
    # doesn't call water: the wharves' decks over it)
    dry = have & ~wet & (raw > 0.0)
    idx = ndimage.distance_transform_edt(~dry, return_distances=False, return_indices=True)
    h = h[idx[0], idx[1]]
    # (narrow ditches and pits filled: the drains that matter are water in
    # the map; and LiDAR ground still has kerbs and garden walls in it)
    h = ndimage.grey_closing(h, size=(5, 5))
    h = ndimage.gaussian_filter(h, 1.0)
    # (no cliffs: a retaining wall or a podium's edge becomes a bank no
    # steeper than MAX_SLOPE, the low side built up to it)
    h = limit_slope(h, raise_low=True)
    # into the grid outside, at this one's edge
    edge = edge_dist(X, Z)
    h = blend(h, under, 1.0 - smoothstep(edge / EDGE_FADE))

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

    # the streets: flat across, along a long smooth line
    pts, half = shared["road_pts"], shared["road_half"]
    if "road_y" not in shared:
        smooth = ndimage.gaussian_filter(h, ROAD_SMOOTH / CELL)
        shared["road_y"] = ndimage.map_coordinates(smooth, [(pts[:, 1] + HALF) / CELL, (pts[:, 0] + HALF) / CELL], order=1)
        own = shared["road_y"]
    else:
        # (this grid's own line, but where it eases into the grid outside,
        # the line that one followed)
        smooth = ndimage.gaussian_filter(h, ROAD_SMOOTH / CELL)
        own = ndimage.map_coordinates(smooth, [(pts[:, 1] + HALF) / CELL, (pts[:, 0] + HALF) / CELL], order=1)
        band = 1.0 - smoothstep((HALF - np.maximum(np.abs(pts[:, 0]), np.abs(pts[:, 1]))) / EDGE_FADE)
        own = blend(own, shared["road_y"], band)
    ins = (np.abs(pts[:, 0]) < HALF - 1) & (np.abs(pts[:, 1]) < HALF - 1)
    sm = own[ins]
    pts, half = pts[ins], half[ins]
    tree = cKDTree(pts)
    nodes = np.column_stack([X.ravel(), Z.ravel()])
    # (the widest corridor any road has, to look that far)
    reach = float(half.max()) + ROAD_EASE
    dist, near = tree.query(nodes, k=8, distance_upper_bound=reach)
    w = np.zeros(nodes.shape[0])
    tgt = np.zeros(nodes.shape[0])
    for k in range(dist.shape[1]):
        ok = np.isfinite(dist[:, k])
        j = near[ok, k]
        wk = 1.0 - smoothstep((dist[ok, k] - half[j]) / ROAD_EASE)
        better = wk > w[ok]
        sel = np.where(ok)[0][better]
        w[sel] = wk[better]
        tgt[sel] = sm[j[better]]
    h = blend(h, tgt.reshape(h.shape), w.reshape(h.shape))
    road_core = w.reshape(h.shape) > 0.99

    # the site pad and the CityCat's bank at 0
    site = np.zeros_like(h, dtype=bool)
    for x0, z0, x1, z1 in SITE:
        site |= (X >= x0) & (X <= x1) & (Z >= z0) & (Z <= z1)
    site_w = 1.0 - smoothstep((dist_outside(site) - SITE_FLAT) / SITE_EASE)
    h = blend(h, 0.0, site_w)
    flat = site_w > 0.99
    for fe in d.get("ferry", []):
        ex, ez = fe["edge"]
        r = np.hypot(X - ex, Z - ez)
        fw = 1.0 - smoothstep((r - FERRY_FLAT) / FERRY_EASE)
        h = blend(h, 0.0, fw)
        flat |= fw > 0.99

    # buildings, the golf course's ponds and the sports fields on level pads,
    # last, so nothing tilts them; ones close together share a pad
    # (two nodes past the walls all round, so every corner's on the level)
    grow = max(1, int(round(4.0 / CELL)))
    margin = int(PAD_EASE / CELL) + grow + 6
    foot = np.zeros_like(h, dtype=bool)
    levels = shared.setdefault("pad_y", {})
    n = 0
    for k, g in enumerate(shared["pads"]):
        xs = np.concatenate([np.array(p)[:, 0] for p in g])
        zs = np.concatenate([np.array(p)[:, 1] for p in g])
        c0 = max(0, int((xs.min() + HALF) / CELL) - margin)
        c1 = min(GRID, int((xs.max() + HALF) / CELL) + margin + 2)
        r0 = max(0, int((zs.min() + HALF) / CELL) - margin)
        r1 = min(GRID, int((zs.max() + HALF) / CELL) + margin + 2)
        if c1 - c0 < 2 or r1 - r0 < 2:
            continue
        im = Image.new("L", (c1 - c0, r1 - r0), 0)
        dr = ImageDraw.Draw(im)
        for p in g:
            dr.polygon([((x + HALF) / CELL - c0, (z + HALF) / CELL - r0) for x, z in p], fill=1)
        m = ndimage.binary_dilation(np.array(im) > 0, structure=np.ones((3, 3), bool), iterations=grow)
        if not m.any():
            continue
        n += 1
        sub = h[r0:r1, c0:c1]
        out = dist_outside(m)
        reach = max(np.abs(xs).max(), np.abs(zs).max())
        if k not in levels or reach < HALF - EDGE_FADE - 10.0:
            # (well inside, its own level; one out by the edge, the level
            # the grid outside gave it, so they agree)
            # (level with the ground just round it, under a big roof the
            # LiDAR's ground being guesswork; on a hill (HILL between the
            # low and high sides), nearer its foot, so it's set
            # into the slope rather than standing up on a plinth)
            ring = (out > 1.0) & (out < 8.0)
            q25, q50, q75 = np.percentile(sub[ring] if ring.any() else sub[m], [25, 50, 75])
            level = float(q50 if q75 - q25 < HILL else q25)
            levels.setdefault(k, level)
        else:
            level = levels[k]
        w = 1.0 - smoothstep(out / PAD_EASE)
        h[r0:r1, c0:c1] = blend(sub, level, w)
        foot[r0:r1, c0:c1] |= m
    print("pads: %d groups" % n)
    # (and where a pad or a street's cut into a bank, the bank cut back)
    h = limit_slope(h, raise_low=False, locked=foot | road_core | flat | wet)

    low = (h < DRY_MIN) & ~wet
    print("dry nodes lifted to %.1f: %d (%.1f%%)" % (DRY_MIN, low.sum(), 100.0 * low.mean()))
    h = np.maximum(h, DRY_MIN)
    # (and exactly onto it at the very edge)
    h = blend(h, under, 1.0 - smoothstep(edge / EDGE_MEET))
    return X, Z, h, raw, wet


# ---------------------------------------------------------------- the ground

def height_at(h, x, z):
    c = (np.atleast_1d(np.asarray(x, dtype=float)) + HALF) / CELL
    r = (np.atleast_1d(np.asarray(z, dtype=float)) + HALF) / CELL
    return ndimage.map_coordinates(h, [r, c], order=1, mode="nearest")


def layered(grids, x, z):
    """Height at (x, z) from the finest grid that reaches, as
    scripts/terrain.gd's y(): `grids` [(half, cell, h)], outside in."""
    x = np.atleast_1d(np.asarray(x, dtype=float))
    z = np.atleast_1d(np.asarray(z, dtype=float))
    out = np.zeros(x.shape)
    for half, cell, h in grids:
        m = (x >= -half) & (z >= -half) & (x < half) & (z < half)
        if m.any():
            out[m] = ndimage.map_coordinates(h, [(z[m] + half) / cell, (x[m] + half) / cell], order=1, mode="nearest")
    return out


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
    """A triangle cut into pieces along the grid (convex polygons): FINE m
    lines near the site, STEP m further out."""
    xs = [p[0] for p in tri]
    zs = [p[1] for p in tri]
    near = max(max(abs(x), abs(z)) for x, z in tri) <= FINE_R
    far = min(max(abs(x), abs(z)) for x, z in tri) >= FINE_R
    if near or far:
        return _cut(tri, FINE if near else STEP)
    # (straddling the edge of the fine square: cut at the square first)
    out = []
    for piece in _cut(tri, FINE_R * 2.0, -FINE_R):
        cx = sum(p[0] for p in piece) / len(piece)
        cz = sum(p[1] for p in piece) / len(piece)
        out += _cut(piece, FINE if max(abs(cx), abs(cz)) < FINE_R else STEP)
    return out


def _cut(poly, step, offset=0.0):
    xs = [p[0] for p in poly]
    zs = [p[1] for p in poly]
    out = []
    for gx in range(int(math.floor((min(xs) - offset) / step)), int(math.floor((max(xs) - offset) / step)) + 1):
        col = clip_poly(clip_poly(poly, 0, offset + gx * step, False), 0, offset + (gx + 1) * step, True)
        if len(col) < 3:
            continue
        for gz in range(int(math.floor((min(zs) - offset) / step)), int(math.floor((max(zs) - offset) / step)) + 1):
            piece = clip_poly(clip_poly(col, 1, offset + gz * step, False), 1, offset + (gz + 1) * step, True)
            if len(piece) >= 3:
                out.append(piece)
    return out


def write_ground(d, grids):
    """The map's dry ground, cut along the STEP grid on the near grid (FINE
    by the site) and MID_STEP past it, each corner at its height. Water stays
    flat (surrounds.gd lays it).

    Layout: uint32 kinds; per kind: uint8 name length, the name, uint32
    vertex count, uint32 index count, then float32 x, y, z per vertex, then
    float32 x, z per vertex of the ground's normal there (its y the rest of
    a unit vector: lit smooth across the triangles, not faceted), then
    int32 indices, three to a triangle."""
    lim = grids[-1][0] - 1.0
    lim_mid = grids[-2][0] - 1.0
    kinds = []
    for g in d["ground"]:
        if g["kind"] in ("water", "drain"):
            continue
        t = g["tris"]
        verts = []
        for i in range(0, len(t) - 5, 6):
            tri = [(t[i], t[i + 1]), (t[i + 2], t[i + 3]), (t[i + 4], t[i + 5])]
            reach = max(max(abs(x), abs(z)) for x, z in tri)
            if reach < lim:
                pieces = cut_tri(tri)
            elif reach < lim_mid:
                pieces = _cut(tri, MID_STEP)
            else:
                pieces = [tri]
            for pc in pieces:
                # (the clip keeps the triangle's winding; fan each piece)
                for k in range(1, len(pc) - 1):
                    verts += [pc[0], pc[k], pc[k + 1]]
        if not verts:
            continue
        v = np.array(verts, dtype=np.float64)
        # (corners shared: the same spot to the millimetre is one vertex)
        v, idx = np.unique(np.round(v, 3), axis=0, return_inverse=True)
        y = layered(grids, v[:, 0], v[:, 1])
        # (the lean over a cell of the grid there, either side)
        r = np.maximum(np.abs(v[:, 0]), np.abs(v[:, 1]))
        e = np.where(r < grids[-1][0], grids[-1][1], np.where(r < grids[-2][0], grids[-2][1], grids[0][1]))
        hx = layered(grids, v[:, 0] + e, v[:, 1]) - layered(grids, v[:, 0] - e, v[:, 1])
        hz = layered(grids, v[:, 0], v[:, 1] + e) - layered(grids, v[:, 0], v[:, 1] - e)
        nrm = np.column_stack([-hx, 2.0 * e, -hz])
        nrm /= np.linalg.norm(nrm, axis=1, keepdims=True)
        kinds.append((g["kind"], np.column_stack([v[:, 0], y, v[:, 1]]).astype(np.float32),
                      nrm[:, [0, 2]].astype(np.float32), idx.ravel().astype("<i4")))
    with open(OUT_GROUND, "wb") as f:
        f.write(struct.pack("<I", len(kinds)))
        total = 0
        for name, arr, nrm, idx in kinds:
            nb = name.encode()
            f.write(struct.pack("<B", len(nb)) + nb + struct.pack("<II", len(arr), len(idx)))
            f.write(arr.tobytes())
            f.write(nrm.tobytes())
            f.write(idx.tobytes())
            total += len(idx) // 3
    return total


def report(name, X, Z, h, raw, wet):
    print("%s: grid %d x %d, %.0f m cells, %.0f m each way" % (name, GRID, GRID, CELL, HALF))
    land = ~wet
    print("land heights: min %.2f  p5 %.2f  median %.2f  p95 %.2f  max %.2f" % tuple(
        np.percentile(h[land], [0, 5, 50, 95, 100])))
    for nm, x, z in [("site", 0, 0), ("ferry bank", 112, -199), ("riverwalk W", -150, -60), ("golf", 250, 200),
                     ("Hamilton Hill", 2939, -277), ("Toorak Hill", 3540, -317), ("Mt Coot-tha", 12778, -5500),
                     ("Mt Gravatt", -1516, -10956)]:
        if abs(x) < HALF and abs(z) < HALF:
            print("  %-13s %7.2f  (AHD %.2f)" % (nm, float(height_at(h, x, z)[0]), float(height_at(np.nan_to_num(raw), x, z)[0])))
    gy, gx = np.gradient(h, CELL)
    s = np.hypot(gx, gy)
    print("slope p95 %.1f%%  max %.1f%%" % (np.percentile(s[land], 95) * 100, s[land].max() * 100))


def main():
    d = json.load(open(OSM))
    sky = json.load(open(SKYLINE))
    grids = []
    meta = []
    pts, half_w = road_points(d)
    shared = {"road_pts": pts, "road_half": half_w, "pads": pad_groups(d)}
    for name, half, cell, out, levelled in LAYERS:
        use(half, cell)
        if levelled:
            X, Z = node_xz()
            under = layered(grids, X.ravel(), Z.ravel()).reshape(X.shape)
            X, Z, h, raw, wet = build(d, sky, under, shared)
        else:
            X, Z, h, raw, wet = build_far(d, sky)
        report(name, X, Z, h, raw, wet)
        h.astype("<f4").tofile(os.path.join(ROOT, "data", out))
        grids.append((half, cell, h))
        meta.append({"name": name, "file": "res://data/" + out, "half": half, "cell": cell, "grid": GRID})
    # (the near grid's own, at the top, for tools/terrain_check.py)
    json.dump({"source": "QldDem bare ground (2019 LiDAR round the site) (c) State of Queensland, CC BY 4.0; "
                         "tools/terrain_to_game.py",
               "half": HALF, "cell": CELL, "grid": GRID, "datum_ahd": DATUM, "step": STEP,
               "layers": meta[::-1],
               "frame": "map frame of data/riverlight_osm.json; rows from z = -half, x = -half first; "
                        "layers finest first, each meeting the next at its edge"},
              open(OUT_JSON, "w"), indent=1)
    n = write_ground(d, grids)
    print("ground: %d triangles, %.1f MB" % (n, os.path.getsize(OUT_GROUND) / 1e6))


if __name__ == "__main__":
    main()
