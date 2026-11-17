#!/usr/bin/env python3
"""Cut a Spire-style reference pack for each remaining SCP tower out of the big site download.

    python3 tools/sites/prep_site.py <PourDecisions-sites>/data [site,site,...] [--only=osm,dem,lidar,aerial,council]

Sites: william1, skytower, queenswharf, hsw, alcyone (default: all). numpy + Pillow only, so it runs in
the cloud or on the PC. Writes reference/sites/<id>/ in a LOCAL frame per site:
    origin = centroid of the site's OSM outline, +x east, +y north (MGA zone 56 grid), z metres AHD.

Per site:
    site.json                     origin (MGA56 + lat/lon), outline, OSM tags, what each file is
    osm_<id>_800m.json.gz         OSM elements touching the 880 m square (ODbL)
    dem_1m.f32.gz + dem_1m.json   QldDem default mix, 1 m, 801 x 801, includes the river bed (CC BY 4.0 Qld)
    lidar/                        2019 LiDAR 1 m grids, building heights, tree tops, site outline (CBD only)
    aerial_YYYY_800m_0p5m.jpg     aerials in the local frame, north up, 1600 px (CC BY 4.0 Qld)
    aerial_YYYY_site<N>m.jpg      close crops of the site for the build years, 1600 px
    council_<id>.geojson          Brisbane City Council layers in the square (CC BY 4.0 BCC)
Never reads my_photos or commons.
"""
import csv
import gzip
import json
import math
import os
import struct
import sys

import numpy as np
from PIL import Image

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
HALF = 400.0
MARGIN = 40.0

# rough centres the 14 Nov download used for each aerial square (fetch_sites.AREAS; spire_c = layout.ORIGIN)
AERIAL_CENTRES = {
    "cbd": {"spire": (-27.4627, 153.0334), "spire_c": (-27.4630417, 153.0308272), "hsw": (-27.4640, 153.0362),
            "william1": (-27.4738, 153.0262), "skytower": (-27.4705, 153.0290), "queenswharf": (-27.4730, 153.0235)},
    "portside": {"alcyone": (-27.4383, 153.0700)},
}

SITES = {
    "william1": {"name": "1 William Street", "area": "cbd", "osm": ("way", 521115344),
                 "site_years": [2012, 2013, 2015, 2016, 2017], "site_half": 100.0, "build": "2013-2016"},
    "skytower": {"name": "Brisbane Skytower", "area": "cbd", "osm": ("way", 683336940),
                 "site_years": [2015, 2016, 2017, 2018, 2019], "site_half": 80.0, "build": "2015-2019"},
    "queenswharf": {"name": "Queen's Wharf Brisbane", "area": "cbd", "osm": ("way", 514750387),
                    "site_years": [2017, 2018, 2019, 2020, 2021, 2022], "site_half": 200.0, "build": "2018-2024"},
    "hsw": {"name": "Howard Smith Wharves", "area": "cbd", "osm": ("way", 564498898),
            "site_years": [2016, 2017, 2018, 2019, 2020], "site_half": 200.0, "build": "2017-2019"},
    "alcyone": {"name": "Alcyone Hotel Residences", "area": "portside", "osm": ("way", 566453920),
                "site_years": [2015, 2016, 2017, 2018], "site_half": 80.0, "build": "2015-2017"},
}

COUNCIL = ["commercial-vehicle-loading-zones", "two-minute-passenger-loading-zones", "brisbane-bus-stops",
           "cp14-road-hierarchy-overlay-road-hierarchy", "bikeway-sections", "cp14-bicycle-network-overlay",
           "cp14-significant-landscape-tree-overlay",
           "protected-vegetation-natural-assets-local-law-2003-significant-urban-vegetation",
           "parking-sign-locations", "parking-line-locations", "bicycle-racks", "park-locations",
           "public-toilets-in-brisbane"]


# ================================================================ maths
def mga56(lat, lon):
    """GDA94 lat/lon (deg) -> MGA zone 56 easting, northing (m). Same as tools/blender/spire/layout.py."""
    a, f = 6378137.0, 1 / 298.257222101
    k0, lon0, fe, fn = 0.9996, math.radians(153.0), 500000.0, 10000000.0
    e2 = f * (2 - f)
    ep2 = e2 / (1 - e2)
    phi, lam = math.radians(lat), math.radians(lon)
    N = a / math.sqrt(1 - e2 * math.sin(phi) ** 2)
    T = math.tan(phi) ** 2
    C = ep2 * math.cos(phi) ** 2
    A = math.cos(phi) * (lam - lon0)
    M = a * ((1 - e2 / 4 - 3 * e2 ** 2 / 64 - 5 * e2 ** 3 / 256) * phi
             - (3 * e2 / 8 + 3 * e2 ** 2 / 32 + 45 * e2 ** 3 / 1024) * math.sin(2 * phi)
             + (15 * e2 ** 2 / 256 + 45 * e2 ** 3 / 1024) * math.sin(4 * phi)
             - (35 * e2 ** 3 / 3072) * math.sin(6 * phi))
    E = fe + k0 * N * (A + (1 - T + C) * A ** 3 / 6 + (5 - 18 * T + T * T + 72 * C - 58 * ep2) * A ** 5 / 120)
    Nn = fn + k0 * (M + N * math.tan(phi) * (A * A / 2 + (5 - T + 9 * C + 4 * C * C) * A ** 4 / 24
                                              + (61 - 58 * T + T * T + 600 * C - 330 * ep2) * A ** 6 / 720))
    return E, Nn


def to_merc(lon, lat):
    x = lon * 20037508.34 / 180.0
    y = math.log(math.tan((90 + lat) * math.pi / 360.0)) * 20037508.34 / math.pi
    return x, y


def merc_box(lat, lon, half_m):
    k = 1.0 / math.cos(math.radians(lat))
    x, y = to_merc(lon, lat)
    return (x - half_m * k, y - half_m * k, x + half_m * k, y + half_m * k)


class Frame:
    def __init__(self, lat, lon):
        self.lat, self.lon = lat, lon
        self.E0, self.N0 = mga56(lat, lon)
        rows, rhs = [], []
        for i in range(-4, 5):
            for j in range(-4, 5):
                la, lo = lat + i * 0.0015, lon + j * 0.0015
                rows.append(list(self.local(la, lo)) + [1.0])
                rhs.append(to_merc(lo, la))
        sol, *_ = np.linalg.lstsq(np.array(rows), np.array(rhs), rcond=None)
        self.A = sol.T   # local (x, y, 1) -> merc

    def local(self, lat, lon):
        E, N = mga56(lat, lon)
        return E - self.E0, N - self.N0


def inside(p, half=HALF + MARGIN):
    return abs(p[0]) <= half and abs(p[1]) <= half


# ================================================================ OSM
def load_osm(src):
    raw = json.load(gzip.open(os.path.join(src, "osm", "osm_all.json.gz"), "rt", encoding="utf-8"))
    nodes, ways, rels = {}, {}, []
    for el in raw["elements"]:
        if el["type"] == "node":
            nodes[el["id"]] = el
        elif el["type"] == "way":
            ways[el["id"]] = el
        else:
            rels.append(el)
    return nodes, ways, rels


def site_origin(cfg, osm):
    nodes, ways, _ = osm
    w = ways[cfg["osm"][1]]
    pts = [(nodes[n]["lat"], nodes[n]["lon"]) for n in w["nodes"] if n in nodes]
    if pts[0] == pts[-1]:
        pts = pts[:-1]
    # area centroid in a flat frame
    la0, lo0 = pts[0]
    k = math.cos(math.radians(la0))
    xy = [((lo - lo0) * k, la - la0) for la, lo in pts]
    A = cx = cy = 0.0
    for (x1, y1), (x2, y2) in zip(xy, xy[1:] + xy[:1]):
        c = x1 * y2 - x2 * y1
        A += c
        cx += (x1 + x2) * c
        cy += (y1 + y2) * c
    cx, cy = cx / (3 * A), cy / (3 * A)
    return la0 + cy, lo0 + cx / k, w


def prep_osm(site, cfg, F, osm, out):
    nodes, ways, rels = osm
    loc = {nid: F.local(n["lat"], n["lon"]) for nid, n in nodes.items()}
    keep_w = {wid for wid, w in ways.items() if any(n in loc and inside(loc[n]) for n in w["nodes"])}
    keep_r = []
    for r in rels:
        mem = [m for m in r.get("members", []) if m["type"] == "way" and m["ref"] in keep_w]
        if mem:
            r = dict(r)
            r["members"] = mem
            keep_r.append(r)
    keep_n = set()
    for wid in keep_w:
        keep_n.update(ways[wid]["nodes"])
    keep_n.update(nid for nid, p in loc.items() if inside(p) and nodes[nid].get("tags"))
    els = []
    for nid in sorted(keep_n):
        if nid in nodes:
            n = nodes[nid]
            e = {"type": "node", "id": nid, "lat": round(n["lat"], 7), "lon": round(n["lon"], 7)}
            if n.get("tags"):
                e["tags"] = n["tags"]
            els.append(e)
    els += [ways[w] for w in sorted(keep_w)] + keep_r
    p = os.path.join(out, "osm_%s_800m.json.gz" % site)
    with gzip.open(p, "wt", encoding="utf-8") as f:
        json.dump({"note": "OpenStreetMap data (c) OpenStreetMap contributors, ODbL 1.0. Elements touching the "
                           "880 m square round %s (site.json origin)." % cfg["name"], "elements": els},
                  f, separators=(",", ":"))
    print("  osm: %d nodes, %d ways, %d relations (%.1f MB)" % (len(keep_n), len(keep_w), len(keep_r),
                                                               os.path.getsize(p) / 1e6))
    return loc


# ================================================================ rasters
def read_tif(path):
    b = open(path, "rb").read()
    bo = "<" if b[:2] == b"II" else ">"
    off = struct.unpack(bo + "I", b[4:8])[0]
    n = struct.unpack(bo + "H", b[off:off + 2])[0]
    tags = {}
    for i in range(n):
        e = b[off + 2 + 12 * i: off + 14 + 12 * i]
        tag, typ, cnt = struct.unpack(bo + "HHI", e[:8])
        size = {1: 1, 2: 1, 3: 2, 4: 4, 5: 8, 11: 4, 12: 8, 16: 8}.get(typ, 1) * cnt
        raw = e[8:12] if size <= 4 else b[struct.unpack(bo + "I", e[8:12])[0]:][:size]
        fmt = {3: "H", 4: "I", 11: "f", 12: "d", 16: "Q"}.get(typ)
        tags[tag] = struct.unpack(bo + fmt * cnt, raw[:size]) if fmt else raw[:size]
    w, h = tags[256][0], tags[257][0]
    assert tags.get(259, (1,))[0] == 1, "compressed TIFF"
    dt = np.dtype(bo + "f4")
    if 322 in tags:
        tw, th = tags[322][0], tags[323][0]
        out = np.zeros((h, w), "f4")
        txn = (w + tw - 1) // tw
        for k, (o, c) in enumerate(zip(tags[324], tags[325])):
            ty, tx = divmod(k, txn)
            blk = np.frombuffer(b[o:o + c], dt).reshape(th, tw)
            hh, ww = min(th, h - ty * th), min(tw, w - tx * tw)
            out[ty * th:ty * th + hh, tx * tw:tx * tw + ww] = blk[:hh, :ww]
        return out
    data = b"".join(b[o:o + c] for o, c in zip(tags[273], tags[279]))
    return np.frombuffer(data[:w * h * 4], dt).reshape(h, w).astype("f4")


def mga_mosaic_dem(d, E_lo, E_hi, N_lo, N_hi):
    """QldDem default 1 km tiles -> one array covering [E_lo,E_hi) x [N_lo,N_hi) (rows north->south)."""
    te0, te1 = int(E_lo // 1000) * 1000, int(E_hi // 1000) * 1000
    tn0, tn1 = int(N_lo // 1000) * 1000, int(N_hi // 1000) * 1000
    W, H = te1 - te0 + 1000, tn1 - tn0 + 1000
    out = np.full((H, W), np.nan, "f4")
    for te in range(te0, te1 + 1, 1000):
        for tn in range(tn0, tn1 + 1, 1000):
            p = os.path.join(d, "dem_%d_%d.tif" % (te, tn))
            if not os.path.exists(p):
                continue
            r0 = (tn1 + 1000) - (tn + 1000)
            out[r0:r0 + 1000, te - te0:te - te0 + 1000] = read_tif(p)
    return out, te0, tn1 + 1000   # array, west E, north N


def sample_bilinear(a, E0, N1, E, N):
    """Pixel centres at (E0+c+0.5, N1-r-0.5)."""
    c = E - E0 - 0.5
    r = N1 - N - 0.5
    c0 = np.clip(np.floor(c).astype(int), 0, a.shape[1] - 2)
    r0 = np.clip(np.floor(r).astype(int), 0, a.shape[0] - 2)
    fc, fr = np.clip(c - c0, 0, 1), np.clip(r - r0, 0, 1)
    return ((a[r0, c0] * (1 - fc) + a[r0, c0 + 1] * fc) * (1 - fr)
            + (a[r0 + 1, c0] * (1 - fc) + a[r0 + 1, c0 + 1] * fc) * fr)


def prep_dem(site, F, src, out):
    xs = np.arange(-HALF, HALF + 0.5, 1.0)
    X, Y = np.meshgrid(xs, -xs)
    E, N = F.E0 + X, F.N0 + Y
    a, E0, N1 = mga_mosaic_dem(os.path.join(src, "dem", "default"), E.min() - 2, E.max() + 2, N.min() - 2, N.max() + 2)
    v = sample_bilinear(a, E0, N1, E, N)
    bad = ~np.isfinite(v) | (v < -100)
    v[bad] = 0.0
    with gzip.open(os.path.join(out, "dem_1m.f32.gz"), "wb") as f:
        f.write(v.astype("<f4").tobytes())
    json.dump({"rows": v.shape[0], "cols": v.shape[1], "x0": -HALF, "y0": HALF, "step": 1.0, "units": "metres AHD",
               "order": "rows north to south, cols west to east, sample at grid point", "nodata_filled": int(bad.sum()),
               "source": "Queensland DEM image service (QldDem, default mix: LiDAR + river bed), 1 m tiles, MGA56",
               "credit": "(c) State of Queensland (Department of Resources) 2026, CC BY 4.0"},
              open(os.path.join(out, "dem_1m.json"), "w"), indent=1)
    print("  dem: %.2f..%.2f m AHD, nodata %d" % (v.min(), v.max(), bad.sum()))


# ================================================================ LiDAR (2019, CBD only)
def lidar_mosaic(src, names):
    d = os.path.join(src, "elvis", "grid2019")
    if not os.path.isdir(d):
        return None
    tiles = [t for t in os.listdir(d) if os.path.exists(os.path.join(d, t, "grid.json"))]
    es = sorted({int(t.split("_")[0]) for t in tiles})
    ns = sorted({int(t.split("_")[1]) for t in tiles})
    E0, N1 = es[0], ns[-1] + 1000
    W, H = es[-1] + 1000 - E0, N1 - ns[0]
    out = {k: np.full((H, W), np.nan, "f4") for k in names}
    for t in tiles:
        g = json.load(open(os.path.join(d, t, "grid.json")))
        r0, c0 = N1 - g["Y1"], g["X0"] - E0
        for k in names:
            p = os.path.join(d, t, k + ".f32")
            if not os.path.exists(p):
                continue
            a = np.fromfile(p, "<f4").reshape(g["H"], g["W"])
            r1, c1 = min(H, r0 + g["H"]), min(W, c0 + g["W"])
            sub = a[: r1 - r0, : c1 - c0]
            cur = out[k][r0:r1, c0:c1]
            out[k][r0:r1, c0:c1] = np.where(np.isnan(cur), sub, np.fmax(cur, sub))
    return out, E0, N1


def ring_mask(ring, box):
    x0, y0, x1, y1 = box
    xs = [p[0] for p in ring]
    ys = [p[1] for p in ring]
    c0 = max(0, int(math.floor(min(xs) - x0)))
    c1 = min(x1 - x0, int(math.ceil(max(xs) - x0)))
    r0 = max(0, int(math.floor(y1 - max(ys))))
    r1 = min(y1 - y0, int(math.ceil(y1 - min(ys))))
    if c1 <= c0 or r1 <= r0:
        return None, 0, 0
    X, Y = np.meshgrid(x0 + np.arange(c0, c1) + 0.5, y1 - np.arange(r0, r1) - 0.5)
    m = np.zeros(X.shape, bool)
    n = len(ring)
    for i in range(n):
        (xa, ya), (xb, yb) = ring[i], ring[(i + 1) % n]
        if ya == yb:
            continue
        cond = (ya > Y) != (yb > Y)
        m ^= cond & (X < (xb - xa) * (Y - ya) / (yb - ya) + xa)
    return m, r0, c0


def prep_lidar(site, cfg, F, src, out, osm, loc):
    names = ["dsm", "gnd", "veg", "bld", "oth"]
    mos = lidar_mosaic(src, names)
    if mos is None:
        print("  lidar: none for this area")
        return
    mos, E0, N1 = mos
    box = (-int(HALF), -int(HALF), int(HALF), int(HALF))
    cols = np.floor(F.E0 + np.arange(box[0], box[2]) + 0.5 - E0).astype(int)
    rows = np.floor(N1 - (F.N0 + np.arange(box[3], box[1], -1) - 0.5)).astype(int)
    okc = (cols >= 0) & (cols < mos["dsm"].shape[1])
    okr = (rows >= 0) & (rows < mos["dsm"].shape[0])
    loc_g = {}
    for k in names:
        g = np.full((len(rows), len(cols)), np.nan, "f4")
        g[np.ix_(okr, okc)] = mos[k][np.ix_(rows[okr], cols[okc])]
        loc_g[k] = g
    xs = np.arange(box[0], box[2]) + 0.5
    X, Y = np.meshgrid(xs, -xs)
    d, dE0, dN1 = mga_mosaic_dem(os.path.join(src, "dem", "default"), F.E0 - 450, F.E0 + 450, F.N0 - 450, F.N0 + 450)
    old = sample_bilinear(d, dE0, dN1, F.E0 + X, F.N0 + Y)
    old = np.where(np.isfinite(old), old, 0.0)
    gnd = np.where(np.isnan(loc_g["gnd"]), old, loc_g["gnd"]).astype("f4")
    top = loc_g["dsm"]
    dsm = np.where(np.isnan(top), gnd, np.fmax(top, gnd)).astype("f4")
    cls = np.zeros(dsm.shape, "u1")
    near = lambda a: np.isfinite(a) & (np.abs(a - top) < 0.01)
    cls[near(loc_g["gnd"]) | (np.isfinite(top) & (top - gnd < 0.5))] = 1
    cls[near(loc_g["veg"])] = 2
    cls[near(loc_g["oth"])] = 4
    cls[near(loc_g["bld"])] = 3
    cls[np.isnan(top)] = 0
    od = os.path.join(out, "lidar")
    os.makedirs(od, exist_ok=True)
    for name, a in (("dsm_1m.f32.gz", dsm), ("ground_1m.f32.gz", gnd)):
        with gzip.open(os.path.join(od, name), "wb") as f:
            f.write(a.astype("<f4").tobytes())
    with gzip.open(os.path.join(od, "class_1m.u8.gz"), "wb") as f:
        f.write(cls.tobytes())
    # trees
    can = np.nan_to_num(loc_g["veg"] - gnd, nan=0.0)
    from numpy.lib.stride_tricks import sliding_window_view
    mx = sliding_window_view(np.pad(can, 2), (5, 5)).max(axis=(2, 3))
    rr, cc = np.nonzero((can >= mx) & (can > 3.0))
    with open(os.path.join(od, "tree_points.csv"), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["x_local", "y_local", "height_m", "ground_ahd"])
        for r, c in zip(rr, cc):
            w.writerow([box[0] + c + 0.5, box[3] - r - 0.5, round(float(can[r, c]), 2), round(float(gnd[r, c]), 2)])
    # building heights per OSM footprint
    nodes, ways, _ = osm
    rows_out = []
    for wid, wy in ways.items():
        t = wy.get("tags", {})
        if "building" not in t and "building:part" not in t:
            continue
        ring = [loc[n] for n in wy["nodes"] if n in loc]
        if len(ring) < 3 or not any(inside(p, HALF) for p in ring):
            continue
        m, r0, c0 = ring_mask(ring, box)
        if m is None or not m.any():
            continue
        sub = (slice(r0, r0 + m.shape[0]), slice(c0, c0 + m.shape[1]))
        tops = dsm[sub][m]
        roof = tops[(cls[sub][m] == 3) | (cls[sub][m] == 4)]
        g = float(np.median(gnd[sub][m]))
        if len(roof) < max(3, 0.2 * m.sum()):
            roof = tops
        h = float(np.percentile(roof, 90)) - g
        rows_out.append({"osm_way": wid, "name": t.get("name", ""), "kind": "part" if "building:part" in t else "building",
                         "cells": int(m.sum()), "roof_cells": int(len(roof)), "ground_median_ahd": round(g, 2),
                         "roof_p90_ahd": round(g + h, 2), "roof_max_ahd": round(float(roof.max()), 2),
                         "height_m": round(h, 2), "osm_height": t.get("height", ""),
                         "osm_levels": t.get("building:levels", "")})
    with open(os.path.join(od, "building_heights.csv"), "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(rows_out[0].keys()))
        w.writeheader()
        w.writerows(rows_out)
    # the site itself: height profile inside the outline grown 10 %
    ring = [loc[n] for n in ways[cfg["osm"][1]]["nodes"] if n in loc]
    cx = sum(p[0] for p in ring) / len(ring)
    cy = sum(p[1] for p in ring) / len(ring)
    grown = [(cx + (x - cx) * 1.1, cy + (y - cy) * 1.1) for x, y in ring]
    m, r0, c0 = ring_mask(grown, box)
    sub = (slice(r0, r0 + m.shape[0]), slice(c0, c0 + m.shape[1]))
    hgt = (dsm[sub] - gnd[sub])[m]
    top_cells = dsm[sub][m]
    site = {"cells": int(m.sum()), "ground_min_ahd": round(float(gnd[sub][m].min()), 2),
            "ground_median_ahd": round(float(np.median(gnd[sub][m])), 2),
            "ground_max_ahd": round(float(gnd[sub][m].max()), 2),
            "top_max_ahd": round(float(top_cells.max()), 2),
            "top_p99_ahd": round(float(np.percentile(top_cells, 99)), 2),
            "area_over_6m_m2": int((hgt > 6).sum()), "area_over_50m_m2": int((hgt > 50).sum()),
            "area_over_150m_m2": int((hgt > 150).sum()),
            "height_bands_m2": {"%d-%d" % (a, a + 20): int(((hgt >= a) & (hgt < a + 20)).sum())
                                for a in range(-40, 300, 20) if ((hgt >= a) & (hgt < a + 20)).any()},
            "note": "2019 LiDAR (flown Jun-Aug 2019) inside the OSM outline grown 10 %; heights = DSM - ground."}
    hdr = {"box_local": list(box), "step_m": 1.0, "rows": int(dsm.shape[0]), "cols": int(dsm.shape[1]),
           "order": "rows north to south, cols west to east; cell centres at (x0+c+0.5, y1-r-0.5)",
           "class_codes": {"0": "no return", "1": "ground", "2": "vegetation", "3": "building", "4": "other (bridge, cranes...)"},
           "trees": int(len(rr)), "buildings": len(rows_out), "site_2019": site,
           "source": "Brisbane 2019 Project LiDAR (classified point cloud, flown 2019-06/08), ordered from ELVIS, "
                     "gridded by tools/lidar/grid.js; gaps from the QldDem default mix.",
           "credit": "(c) State of Queensland (Department of Resources), CC BY 4.0"}
    json.dump(hdr, open(os.path.join(od, "lidar.json"), "w"), indent=1)
    print("  lidar: trees %d, buildings %d, site top %.1f m AHD (ground %.1f)" % (len(rr), len(rows_out),
          site["top_max_ahd"], site["ground_median_ahd"]))
    return dsm, gnd, cls


# ================================================================ aerials
_img_cache = {}


def aerial_sources(src, area, year):
    """All 800 m squares downloaded for this year in the area: [(merc box, image array)]."""
    out = []
    for sid, (la, lo) in AERIAL_CENTRES[area].items():
        n = os.path.join(src, "aerial", sid, "aerial_%d_800m_0p2m_n.jpg" % year)
        s = os.path.join(src, "aerial", sid, "aerial_%d_800m_0p2m_s.jpg" % year)
        if not (os.path.exists(n) and os.path.exists(s)):
            continue
        key = (sid, year)
        if key not in _img_cache:
            _img_cache[key] = np.concatenate([np.asarray(Image.open(n).convert("RGB")),
                                              np.asarray(Image.open(s).convert("RGB"))], 0)
        out.append((merc_box(la, lo, 400), _img_cache[key], sid))
    return out


def render_aerial(F, srcs, half, px):
    mpp = 2 * half / px
    v = -half + (np.arange(px) + 0.5) * mpp
    X, Y = np.meshgrid(v, -v)
    MX = F.A[0, 0] * X + F.A[0, 1] * Y + F.A[0, 2]
    MY = F.A[1, 0] * X + F.A[1, 1] * Y + F.A[1, 2]
    out = np.full((px, px, 3), 128.0, "f4")
    done = np.zeros((px, px), bool)
    used = []
    # prefer the square whose centre is nearest the site (least lean / seams)
    srcs = sorted(srcs, key=lambda s: ((s[0][0] + s[0][2]) / 2 - F.A[0, 2]) ** 2 + ((s[0][1] + s[0][3]) / 2 - F.A[1, 2]) ** 2)
    for (bx0, by0, bx1, by1), img, sid in srcs:
        H, W = img.shape[:2]
        col = (MX - bx0) / (bx1 - bx0) * W - 0.5
        row = (by1 - MY) / (by1 - by0) * H - 0.5
        ok = (~done) & (col >= 0) & (col <= W - 1.001) & (row >= 0) & (row <= H - 1.001)
        if not ok.any():
            continue
        c, r = col[ok], row[ok]
        c0, r0 = c.astype(int), r.astype(int)
        fc, fr = (c - c0)[:, None], (r - r0)[:, None]
        imf = img.astype("f4")
        val = ((imf[r0, c0] * (1 - fc) + imf[r0, c0 + 1] * fc) * (1 - fr)
               + (imf[r0 + 1, c0] * (1 - fc) + imf[r0 + 1, c0 + 1] * fc) * fr)
        out[ok] = val
        done |= ok
        used.append(sid)
    return out.astype("u1"), float(done.mean()), used


def prep_aerials(site, cfg, F, src, out):
    years = sorted({int(f.split("_")[1]) for sid in AERIAL_CENTRES[cfg["area"]]
                    if os.path.isdir(os.path.join(src, "aerial", sid))
                    for f in os.listdir(os.path.join(src, "aerial", sid)) if f.endswith("_n.jpg")})
    info = {}
    for yr in years:
        srcs = aerial_sources(src, cfg["area"], yr)
        img, cover, used = render_aerial(F, srcs, HALF, 1600)
        if cover < 0.5:
            continue
        p = os.path.join(out, "aerial_%d_800m_0p5m.jpg" % yr)
        Image.fromarray(img).save(p, quality=88)
        info[yr] = {"cover_800m": round(cover, 3), "from": used}
        if yr in cfg["site_years"] or yr == max(years):
            sh = cfg["site_half"]
            img, cover, used = render_aerial(F, srcs, sh, 1600)
            p = os.path.join(out, "aerial_%d_site%dm.jpg" % (yr, int(2 * sh)))
            Image.fromarray(img).save(p, quality=90)
            info[yr]["site_crop"] = {"file": os.path.basename(p), "m_per_px": round(2 * sh / 1600, 4)}
        print("  aerial %d: %.0f %% covered" % (yr, 100 * cover))
    _img_cache.clear()
    return info


# ================================================================ council
def coords_of(g):
    if g is None:
        return []
    t, c = g["type"], g.get("coordinates")
    if t == "Point":
        return [c]
    if t in ("LineString", "MultiPoint"):
        return c
    if t in ("Polygon", "MultiLineString"):
        return [p for r in c for p in r]
    if t == "MultiPolygon":
        return [p for poly in c for r in poly for p in r]
    if t == "GeometryCollection":
        return [p for gg in g["geometries"] for p in coords_of(gg)]
    return []


def prep_council(site, F, src, out):
    feats, counts = [], {}
    for name in COUNCIL:
        p = os.path.join(src, "council", name + ".geojson")
        if not os.path.exists(p):
            continue
        n = 0
        for f in json.load(open(p, encoding="utf-8")).get("features", []):
            pts = coords_of(f.get("geometry"))
            if pts and any(inside(F.local(q[1], q[0])) for q in pts[:: max(1, len(pts) // 20)] + pts[-1:]):
                f = dict(f)
                f["properties"] = dict(f.get("properties") or {}, layer=name)
                feats.append(f)
                n += 1
        counts[name] = n
    p = os.path.join(out, "council_%s.geojson" % site)
    json.dump({"type": "FeatureCollection", "note": "Brisbane City Council open data (data.brisbane.qld.gov.au), "
               "CC BY 4.0. Cropped to the 880 m square. 'layer' = source dataset id.", "counts": counts,
               "features": feats}, open(p, "w", encoding="utf-8"), separators=(",", ":"))
    print("  council: %d features" % len(feats))


# ================================================================ main
CREDITS = """# {name} reference data: sources and licences

Everything here is cropped to the 800 m square round {name}, in a local frame:
origin = centroid of OSM {otype} {oid} (MGA56 {E:.2f} E, {N:.2f} N; {lat:.7f}, {lon:.7f}), +x east, +y north,
z metres AHD. Made by `tools/sites/prep_site.py` from the site download in `PourDecisions-sites/data/{area}`
(not in git). See `site.json` for the file list.

| File | What | Source | Licence |
|---|---|---|---|
| `osm_{id}_800m.json.gz` | OSM nodes, ways, relations touching the 880 m square | OpenStreetMap, Nov 2026 | ODbL 1.0, (c) OpenStreetMap contributors |
| `dem_1m.f32.gz`, `dem_1m.json` | Ground heights incl. river bed, 1 m, 801 x 801, float32 LE, rows north to south | QldDem default mix | CC BY 4.0, (c) State of Queensland |
| `lidar/*` | 2019 DSM, ground, class grid, building heights, tree tops, site height profile (800 x 800, 1 m) | Brisbane 2019 Project LiDAR via ELVIS | CC BY 4.0, (c) State of Queensland |
| `aerial_YYYY_800m_0p5m.jpg` | Aerial, local frame, north up, 0.5 m/px | Qld aerial orthophoto time series | CC BY 4.0, (c) State of Queensland |
| `aerial_YYYY_site*m.jpg` | Close crop of the site, 1600 px (resampled from 0.2 m) | same | same |
| `council_{id}.geojson` | Loading zones, bus stops, parking signs/lines, road hierarchy, bikeways, significant trees, parks | Brisbane City Council open data | CC BY 4.0, (c) Brisbane City Council |

Credits to show in the game:
- Map data (c) OpenStreetMap contributors, ODbL 1.0.
- Includes material (c) State of Queensland (Department of Resources) 2026, CC BY 4.0. The State gives no
  warranty in relation to the data and accepts no liability for its use.
- Contains data from Brisbane City Council, CC BY 4.0.

Notes
- Aerials are ordinary orthophotos, not true-ortho: tall buildings lean away from the camera's nadir.
- Grey areas in an aerial = outside every square downloaded for that year.
- Not here on purpose: John's own photos and Wikimedia Commons photos (matching only, kept out of git).
"""


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    flags = dict(a[2:].split("=", 1) for a in sys.argv[1:] if a.startswith("--") and "=" in a)
    data = args[0] if args else r"C:\Users\John\Documents\PourDecisions-sites\data"
    sites = args[1].split(",") if len(args) > 1 else list(SITES)
    only = set(flags.get("only", "osm,dem,lidar,aerial,council").split(","))
    osm_cache = {}
    for site in sites:
        cfg = SITES[site]
        src = os.path.join(data, cfg["area"])
        if cfg["area"] not in osm_cache:
            osm_cache[cfg["area"]] = load_osm(src)
        osm = osm_cache[cfg["area"]]
        lat, lon, way = site_origin(cfg, osm)
        F = Frame(lat, lon)
        out = os.path.join(REPO, "reference", "sites", site)
        os.makedirs(out, exist_ok=True)
        print("%s: origin %.7f, %.7f (MGA %.2f, %.2f)" % (site, lat, lon, F.E0, F.N0))
        loc = prep_osm(site, cfg, F, osm, out) if "osm" in only else \
            {nid: F.local(n["lat"], n["lon"]) for nid, n in osm[0].items()}
        outline = [[round(loc[n][0], 2), round(loc[n][1], 2)] for n in way["nodes"] if n in loc]
        if "dem" in only:
            prep_dem(site, F, src, out)
        if "lidar" in only:
            prep_lidar(site, cfg, F, src, out, osm, loc)
        aer = prep_aerials(site, cfg, F, src, out) if "aerial" in only else {}
        if "council" in only:
            prep_council(site, F, src, out)
        meta_p = os.path.join(out, "site.json")
        meta = json.load(open(meta_p)) if os.path.exists(meta_p) else {}
        meta.update({"id": site, "name": cfg["name"], "build_years": cfg["build"],
                     "origin": {"lat": round(lat, 7), "lon": round(lon, 7), "mga56_E": round(F.E0, 2),
                                "mga56_N": round(F.N0, 2),
                                "rule": "centroid of the OSM %s %d outline" % cfg["osm"]},
                     "frame": "+x east, +y north (MGA56 grid), z metres AHD; data covers x, y in [-400, 400]",
                     "osm_outline": {"type": cfg["osm"][0], "id": cfg["osm"][1], "tags": way.get("tags", {}),
                                     "ring_local": outline}})
        if aer:
            meta["aerials"] = {str(k): v for k, v in aer.items()}
        json.dump(meta, open(meta_p, "w"), indent=1)
        with open(os.path.join(out, "CREDITS.md"), "w") as f:
            f.write(CREDITS.format(name=cfg["name"], otype=cfg["osm"][0], oid=cfg["osm"][1], E=F.E0, N=F.N0,
                                   lat=lat, lon=lon, area=cfg["area"], id=site))


if __name__ == "__main__":
    main()
