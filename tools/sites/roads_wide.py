"""Roads, rail and bridges from OSM over the river box (no bpy), with bridge deck heights from the 2019 LiDAR.

    python3 tools/sites/roads_wide.py <PourDecisions-sites>/data

Input: <data>/cbd/osm/osm_all.json.gz (OSM, CBD + inner suburbs) and <data>/cbd/elvis/grid2019 (LiDAR DSM).
Box: reference/sites/spire/river/river.json (river_shape.py). Writes reference/sites/spire/roads/roads.json:

    ways     [{id, kind, cls, name, width, lanes, oneway, bridge, layer, pts: [[x, y], ...] (local, every <= 4 m),
               deck: [z AHD per point] for bridges (LiDAR, else ramped between the ends)}]
    bridges  [{osm, name, ring: [[x, y]...]}]  OSM man_made=bridge outlines (deck footprints)

Kinds: road (car classes, busway), path (footway/cycleway/pedestrian on bridges, and named riverwalks),
rail (railway=rail / light_rail). Tunnels (tunnel=* or layer < 0) are left out: they're underground.
"""
import gzip
import json
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(REPO, "tools", "blender", "spire"))
import layout as L  # noqa: E402

OUT = os.path.join(L.REF, "roads")
ROAD = {"motorway", "motorway_link", "trunk", "trunk_link", "primary", "primary_link", "secondary",
        "secondary_link", "tertiary", "tertiary_link", "unclassified", "residential", "living_street",
        "busway", "service"}
PATH = {"footway", "cycleway", "pedestrian", "path"}
WIDTH = dict(L.ROAD_WIDTH, motorway=7.0, motorway_link=4.5, trunk=10.0, trunk_link=4.5, busway=7.5,
             residential=7.0, service=4.0)
LANE = 3.5
SEG = 4.0


def width(t, kind):
    w = L.tag_float(t, "width")
    if w and 1.0 < w < 40:
        return w
    if kind == "rail":
        return 4.2
    lanes = L.tag_float(t, "lanes")
    hw = t.get("highway", "")
    if kind == "road" and lanes:
        return max(lanes * (LANE if hw.startswith(("motorway", "trunk")) else L.LANE_WIDTH), 3.5)
    return WIDTH.get(hw, 3.0 if kind == "path" else 6.0)


def densify(pts, step=SEG):
    out = [pts[0]]
    for a, b in zip(pts[:-1], pts[1:]):
        d = math.dist(a, b)
        n = max(1, int(math.ceil(d / step)))
        for k in range(1, n + 1):
            out.append((a[0] + (b[0] - a[0]) * k / n, a[1] + (b[1] - a[1]) * k / n))
    return out


class Lidar:
    def __init__(self, gdir):
        self.tiles = {}
        for t in os.listdir(gdir):
            g = json.load(open(os.path.join(gdir, t, "grid.json")))
            self.tiles[(g["X0"], g["Y1"] - g["H"])] = (g, os.path.join(gdir, t))
        self.cache = {}

    def dsm(self, E, N):
        key = (int(E // 1000) * 1000, int(N // 1000) * 1000)
        if key not in self.tiles:
            return np.nan
        if key not in self.cache:
            g, d = self.tiles[key]
            self.cache[key] = (g, np.fromfile(os.path.join(d, "dsm.f32"), "<f4").reshape(g["H"], g["W"]),
                               np.fromfile(os.path.join(d, "gnd.f32"), "<f4").reshape(g["H"], g["W"]))
        g, a, _ = self.cache[key]
        c, r = int(E - g["X0"]), int(g["Y1"] - N)
        if 0 <= r < g["H"] and 0 <= c < g["W"]:
            return float(a[r, c])
        return np.nan

    def window(self, E, N, r=1):
        v = [self.dsm(E + dx, N + dy) for dx in range(-r, r + 1) for dy in range(-r, r + 1)]
        v = [x for x in v if x == x]
        return float(np.median(v)) if v else np.nan


# decks the LiDAR can't see: built after 2019 (river clearance 11.4-12.7 m above high water, Wikipedia)
DECK_MID = {"Neville Bonner Bridge": 13.5, "Kangaroo Point Bridge": 14.0}
# decks under a canopy or arch bracing (the LiDAR reads the steel above): capped at the approach level
DECK_CAP = {"Kurilpa Bridge": 15.5, "Merivale Bridge": 17.0}


def deck_heights(pts, w, lid, gz_end, mid=None, cap=None):
    """Deck z per point: LiDAR DSM sampled across the deck (min of three lines, so arches, masts and
    trucks over the centre drop out), a rolling 30th percentile along it, ends tied to the approaches."""
    oE, oN = L.ORIGIN_MGA56
    n = len(pts)
    z = np.full(n, np.nan)
    for i, (x, y) in enumerate(pts):
        a = pts[max(i - 1, 0)]
        b = pts[min(i + 1, n - 1)]
        dx, dy = b[0] - a[0], b[1] - a[1]
        ln = math.hypot(dx, dy) or 1.0
        nx, ny = -dy / ln, dx / ln
        off = max(0.0, w / 2 - 1.2)
        vals = [lid.window(oE + x + nx * o, oN + y + ny * o) for o in (-off, 0.0, off)]
        vals = [v for v in vals if v == v]
        if vals:
            z[i] = min(vals)
    ok = ~np.isnan(z)
    if ok.sum() >= max(3, 0.3 * n):
        idx = np.arange(n)
        z = np.interp(idx, idx[ok], z[ok])
        k = 4
        z = np.array([np.percentile(z[max(0, i - k):i + k + 1], 30) for i in range(n)])
        src = "lidar"
    else:
        z0, z1 = gz_end
        t = np.linspace(0, 1, n)
        z = z0 + (z1 - z0) * t + 4.0 * np.sin(np.pi * t)       # no LiDAR: a gentle hump between the ends
        src = "ramp (no lidar)"
        if mid is not None:                                    # built after the 2019 LiDAR: published clearance,
            d = t * n * SEG                                    # the last 60 m each end comes down to the landing
            e0, e1 = max(z0, 3.0), max(z1, 3.0)
            k0 = np.clip(d / 60.0, 0, 1)
            k1 = np.clip((n * SEG - d) / 60.0, 0, 1)
            z = np.minimum(e0 + (mid - e0) * k0, e1 + (mid - e1) * k1)
            src = "published clearance (built after the LiDAR)"
    if cap is not None:
        z = np.minimum(z, cap)
    return [round(float(v), 2) for v in z], src


def main():
    data = sys.argv[1]
    rv = json.load(open(os.path.join(L.REF, "river", "river.json")))
    bx0, by0, bx1, by1 = rv["box_local"]
    raw = json.load(gzip.open(os.path.join(data, "cbd", "osm", "osm_all.json.gz"), "rt", encoding="utf-8"))
    nodes = {}
    ways = []
    for el in raw["elements"]:
        if el["type"] == "node":
            nodes[el["id"]] = (el["lat"], el["lon"])
        elif el["type"] == "way":
            ways.append(el)
    loc = {}

    def P(nid):
        if nid not in loc:
            la, lo = nodes[nid]
            loc[nid] = L.to_local(la, lo)
        return loc[nid]

    lid = Lidar(os.path.join(data, "cbd", "elvis", "grid2019"))
    oE, oN = L.ORIGIN_MGA56

    def ground(x, y):
        if L.LIDAR_BOX[0] <= x < L.LIDAR_BOX[2] and L.LIDAR_BOX[1] < y <= L.LIDAR_BOX[3]:
            return L.ground_z(x, y)
        key = (int((oE + x) // 1000) * 1000, int((oN + y) // 1000) * 1000)
        if key in lid.tiles:
            lid.dsm(oE + x, oN + y)
            g, _, gn = lid.cache[key]
            c, r = int(oE + x - g["X0"]), int(g["Y1"] - oN - y)
            win = gn[max(r - 3, 0):r + 4, max(c - 3, 0):c + 4]
            if np.isfinite(win).any():
                return float(np.nanmedian(win))
        return 8.0

    out, bridges, counts = [], [], {}
    for w in ways:
        t = w.get("tags", {})
        if t.get("man_made") == "bridge" and w["nodes"][0] == w["nodes"][-1]:
            if all(n in nodes for n in w["nodes"]):
                ring = [P(n) for n in w["nodes"][:-1]]
                cx = sum(p[0] for p in ring) / len(ring)
                cy = sum(p[1] for p in ring) / len(ring)
                if bx0 < cx < bx1 and by0 < cy < by1:
                    bridges.append({"osm": w["id"], "name": t.get("name", ""),
                                    "ring": [[round(x, 2), round(y, 2)] for x, y in ring]})
            continue
        hw, rw = t.get("highway"), t.get("railway")
        if hw in ROAD:
            if hw == "service" and t.get("service") in ("driveway", "parking_aisle", "drive-through"):
                continue
            kind = "road"
        elif hw in PATH and (t.get("bridge", "no") != "no" or "Riverwalk" in t.get("name", "")):
            kind = "path"
        elif rw in ("rail", "light_rail") and t.get("service") not in ("siding", "yard", "spur"):
            kind = "rail"
        else:
            continue
        if t.get("tunnel", "no") != "no" or t.get("covered") == "yes" or (L.tag_float(t, "layer") or 0) < 0:
            continue
        if t.get("area") == "yes" or not all(n in nodes for n in w["nodes"]):
            continue
        pts = [P(n) for n in w["nodes"]]
        if not any(bx0 < x < bx1 and by0 < y < by1 for x, y in pts):
            continue
        pts = densify(pts)
        wd = width(t, kind)
        rec = {"id": w["id"], "kind": kind, "cls": hw or rw, "name": t.get("name", ""), "width": round(wd, 2),
               "lanes": L.tag_float(t, "lanes"), "oneway": t.get("oneway") == "yes",
               "bridge": t.get("bridge", "no") != "no", "layer": L.tag_float(t, "layer") or 0,
               "pts": [[round(x, 2), round(y, 2)] for x, y in pts]}
        if rec["bridge"]:
            z, src = deck_heights(pts, wd, lid, (ground(*pts[0]), ground(*pts[-1])),
                                  DECK_MID.get(t.get("name")), DECK_CAP.get(t.get("name")))
            rec["deck"], rec["deck_src"] = z, src
        out.append(rec)
        counts[kind + (" bridge" if rec["bridge"] else "")] = counts.get(kind + (" bridge" if rec["bridge"] else ""), 0) + 1
    os.makedirs(OUT, exist_ok=True)
    json.dump({"note": "OSM roads/rail/paths + bridge decks (LiDAR heights), Spire local metres. tools/sites/roads_wide.py",
               "box_local": [bx0, by0, bx1, by1], "ways": out, "bridges": bridges},
              open(os.path.join(OUT, "roads.json"), "w"), separators=(",", ":"))
    print(counts, "bridge outlines", len(bridges), "MB %.1f" % (os.path.getsize(os.path.join(OUT, "roads.json")) / 1e6))
    named = {}
    for r in out:
        if r["bridge"] and r["name"]:
            d = named.setdefault(r["name"], [])
            d.append((r["cls"], round(max(r["deck"]), 1), r["deck_src"], len(r["pts"]) * SEG))
    for k in sorted(named):
        print(k, named[k][:3])


if __name__ == "__main__":
    main()
