"""Hand-built finished tops and skins for the game towers outside the Spire square (critic loop, 17 Nov 2026).

Replaces the generic recipe meshes of Brisbane Skytower and 1 William St (cbd_ext) with their own parts,
from the Commons photos (colours, banding, crown) on the OSM outline and LiDAR heights. Each part is its own
object, so a construction stage can leave parts out (skin, rings, crown, lobby, mast).

- Skytower: near-black navy glass, fine floor lines, white slab rings in two clusters, the dark plant band
  about two thirds up, a crown lip and roof plant, glass lobby.
- 1 William St: charcoal-blue glass with bronze floor lines, the white spine up the river face, the sloped
  crown (low to the river, high behind, 200 to 234 m AHD) with a white rim and dark deck, the mast.
"""
import json
import math
import os

import layout as L
import common as C
import shapes as S

SKY, WIL = 683336940, 521115344
WIL_PART = 1104813702                                           # OSM building:part on the river face; read as a pasted panel
MATS = {   # name: (rgb, roughness, metallic)
    "sky_glass": ((0.035, 0.06, 0.10), 0.10, 0.5), "sky_line": ((0.035, 0.055, 0.11), 0.3, 0.0),
    "sky_ring": ((0.42, 0.52, 0.70), 0.5, 0.0), "sky_band": ((0.028, 0.036, 0.055), 0.5, 0.0),
    "sky_crown": ((0.035, 0.045, 0.065), 0.4, 0.0), "sky_lobby": ((0.02, 0.035, 0.06), 0.05, 0.0),
    "wil_glass": ((0.09, 0.125, 0.20), 0.10, 0.2), "wil_band": ((0.06, 0.055, 0.05), 0.5, 0.3), "wil_fin": ((0.46, 0.39, 0.28), 0.4, 0.6), "wil_line": ((0.20, 0.16, 0.11), 0.45, 0.3),
    "wil_white": ((0.82, 0.80, 0.74), 0.45, 0.0), "wil_deck": ((0.05, 0.043, 0.036), 0.8, 0.0),
    "wil_lobby": ((0.03, 0.05, 0.07), 0.05, 0.0),
    "qw_gold": ((0.075, 0.062, 0.045), 0.08, 0.8), "qw_line": ((0.42, 0.36, 0.22), 0.4, 0.4),
    "qw_dark": ((0.035, 0.05, 0.075), 0.12, 0.5), "qw_dline": ((0.10, 0.13, 0.17), 0.4, 0.0),
    "qw_podium": ((0.05, 0.047, 0.042), 0.2, 0.4), "qw_deck": ((0.80, 0.80, 0.78), 0.5, 0.0), "qw_fin": ((0.085, 0.066, 0.04), 0.35, 0.6), "qw_green": ((0.10, 0.20, 0.06), 0.9, 0.0),
}
QW_O = (-532.81, -1167.73)                                        # Queen's Wharf pack origin in the Spire frame
QW_ARC = (-34.5, -60.0, 33.0, 53.0)                               # Star Grand arc: centre x, y, inner and outer radius (2022 aerial)
QW_OVAL = (-30.0, 30.0, 32.0, 11.0, 45.0)                        # Dorsett and Rosewood oval tower: centre, semi-axes, turn (deg)
QW_RES = (47.0, -55.0, 18.0)                                      # Queen's Wharf Residences tube: centre, radius


def rings(buf, ring, z0, z1, step, h, out):
    import buildings as B
    r = B.offset(ring, out)
    z = z0
    while z < z1:
        buf.prism(r, z, z + h)
        z += step


def skytower(b, bufs):
    import buildings as B
    ring = S.ccw([tuple(p) for p in b["tiers"][-1]["ring"]])
    g, top = 4.4, b["tiers"][-1]["top_ahd"]
    H = top - g
    floor = 3.05
    bufs["sky_glass"].prism(ring, g - 1.0, top)
    rings(bufs["sky_line"], ring, g + 12.0, top - 2.0, floor, 0.16, 0.03)
    band = g + 0.725 * H                                           # critic round 2: plant bands 29% and 60% down
    for a in (0.905, 0.76, 0.64, 0.43, 0.33):                                # critic round 9: clusters of 3 rings two floors apart (5 a floor apart read as a white block)
        rings(bufs["sky_ring"], ring, g + a * H, g + a * H + 6 * floor - 0.5, 1.5 * floor, 0.24, 0.12)
    bufs["sky_band"].prism(B.offset(ring, 0.05), band, band + 6.0)
    bufs["sky_band"].prism(B.offset(ring, 0.05), g + 0.40 * H, g + 0.40 * H + 5.0)     # lower plant and amenity floor
    bufs["sky_crown"].prism(B.offset(ring, 0.12), top - 1.0, top + 0.4)             # crown lip
    bufs["sky_ring"].prism(B.offset(ring, 0.16), top + 0.4, top + 0.6)              # thin pale rim
    bufs["sky_crown"].prism(B.offset(ring, -2.5), top, top + 1.6)                   # roof plant behind the lip
    bufs["sky_lobby"].prism(B.offset(ring, 0.12), g - 0.5, g + 9.0)
    bufs["sky_ring"].prism(B.offset(ring, 1.6), g + 9.0, g + 9.5)                   # entrance canopy line
    return ["glass skin", "floor lines", "white rings", "plant bands", "crown", "lobby"]


def william1(b, bufs):
    import buildings as B
    pod, tw = b["tiers"][0], b["tiers"][-1]
    ring = S.ccw([tuple(p) for p in tw["ring"]])
    for _ in range(2):                                             # corner cutting: a smooth rounded shaft, no facets
        ring = [q for i in range(len(ring)) for q in (
            (0.75 * ring[i][0] + 0.25 * ring[(i + 1) % len(ring)][0], 0.75 * ring[i][1] + 0.25 * ring[(i + 1) % len(ring)][1]),
            (0.25 * ring[i][0] + 0.75 * ring[(i + 1) % len(ring)][0], 0.25 * ring[i][1] + 0.75 * ring[(i + 1) % len(ring)][1]))]
    g, top = 7.7, tw["top_ahd"]
    cx, cy = sum(p[0] for p in ring) / len(ring), sum(p[1] for p in ring) / len(ring)
    rv = math.sqrt(0.5)                                            # the slot down the river face: the heart's notch
    kn = min((i for i in range(len(ring)) if (ring[i][0] - cx) * -rv + (ring[i][1] - cy) * -rv > 0),
             key=lambda i: abs((ring[i][0] - cx) * -rv - (ring[i][1] - cy) * -rv))
    for o in range(-5, 6):
        i = (kn + o) % len(ring)
        f = 1.0 - 0.16 * (0.5 + 0.5 * math.cos(math.pi * o / 6.0))
        ring[i] = (cx + (ring[i][0] - cx) * f, cy + (ring[i][1] - cy) * f)
    top = 186.0                                                    # the glass shaft ends where the crown slope starts
    bufs["wil_glass"].prism(ring, g - 1.0, top)
    bufs["wil_lobby"].prism(S.ccw([tuple(p) for p in pod["ring"]]), g - 1.0, pod["top_ahd"])
    rings(bufs["wil_line"], ring, pod["top_ahd"] + 2.0, top, 3.9, 0.22, 0.04)
    # crown: the glass carries on up to a sloped roof, low to the river (south-west), high behind
    ux, uy = -math.sqrt(0.5), -math.sqrt(0.5)                      # towards the river (the broad 70 m face)
    d = [(p[0] - cx) * ux + (p[1] - cy) * uy for p in ring]
    lo, hi = min(d), max(d)
    zt = [190.0 + 46.0 * (hi - v) / (hi - lo) for v in d]          # steep dark roof face to the river (LiDAR roof cells 188 to 234 m)
    n = len(ring)
    verts = [(p[0], p[1], top) for p in ring] + [(p[0], p[1], z) for p, z in zip(ring, zt)]
    bufs["wil_glass"].add(verts, [[i, (i + 1) % n, n + (i + 1) % n, n + i] for i in range(n)])
    inner = [(cx + (p[0] - cx) * 0.96, cy + (p[1] - cy) * 0.96) for p in ring]
    bufs["wil_deck"].add([(p[0], p[1], z - 0.5) for p, z in zip(inner, zt)], [list(range(n))])
    for i in range(n):                                             # white rim round the sloped top
        j = (i + 1) % n
        bufs["wil_white"].beam((ring[i][0], ring[i][1], zt[i]), (ring[j][0], ring[j][1], zt[j]), 1.4, 1.2)
    k = min((i for i in range(n) if d[i] > 0), key=lambda i: abs((ring[i][0] - cx) * uy - (ring[i][1] - cy) * ux))   # the spine: centre of the river face
    for i in range(n):                                             # fine bronze mullions round the shaft
        j = (i + 1) % n
        m = max(1, int(math.hypot(ring[j][0] - ring[i][0], ring[j][1] - ring[i][1]) / 1.6))
        for q in range(m):                                         # critic round 13: bronze mullions dense enough to read from the river
            t = q / m
            mx, my = ring[i][0] + (ring[j][0] - ring[i][0]) * t, ring[i][1] + (ring[j][1] - ring[i][1]) * t
            bufs["wil_fin"].beam((mx, my, pod["top_ahd"]), (mx, my, zt[i] + (zt[j] - zt[i]) * t), 0.22)
    lat = [(ring[i][0] - cx) * -uy + (ring[i][1] - cy) * ux for i in range(n)]     # sideways position along the river face
    rib = []
    for s in (-2.6, 2.6):                                          # two thin ribs 4 m apart with glass between (critic round 11: one fat bar read as a sticker)
        i = min((i for i in range(n) if d[i] > 0), key=lambda i: abs(lat[i] - lat[k] - s))
        qx, qy = ring[k][0] - uy * s + ux * 0.5, ring[k][1] + ux * s + uy * 0.5
        if (qx - cx) * ux + (qy - cy) * uy < d[i] + 0.5:           # never buried in the glass
            qx, qy = qx + ux * (d[i] + 0.5 - ((qx - cx) * ux + (qy - cy) * uy)), qy + uy * (d[i] + 0.5 - ((qx - cx) * ux + (qy - cy) * uy))
        rib.append((qx, qy))
        bufs["wil_white"].beam((qx, qy, g + 22.0), (qx, qy, zt[k] - 0.6), 1.8, 1.2)
        bufs["wil_white"].beam((qx, qy, g + 22.0), (qx - uy * s * 3.5, qy + ux * s * 3.5, g + 4.0), 1.8, 1.2)   # flare to the entrance arch
        bufs["wil_white"].beam((qx - uy * s * 3.5, qy + ux * s * 3.5, g + 4.0), (qx - uy * s * 3.5, qy + ux * s * 3.5, g), 1.8, 1.2)
    ko = min(range(n), key=lambda i: d[i] + 0.3 * abs(lat[i]))     # back of the roof, on the axis
    for qx, qy in rib:                                             # the ribs carry on over the roof as two thin bars
        bufs["wil_white"].beam((qx, qy, zt[k] + 0.2), (ring[ko][0] + qx - ring[k][0] - ux * 0.5, ring[ko][1] + qy - ring[k][1] - uy * 0.5, zt[ko] + 0.2), 1.8, 1.2)
    zb = g + 0.40 * (top - g)                                      # dark louvre band low on the shaft
    bufs["wil_band"].prism(B.offset(ring, 0.3), zb, zb + 6.0)
    bufs["wil_white"].beam((cx, cy, 214.0), (cx, cy, 254.0), 0.6)  # mast (LiDAR tip 266.6 m AHD)
    return ["glass skin", "floor lines", "podium lobby", "sloped crown", "white rim and spine", "mast"]


def queenswharf(bufs):
    """Queen's Wharf (opened 2024) is in no OSM, LiDAR or public aerial as finished towers: footprints are traced
    from the 2022 construction aerial, heights and skins from 2024-25 photos. Star Grand is a 180 degree arc of
    gold glass with a gap facing the river, bridged at the top by the Sky Deck (100 m up)."""
    ox, oy = QW_O

    def sector(a0, a1, ri, ro, step=6.0):
        n = max(2, int(abs(a1 - a0) / step))
        an = [math.radians(a0 + (a1 - a0) * i / n) for i in range(n + 1)]
        cx, cy = ox + QW_ARC[0], oy + QW_ARC[1]
        return S.ccw([(cx + ro * math.cos(a), cy + ro * math.sin(a)) for a in an] + [(cx + ri * math.cos(a), cy + ri * math.sin(a)) for a in reversed(an)])

    def oval(cx, cy, a, b, turn=0.0, n=40):
        t = math.radians(turn)
        return S.ccw([(ox + cx + a * math.cos(u) * math.cos(t) - b * math.sin(u) * math.sin(t), oy + cy + a * math.cos(u) * math.sin(t) + b * math.sin(u) * math.cos(t))
                      for u in (2 * math.pi * i / n for i in range(n))])

    g, ri, ro = 3.0, QW_ARC[2], QW_ARC[3]
    top, deck0 = 102.0, 86.0
    bufs["qw_podium"].prism(oval(QW_ARC[0], QW_ARC[1], ro + 8.0, ro + 8.0), g, 30.0)                       # podium over the expressway
    bufs["qw_podium"].prism([(ox - 29.0, oy - 36.0), (ox + 51.0, oy - 36.0), (ox + 51.0, oy + 29.0), (ox - 29.0, oy + 29.0)], g, 30.0)
    for a0, a1, z0, z1 in ((120.0, 201.0, 30.0, top), (249.0, 330.0, 30.0, top)):
        bufs["qw_gold"].prism(sector(a0, a1, ri, ro), z0, z1)
        z = z0 + 3.6
        while z < z1 - 1.0:                                        # pale floor lines every second floor
            bufs["qw_line"].prism(sector(a0, a1, ri - 0.05, ro + 0.05), z, z + 0.2)
            z += 7.2
    bufs["qw_gold"].prism(sector(200.0, 250.0, ri - 2.0, ro + 1.5), deck0 + 10.0, top)                    # Sky Deck bridging the gap
    bufs["qw_fin"].prism(sector(200.0, 250.0, ri - 2.5, ro + 2.0), deck0 + 9.4, deck0 + 10.0)
    bufs["qw_green"].prism(sector(0.0, 360.0, ro + 2.0, ro + 7.6), 30.6, 32.0)                              # planted podium terrace
    bufs["qw_deck"].prism(sector(120.0, 330.0, ri - 1.5, ro + 2.0), top, top + 2.4)                         # pale overhanging roof ring
    a = 121.0
    while a < 329.0:                                               # vertical bronze-black fins round the drum
        if not 201.0 < a < 249.0:
            bufs["qw_fin"].prism(sector(a, a + 0.5, ro, ro + 0.6, 0.5), 30.0, top)
        a += 2.2
    bufs["qw_deck"].prism(oval(QW_ARC[0], QW_ARC[1], ro + 8.3, ro + 8.3), 30.0, 30.6)                       # podium terrace edge
    bufs["qw_deck"].beam((ox + QW_ARC[0] - 30.0, oy + QW_ARC[1] + 38.0, top - 4.0), (ox + QW_OVAL[0] - 6.0, oy + QW_OVAL[1] - 8.0, top - 4.0), 4.0, 3.0)   # skybridge to the hotel tower
    for (cx, cy, a, b, turn, z1) in ((QW_OVAL[0], QW_OVAL[1], QW_OVAL[2], QW_OVAL[3], QW_OVAL[4], 165.0), (QW_RES[0], QW_RES[1], QW_RES[2], QW_RES[2], 0.0, 240.0)):
        ring = oval(cx, cy, a, b, turn)
        bufs["qw_dark"].prism(ring, g, z1)
        bufs["qw_dark"].prism(oval(cx, cy, a * 0.8, b * 0.8, turn), z1, z1 + 3.0)                            # stepped rounded top
        z = 34.0
        while z < z1 - 2.0:
            bufs["qw_dline"].prism(oval(cx, cy, a + 0.1, b + 0.1, turn), z, z + 0.25)
            if a != b and int((z - 34.0) / 7.0) % 3 == 0:              # the hotel blade's white ring bands
                bufs["qw_deck"].prism(oval(cx, cy, a + 0.35, b + 0.35, turn), z + 3.0, z + 3.4)
            z += 7.0
    return ["podium over the expressway", "Star Grand arc (two wings)", "Sky Deck", "Dorsett and Rosewood oval tower", "Residences tube"]


def clear_queenswharf():
    """Sink the generic building blocks standing where Queen's Wharf goes (numpy only: bmesh runs out of memory here)."""
    import bpy
    import numpy as np
    ox, oy = QW_O
    discs = [(ox + QW_ARC[0], oy + QW_ARC[1], QW_ARC[3] + 8.0), (ox + QW_OVAL[0], oy + QW_OVAL[1], QW_OVAL[2] + 5.0), (ox + QW_RES[0], oy + QW_RES[1], QW_RES[2] + 12.0), (ox + 11.0, oy - 3.5, 46.0)]
    n = 0
    for o in bpy.data.objects:
        if o.type != "MESH" or not o.name.startswith("bldg") or not len(o.data.vertices):
            continue
        co = np.empty(len(o.data.vertices) * 3, dtype=np.float32)
        o.data.vertices.foreach_get("co", co)
        co = co.reshape(-1, 3)
        w = co + np.array(o.location, dtype=np.float32)
        hit = np.zeros(len(co), bool)
        for x, y, r in discs:
            hit |= (np.hypot(w[:, 0] - x, w[:, 1] - y) < r) & (w[:, 2] > 5.0)
        if hit.any():
            co[hit, 2] -= 400.0
            o.data.vertices.foreach_set("co", co.ravel())
            o.data.update()
            n += int(hit.sum())
    print("hero_towers: sank", n, "generic verts at Queen's Wharf")
    return n


def clear_column(jobs):
    """Other modules' leftovers on the two towers (toppers, roof plant, masts in shared meshes): every vertex
    inside a tower's outline box and above its podium goes."""
    import bpy
    import bmesh
    import numpy as np
    boxes = []
    for b, z0 in jobs:
        r = b["tiers"][-1]["ring"]
        boxes.append((min(p[0] for p in r) - 3, min(p[1] for p in r) - 3, max(p[0] for p in r) + 3, max(p[1] for p in r) + 3, z0))
    n = 0
    for o in bpy.data.objects:
        if o.type != "MESH" or not len(o.data.vertices):
            continue
        co = np.empty(len(o.data.vertices) * 3)
        o.data.vertices.foreach_get("co", co)
        co = co.reshape(-1, 3) + np.array(o.location)
        hit = np.zeros(len(co), bool)
        for x0, y0, x1, y1, z0 in boxes:
            hit |= (co[:, 0] > x0) & (co[:, 0] < x1) & (co[:, 1] > y0) & (co[:, 1] < y1) & (co[:, 2] > z0)
        if hit.any():
            bm = bmesh.new()
            bm.from_mesh(o.data)
            bm.verts.ensure_lookup_table()
            bmesh.ops.delete(bm, geom=[bm.verts[i] for i in np.nonzero(hit)[0]], context="VERTS")
            bm.to_mesh(o.data)
            bm.free()
            n += int(hit.sum())
            print("hero_towers: cleared", o.name, int(hit.sum()))
    return n


def build():
    import bpy
    fp = os.path.join(L.REF, "ext", "buildings_ext.json")
    if L.GAME_EXPORT or getattr(L, "ACTIVE_STAGE", None) or not os.path.exists(fp):
        return {"module": "hero_towers", "objects": [], "note": "skipped (game export, stage build or no data)"}
    recs = {b["osm"]: b for b in json.load(open(fp))["buildings"] if b["osm"] in (SKY, WIL)}
    gone = []
    for o in list(bpy.data.objects):                               # the generic recipe meshes of the two towers
        if any(str(i) in o.name for i in (SKY, WIL, WIL_PART)):
            gone.append(o.name)
            bpy.data.objects.remove(o, do_unlink=True)
    cleared = clear_column([(recs[i], z) for i, z in ((SKY, 20.0), (WIL, 40.0)) if i in recs])
    bufs = {k: C.MeshBuf() for k in MATS}
    parts = {}
    if SKY in recs:
        parts["Brisbane Skytower"] = skytower(recs[SKY], bufs)
    if WIL in recs:
        parts["1 William St"] = william1(recs[WIL], bufs)
    clear_queenswharf()
    parts["Queen's Wharf"] = queenswharf(bufs)
    col = C.collection("hero_towers")
    objs = []
    for k, buf in bufs.items():
        ob = buf.object("hero_" + k, col, "roof")
        if not ob:
            continue
        rgb, rough, metal = MATS[k]
        m = bpy.data.materials.get("hero_" + k) or bpy.data.materials.new("hero_" + k)
        m.use_nodes = True
        bsdf = m.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Base Color"].default_value = (*rgb, 1)
        bsdf.inputs["Roughness"].default_value = rough
        bsdf.inputs["Metallic"].default_value = metal
        m.diffuse_color = (*rgb, 1)
        if k == "wil_deck":
            bsdf.inputs["Specular IOR Level"].default_value = 0.0
        m["look_done"] = True                                      # preview.setup_morning leaves it alone
        ob.data.materials[0] = m
        objs.append(ob.name)
    return {"module": "hero_towers", "objects": objs, "replaced": gone, "parts": parts,
            "source": "OSM outlines + 2019 LiDAR heights; skins and crowns from Commons photos 2016-2019",
            "note": "Crown slope of 1 William St (200 to 234 m, LiDAR roof cells) and the Skytower ring spacing are read off photos, not surveyed."}
