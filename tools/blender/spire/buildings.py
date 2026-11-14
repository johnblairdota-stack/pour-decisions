"""Neighbouring buildings (step 7a): every OSM footprint (simplified, squared), extruded to its LiDAR-measured
roof tiers (reference/sites/spire/lidar/buildings_clean.json), dressed with a facade recipe from looks.py:
named buildings from the photo research, the rest from generic recipes by use and height. LiDAR is for
measuring only. Materials are procedural (preview.setup_morning builds the shaders from the props)."""
import json
import math
import os

import layout as L
import common as C
import shapes as S
from looks import look_for, PATTERNS

HSW_ZONE = (380, -130, 800, 140)      # local x0, y0, x1, y1: the strip under the cliffs (hsw.py adds the rest)
SKIP = {26384715, 679146312}          # St John's Cathedral (cathedral.py), Mr Percival's (hsw.py)
STREETS_WITH_AWNINGS = ("Ann Street", "Queen Street", "Adelaide Street", "Wickham Street", "Boundary Street")


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


def loop_wall(buf, ring, z0, z1):
    """Thin open wall (one quad per edge) - balustrades."""
    n = len(ring)
    for i in range(n):
        (ax, ay), (bx, by) = ring[i], ring[(i + 1) % n]
        buf.add([(ax, ay, z0), (bx, by, z0), (bx, by, z1), (ax, ay, z1)], [[0, 1, 2, 3]])


def gable(buf, g, base):
    c, s = math.cos(g["angle"]), math.sin(g["angle"])
    hl, hw = g["length"] / 2 + 0.3, g["width"] / 2 + 0.3
    e, r = g["eave_ahd"], g["ridge_ahd"]
    def P(u, v, z):
        return (g["cx"] + u * c - v * s, g["cy"] + u * s + v * c, z)
    verts = [P(-hl, -hw, e), P(hl, -hw, e), P(hl, hw, e), P(-hl, hw, e), P(-hl, 0, r), P(hl, 0, r)]
    buf.add(verts, [[0, 1, 5, 4], [2, 3, 4, 5], [0, 4, 3], [1, 2, 5], [0, 3, 2, 1]])


def cone(buf, x, y, z0, r, z1, n=8):
    ring = [(x + r * math.cos(2 * math.pi * k / n), y + r * math.sin(2 * math.pi * k / n), z0) for k in range(n)]
    buf.add(ring + [(x, y, z1)], [[k, (k + 1) % n, n] for k in range(n)] + [list(range(n - 1, -1, -1))])


def dome(buf, x, y, z0, r):
    rings, n = 4, 12
    verts, faces = [], []
    for j in range(rings):
        a = math.pi / 2 * j / rings
        for k in range(n):
            t = 2 * math.pi * k / n
            verts.append((x + r * math.cos(a) * math.cos(t), y + r * math.cos(a) * math.sin(t), z0 + r * math.sin(a)))
    verts.append((x, y, z0 + r))
    for j in range(rings - 1):
        for k in range(n):
            faces.append([j * n + k, j * n + (k + 1) % n, (j + 1) * n + (k + 1) % n, (j + 1) * n + k])
    top = len(verts) - 1
    faces += [[(rings - 1) * n + k, (rings - 1) * n + (k + 1) % n, top] for k in range(n)]
    buf.add(verts, faces)


def street_lines():
    o = L.osm()
    return [o["line"](w) for w in o["ways"].values()
            if w.get("tags", {}).get("highway") and w.get("tags", {}).get("name") in STREETS_WITH_AWNINGS]


def near_street(x, y, lines, d=11.0):
    for ln in lines:
        for (ax, ay), (bx, by) in zip(ln[:-1], ln[1:]):
            dx, dy = bx - ax, by - ay
            l2 = dx * dx + dy * dy or 1
            t = max(0, min(1, ((x - ax) * dx + (y - ay) * dy) / l2))
            if math.hypot(ax + dx * t - x, ay + dy * t - y) < d:
                return True
    return False


class Bufs:
    def __init__(self):
        self.walls, self.roof, self.band, self.accent, self.ground = (C.MeshBuf() for _ in range(5))


def dress(rec, bf, ring, ground, z0, top, first, last, lines, glass_rail):
    """Recipe geometry for one tier: bands/balconies, ground band, pilasters, cornice, awnings, verandahs, accent."""
    pat = PATTERNS.get(rec.get("pattern") or "none")
    floor = pat["floor"] if pat else L.LEVEL_HEIGHT
    if rec.get("band") or rec.get("balcony"):
        out = offset(ring, 1.2 if rec.get("balcony") else 0.12)
        z = ground + floor
        while z < top - 1.0:
            if z > z0 + 0.5:
                bf.band.prism(out, z - 0.25, z)
                if rec.get("balcony") == "white_solid":
                    loop_wall(bf.band, offset(ring, 1.15), z, z + 1.05)
                elif rec.get("balcony") == "glass":
                    loop_wall(glass_rail, offset(ring, 1.15), z, z + 1.05)
            z += floor
    if first and rec.get("ground"):
        bf.ground.prism(offset(ring, 0.06), z0, min(top, ground + 4.5))
    if rec.get("pilasters"):
        n = len(ring)
        for i in range(n):
            (ax, ay), (bx, by) = ring[i], ring[(i + 1) % n]
            ln = math.dist((ax, ay), (bx, by))
            k = int(ln // 4.0)
            ang = math.atan2(by - ay, bx - ax)
            nx, ny = math.sin(ang), -math.cos(ang)
            for j in range(1, k):
                t = j / k
                bf.ground.box(ax + (bx - ax) * t + nx * 0.15, ay + (by - ay) * t + ny * 0.15, z0, 0.45, 0.3, top - z0, ang)
    if last and rec.get("cornice") and top - ground > 5:
        bf.roof.prism(offset(ring, 0.35), top - 0.7, top - 0.2)
    if first and rec.get("awning") and top - ground < 18:
        n = len(ring)
        for i in range(n):
            (ax, ay), (bx, by) = ring[i], ring[(i + 1) % n]
            mx, my = (ax + bx) / 2, (ay + by) / 2
            ln = math.dist((ax, ay), (bx, by))
            if ln < 3 or not near_street(mx, my, lines):
                continue
            ang = math.atan2(by - ay, bx - ax)
            nx, ny = math.sin(ang), -math.cos(ang)
            bf.roof.box(mx + nx * 1.5, my + ny * 1.5, ground + 3.4, ln, 2.8, 0.2, ang)
    if first and rec.get("skirt_roof") and top - ground > 7:                 # tier roof between L1 and L2 (Orient)
        a = offset(ring, 0.0)
        b = offset(ring, 1.5)
        n = len(ring)
        verts = [(x, y, ground + 5.3) for x, y in a] + [(x, y, ground + 4.6) for x, y in b]
        bf.accent.add(verts, [[i, (i + 1) % n, n + (i + 1) % n, n + i] for i in range(n)])
        bf.accent.prism(b, ground + 4.4, ground + 4.6)                       # fascia
    if first and rec.get("verandah") and top - ground < 14:
        ver = offset(ring, 2.4)
        for zz in (ground + 3.6, ground + 7.0):
            if zz < top - 0.5:
                bf.band.prism(ver, zz, zz + 0.2)
                loop_wall(bf.band, offset(ring, 2.3), zz + 0.2, zz + 1.1)
                for x, y in ver:
                    bf.band.box(x, y, zz - 3.4, 0.18, 0.18, 3.4)
    if last and rec.get("accent") and top - ground > 12:
        n = len(ring)
        i = max(range(n), key=lambda k: math.dist(ring[k], ring[(k + 1) % n]))
        (ax, ay), (bx, by) = ring[i], ring[(i + 1) % n]
        ang = math.atan2(by - ay, bx - ax)
        nx, ny = math.sin(ang), -math.cos(ang)
        bf.accent.box((ax + bx) / 2 + nx * 0.4, (ay + by) / 2 + ny * 0.4, ground + 4.0, 1.8, 0.6, top - ground - 3.0, ang)


def toppers(rec, bf, ring, top):
    cx = sum(p[0] for p in ring) / len(ring)
    cy = sum(p[1] for p in ring) / len(ring)
    rmin = min(math.dist((cx, cy), p) for p in ring)
    if rec.get("dome"):
        r = max(2.5, 0.45 * rmin)
        bf.accent.box(cx, cy, top, 2 * r, 2 * r, 1.5)
        dome(bf.accent, cx, cy, top + 1.5, r)
    if rec.get("spike"):
        cone(bf.roof, cx, cy, top, 1.2, top + 18.0, 6)
    if rec.get("crown"):
        for p in ring[:: max(1, len(ring) // 6)]:
            bf.roof.box(p[0], p[1], top, 0.5, 0.5, 6.0)
        bf.roof.prism(offset(ring, 0.1), top + 5.6, top + 6.0)


_ROOFS = json.load(open(os.path.join(L.HERE, "street_catalogue.json"), encoding="utf-8"))["roofs"]


def hipped(buf, ring, z, pitch_deg):
    """Hipped roof over the footprint's min rectangle."""
    cx, cy, ln, wd, ang = S.min_rect(ring)
    c, s = math.cos(ang), math.sin(ang)
    hl, hw = ln / 2 + 0.4, wd / 2 + 0.4
    rise = math.tan(math.radians(pitch_deg)) * hw
    rl = max(0.0, hl - hw)
    P = lambda u, v, zz: (cx + u * c - v * s, cy + u * s + v * c, zz)
    verts = [P(-hl, -hw, z), P(hl, -hw, z), P(hl, hw, z), P(-hl, hw, z), P(-rl, 0, z + rise), P(rl, 0, z + rise)]
    buf.add(verts, [[0, 1, 5, 4], [2, 3, 4, 5], [3, 0, 4], [1, 2, 5]])


def roof_override(osm, bf, ring, top, ground):
    r = _ROOFS.get(str(osm))
    if not r:
        return False
    shape = r["shape"]
    if shape == "hipped":
        hipped(bf.accent, ring, top, r["pitch_deg"])
        return True
    if shape == "crown_ring":
        bf.band.prism(offset(ring, 0.3), top + 0.9, top + 1.2)
        for p in ring[::2]:
            bf.band.box(p[0], p[1], top, 0.3, 0.3, 4.0)
        bf.band.prism(offset(ring, 0.3), top + 3.8, top + 4.2)
    if shape == "swoosh":
        cx = sum(p[0] for p in ring) / len(ring)
        cy = sum(p[1] for p in ring) / len(ring)
        for p in sorted(ring, key=lambda p: -math.dist(p, (cx, cy)))[:2]:
            for k in range(6):                                           # blue fin sweeping out and up
                f = k / 5
                bf.accent.box(p[0] + (p[0] - cx) * 0.45 * f * f, p[1] + (p[1] - cy) * 0.45 * f * f, top - 24 + 24 * f,
                              1.4, 1.4, 4.4)
    if r.get("plant") or shape in ("crown_ring", "swoosh", "flat"):
        cx = sum(p[0] for p in ring) / len(ring)
        cy = sum(p[1] for p in ring) / len(ring)
        bf.roof.box(cx, cy, top + 0.9, 5.0, 4.0, 2.4)                    # plant room / AC units
        bf.roof.box(cx + 4.0, cy + 2.0, top + 0.9, 1.6, 1.6, 1.2)
    return shape != "hipped"


def build(zone=None, collection="buildings", skip_zone=HSW_ZONE, exclude=(), only=None, lift=0.0, suffix=""):
    col = C.collection(collection)
    o = L.osm()
    lines = street_lines()
    st = L.spire_stage()
    bufs, recipes = {}, {}
    spire_buf, glass_rail = C.MeshBuf(), C.MeshBuf()
    n, named = 0, set()
    for b in records():
        if b["osm"] in SKIP or b["osm"] in exclude:
            continue
        if only is not None and b["osm"] not in only:
            continue
        ring0 = b["tiers"][0]["ring"]
        cx = sum(p[0] for p in ring0) / len(ring0)
        cy = sum(p[1] for p in ring0) / len(ring0)
        inz = lambda z: z and z[0] <= cx <= z[2] and z[1] <= cy <= z[3]
        if only is None and zone is not None and not inz(zone):
            continue
        if zone is None and (inz(skip_zone) or not C.in_model(cx, cy, 300)):
            continue
        tags = o["ways"].get(b["osm"], {}).get("tags", {})
        hmax = max(t["top_ahd"] for t in b["tiers"]) - b["base_ahd"]
        key, rec = look_for(b["osm"], tags, hmax, b["family"])
        if key.startswith("look_"):
            named.add(rec["name"])
        recipes[key] = rec
        bf = bufs.setdefault(key, Bufs())
        base = b["base_ahd"] - 0.5 + lift
        lower = base
        cut = b["base_ahd"] + 0.55 * hmax if (st and rec.get("under_construction_2016")) else None
        tiers = b["tiers"]
        for k, t in enumerate(tiers):
            ring = S.ccw([tuple(p) for p in t["ring"]])
            z0 = base if k == 0 else max(lower - 0.2, base)
            top = t["top_ahd"] + lift
            if cut:
                top = min(top, cut)
            cap = _ROOFS.get(str(b["osm"]), {}).get("eave_above_ground")    # LiDAR top includes a roof sign
            if cap:
                top = min(top, b["base_ahd"] + cap + lift)
            if top - z0 < 1.0:
                continue
            bf.walls.prism(ring, z0, top)
            last = k == len(tiers) - 1
            ov = _ROOFS.get(str(b["osm"]), {}).get("shape")
            if last and ov:
                roof_override(b["osm"], bf, ring, top, b["base_ahd"])
                if ov == "hipped":
                    b = dict(b, gable=None)
            if ov != "hipped" and not (k == 0 and b["gable"]) and top - b["base_ahd"] > 8:
                bf.roof.prism(offset(ring, -0.25), top, top + 0.9)    # parapet cap
            dress(rec, bf, ring, b["base_ahd"] + lift, z0, top, k == 0, k == len(tiers) - 1, lines, glass_rail)
            if k == len(tiers) - 1 and not cut:
                toppers(rec, bf, ring, top + 0.9)
            lower = top
        if b["gable"]:
            gb = b["gable"]
            gable(bf.roof, dict(gb, eave_ahd=gb["eave_ahd"] + lift, ridge_ahd=gb["ridge_ahd"] + lift), base)
        for sp in b["spires"]:
            cone(spire_buf, sp["x"], sp["y"], sp["base_ahd"] + lift, sp["r"], sp["top_ahd"] + lift)
        n += 1
    objs = []
    for key, bf in bufs.items():
        rec = recipes[key]
        pat = PATTERNS.get(rec.get("pattern") or "none")
        mats = {
            "walls": C.material_rgb(key + "_wall", rec["wall"], window=dict(pat, glass=rec["glass"]) if pat else None,
                                    shader=rec.get("shader", "render"), palette=rec.get("stone_palette")),
            "roof": C.material_rgb(key + "_roof", rec["roof"]),
            "band": C.material_rgb(key + "_band", rec.get("band") or rec.get("verandah") or (0.95, 0.95, 0.93)),
            "accent": C.material_rgb(key + "_accent", tuple(_ROOFS.get(key[5:], {}).get("colour") or ()) or rec.get("accent") or rec.get("dome") or rec["roof"]),
            "ground": C.material_rgb(key + "_ground", rec.get("ground") or rec["wall"]),
        }
        for part in ("walls", "roof", "band", "accent", "ground"):
            ob = getattr(bf, part).object("bldg_%s_%s%s" % (key, part, suffix), col, "roof")
            if ob:
                ob.data.materials[0] = mats[part]
                ob["recipe"] = rec.get("name", key)
                ob["recipe_source"] = rec.get("src", "generic (looks.GENERIC)")
                objs.append(ob.name)
    for buf, name, key in ((spire_buf, "bldg_spires_masts", "roof"), (glass_rail, "bldg_glass_balustrades", "balustrade")):
        ob = buf.object(name + suffix, col, key)
        if ob:
            objs.append(ob.name)
    return {"module": "buildings" if zone is None else collection, "objects": objs, "buildings": n,
            "named_recipes": sorted(named), "generic_recipes": sorted(k for k in bufs if k.startswith("gen_")),
            "source": "OSM footprints + 2019 LiDAR tiers (prep_clean.py); recipes in looks.py",
            "note": "Procedural facades from the photo notes; nothing copied from photos."}
