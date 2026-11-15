"""2019 LiDAR -> reference/sites/spire/lidar/ (game-ready, small). Run after tools/lidar/grid_spire.js.

    <blender python> -I tools/blender/spire/prep_lidar.py <PourDecisions-sites>/data/cbd

Inputs (not in git): data/cbd/elvis/grid2019/<E>_<N>/{dsm,gnd,veg,bld,oth}.f32 + vox_*.i32 + grid.json,
and data/cbd/dem/default (2014-mix DEM, only to fill ground under roofs and the river).
Outputs, all in the local frame of layout.py over layout.LIDAR_BOX at 1 m:
    dsm_1m.f32.gz        top surface (max of all but noise/water), m AHD, rows north->south
    ground_1m.f32.gz     2019 bare ground (mean of class 2), gaps filled from the 2014-mix DEM, m AHD
    class_1m.u8.gz       what made the top: 0 none, 1 ground, 2 vegetation, 3 building, 4 other (bridge 17, ...)
    vox_<box>.i32.gz     occupied voxels of the hero boxes (bridge_hsw, cathedral, spire), see lidar.json
    building_heights.csv per OSM footprint: p90 of DSM inside - median ground inside
    tree_points.csv      tree tops (5 m local max of canopy over 3 m)
    lidar.json           grid header, sources, licence
"""
import csv
import gzip
import json
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import layout as L  # noqa: E402
import prep_data  # noqa: E402  (read_tif)

OUT = os.path.join(L.REF, "lidar")


def mosaic(src, names):
    """All tiles -> MGA mosaics (dict name -> array, plus E0, N1)."""
    d = os.path.join(src, "elvis", "grid2019")
    tiles = [t for t in os.listdir(d) if os.path.exists(os.path.join(d, t, "grid.json"))]
    es = sorted({int(t.split("_")[0]) for t in tiles})
    ns = sorted({int(t.split("_")[1]) for t in tiles})
    E0, N1 = es[0], ns[-1] + 1000
    W, H = (es[-1] + 1000 - E0), (N1 - ns[0])
    out = {k: np.full((H, W), np.nan, "f4") for k in names}
    hdrs = []
    for t in tiles:
        g = json.load(open(os.path.join(d, t, "grid.json")))
        hdrs.append(g)
        r0, c0 = N1 - g["Y1"], g["X0"] - E0
        for k in names:
            a = np.fromfile(os.path.join(d, t, k + ".f32"), "<f4").reshape(g["H"], g["W"])
            r1, c1 = min(H, r0 + g["H"]), min(W, c0 + g["W"])
            sub = a[: r1 - r0, : c1 - c0]
            cur = out[k][r0:r1, c0:c1]
            out[k][r0:r1, c0:c1] = np.where(np.isnan(cur), sub, np.fmax(cur, sub))
    return out, E0, N1, hdrs


def to_local_grid(a, E0, N1, box):
    """Pick the local box out of an MGA mosaic (local = MGA - origin; 1 m, nearest cell)."""
    x0, y0, x1, y1 = box
    ox, oy = L.ORIGIN_MGA56
    cols = np.floor(ox + np.arange(x0, x1) + 0.5 - E0).astype(int)
    rows = np.floor(N1 - (oy + np.arange(y1, y0, -1) - 0.5)).astype(int)
    return a[np.ix_(rows, cols)]


def old_dem(box, src):
    """2014-mix DEM over the local box (for ground gaps under roofs and in the river)."""
    x0, y0, x1, y1 = box
    ox, oy = L.ORIGIN_MGA56
    d = os.path.join(src, "dem", "default")
    out = np.zeros((y1 - y0, x1 - x0), "f4")
    cache = {}
    for r, y in enumerate(range(y1, y0, -1)):
        N = oy + y - 0.5
        Es = ox + np.arange(x0, x1) + 0.5
        tE = (np.floor(Es / 1000) * 1000).astype(int)
        tn = int(math.floor(N / 1000) * 1000)
        for te in np.unique(tE):
            if (te, tn) not in cache:
                p = os.path.join(d, "dem_%d_%d.tif" % (te, tn))
                cache[(te, tn)] = prep_data.read_tif(p) if os.path.exists(p) else None
            a = cache[(te, tn)]
            m = tE == te
            if a is None:
                continue
            out[r, m] = a[999 - int(N - tn), (Es[m] - te).astype(int)]
    return out


def ring_mask(ring, box):
    """Boolean mask of the local 1 m cells whose centres fall inside ring; plus (r0, c0) offset."""
    x0, y0, x1, y1 = box
    xs = [p[0] for p in ring]
    ys = [p[1] for p in ring]
    c0 = max(0, int(math.floor(min(xs) - x0)))
    c1 = min(x1 - x0, int(math.ceil(max(xs) - x0)))
    r0 = max(0, int(math.floor(y1 - max(ys))))
    r1 = min(y1 - y0, int(math.ceil(y1 - min(ys))))
    if c1 <= c0 or r1 <= r0:
        return None, 0, 0
    cx = x0 + np.arange(c0, c1) + 0.5
    cy = y1 - np.arange(r0, r1) - 0.5
    X, Y = np.meshgrid(cx, cy)
    inside = np.zeros(X.shape, bool)
    n = len(ring)
    for i in range(n):
        (xa, ya), (xb, yb) = ring[i], ring[(i + 1) % n]
        if ya == yb:
            continue
        cond = (ya > Y) != (yb > Y)
        xc = (xb - xa) * (Y - ya) / (yb - ya) + xa
        inside ^= cond & (X < xc)
    return inside, r0, c0


def trace(mask, box, r0=0, c0=0):
    """Outer boundary of a boolean cell mask -> list of loops in local metres (CCW, interior left)."""
    x0, y0, x1, y1 = box
    H, W = mask.shape
    m = np.pad(mask, 1)
    nxt = {}
    rs, cs = np.nonzero(mask)
    for r, c in zip(rs.tolist(), cs.tolist()):
        R, C = r + 1, c + 1
        if not m[R + 1, C]:
            nxt[(c, r + 1)] = (c + 1, r + 1)       # bottom edge, west -> east
        if not m[R, C + 1]:
            nxt[(c + 1, r + 1)] = (c + 1, r)       # right edge, south -> north
        if not m[R - 1, C]:
            nxt[(c + 1, r)] = (c, r)               # top edge, east -> west
        if not m[R, C - 1]:
            nxt[(c, r)] = (c, r + 1)               # left edge, north -> south
    loops = []
    while nxt:
        start, cur = next(iter(nxt.items()))
        loop = [start]
        nxt.pop(start)
        while cur != start and cur in nxt:
            loop.append(cur)
            cur = nxt.pop(cur)
        loops.append([(x0 + c0 + c, y1 - r0 - r) for c, r in loop])
    return loops


def rdp(pts, eps):
    if len(pts) < 3:
        return pts
    a, b = np.array(pts[0]), np.array(pts[-1])
    d = b - a
    ln = np.hypot(*d) or 1e-9
    dist = [abs(d[0] * (p[1] - a[1]) - d[1] * (p[0] - a[0])) / ln for p in pts]
    i = int(np.argmax(dist))
    if dist[i] > eps:
        return rdp(pts[:i + 1], eps)[:-1] + rdp(pts[i:], eps)
    return [pts[0], pts[-1]]


def simplify_loop(loop, eps=0.8):
    p0 = loop[0]
    k = max(range(len(loop)), key=lambda i: (loop[i][0] - p0[0]) ** 2 + (loop[i][1] - p0[1]) ** 2)
    first = rdp(loop[:k + 1], eps)                      # start -> farthest point
    second = rdp(loop[k:] + [loop[0]], eps)             # farthest point -> back to start
    return first[:-1] + second[:-1]


def podium_outline(dsm, gnd, box):
    """Spire's podium edge: cells over 6 m above ground inside the lot (grown 2 m), traced and simplified."""
    o = L.osm()
    lot = o["line"](o["ways"][L.SPIRE["osm_way"]])
    cx = sum(p[0] for p in lot) / len(lot)
    cy = sum(p[1] for p in lot) / len(lot)
    grown = [(cx + (x - cx) * 1.08, cy + (y - cy) * 1.08) for x, y in lot]
    m, r0, c0 = ring_mask(grown, box)
    sub = (slice(r0, r0 + m.shape[0]), slice(c0, c0 + m.shape[1]))
    hgt = dsm[sub] - gnd[sub]
    pod = m & (hgt > 6.0)
    loops = trace(pod, box, r0, c0)
    loop = max(loops, key=len)
    poly = simplify_loop(loop, 0.8)
    low = pod & (dsm[sub] < 60)
    roof = float(np.median(dsm[sub][low])) if low.any() else None
    out = {"outline_local": [[round(x, 2), round(y, 2)] for x, y in poly], "cells": int(pod.sum()),
           "podium_roof_median_ahd": round(roof, 2) if roof else None,
           "method": "2019 LiDAR DSM cells > 6 m above ground inside the OSM lot grown 8 %, traced, RDP 0.8 m"}
    json.dump(out, open(os.path.join(OUT, "spire_podium.json"), "w"), indent=1)
    print("podium outline", len(poly), "pts, roof median", out["podium_roof_median_ahd"])
    return out


def building_heights(dsm, gnd, cls, box):
    """p90 of building/other DSM cells inside each OSM footprint minus median ground inside."""
    o = L.osm()
    rows = []
    for wid, w in o["ways"].items():
        t = w.get("tags", {})
        if "building" not in t and "building:part" not in t:
            continue
        ring = o["line"](w)
        if len(ring) < 3:
            continue
        m, r0, c0 = ring_mask(ring, box)
        if m is None or not m.any():
            continue
        sub = (slice(r0, r0 + m.shape[0]), slice(c0, c0 + m.shape[1]))
        top = dsm[sub][m]
        roof = top[(cls[sub][m] == 3) | (cls[sub][m] == 4)]
        g = float(np.median(gnd[sub][m]))
        if len(roof) < max(3, 0.2 * m.sum()):
            roof = top
        h = float(np.percentile(roof, 90)) - g
        rows.append({"osm_way": wid, "name": t.get("name", ""), "kind": "part" if "building:part" in t else "building",
                     "cells": int(m.sum()), "roof_cells": int(len(roof)), "ground_median_ahd": round(g, 2),
                     "roof_p90_ahd": round(g + h, 2), "height_m": round(h, 2),
                     "osm_height": t.get("height", ""), "osm_levels": t.get("building:levels", "")})
    with open(os.path.join(OUT, "building_heights.csv"), "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)
    print("building heights", len(rows))
    return rows


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else r"C:\Users\John\Documents\PourDecisions-sites\data\cbd"
    os.makedirs(OUT, exist_ok=True)
    box = L.LIDAR_BOX
    names = ["dsm", "gnd", "veg", "bld", "oth"]
    mos, E0, N1, hdrs = mosaic(src, names)
    loc = {k: to_local_grid(mos[k], E0, N1, box) for k in names}
    old = old_dem(box, src)
    gnd = np.where(np.isnan(loc["gnd"]), old, loc["gnd"]).astype("f4")
    dsm = np.where(np.isnan(loc["dsm"]), gnd, np.fmax(loc["dsm"], gnd)).astype("f4")
    cls = np.zeros(dsm.shape, "u1")
    top = loc["dsm"]
    near = lambda a: np.isfinite(a) & (np.abs(a - top) < 0.01)
    cls[near(loc["gnd"]) | (np.isfinite(top) & (top - gnd < 0.5))] = 1
    cls[near(loc["veg"])] = 2
    cls[near(loc["oth"])] = 4
    cls[near(loc["bld"])] = 3
    for name, a in (("dsm_1m.f32.gz", dsm), ("ground_1m.f32.gz", gnd)):
        with gzip.open(os.path.join(OUT, name), "wb") as f:
            f.write(a.astype("<f4").tobytes())
    with gzip.open(os.path.join(OUT, "class_1m.u8.gz"), "wb") as f:
        f.write(cls.tobytes())
    # hero voxels: merge tiles, keep box-relative indices
    vox = {}
    d = os.path.join(src, "elvis", "grid2019")
    for t in os.listdir(d):
        for f in os.listdir(os.path.join(d, t)):
            if f.startswith("vox_"):
                name = f[4:-4]
                vox.setdefault(name, []).append(np.fromfile(os.path.join(d, t, f), "<i4").reshape(-1, 3))
    vinfo = {}
    for name, parts in vox.items():
        v = np.unique(np.concatenate(parts), axis=0)
        with gzip.open(os.path.join(OUT, "vox_%s.i32.gz" % name), "wb") as f:
            f.write(v.astype("<i4").tobytes())
        vinfo[name] = {"count": int(len(v)), "box_mga": hdrs[0]["hero"][name]}
    # trees: local maxima of canopy height (5 m window) over 3 m
    can = np.nan_to_num(loc["veg"] - gnd, nan=0.0)
    from numpy.lib.stride_tricks import sliding_window_view
    pad = np.pad(can, 2, constant_values=0)
    mx = sliding_window_view(pad, (5, 5)).max(axis=(2, 3))
    rr, cc = np.nonzero((can >= mx) & (can > 3.0))
    with open(os.path.join(OUT, "tree_points.csv"), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["x_local", "y_local", "height_m", "ground_ahd"])
        for r, c in zip(rr, cc):
            w.writerow([box[0] + c + 0.5, box[3] - r - 0.5, round(float(can[r, c]), 2), round(float(gnd[r, c]), 2)])
    heights = building_heights(dsm, gnd, cls, box)
    podium_outline(dsm, gnd, box)
    hdr = {"box_local": box, "step_m": 1.0, "rows": int(dsm.shape[0]), "cols": int(dsm.shape[1]),
           "order": "rows north to south, cols west to east; cell centres at (x0+c+0.5, y1-r-0.5)",
           "voxels": vinfo, "voxel_order": "int32 triplets (ix, iy, iz) from the box's (E0, N0, Z0) corner in MGA56",
           "trees": int(len(rr)),
           "source": "Brisbane 2019 Project LiDAR (classified point cloud, 16 x 1 km tiles E 501000-505000 "
                     "N 6960000-6964000, flown 2019-06/08), ordered from ELVIS; gaps from the QldDem default mix.",
           "credit": "(c) State of Queensland (Department of Resources), CC BY 4.0"}
    json.dump(hdr, open(os.path.join(OUT, "lidar.json"), "w"), indent=1)
    print("lidar grid", dsm.shape, "trees", len(rr), "voxels", {k: v["count"] for k, v in vinfo.items()})
    print("classes", {int(k): int((cls == k).sum()) for k in range(5)})


if __name__ == "__main__":
    main()
