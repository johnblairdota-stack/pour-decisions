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


def blob(buf, x, y, z, rx, rz):
    vs, fs = ICO
    buf.add([(x + a * rx, y + b * rx, z + c * rz) for a, b, c in vs], [list(f) for f in fs])


def species(x, y, h):
    k = (int(x * 7.0) * 73856093 ^ int(y * 7.0) * 19349663) % 100
    if h >= 18:
        return "fig" if k < 55 else "eucalypt"
    if 6 <= h < 14 and k < 10:
        return "palm"
    if h >= 7 and k < 40:
        return "jacaranda" if k < 25 else "poinciana"
    return "generic"


def build():
    col = C.collection("trees")
    trunks, crowns, palms = C.MeshBuf(), C.MeshBuf(), C.MeshBuf()
    count = {}
    for x, y, h, g in L.tree_points():
        if h < 3.0 or h > 40.0:
            continue
        s = species(x, y, h)
        count[s] = count.get(s, 0) + 1
        if s == "palm":
            trunks.box(x, y, g, 0.35, 0.35, h - 1.0)
            for k in range(7):
                a = 2 * math.pi * k / 7
                palms.beam((x, y, g + h - 1.2), (x + 3.2 * math.cos(a), y + 3.2 * math.sin(a), g + h - 2.6), 0.5, 0.12)
            continue
        if s == "fig":
            r = 0.42 * h
            trunks.box(x, y, g, 1.4, 1.4, h * 0.45)
            blob(crowns, x, y, g + h - 0.45 * r, r, 0.45 * r)
        elif s in ("jacaranda", "poinciana"):
            r = 0.38 * h
            trunks.box(x, y, g, 0.5, 0.5, h * 0.6)
            blob(crowns, x, y, g + h - 0.3 * r, r, 0.3 * r)
        elif s == "eucalypt":
            r = 0.25 * h
            trunks.box(x, y, g, 0.6, 0.6, h * 0.7)
            blob(crowns, x + 0.3 * r, y, g + h - r, r, r)
            blob(crowns, x - 0.4 * r, y + 0.3 * r, g + h - 2.2 * r, 0.8 * r, 0.8 * r)
        else:
            r = max(1.0, 0.24 * h)                                  # step 7b: photos show smaller, higher crowns
            trunks.box(x, y, g, 0.35, 0.35, max(0.5, h - 1.6 * r))
            blob(crowns, x, y, g + h - r, r, r)
    objs = []
    for buf, name, key in ((trunks, "tree_trunks", "bark"), (crowns, "tree_crowns", "tree"), (palms, "palm_fronds", "palm")):
        ob = buf.object(name, col, key)
        if ob:
            for p in ob.data.polygons:
                p.use_smooth = key != "bark"
            objs.append(ob.name)
    return {"module": "trees", "objects": objs, "species_count": count,
            "note": "Positions and heights from the 2019 LiDAR; species are stand-ins (see the docstring)."}
