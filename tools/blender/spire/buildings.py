"""Neighbouring buildings, clean (step 5). LiDAR is for measuring only.

Each OSM footprint (simplified, squared) is extruded to its LiDAR-measured roof tiers
(reference/sites/spire/lidar/buildings_clean.json, made by prep_clean.py), with:
  - flat roofs: a parapet; pitched roofs: a clean gable over the footprint's rectangle
  - spires / roof masts: clean pyramids
  - floor lines every LEVEL_HEIGHT on the walls, and a facade family colour
    (heritage stone, brick low-rise, 70s-80s concrete, glass curtain wall)
"""
import json
import math
import os

import layout as L
import common as C
import shapes as S

HSW_ZONE = (380, -130, 800, 140)      # local x0, y0, x1, y1: the strip under the cliffs (hsw.py adds the rest)
SKIP = {26384715}                     # St John's Cathedral: cathedral.py
FAMILY_KEY = {"heritage": "fam_heritage", "brick": "fam_brick", "concrete": "fam_concrete", "glass": "fam_glass"}


def records():
    return json.load(open(os.path.join(L.REF, "lidar", "buildings_clean.json")))["buildings"]


def offset(ring, d):
    """Outward (d > 0) vertex offset of a CCW ring."""
    ring = S.ccw(ring)
    n = len(ring)
    out = []
    for i in range(n):
        p0, p1, p2 = ring[i - 1], ring[i], ring[(i + 1) % n]
        a = (p1[0] - p0[0], p1[1] - p0[1])
        b = (p2[0] - p1[0], p2[1] - p1[1])
        la, lb = math.hypot(*a) or 1, math.hypot(*b) or 1
        na = (a[1] / la, -a[0] / la)
        nb = (b[1] / lb, -b[0] / lb)
        nx, ny = na[0] + nb[0], na[1] + nb[1]
        ln = math.hypot(nx, ny) or 1
        nx, ny = nx / ln, ny / ln
        k = 1.0 / max(0.35, nx * na[0] + ny * na[1])
        out.append((p1[0] + nx * d * k, p1[1] + ny * d * k))
    return out


def gable(buf, g, base):
    """Triangular prism roof on the footprint's min rectangle, from the eave to the ridge."""
    c, s = math.cos(g["angle"]), math.sin(g["angle"])
    hl, hw = g["length"] / 2 + 0.3, g["width"] / 2 + 0.3
    e, r = g["eave_ahd"], g["ridge_ahd"]
    def P(u, v, z):
        return (g["cx"] + u * c - v * s, g["cy"] + u * s + v * c, z)
    verts = [P(-hl, -hw, e), P(hl, -hw, e), P(hl, hw, e), P(-hl, hw, e), P(-hl, 0, r), P(hl, 0, r)]
    faces = [[0, 1, 5, 4], [2, 3, 4, 5], [0, 4, 3], [1, 2, 5], [0, 3, 2, 1]]
    buf.add(verts, faces)


def spire(buf, sp):
    n = 8
    ring = [(sp["x"] + sp["r"] * math.cos(2 * math.pi * k / n), sp["y"] + sp["r"] * math.sin(2 * math.pi * k / n),
             sp["base_ahd"]) for k in range(n)]
    buf.add(ring + [(sp["x"], sp["y"], sp["top_ahd"])],
            [[k, (k + 1) % n, n] for k in range(n)] + [list(range(n - 1, -1, -1))])


def build(zone=None, collection="buildings", skip_zone=HSW_ZONE):
    col = C.collection(collection)
    walls = {k: C.MeshBuf() for k in FAMILY_KEY.values()}
    roofs, bands, extras = C.MeshBuf(), C.MeshBuf(), C.MeshBuf()
    n = 0
    for b in records():
        if b["osm"] in SKIP:
            continue
        ring0 = b["tiers"][0]["ring"]
        cx = sum(p[0] for p in ring0) / len(ring0)
        cy = sum(p[1] for p in ring0) / len(ring0)
        inz = lambda z: z and z[0] <= cx <= z[2] and z[1] <= cy <= z[3]
        if zone is not None and not inz(zone):
            continue
        if zone is None and (inz(skip_zone) or not C.in_model(cx, cy, 300)):
            continue
        fam = FAMILY_KEY[b["family"]]
        base = b["base_ahd"] - 0.5
        lower = base
        for k, t in enumerate(b["tiers"]):
            ring = S.ccw([tuple(p) for p in t["ring"]])
            z0 = base if k == 0 else max(lower - 0.2, base)
            top = t["top_ahd"]
            if top - z0 < 1.0:
                continue
            walls[fam].prism(ring, z0, top)
            flat = not (k == 0 and b["gable"])
            if flat and top - b["base_ahd"] > 8:
                pr = offset(ring, -0.25)
                roofs.prism(pr, top, top + 0.9)                     # parapet (solid cap, reads clean)
            if b["family"] != "heritage":
                z = b["base_ahd"] + L.LEVEL_HEIGHT
                band_ring = offset(ring, 0.08)
                while z < top - 1.0:
                    if z > z0 + 0.5:
                        bands.prism(band_ring, z, z + 0.25)
                    z += L.LEVEL_HEIGHT
            lower = top
        if b["gable"]:
            gable(roofs, b["gable"], base)
        for sp in b["spires"]:
            spire(extras, sp)
        n += 1
    objs = []
    for key, buf in walls.items():
        ob = buf.object("bldg_" + key, col, key)
        if ob:
            objs.append(ob.name)
    for buf, name, key in ((roofs, "bldg_roofs_parapets_gables", "roof"), (bands, "bldg_floor_lines", "band"),
                           (extras, "bldg_spires_masts", "roof")):
        ob = buf.object(name, col, key)
        if ob:
            objs.append(ob.name)
    return {"module": "buildings" if zone is None else collection, "objects": objs, "buildings": n,
            "source": "OSM footprints (simplified 0.3 m, squared) + 2019 LiDAR roof tiers (prep_clean.py)",
            "note": "Facade families are picked from height/tags; floor lines every %.1f m. No LiDAR mesh is "
                    "shown." % L.LEVEL_HEIGHT}
