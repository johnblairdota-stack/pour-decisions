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
    "sky_glass": ((0.06, 0.085, 0.125), 0.08, 0.5), "sky_line": ((0.035, 0.055, 0.11), 0.3, 0.0),
    "sky_ring": ((0.50, 0.72, 0.84), 0.4, 0.0), "sky_band": ((0.018, 0.022, 0.032), 0.5, 0.0),
    "sky_crown": ((0.035, 0.045, 0.065), 0.4, 0.0), "sky_lobby": ((0.02, 0.035, 0.06), 0.05, 0.0),
    "wil_glass": ((0.17, 0.195, 0.235), 0.06, 0.7), "wil_glow": ((0.80, 0.68, 0.42), 0.4, 0.0), "wil_band": ((0.08, 0.07, 0.06), 0.5, 0.3), "wil_fin": ((0.42, 0.30, 0.16), 0.35, 0.7), "wil_line": ((0.20, 0.16, 0.11), 0.45, 0.3),
    "wil_white": ((0.82, 0.80, 0.74), 0.45, 0.0), "wil_deck": ((0.10, 0.09, 0.08), 0.8, 0.0),
    "wil_lobby": ((0.03, 0.05, 0.07), 0.05, 0.0),
    # Eagle St towers and the Treasury Casino (John 18 Nov)
    "eag_dark": ((0.04, 0.055, 0.07), 0.12, 0.3), "eag_white": ((0.86, 0.85, 0.80), 0.5, 0.0), "eag_cream": ((0.74, 0.70, 0.60), 0.6, 0.0),
    "eag_blue": ((0.05, 0.12, 0.24), 0.08, 0.5), "eag_teal": ((0.05, 0.16, 0.19), 0.08, 0.5), "eag_tline": ((0.30, 0.42, 0.42), 0.4, 0.0),
    "tre_stone": ((0.43, 0.29, 0.14), 0.9, 0.0), "tre_pale": ((0.52, 0.38, 0.20), 0.85, 0.0), "tre_dark": ((0.025, 0.02, 0.016), 0.9, 0.0),
    "tre_roof": ((0.30, 0.32, 0.33), 0.6, 0.2),
    "qw_gold": ((0.06, 0.05, 0.045), 0.03, 0.5), "qw_line": ((0.42, 0.36, 0.22), 0.4, 0.4),
    "qw_dark": ((0.06, 0.075, 0.09), 0.08, 0.5), "qw_dline": ((0.10, 0.13, 0.17), 0.4, 0.0),
    "qw_podium": ((0.05, 0.047, 0.042), 0.2, 0.4), "qw_deck": ((0.80, 0.80, 0.78), 0.5, 0.0), "qw_fin": ((0.10, 0.075, 0.05), 0.35, 0.6), "qw_green": ((0.07, 0.16, 0.045), 0.9, 0.0),
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
    for a in (0.905, 0.76, 0.64, 0.36):                                # critic round 9: clusters of 3 rings two floors apart (5 a floor apart read as a white block)
        rings(bufs["sky_ring"], ring, g + a * H, g + a * H + 6 * floor - 0.5, 1.5 * floor, 0.24, 0.12)
    bufs["sky_band"].prism(B.offset(ring, 0.05), band, band + 4.0)
    bufs["sky_band"].prism(B.offset(ring, 0.05), g + 0.40 * H, g + 0.40 * H + 3.5)     # lower plant and amenity floor
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
        f = 1.0 - 0.05 * (0.5 + 0.5 * math.cos(math.pi * o / 6.0))    # critic round 17: a shallow dip, not a peanut waist
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
    k0 = min((i for i in range(n) if d[i] > 0), key=lambda i: abs((ring[i][0] - cx) * uy - (ring[i][1] - cy) * ux))
    lat0 = [(ring[i][0] - cx) * -uy + (ring[i][1] - cy) * ux for i in range(n)]
    for i in range(n):                                             # round 18: the rim dips to a V at the spine on the river face (two bays, like the photo)
        dl = abs(lat0[i] - lat0[k0])
        if d[i] > 0 and dl < 7.0:                                  # critic round 18: a near-level rim with a narrow slot, not a heart
            zt[i] -= 2.5 * (0.5 + 0.5 * math.cos(math.pi * dl / 7.0))
    verts = [(p[0], p[1], top) for p in ring] + [(p[0], p[1], z) for p, z in zip(ring, zt)]
    bufs["wil_glass"].add(verts, [[i, (i + 1) % n, n + (i + 1) % n, n + i] for i in range(n)])
    inner = [(cx + (p[0] - cx) * 0.96, cy + (p[1] - cy) * 0.96) for p in ring]
    bufs["wil_deck"].add([(p[0], p[1], z - 0.5) for p, z in zip(inner, zt)] + [(cx, cy, 190.0 + 46.0 * hi / (hi - lo) - 0.5)], [[n, i, (i + 1) % n] for i in range(n)])
    for i in range(n):                                             # white rim round the sloped top
        j = (i + 1) % n
        bufs["wil_white"].beam((ring[i][0], ring[i][1], zt[i]), (ring[j][0], ring[j][1], zt[j]), 1.7, 1.5)
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
        bufs["wil_white"].beam((qx, qy, g + 17.0), (qx, qy, zt[k] - 0.6), 1.0, 1.0)
        prev = (qx, qy, g + 17.0)
        for f, zz in ((0.12, 14.0), (0.38, 11.0), (0.72, 7.5), (0.95, 4.0), (1.0, 0.0)):       # the ribs curve out into an arch about 12 m wide round the lobby
            cur = (qx - uy * s * 1.35 * f, qy + ux * s * 1.35 * f, g + zz)
            bufs["wil_white"].beam(prev, cur, 1.0, 1.0)
            prev = cur
    ko = min(range(n), key=lambda i: d[i] + 0.3 * abs(lat[i]))     # back of the roof, on the axis
    zr = lambda px, py: 190.0 + 46.0 * (hi - ((px - cx) * ux + (py - cy) * uy)) / (hi - lo)
    zc = zr(cx, cy) - 0.25
    for s in (-2.6, 2.6):                                          # critic round 18: the bay edges lie on the roof (no floating slivers) and close a loop round each lobe
        i = min((i for i in range(n) if d[i] > 0), key=lambda i: abs(lat[i] - lat[k] - s))
        bufs["wil_white"].beam((inner[i][0], inner[i][1], zt[i] - 0.25), (cx - uy * s * 0.5, cy + ux * s * 0.5, zc), 1.0, 0.5)
        bufs["wil_white"].beam((cx - uy * s * 0.5, cy + ux * s * 0.5, zc), (inner[ko][0] - uy * s * 0.5, inner[ko][1] + ux * s * 0.5, zt[ko] - 0.25), 1.0, 0.5)
    lx, ly = -uy, ux                                               # glazed, warm-lit lobby inside the arch
    c0 = (ring[k][0] + ux * 0.4, ring[k][1] + uy * 0.4)
    bufs["wil_glow"].prism(S.ccw([(c0[0] - lx * 5.0, c0[1] - ly * 5.0), (c0[0] + lx * 5.0, c0[1] + ly * 5.0),
                                  (c0[0] + lx * 5.0 + ux * 0.5, c0[1] + ly * 5.0 + uy * 0.5), (c0[0] - lx * 5.0 + ux * 0.5, c0[1] - ly * 5.0 + uy * 0.5)]), g, g + 9.0)
    zb = g + 0.40 * (top - g)                                      # dark louvre band low on the shaft
    bufs["wil_band"].prism(B.offset(ring, 0.3), zb, zb + 2.6)
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
    bufs["qw_podium"].prism(oval(QW_ARC[0], QW_ARC[1], ro + 9.0, ro + 9.0), g, 21.0)
    bufs["qw_podium"].prism(oval(QW_ARC[0], QW_ARC[1], ro + 6.5, ro + 6.5), 21.0, 25.5)
    bufs["qw_podium"].prism(oval(QW_ARC[0], QW_ARC[1], ro + 4.0, ro + 4.0), 25.5, 30.0)                       # podium over the expressway
    bufs["qw_podium"].prism([(ox - 29.0, oy - 36.0), (ox + 51.0, oy - 36.0), (ox + 51.0, oy + 29.0), (ox - 29.0, oy + 29.0)], g, 30.0)
    for a0, a1, z0, z1 in ((120.0, 201.0, 30.0, top), (249.0, 330.0, 30.0, top)):
        for b_ in range(8):                                        # critic round 18: a bowed barrel, not a straight cylinder
            za, zb_ = z0 + (z1 - z0) * b_ / 8.0, z0 + (z1 - z0) * (b_ + 1) / 8.0
            bufs["qw_gold"].prism(sector(a0, a1, ri, ro + 3.0 * math.sin(math.pi * (b_ + 0.5) / 8.0)), za, zb_)
        z = z0 + 3.6
        while z < z1 - 1.0:                                        # pale floor lines every second floor
            bufs["qw_line"].prism(sector(a0, a1, ri - 0.05, ro + 0.05), z, z + 0.2)
            z += 7.2
    bufs["qw_gold"].prism(sector(200.0, 250.0, ri - 2.0, ro + 1.5), deck0 + 10.0, top)                    # Sky Deck bridging the gap
    bufs["qw_fin"].prism(sector(200.0, 250.0, ri - 2.5, ro + 2.0), deck0 + 9.4, deck0 + 10.0)
    for st, (rr, zz) in enumerate(((ro + 8.0, 21.0), (ro + 5.5, 25.5), (ro + 3.0, 30.0))):                   # three planted terraces stepping in up the podium
        bufs["qw_green"].prism(sector(0.0, 360.0, rr - 1.6, rr + 0.9), zz + 0.1, zz + 1.5)
        bufs["qw_fin"].prism(sector(0.0, 360.0, rr + 0.9, rr + 1.3), zz - 4.3, zz + 0.3)
    bufs["qw_deck"].prism(sector(120.0, 330.0, ri - 1.5, ro + 2.0), top, top + 2.4)                         # pale overhanging roof ring
    a = 121.0
    while a < 329.0:                                               # vertical bronze-black fins round the drum
        if not 201.0 < a < 249.0:
            for b_ in range(8):                                    # fins follow the barrel and step half a bay every band
                bulge = 3.0 * math.sin(math.pi * (b_ + 0.5) / 8.0)
                a_ = a + (1.1 if b_ % 2 else 0.0)
                bufs["qw_fin"].prism(sector(a_, a_ + 0.5, ro + bulge, ro + bulge + 0.3, 0.5), 30.0 + (top - 30.0) * b_ / 8.0, 30.0 + (top - 30.0) * (b_ + 1) / 8.0)
        a += 2.2
    bufs["qw_deck"].prism(oval(QW_ARC[0], QW_ARC[1], ro + 4.3, ro + 4.3), 30.0, 30.6)                       # podium terrace edge
    bufs["qw_deck"].beam((ox + QW_ARC[0] - 30.0, oy + QW_ARC[1] + 38.0, top - 4.0), (ox + QW_OVAL[0] - 6.0, oy + QW_OVAL[1] - 8.0, top - 4.0), 4.0, 3.0)   # skybridge to the hotel tower
    for (cx, cy, a, b, turn, z1) in ((QW_OVAL[0], QW_OVAL[1], QW_OVAL[2], QW_OVAL[3], QW_OVAL[4], 165.0), (QW_RES[0], QW_RES[1], QW_RES[2], QW_RES[2], 0.0, 240.0)):
        ring = oval(cx, cy, a, b, turn)
        bufs["qw_dark"].prism(ring, g, z1)
        m = len(ring)                                                  # round 20: slanted, scooped top with a planted strip, not a stepped cap
        tr = math.radians(turn)
        sl = [((q[0] - ox - cx) * math.cos(tr) + (q[1] - oy - cy) * math.sin(tr)) / max(a, b) for q in ring]
        zs = [z1 + 4.5 + 4.5 * max(-1.0, min(1.0, v)) for v in sl]
        bufs["qw_dark"].add([(q[0], q[1], z1) for q in ring] + [(q[0], q[1], z) for q, z in zip(ring, zs)],
                            [[i, (i + 1) % m, m + (i + 1) % m, m + i] for i in range(m)])
        mcx, mcy = sum(q[0] for q in ring) / m, sum(q[1] for q in ring) / m
        bufs["qw_podium"].add([(mcx + (q[0] - mcx) * 0.97, mcy + (q[1] - mcy) * 0.97, z - 1.2) for q, z in zip(ring, zs)] + [(mcx, mcy, z1 + 2.0)],
                              [[m, i, (i + 1) % m] for i in range(m)])
        bufs["qw_green"].add([(mcx + (q[0] - mcx) * 0.55, mcy + (q[1] - mcy) * 0.55, z1 + 2.0 + (z - 1.2 - z1 - 2.0) * 0.55 + 0.3) for q, z in zip(ring, zs)] + [(mcx, mcy, z1 + 2.3)],
                             [[m, i, (i + 1) % m] for i in range(m)])
        for i in range(m):
            bufs["qw_deck"].beam((ring[i][0], ring[i][1], zs[i]), (ring[(i + 1) % m][0], ring[(i + 1) % m][1], zs[(i + 1) % m]), 0.5, 0.5)
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


EAGLE = {"riparian": 140808831, "oneoneone": 134816032, "riverside": 134816031, "waterfront": 140804995}
TREASURY = [(-770.0, -944.0), (-713.0, -1009.0), (-661.0, -963.0), (-719.0, -900.0)]     # OSM relation 7772386 (Treasury Building, 27 m), four corners


def sink_polys(polys, zmin=5.0):
    """Generic building blocks standing inside these outlines go under the ground (numpy only, like clear_queenswharf)."""
    import bpy
    import numpy as np
    n = 0
    for o in bpy.data.objects:
        if o.type != "MESH" or not o.name.startswith("bldg") or not len(o.data.vertices):
            continue
        co = np.empty(len(o.data.vertices) * 3, dtype=np.float32)
        o.data.vertices.foreach_get("co", co)
        co = co.reshape(-1, 3)
        w = co + np.array(o.location, dtype=np.float32)
        hit = np.zeros(len(co), bool)
        for poly in polys:
            xs, ys = [p[0] for p in poly], [p[1] for p in poly]
            box = (w[:, 0] > min(xs)) & (w[:, 0] < max(xs)) & (w[:, 1] > min(ys)) & (w[:, 1] < max(ys)) & (w[:, 2] > zmin)
            if not box.any():
                continue
            ins = np.zeros(len(co), bool)
            for i in range(len(poly)):                             # even-odd rule
                x0, y0 = poly[i]
                x1, y1 = poly[(i + 1) % len(poly)]
                if y0 == y1:
                    continue
                cr = ((y0 > w[:, 1]) != (y1 > w[:, 1])) & (w[:, 0] < (x1 - x0) * (w[:, 1] - y0) / (y1 - y0) + x0)
                ins ^= cr
            hit |= box & ins
        if hit.any():
            co[hit, 2] -= 400.0
            o.data.vertices.foreach_set("co", co.ravel())
            o.data.update()
            n += int(hit.sum())
    print("hero_towers: sank", n, "generic verts under the Eagle St towers and the Treasury")
    return n


def eagle_street(recs, bufs):
    """Riparian Plaza, One One One Eagle St, Riverside Centre and Waterfront Place on their LiDAR tiers (photos: Petrie
    Bight from the river, the Story Bridge view)."""
    import buildings as B
    made = []
    b = recs.get(EAGLE["riparian"])
    if b:                                                          # white bands on dark strip windows below, deeper wavy balconies above, stepped top and the mast
        t = [x for x in b["tiers"] if len(x["ring"]) > 8]
        g = b["base_ahd"]
        z0 = g - 1.0
        for x in t:
            ring = S.ccw([tuple(p) for p in x["ring"]])
            bufs["eag_dark"].prism(ring, z0, x["top_ahd"])
            z = max(z0 + 4.0, g + 8.0)
            k = 0
            while z < x["top_ahd"] - 1.0:
                res = z > 147.0
                bufs["eag_white"].prism(B.offset(ring, (1.5 if k % 2 else 0.5) if res else 0.3), z, z + (1.2 if res else 1.5))
                z += 3.3 if res else 3.9
                k += 1
            bufs["eag_white"].prism(B.offset(ring, 0.4), x["top_ahd"] - 0.6, x["top_ahd"] + 0.6)
            z0 = x["top_ahd"]
        top = t[-1]["top_ahd"]
        bufs["eag_white"].beam((-48.4, -573.6, top), (-48.4, -573.6, 252.0), 2.2)
        bufs["eag_white"].beam((-48.4, -573.6, 252.0), (-48.4, -573.6, 262.0), 0.6)
        bufs["eag_white"].beam((-40.2, -550.4, top), (-40.2, -550.4, top + 14.0), 1.4)
        made.append("Riparian Plaza")
    b = recs.get(EAGLE["oneoneone"])
    if b:                                                          # blue glass with the white branching columns, white frame at the crown
        g = b["base_ahd"]
        z0 = g - 1.0
        for x in b["tiers"]:
            ring = S.ccw([tuple(p) for p in x["ring"]])
            bufs["eag_blue" if len(ring) > 8 else "eag_dark"].prism(ring, z0, x["top_ahd"])
            z0 = x["top_ahd"]
        ring = S.ccw([tuple(p) for p in b["tiers"][1]["ring"]])
        top1 = b["tiers"][1]["top_ahd"]
        out = B.offset(ring, 0.35)
        per = [0.0]
        for i in range(len(out)):
            j = (i + 1) % len(out)
            per.append(per[-1] + math.hypot(out[j][0] - out[i][0], out[j][1] - out[i][1]))

        def at(d_):
            d_ %= per[-1]
            for i in range(len(out)):
                if per[i + 1] >= d_:
                    j = (i + 1) % len(out)
                    f = (d_ - per[i]) / max(per[i + 1] - per[i], 1e-6)
                    return out[i][0] + (out[j][0] - out[i][0]) * f, out[i][1] + (out[j][1] - out[i][1]) * f
            return out[0]
        nb = max(6, int(per[-1] / 14.0))
        lv = [g + 16.0 + (top1 - g - 16.0) * q / 4.0 for q in range(5)]
        for c in range(nb):                                        # leaning columns that branch every quarter of the height
            d0 = per[-1] * c / nb
            for q in range(4):
                sh = (per[-1] / nb) * 0.5
                a, b_ = at(d0 + (sh if q % 2 else 0.0)), at(d0 + (0.0 if q % 2 else sh))
                bufs["eag_white"].beam((a[0], a[1], lv[q]), (b_[0], b_[1], lv[q + 1]), 0.7)
                a, b_ = at(d0 + (sh if q % 2 else 0.0)), at(d0 + (2 * sh if q % 2 else -sh))
                bufs["eag_white"].beam((a[0], a[1], lv[q]), (b_[0], b_[1], lv[q + 1]), 0.5)
        z = g + 16.0
        while z < top1:
            bufs["eag_tline"].prism(B.offset(ring, 0.05), z, z + 0.15)
            z += 3.9
        bufs["eag_white"].prism(B.offset(ring, 0.5), top1 - 0.5, top1 + 0.5)
        tr = S.ccw([tuple(p) for p in b["tiers"][-1]["ring"]])
        bufs["eag_white"].prism(B.offset(tr, 0.4), b["tiers"][-1]["top_ahd"] - 0.4, b["tiers"][-1]["top_ahd"] + 0.6)
        made.append("One One One Eagle St")
    b = recs.get(EAGLE["riverside"])
    if b:                                                          # cream precast bands with dark strip windows, flat top, mast
        g = b["base_ahd"]
        ring = S.ccw([tuple(p) for p in b["tiers"][-1]["ring"]])
        top = b["tiers"][0]["top_ahd"]
        bufs["eag_dark"].prism(ring, g - 1.0, top)
        z = g + 10.0
        while z < top - 1.0:
            bufs["eag_cream"].prism(B.offset(ring, 0.35), z, z + 2.0)
            z += 3.7
        bufs["eag_cream"].prism(B.offset(ring, 0.5), top - 1.5, b["tiers"][-1]["top_ahd"])
        bufs["eag_cream"].prism(B.offset(ring, 0.6), g - 1.0, g + 9.0)
        for sp in b["spires"]:
            bufs["eag_white"].beam((sp["x"], sp["y"], sp["base_ahd"]), (sp["x"], sp["y"], sp["top_ahd"]), 1.2)
        made.append("Riverside Centre")
    b = recs.get(EAGLE["waterfront"])
    if b:                                                          # teal mirror glass with fine pale lines and a stepped top
        g = b["base_ahd"]
        ring = S.ccw([tuple(p) for p in b["tiers"][-1]["ring"]])
        top = b["tiers"][-1]["top_ahd"]
        bufs["eag_teal"].prism(ring, g - 1.0, top - 12.0)
        bufs["eag_teal"].prism(B.offset(ring, -3.0), top - 12.0, top - 5.0)
        bufs["eag_teal"].prism(B.offset(ring, -7.0), top - 5.0, top)
        for zz, off in ((top - 12.0, 0.3), (top - 5.0, -2.7), (top, -6.7)):
            bufs["eag_white"].prism(B.offset(ring, off), zz - 0.3, zz + 0.5)
        z = g + 12.0
        k = 0
        while z < top - 13.0:
            bufs["eag_tline"].prism(B.offset(ring, 0.05), z, z + (0.5 if k % 4 == 0 else 0.14))
            z += 3.8
            k += 1
        bufs["eag_cream"].prism(B.offset(ring, 0.5), g - 1.0, g + 10.0)
        made.append("Waterfront Place")
    return made


def treasury(bufs):
    """Treasury Casino: four-storey sandstone palazzo round a courtyard, arcaded loggias on every floor, corner
    pavilions, balustraded parapet. Outline from OSM (relation 7772386), 27 m; arcade rhythm from the 2010 William St photo."""
    import buildings as B
    ring = S.ccw(TREASURY)
    n = len(ring)
    g, eave = 6.0, 30.0
    floors = [(g, 12.5), (12.5, 18.5), (18.5, 24.5), (24.5, eave - 1.5)]
    bufs["tre_stone"].prism(ring, g - 4.0, eave)
    bufs["tre_roof"].prism(B.offset(ring, -1.5), eave, eave + 1.4)
    bufs["tre_roof"].prism(B.offset(ring, -6.0), eave + 1.4, eave + 2.6)
    bufs["tre_dark"].prism(B.offset(ring, -19.0), eave + 2.6, eave + 2.7)     # the courtyard, read from above
    for z0, z1 in floors:                                          # pale cornice at every floor
        bufs["tre_pale"].prism(B.offset(ring, 0.7), z1 - 0.5, z1)
    bufs["tre_pale"].prism(B.offset(ring, 0.9), eave - 0.6, eave + 0.2)
    bufs["tre_pale"].prism(B.offset(ring, 0.35), eave + 0.2, eave + 1.3)       # balustrade
    cx, cy = sum(p[0] for p in ring) / n, sum(p[1] for p in ring) / n
    for i in range(n):
        a, b = ring[i], ring[(i + 1) % n]
        ln = math.hypot(b[0] - a[0], b[1] - a[1])
        u = ((b[0] - a[0]) / ln, (b[1] - a[1]) / ln)
        nx, ny = u[1], -u[0]
        if (a[0] + nx - cx) ** 2 + (a[1] + ny - cy) ** 2 < (a[0] - cx) ** 2 + (a[1] - cy) ** 2:
            nx, ny = -nx, -ny

        def quad(t0, t1, o0, o1):
            return S.ccw([(a[0] + u[0] * t0 + nx * o0, a[1] + u[1] * t0 + ny * o0), (a[0] + u[0] * t1 + nx * o0, a[1] + u[1] * t1 + ny * o0),
                          (a[0] + u[0] * t1 + nx * o1, a[1] + u[1] * t1 + ny * o1), (a[0] + u[0] * t0 + nx * o1, a[1] + u[1] * t0 + ny * o1)])
        for t0, t1 in ((0.0, 10.0), (ln - 10.0, ln), (ln / 2 - 7.0, ln / 2 + 7.0)):     # corner and centre pavilions stand proud and a little taller
            bufs["tre_stone"].prism(quad(t0, t1, -1.0, 1.3), g - 4.0, eave + 1.6)
            bufs["tre_pale"].prism(quad(t0 - 0.4, t1 + 0.4, -1.0, 1.8), eave + 1.6, eave + 2.3)
        bays = max(4, int((ln - 22.0) / 4.3))
        step = (ln - 22.0) / bays
        for k in range(bays):
            t = 11.0 + step * (k + 0.5)
            if abs(t - ln / 2) < 7.6:
                proud = 1.3
            else:
                proud = 0.0
            for fi, (z0, z1) in enumerate(floors):
                w = step * 0.62
                h = (z1 - z0) - 2.4
                bufs["tre_dark"].prism(quad(t - w / 2, t + w / 2, proud, proud + 0.12), z0 + 1.0, z0 + 1.0 + h)
                if fi < 3:                                         # round arch heads, stepped
                    bufs["tre_dark"].prism(quad(t - w * 0.38, t + w * 0.38, proud, proud + 0.12), z0 + 1.0 + h, z0 + 1.0 + h + 0.55)
                    bufs["tre_dark"].prism(quad(t - w * 0.2, t + w * 0.2, proud, proud + 0.12), z0 + 1.55 + h, z0 + 1.9 + h)
            bufs["tre_pale"].prism(quad(t + step / 2 - 0.5, t + step / 2 + 0.5, proud, proud + 1.0), g, eave - 0.6)   # pilaster between bays
    return ["sandstone block", "arcades", "pavilions", "cornices and balustrade", "roofs and courtyard"]


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


def fill_tree_gaps(col):
    """The tower data packs leave holes in the ext box (the river edge of the City Botanic Gardens has no pack, and
    the city-wide trees skip the whole box), so the bank showed as a bare grey patch from Kangaroo Point. Plant
    garden trees there: a jittered 10 m grid, only on dry ground clear of roads, buildings and the river."""
    import bpy
    import gzip
    import numpy as np
    import trees as T
    import far_roads as FR
    m = json.load(open(os.path.join(L.REF, "ext", "ext.json")))
    x0, y0, x1, y1 = m["box_local"]
    cov = np.frombuffer(gzip.open(os.path.join(L.REF, "ext", "cover_1m.u8.gz")).read(), "u1").reshape(m["rows"], m["cols"])
    rv = json.load(open(os.path.join(L.REF, "river", "river.json")))
    wat = np.frombuffer(gzip.open(os.path.join(L.REF, "river", "water_2m.u8.gz")).read(), "u1").reshape(rv["rows"], rv["cols"])
    rx0, ry0, rx1, ry1 = rv["box_local"]
    polys = []
    for fp in (("wide", "buildings_wide.json"), ("ext", "buildings_ext.json"), ("lidar", "buildings_clean.json")):
        for bd in json.load(open(os.path.join(L.REF, *fp)))["buildings"]:
            for t in bd["tiers"]:
                rg = t["ring"]
                bx = (min(q[0] for q in rg) - 5.0, min(q[1] for q in rg) - 5.0, max(q[0] for q in rg) + 5.0, max(q[1] for q in rg) + 5.0)
                if bx[2] > x0 and bx[0] < x1 and bx[3] > y0 and bx[1] < y1:
                    polys.append(bx)

    def wet(x, y):
        c2, r2 = int((x - rx0) / rv["step_m"]), int((ry1 - y) / rv["step_m"])
        return 0 <= r2 < rv["rows"] and 0 <= c2 < rv["cols"] and wat[max(0, r2 - 2):r2 + 3, max(0, c2 - 2):c2 + 3].any()
    trunks, crowns = C.MeshBuf(), C.MeshBuf()
    n = 0
    gx = x0 + 5.0
    while gx < x1:
        gy = y0 + 5.0
        while gy < y1:
            hsh = math.sin(gx * 12.9898 + gy * 78.233) * 43758.5453
            j1, j2 = hsh - math.floor(hsh), (hsh * 7.13) - math.floor(hsh * 7.13)
            x, y = gx + (j1 - 0.5) * 7.0, gy + (j2 - 0.5) * 7.0
            c, r = int(x - x0), int(y1 - y)
            gy += 10.0
            if not (0 <= r < m["rows"] and 0 <= c < m["cols"]) or cov[r, c] or FR.on_road(x, y) or x < -94.0 or y > -1378.0:   # only the gardens corner no pack reaches
                continue
            if wet(x, y) or any(q[0] < x < q[2] and q[1] < y < q[3] for q in polys):
                continue
            g = float(FR.GROUND.z([x], [y])[0]) if FR.GROUND else 4.0
            if g < 1.6:
                continue
            h = 9.0 + 9.0 * j2
            rr = 0.34 * h
            if FR.over_deck(x, y, rr * 1.25):
                continue
            T.trunk(trunks, x, y, g, 0.25, h * 0.55, 0)
            T.blob(crowns, x, y, g + h * 0.5, rr * 1.2, h * 0.34)
            for k2 in range(4):
                a2 = (x * 12.9898 + y * 78.233 + k2 * 2.4) % 6.2832
                T.blob(crowns, x + math.cos(a2) * rr * 0.8, y + math.sin(a2) * rr * 0.8, g + h * (0.34 + 0.07 * k2), rr * (0.55 + 0.12 * k2), h * 0.24)
            n += 1
        gx += 10.0
    names = []
    for buf, name, mname in ((trunks, "fill_tree_trunks", "tree_trunks"), (crowns, "fill_tree_crowns", "tree_crowns_far")):
        ob = buf.object(name, col, "tree")
        if ob:
            mat = bpy.data.materials.get(mname)
            if mat:
                ob.data.materials.clear()
                ob.data.materials.append(mat)
            names.append(ob.name)
    return names, n


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
    efp = os.path.join(L.REF, "lidar", "buildings_clean.json")
    erecs = {b["osm"]: b for b in json.load(open(efp))["buildings"] if b["osm"] in EAGLE.values()} if os.path.exists(efp) else {}
    for o in list(bpy.data.objects):                               # Waterfront Place also has a generic mesh of its own
        if str(EAGLE["waterfront"]) in o.name:
            gone.append(o.name)
            bpy.data.objects.remove(o, do_unlink=True)
    import buildings as B_
    sink_polys([B_.offset(S.ccw([tuple(p) for p in x["ring"]]), 2.0) for b in erecs.values() for x in b["tiers"]] + [B_.offset(S.ccw(TREASURY), 2.0)])
    parts["Eagle St towers"] = eagle_street(erecs, bufs)
    parts["Treasury Casino"] = treasury(bufs)
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
    fill, nfill = fill_tree_gaps(col)
    objs += fill
    parts["Botanic Gardens bank trees (data gap fill)"] = nfill
    return {"module": "hero_towers", "objects": objs, "replaced": gone, "parts": parts,
            "source": "OSM outlines + 2019 LiDAR heights; skins and crowns from Commons photos 2016-2019",
            "note": "Crown slope of 1 William St (200 to 234 m, LiDAR roof cells) and the Skytower ring spacing are read off photos, not surveyed."}
