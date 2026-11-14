"""Trees (step 5): clean low-poly models placed on the 2019 LiDAR tree tops and sized by the measured
height. Species shapes: fig (wide dome), jacaranda / poinciana (umbrella), eucalypt (tall, two
crowns), palm (bare trunk + fronds), generic street tree (round). The council species list has no
positions (street-tree-species), so the species is a stand-in chosen from height and a stable hash of
the position; replace it when a geo-tagged species layer turns up."""
import math

import layout as L
import common as C


def ico(r):
    """Unit octahedron subdivided once -> 32 faces, scaled by (rx, ry, rz)."""
    v = [(1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)]
    f = [(0, 2, 4), (2, 1, 4), (1, 3, 4), (3, 0, 4), (2, 0, 5), (1, 2, 5), (3, 1, 5), (0, 3, 5)]
    verts, faces, cache = list(v), [], {}
    def mid(a, b):
        k = (min(a, b), max(a, b))
        if k not in cache:
            p = [(verts[a][i] + verts[b][i]) / 2 for i in range(3)]
            ln = math.sqrt(sum(c * c for c in p))
            verts.append(tuple(c / ln for c in p))
            cache[k] = len(verts) - 1
        return cache[k]
    for a, b, c in f:
        ab, bc, ca = mid(a, b), mid(b, c), mid(c, a)
        faces += [(a, ab, ca), (b, bc, ab), (c, ca, bc), (ab, bc, ca)]
    return [(x * r[0], y * r[1], z * r[2]) for x, y, z in verts], faces


ICO = ico((1, 1, 1))


def trunk(buf, x, y, g, r, h, branches=0, spread=1.0):
    """Octagonal tapered trunk plus a few branches up into the crown."""
    n = 8
    bot = [(x + r * math.cos(2 * math.pi * k / n), y + r * math.sin(2 * math.pi * k / n), g) for k in range(n)]
    top = [(x + 0.6 * r * math.cos(2 * math.pi * k / n), y + 0.6 * r * math.sin(2 * math.pi * k / n), g + h) for k in range(n)]
    buf.add(bot + top, [[k, (k + 1) % n, n + (k + 1) % n, n + k] for k in range(n)])
    seed = int(abs(x * 13.1 + y * 7.7)) % 360
    for b in range(branches):
        a = math.radians(seed + b * 360 / max(branches, 1))
        tube(buf, (x, y, g + h * 0.9), (x + math.cos(a) * spread, y + math.sin(a) * spread, g + h + spread * 0.6), r * 0.45, r * 0.18)


def tube(buf, p, q, r0, r1, n=8):
    """Round tapered limb from p (radius r0) to q (radius r1)."""
    d = [q[i] - p[i] for i in range(3)]
    ln = math.sqrt(sum(c * c for c in d)) or 1e-6
    d = [c / ln for c in d]
    up = (0, 0, 1) if abs(d[2]) < 0.9 else (1, 0, 0)
    s = [d[1] * up[2] - d[2] * up[1], d[2] * up[0] - d[0] * up[2], d[0] * up[1] - d[1] * up[0]]
    sl = math.sqrt(sum(c * c for c in s))
    s = [c / sl for c in s]
    u = [s[1] * d[2] - s[2] * d[1], s[2] * d[0] - s[0] * d[2], s[0] * d[1] - s[1] * d[0]]
    ring = lambda c, r: [tuple(c[i] + r * (math.cos(2 * math.pi * k / n) * s[i] + math.sin(2 * math.pi * k / n) * u[i]) for i in range(3)) for k in range(n)]
    buf.add(ring(p, r0) + ring(q, r1), [[k, (k + 1) % n, n + (k + 1) % n, n + k] for k in range(n)])


def crown(buf, x, y, zc, r, flat, lobes=5):
    """Clustered crown: a few overlapping lobes, varied by position."""
    seed = int(abs(x * 31.7 + y * 17.3))
    blob(buf, x, y, zc, r * 0.75, r * 0.75 * flat)
    for k in range(lobes):
        a = math.radians((seed * 37 + k * 360 / lobes) % 360)
        s = 0.45 + 0.2 * ((seed + k * 7) % 5) / 4
        d = r * (0.5 + 0.1 * (k % 2))
        blob(buf, x + math.cos(a) * d, y + math.sin(a) * d, zc + r * flat * (0.1 * (k % 3) - 0.1), r * s, r * s * flat)


def blob(buf, x, y, z, rx, rz):
    vs, fs = ICO
    buf.add([(x + a * rx, y + b * rx, z + c * rz) for a, b, c in vs], [list(f) for f in fs])


import json as _json
import os as _os
_ZONES = _json.load(open(_os.path.join(L.HERE, "street_catalogue.json"), encoding="utf-8"))["greenery"]["tree_species"]


def species(x, y, h):
    for z in _ZONES:                                     # step 7c: species seen in the photos
        if math.hypot(x - z["centre"][0], y - z["centre"][1]) < z["radius"] and (h > 6 or z["species"] == "palm"):
            return z["species"]
    k = (int(x * 7.0) * 73856093 ^ int(y * 7.0) * 19349663) % 100
    if h >= 18:
        return "fig" if k < 55 else "eucalypt"
    if 6 <= h < 14 and k < 10:
        return "palm"
    if h >= 7 and k < 40:
        return "jacaranda" if k < 25 else "poinciana"
    return "generic"


HERO_CENTRES = [(0.0, 0.0, 220.0), (-80.0, -100.0, 140.0)]   # leaf-card trees round Spire and the cathedral
SPECIES_LEAF = {   # leaf colour pairs (dark, light) and trunk colour
    "fig": ((0.035, 0.09, 0.03), (0.09, 0.19, 0.06), (0.30, 0.27, 0.22)),
    "poinciana": ((0.07, 0.15, 0.04), (0.16, 0.28, 0.07), (0.28, 0.24, 0.20)),
    "jacaranda": ((0.06, 0.13, 0.05), (0.14, 0.24, 0.08), (0.26, 0.22, 0.19)),
    "eucalypt": ((0.08, 0.12, 0.07), (0.17, 0.22, 0.13), (0.78, 0.76, 0.70)),
    "generic": ((0.05, 0.12, 0.04), (0.13, 0.24, 0.07), (0.30, 0.26, 0.21)),
    "palm": ((0.08, 0.17, 0.05), (0.20, 0.32, 0.09), (0.45, 0.43, 0.40)),
}


def hero(x, y):
    return any(math.hypot(x - cx, y - cy) < r for cx, cy, r in HERO_CENTRES)


def fig_trunk(buf, x, y, g, h, rb):
    """Buttressed fig: wide flared base narrowing to the trunk, then thick limbs."""
    n = 10
    levels = [(0.0, rb * 2.4), (0.6, rb * 1.6), (1.6, rb * 1.1), (h, rb * 0.8)]
    rings = [[(x + r * math.cos(2 * math.pi * k / n) * (1 + 0.25 * math.sin(k * 2.7)), y + r * math.sin(2 * math.pi * k / n) * (1 + 0.25 * math.cos(k * 1.9)), g + z)
              for k in range(n)] for z, r in levels]
    for lo, hi in zip(rings[:-1], rings[1:]):
        buf.add(lo + hi, [[k, (k + 1) % n, n + (k + 1) % n, n + k] for k in range(n)])


def build():
    import foliage as FO
    col = C.collection("trees")
    trunks, pale, crowns, palms = C.MeshBuf(), C.MeshBuf(), C.MeshBuf(), C.MeshBuf()
    leaves = {s: FO.Foliage(seed=i + 3) for i, s in enumerate(SPECIES_LEAF)}
    blooms = {"poinciana": FO.Foliage(seed=91), "jacaranda": FO.Foliage(seed=92)}
    flowers = []
    count, nhero = {}, 0
    for x, y, h, g in L.tree_points():
        if h < 3.0 or h > 40.0:
            continue
        s = species(x, y, h)
        count[s] = count.get(s, 0) + 1
        near = hero(x, y)
        nhero += near
        if s == "palm":
            trunk(trunks, x, y, g, 0.2, h - 1.0, 0)
            n = 12 if near else 7
            for k in range(n):
                a = 2 * math.pi * k / n
                if near:                                                    # arching frond of cards
                    pts = [(x + math.cos(a) * 3.4 * f, y + math.sin(a) * 3.4 * f, g + h - 1.0 + 1.2 * f - 2.6 * f * f) for f in [i / 8 for i in range(1, 9)]]
                    leaves["palm"].strands([(px, py, pz + 0.2) for px, py, pz in pts], (0, 0, 1), 0.6, 0.5, 0.9)
                else:
                    palms.beam((x, y, g + h - 1.2), (x + 3.2 * math.cos(a), y + 3.2 * math.sin(a), g + h - 2.6), 0.5, 0.12)
            continue
        if s == "fig":
            r = 0.42 * h
            rz = 0.25 * h
            fig_trunk(trunks, x, y, g, h * 0.45, 0.5)
            trunk(trunks, x, y, g + h * 0.4, 0.4, 0.1, 6, r * 0.6)
            cz = g + h - rz
            if near:
                leaves["fig"].cloud((x, y, cz), (r, r, rz), int(5 * (150 + 6 * r * r)), 0.42, shell=0.35, top_bias=0.3)
            else:
                crown(crowns, x, y, cz, r, 0.5, 6)
        elif s in ("jacaranda", "poinciana"):
            r, rz = 0.4 * h, 0.12 * h
            trunk(trunks, x, y, g, 0.25, h * 0.6, 4, r * 0.55)
            cz = g + h - rz
            if near:
                leaves[s].cloud((x, y, cz), (r, r, rz), int(6 * (120 + 5 * r * r)), 0.3, shell=0.55, top_bias=0.5)
                blooms[s].cloud((x, y, cz + rz * 0.4), (r * 0.9, r * 0.9, rz * 0.6), int(5 * (25 + r * r)), 0.28, shell=0.8, top_bias=0.8)
            else:
                crown(crowns, x, y, cz, r, 0.3, 5)
                if s == "poinciana":
                    flowers.append((x, y, g + h - 0.05 * r, r * 0.9))
        elif s == "eucalypt":
            r = 0.25 * h
            trunk(pale, x, y, g, 0.3, h * 0.7, 3, r * 0.7)
            if near:
                for k in range(4):                                          # open, clumpy crown
                    a = k * 1.7
                    leaves["eucalypt"].cloud((x + math.cos(a) * r * 0.6, y + math.sin(a) * r * 0.6, g + h - r * (0.6 + 0.3 * k % 2)),
                                             (r * 0.5, r * 0.5, r * 0.4), 220, 0.32, shell=0.35)
            else:
                crown(crowns, x + 0.3 * r, y, g + h - r, r, 0.9, 3)
        else:
            r = max(1.0, 0.26 * h)
            trunk(trunks, x, y, g, 0.18, max(0.5, h - 1.6 * r), 3, r * 0.5)
            if near:
                leaves["generic"].cloud((x, y, g + h - r), (r, r, r * 0.85), int(5 * (70 + 8 * r * r)), 0.32, shell=0.4, top_bias=0.2)
            else:
                crown(crowns, x, y, g + h - r, r, 0.85, 4)
    objs = []
    fl = C.MeshBuf()
    for x, y, z, r in flowers:
        blob(fl, x, y, z, r, 0.12 * r)
    if fl.v:
        ob = fl.object("tree_flowering_tops", col, "tree")
        ob.data.materials[0] = C.material_rgb("tree_flowers", (0.70, 0.12, 0.05))
        objs.append(ob.name)
    for s, fo in leaves.items():
        dark, light, _ = SPECIES_LEAF[s]
        ob = fo.object("leaves_" + s, col, dark, light)
        if ob:
            objs.append(ob.name)
    for s, rgb in (("poinciana", (0.75, 0.10, 0.04)), ("jacaranda", (0.35, 0.22, 0.65))):
        ob = blooms[s].object("blooms_" + s, col, rgb, tuple(min(1, c * 1.4) for c in rgb))
        if ob:
            objs.append(ob.name)
    for buf, name, key, rgb in ((trunks, "tree_trunks", "bark", (0.30, 0.26, 0.21)), (pale, "tree_trunks_eucalypt", "bark", (0.78, 0.76, 0.70)),
                                (crowns, "tree_crowns_far", "tree", None), (palms, "palm_fronds_far", "palm", None)):
        ob = buf.object(name, col, key)
        if ob:
            if rgb:
                ob.data.materials[0] = C.material_rgb(name, rgb)
            for p in ob.data.polygons:
                p.use_smooth = key != "bark"
            objs.append(ob.name)
    return {"module": "trees", "objects": objs, "species_count": count, "leaf_card_trees": nhero,
            "note": "Leaf-card trees within 330 m of Spire and 160 m of the cathedral; simple crowns further out."}
