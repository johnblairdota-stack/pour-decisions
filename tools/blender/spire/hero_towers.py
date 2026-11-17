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
    "sky_glass": ((0.022, 0.036, 0.075), 0.06, 0.55), "sky_line": ((0.035, 0.055, 0.11), 0.3, 0.0),
    "sky_ring": ((0.42, 0.50, 0.62), 0.5, 0.0), "sky_band": ((0.012, 0.016, 0.026), 0.5, 0.0),
    "sky_crown": ((0.035, 0.045, 0.065), 0.4, 0.0), "sky_lobby": ((0.02, 0.035, 0.06), 0.05, 0.0),
    "wil_glass": ((0.10, 0.13, 0.19), 0.10, 0.7), "wil_line": ((0.16, 0.12, 0.085), 0.4, 0.2),
    "wil_white": ((0.85, 0.86, 0.86), 0.45, 0.0), "wil_deck": ((0.02, 0.014, 0.012), 0.8, 0.0),
    "wil_lobby": ((0.03, 0.05, 0.07), 0.05, 0.0),
}


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
    band = g + 0.70 * H                                            # critic round 2: plant bands 29% and 60% down
    for a in (0.905, 0.725, 0.635, 0.425):                         # critic round 3: clusters of 5 thin rings by the bands, bare glass between
        rings(bufs["sky_ring"], ring, g + a * H, g + a * H + 5 * floor - 0.5, floor, 0.14, 0.10)
    bufs["sky_band"].prism(B.offset(ring, 0.05), band, band + 3.3)
    bufs["sky_band"].prism(B.offset(ring, 0.05), g + 0.40 * H, g + 0.40 * H + 2.4)     # lower plant and amenity floor
    bufs["sky_crown"].prism(B.offset(ring, 0.18), top - 1.4, top + 0.8)             # crown lip
    bufs["sky_crown"].prism(B.offset(ring, -2.5), top, top + 4.0)                   # roof plant behind the lip
    bufs["sky_lobby"].prism(B.offset(ring, 0.12), g - 0.5, g + 9.0)
    bufs["sky_ring"].prism(B.offset(ring, 1.6), g + 9.0, g + 9.5)                   # entrance canopy line
    return ["glass skin", "floor lines", "white rings", "plant bands", "crown", "lobby"]


def william1(b, bufs):
    import buildings as B
    pod, tw = b["tiers"][0], b["tiers"][-1]
    ring = S.ccw([tuple(p) for p in tw["ring"]])
    g, top = 7.7, tw["top_ahd"]
    cx, cy = sum(p[0] for p in ring) / len(ring), sum(p[1] for p in ring) / len(ring)
    top = 198.0                                                    # the glass shaft ends where the crown slope starts
    bufs["wil_glass"].prism(ring, g - 1.0, top)
    bufs["wil_lobby"].prism(S.ccw([tuple(p) for p in pod["ring"]]), g - 1.0, pod["top_ahd"])
    rings(bufs["wil_line"], ring, pod["top_ahd"] + 2.0, top, 3.9, 0.22, 0.04)
    # crown: the glass carries on up to a sloped roof, low to the river (south-west), high behind
    ux, uy = -math.sqrt(0.5), -math.sqrt(0.5)                      # towards the river (the broad 70 m face)
    d = [(p[0] - cx) * ux + (p[1] - cy) * uy for p in ring]
    lo, hi = min(d), max(d)
    zt = [204.0 + 30.0 * (hi - v) / (hi - lo) for v in d]          # LiDAR roof cells: about 204 m at the river edge, 234 m behind
    n = len(ring)
    verts = [(p[0], p[1], top) for p in ring] + [(p[0], p[1], z) for p, z in zip(ring, zt)]
    bufs["wil_glass"].add(verts, [[i, (i + 1) % n, n + (i + 1) % n, n + i] for i in range(n)])
    inner = [(cx + (p[0] - cx) * 0.9, cy + (p[1] - cy) * 0.9) for p in ring]
    bufs["wil_deck"].add([(p[0], p[1], z - 1.2) for p, z in zip(inner, zt)], [list(range(n))])
    for i in range(n):                                             # white rim round the sloped top
        j = (i + 1) % n
        bufs["wil_white"].beam((ring[i][0], ring[i][1], zt[i]), (ring[j][0], ring[j][1], zt[j]), 3.4, 1.2)
    k = max(range(n), key=lambda i: d[i])                          # the spine up the river face
    px, py = ring[k][0] + ux * 0.4, ring[k][1] + uy * 0.4
    for s in (-2.0, 2.0):                                          # twin rails 4 m apart (critic round 3)
        bufs["wil_white"].beam((px - uy * s, py + ux * s, g), (px - uy * s, py + ux * s, zt[k]), 0.6, 0.8)
    zb = g + 0.27 * (top - g)                                      # dark louvre band low on the shaft
    bufs["wil_deck"].prism(B.offset(ring, 0.06), zb, zb + 4.5)
    bufs["wil_white"].beam((cx, cy, 214.0), (cx, cy, 266.6), 0.6)  # mast (LiDAR tip 266.6 m AHD)
    return ["glass skin", "floor lines", "podium lobby", "sloped crown", "white rim and spine", "mast"]


def build():
    import bpy
    fp = os.path.join(L.REF, "ext", "buildings_ext.json")
    if L.GAME_EXPORT or getattr(L, "ACTIVE_STAGE", None) or not os.path.exists(fp):
        return {"module": "hero_towers", "objects": [], "note": "skipped (game export, stage build or no data)"}
    recs = {b["osm"]: b for b in json.load(open(fp))["buildings"] if b["osm"] in (SKY, WIL)}
    gone = []
    for o in list(bpy.data.objects):                               # the generic recipe meshes of the two towers
        if o.name.startswith(("bldg_look_%d_" % SKY, "bldg_look_%d_" % WIL, "bldg_look_%d_" % WIL_PART)):
            gone.append(o.name)
            bpy.data.objects.remove(o, do_unlink=True)
    bufs = {k: C.MeshBuf() for k in MATS}
    parts = {}
    if SKY in recs:
        parts["Brisbane Skytower"] = skytower(recs[SKY], bufs)
    if WIL in recs:
        parts["1 William St"] = william1(recs[WIL], bufs)
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
        m["look_done"] = True                                      # preview.setup_morning leaves it alone
        ob.data.materials[0] = m
        objs.append(ob.name)
    return {"module": "hero_towers", "objects": objs, "replaced": gone, "parts": parts,
            "source": "OSM outlines + 2019 LiDAR heights; skins and crowns from Commons photos 2016-2019",
            "note": "Crown slope of 1 William St (200 to 234 m, LiDAR roof cells) and the Skytower ring spacing are read off photos, not surveyed."}
