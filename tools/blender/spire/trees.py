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
    seed = int(abs(x * 13.1 + y * 7.7)) % 360
    lx, ly = 0.04 * h * math.cos(math.radians(seed)), 0.04 * h * math.sin(math.radians(seed))     # slight lean
    tube(buf, (x, y, g - 0.2), (x + lx * 0.5, y + ly * 0.5, g + h * 0.5), r * 1.15, r * 0.8, 9)
    tube(buf, (x + lx * 0.5, y + ly * 0.5, g + h * 0.5), (x + lx, y + ly, g + h), r * 0.8, r * 0.55, 9)
    for b in range(branches):
        a = math.radians(seed + b * 360 / max(branches, 1))
        s2 = spread * 0.55
        tube(buf, (x, y, g + h * 0.85), (x + math.cos(a) * s2, y + math.sin(a) * s2, g + h + spread * 0.9), r * 0.5, r * 0.15, 6)


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


HERO_CENTRES = [(0.0, 0.0, 340.0), (-80.0, -100.0, 160.0), L.HSW["trees"]["centre_r"]]   # Spire, cathedral, HSW


def in_hsw(x, y):
    cx, cy, r = L.HSW["trees"]["centre_r"]
    return math.hypot(x - cx, y - cy) < r


_HB = []


def _hotel_box():
    if not _HB:
        import hsw_hero
        r = hsw_hero.rec_by_osm()[L.HSW["hotel_way"]]
        xs = [p[0] for t in r["tiers"] for p in t["ring"]]
        ys = [p[1] for t in r["tiers"] for p in t["ring"]]
        _HB.append((min(xs), min(ys), max(xs), max(ys)))
    return _HB[0]


def hsw_ok(x, y, g):
    """HSW round 2: no trunk on the cliff face, near the rim edge, or on low river sand/mud."""
    T = L.HSW["trees"]
    if g < T["min_ground_ahd"]:
        return False
    import hsw_hero
    if hsw_hero.sunk(x, y):                              # r4: deck strips sunk under the river: no tree there
        return False
    if 400.0 <= x <= 612.0 and y < 95.0:                 # r6: open wharf strip: FELONS / HSW roofs and the hotel
        return False                                     # front stay visible from the river (p09, p13)
    hx0, hy0, hx1, hy1 = _hotel_box()
    if hx0 - 14 <= x <= hx1 + 14 and hy0 - 14 <= y <= hy1 - 4:
        return False
    for k in range(8):
        a = k * math.pi / 4
        dz = abs(L.ground_z(x + 1.5 * math.cos(a), y + 1.5 * math.sin(a)) - g)
        if math.degrees(math.atan2(dz, 1.5)) > T["max_slope_deg"]:          # on the face itself
            return False
        rs = T["rim_setback_m"]
        if g - L.ground_z(x + rs * math.cos(a), y + rs * math.sin(a)) > 0.9 * rs * 2:   # right on the rim
            return False
    return True


def hsw_species(x, y, h):
    """HSW round 2: a mixed canopy (figs, eucalypts, poinciana, palms, scrub trees), stable per position."""
    mix = L.HSW["trees"]["mix"]
    k = (int(x * 3.0) * 73856093 ^ int(y * 3.0) * 19349663) % sum(mix.values())
    for s, w in mix.items():
        if k < w:
            if s == "palm" and h > 16:
                return "eucalypt"
            if s == "fig" and h < 7:
                return "generic"
            return s
        k -= w
    return "generic"
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


class RoadGuard:
    """Step 7k: no trunk on a carriageway. Every car road as segments (vectorised); junctions are covered
    because the road buffers overlap there. A tree on the road moves to the nearest clear spot within 3 m
    (footpath or median), else it is dropped."""
    def __init__(self, pad=0.6):
        import numpy as np
        import streetscape as SS
        A, Bs, H = [], [], []
        for pts, hw in SS.carriageways():
            for (ax, ay), (bx, by) in zip(pts[:-1], pts[1:]):
                A.append((ax, ay))
                Bs.append((bx, by))
                H.append(hw + pad)
        self.np = np
        self.A, self.B, self.H = np.array(A), np.array(Bs), np.array(H)
        self.D = self.B - self.A
        self.L2 = np.maximum((self.D ** 2).sum(1), 1e-9)
        self.moved = self.dropped = self.checked = 0
        self.placed = []

    def on_road(self, x, y):
        np = self.np
        k = np.clip(((x - self.A[:, 0]) * self.D[:, 0] + (y - self.A[:, 1]) * self.D[:, 1]) / self.L2, 0, 1)
        dx = self.A[:, 0] + self.D[:, 0] * k - x
        dy = self.A[:, 1] + self.D[:, 1] * k - y
        return bool(((dx * dx + dy * dy) < self.H * self.H).any())

    def fix(self, x, y):
        """(x, y) if clear, a moved spot within 3 m, or None (drop)."""
        self.checked += 1
        if not self.on_road(x, y):
            self.placed.append((x, y))
            return x, y
        for r in (1.0, 1.5, 2.0, 2.5, 3.0):
            for k in range(12):
                a = k * math.pi / 6
                px, py = x + r * math.cos(a), y + r * math.sin(a)
                if not self.on_road(px, py):
                    self.moved += 1
                    self.placed.append((px, py))
                    return px, py
        self.dropped += 1
        return None


def build():
    import foliage as FO
    near_cam = lambda c: math.hypot(c[0], c[1]) < 140 or math.hypot(c[0] + 80, c[1] + 100) < 90 or         math.hypot(c[0] - 150, c[1] - 220) < 80                          # Spire, cathedral, Ann St photo spots
    FO.CLOUDS.clear()
    FO.LOD = lambda c: (1.0, 1.0) if near_cam(c) else (0.3, 1.8)          # GPU budget: ~3M cards in all
    col = C.collection("trees")
    trunks, pale, crowns, palms = C.MeshBuf(), C.MeshBuf(), C.MeshBuf(), C.MeshBuf()
    leaves = {s: FO.Foliage(seed=i + 3) for i, s in enumerate(SPECIES_LEAF)}
    blooms = {"poinciana": FO.Foliage(seed=91), "jacaranda": FO.Foliage(seed=92)}
    flowers = []
    count, nhero = {}, 0
    cams = []
    try:
        cams = [tuple(c["pos"][:2]) for c in _json.load(open(_os.path.join(L.HERE, "photo_cams.json")))["cams"]
                if not c.get("skip") and c.get("eye_above_ground_m", 99) < 3.0]
    except (OSError, KeyError):
        pass
    for c in list(L.CAMERAS) + list(L.HERO_CAMERAS):                     # hero/street views too
        p = c.get("pos")
        if p and p[2] - L.ground_z(p[0], p[1]) < 4.0:
            cams.append(tuple(p[:2]))
    clear = lambda x, y: all(math.hypot(x - cx, y - cy) > 9.0 for cx, cy in cams)   # photos: taken from open spots
    guard = RoadGuard()
    for x, y, h, g in L.tree_points():
        if h < 3.0 or h > 40.0 or not clear(x, y):
            continue
        fx = guard.fix(x, y)
        if fx is None:
            continue
        x, y = fx
        if in_hsw(x, y):
            if 470.0 <= x <= 680.0 and 95.0 <= y <= 150.0 and g > 20.0:   # r8: low crest canopy, the blocks show (p12)
                h = min(h, 9.0)
            if not hsw_ok(x, y, g):
                count["hsw_dropped"] = count.get("hsw_dropped", 0) + 1
                continue
            s = hsw_species(x, y, h)
        else:
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
            fig_trunk(trunks, x, y, g, h * 0.45, 0.3 if in_hsw(x, y) else 0.5)   # HSW r3: slimmer flare
            trunk(trunks, x, y, g + h * 0.4, 0.4, 0.1, 5, r * 0.45)
            cz = g + h - rz
            if near:
                leaves["fig"].cloud((x, y, cz), (r, r, rz), int(9 * (150 + 6 * r * r)), 0.6, shell=0.2, top_bias=0.3)
            else:
                crown(crowns, x, y, cz, r, 0.5, 6)
        elif s in ("jacaranda", "poinciana"):
            r, rz = 0.48 * h, 0.09 * h
            trunk(trunks, x, y, g, 0.28, h * 0.55, 5, r * 0.6)
            cz = g + h - rz
            if near:
                leaves[s].cloud((x, y, cz), (r, r, rz), int(9 * (120 + 5 * r * r)), 0.22, shell=0.3, top_bias=0.6)
                blooms[s].cloud((x, y, cz + rz * 0.5), (r * 0.85, r * 0.85, rz * 0.5), int(2 * (25 + r * r)), 0.18, shell=0.9, top_bias=0.9)
            else:
                crown(crowns, x, y, cz, r * 0.8, 0.6, 6)                 # HSW r3: rounder, not umbrella-pine
        elif s == "eucalypt":
            r = 0.25 * h
            trunk(pale, x, y, g, 0.3, h * 0.7, 3, r * 0.7)
            if near:
                for k in range(4):                                          # open, clumpy crown
                    a = k * 1.7
                    leaves["eucalypt"].cloud((x + math.cos(a) * r * 0.6, y + math.sin(a) * r * 0.6, g + h - r * (0.6 + 0.3 * k % 2)),
                                             (r * 0.5, r * 0.5, r * 0.4), 380, 0.36, shell=0.25)
            else:
                crown(crowns, x + 0.3 * r, y, g + h - r, r, 0.9, 3)
        else:
            r = max(1.2, 0.32 * h)
            trunk(trunks, x, y, g, 0.2, max(0.8, h - 1.7 * r), 3, r * 0.45)
            if near:
                leaves["generic"].cloud((x, y, g + h - r), (r, r, r * 0.85), int(9 * (70 + 8 * r * r)), 0.5, shell=0.2, top_bias=0.2)
            else:
                crown(crowns, x, y, g + h - r, r, 0.85, 4)
    # canopy fill: every 4 m block of LiDAR vegetation with no placed crown nearby gets one
    import numpy as np
    cls = L.lidar("class")
    hgt = L.lidar("dsm") - L.lidar("ground")
    gnd = L.lidar("ground")
    x0, y0, x1, y1 = L.LIDAR_BOX
    veg = (cls == 2) & (hgt > 0.8)
    placed = np.array([(x, y) for x, y, h, g in L.tree_points() if 3 <= h <= 40] or [(1e9, 1e9)])
    nfill = nshrub = 0
    for r0 in range(0, veg.shape[0] - 4, 4):
        for c0 in range(0, veg.shape[1] - 4, 4):
            blk = veg[r0:r0 + 4, c0:c0 + 4]
            if blk.sum() < 6:
                continue
            x = x0 + c0 + 2.0
            y = y1 - r0 - 2.0
            if abs(x) > 420 or abs(y) > 420:
                continue
            h = float(np.percentile(hgt[r0:r0 + 4, c0:c0 + 4][blk], 80))
            g = float(gnd[r0 + 2, c0 + 2])
            if np.min(np.hypot(placed[:, 0] - x, placed[:, 1] - y)) < max(3.0, 0.3 * h) or not clear(x, y):
                continue
            if in_hsw(x, y) and (h < 3.0 or not hsw_ok(x, y, g)):   # HSW: cliff faces get hsw_hero tufts instead
                continue
            fx = guard.fix(x, y)
            if fx is None:
                continue
            x, y = fx
            near = hero(x, y)
            if h < 3.0:                                                      # shrubs and hedges
                if near:
                    leaves["generic"].cloud((x, y, g + h * 0.55), (2.0, 2.0, h * 0.55), 160, 0.28, shell=0.3, top_bias=0.3)
                else:
                    blob(crowns, x, y, g + h * 0.5, 2.0, h * 0.5)
                nshrub += 1
            else:
                r = min(3.2, 0.3 * h + 1.0)
                trunk(trunks, x, y, g, 0.18, max(0.5, h - 1.6 * r), 2, r * 0.5)
                if near:
                    leaves["generic"].cloud((x, y, g + h - r), (r, r, r * 0.8), int(9 * (40 + 8 * r * r)), 0.5, shell=0.2, top_bias=0.2)
                else:
                    crown(crowns, x, y, g + h - r, r, 0.85, 3)
                nfill += 1
    count["road_check"] = {"checked": guard.checked, "moved": guard.moved, "dropped": guard.dropped}
    print("trees road check: checked %d, moved %d, dropped %d" % (guard.checked, guard.moved, guard.dropped))
    bad = [p for p in guard.placed if guard.on_road(*p)]
    if bad:
        raise RuntimeError("tree trunks on a carriageway: %s" % bad[:10])
    count["canopy_fill_trees"] = nfill
    count["canopy_fill_shrubs"] = nshrub
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
    sp = C.MeshBuf()                                                     # crown shadow casters (not seen by the camera)
    for (cx_, cy_, cz_), (rx_, ry_, rz_) in FO.CLOUDS:
        blob(sp, cx_, cy_, cz_, 0.8 * max(rx_, ry_), 0.8 * rz_)
    if sp.v:
        obs = sp.object("tree_shadow_proxies", col, "tree")
        obs.visible_camera = False
        obs.visible_diffuse = obs.visible_glossy = obs.visible_transmission = False
        objs.append(obs.name)
    for s, rgb in (("poinciana", (0.75, 0.10, 0.04)), ("jacaranda", (0.35, 0.22, 0.65))):
        ob = blooms[s].object("blooms_" + s, col, rgb, tuple(min(1, c * 1.4) for c in rgb))
        if ob:
            objs.append(ob.name)
    for buf, name, key, rgb in ((trunks, "tree_trunks", "bark", (0.11, 0.095, 0.08)), (pale, "tree_trunks_eucalypt", "bark", (0.55, 0.53, 0.48)),
                                (crowns, "tree_crowns_far", "tree", (0.035, 0.075, 0.03)), (palms, "palm_fronds_far", "palm", (0.06, 0.12, 0.04))):
        ob = buf.object(name, col, key)
        if ob:
            if rgb:
                ob.data.materials[0] = C.material_rgb(name, rgb)
                if key in ("tree", "palm"):
                    ob.data.materials[0]["shader"] = "canopy"
            for p in ob.data.polygons:
                p.use_smooth = True
            objs.append(ob.name)
    return {"module": "trees", "objects": objs, "species_count": count, "leaf_card_trees": nhero,
            "note": "Leaf-card trees within 330 m of Spire and 160 m of the cathedral; simple crowns further out."}
