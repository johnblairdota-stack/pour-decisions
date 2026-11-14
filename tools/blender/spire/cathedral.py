"""St John's Cathedral, clean Gothic Revival massing (step 5): nave with a steep gable roof, lower aisles
with lean-to roofs, buttresses, a transept where the LiDAR shows the roof widening, and the towers and
spires. Plan from the OSM footprint's rectangle; every height measured from the 2019 LiDAR (DSM over
ground) inside the footprint. Stone colours stand in for the porphyry / sandstone. Window tracery,
porches and the exact plan need John's photos and a plan drawing."""
import math

import numpy as np

import layout as L
import common as C
import shapes as S
import prep_lidar as PL

WAY = 26384715


def build():
    o = L.osm()
    if WAY not in o["ways"]:
        return {"module": "cathedral", "objects": [], "note": "cathedral not in the OSM crop"}
    col = C.collection("landmarks")
    ring = S.clean(o["line"](o["ways"][WAY]), 0.3)
    cx, cy, ln, wd, ang = S.min_rect(ring)
    ux, uy = math.cos(ang), math.sin(ang)          # along the nave
    vx, vy = -uy, ux                               # across
    box = L.LIDAR_BOX
    m, r0, c0 = PL.ring_mask(ring, box)
    sub = (slice(r0, r0 + m.shape[0]), slice(c0, c0 + m.shape[1]))
    g = float(np.median(L.lidar("ground")[sub][m]))
    rr, cc = np.nonzero(m)
    X = box[0] + c0 + cc + 0.5
    Y = box[3] - r0 - rr - 0.5
    H = L.lidar("dsm")[sub][m] - g
    U = (X - cx) * ux + (Y - cy) * uy
    V = (X - cx) * vx + (Y - cy) * vy
    nave_w = 0.42 * wd
    centre = np.abs(V) < 0.12 * wd
    ridge = float(np.percentile(H[centre], 70))
    eave = float(np.percentile(H[(np.abs(V) > 0.17 * wd) & (np.abs(V) < 0.22 * wd)], 50)) if centre.any() else ridge * 0.6
    eave = min(eave, ridge - 4.0)
    aisle_top = float(np.percentile(H[np.abs(V) > 0.32 * wd], 50))
    aisle_top = min(aisle_top, eave - 3.0)
    def P(u, v, z):
        return (cx + u * ux + v * vx, cy + u * uy + v * vy, g + z)
    stone, roof, trim = C.MeshBuf(), C.MeshBuf(), C.MeshBuf()
    hl = ln / 2
    # nave: walls to the eave, steep gable roof
    stone.prism([P(-hl, -nave_w / 2, 0)[:2], P(hl, -nave_w / 2, 0)[:2], P(hl, nave_w / 2, 0)[:2], P(-hl, nave_w / 2, 0)[:2]],
                g - 0.5, g + eave)
    verts = [P(-hl, -nave_w / 2, eave), P(hl, -nave_w / 2, eave), P(hl, nave_w / 2, eave), P(-hl, nave_w / 2, eave),
             P(-hl, 0, ridge), P(hl, 0, ridge)]
    roof.add(verts, [[0, 1, 5, 4], [2, 3, 4, 5], [0, 4, 3], [1, 2, 5]])
    # aisles with lean-to roofs, buttresses every 6 m
    for side in (-1, 1):
        a0, a1 = side * nave_w / 2, side * wd / 2
        ringa = [P(-hl * 0.92, a0, 0)[:2], P(hl * 0.92, a0, 0)[:2], P(hl * 0.92, a1, 0)[:2], P(-hl * 0.92, a1, 0)[:2]]
        stone.prism(S.ccw(ringa), g - 0.5, g + aisle_top)
        verts = [P(-hl * 0.92, a1, aisle_top), P(hl * 0.92, a1, aisle_top), P(hl * 0.92, a0, eave - 1.0), P(-hl * 0.92, a0, eave - 1.0)]
        roof.add(verts, [[0, 1, 2, 3]])
        u = -hl * 0.9
        while u < hl * 0.9:
            x, y, _ = P(u, a1 + side * 0.6, 0)
            trim.box(x, y, g - 0.3, 1.2, 1.2, aisle_top + 1.0, ang)
            u += 6.0
    # transept: where the LiDAR roof is as high as the nave out at the aisle line, across the full width
    wide = (np.abs(V) > 0.30 * wd) & (H > eave)
    tr = None
    if wide.sum() > 20:
        u0, u1 = float(np.percentile(U[wide], 10)), float(np.percentile(U[wide], 90))
        if 6 < u1 - u0 < 0.5 * ln:
            um, tw = (u0 + u1) / 2, u1 - u0
            ringt = [P(um - tw / 2, -wd / 2 - 1, 0)[:2], P(um + tw / 2, -wd / 2 - 1, 0)[:2],
                     P(um + tw / 2, wd / 2 + 1, 0)[:2], P(um - tw / 2, wd / 2 + 1, 0)[:2]]
            stone.prism(S.ccw(ringt), g - 0.5, g + eave)
            verts = [P(um - tw / 2, -wd / 2 - 1, eave), P(um + tw / 2, -wd / 2 - 1, eave), P(um + tw / 2, wd / 2 + 1, eave),
                     P(um - tw / 2, wd / 2 + 1, eave), P(um, -wd / 2 - 1, ridge), P(um, wd / 2 + 1, ridge)]
            roof.add(verts, [[0, 4, 5, 3], [1, 2, 5, 4], [0, 1, 4], [2, 3, 5]])
            tr = [round(um, 1), round(tw, 1)]
    # towers: LiDAR cells far above the ridge, grouped by position; each a square tower + spire
    tall = H > ridge + 6
    towers = []
    if tall.any():
        pts = np.stack([U[tall], V[tall], H[tall]], 1)
        used = np.zeros(len(pts), bool)
        for i in np.argsort(-pts[:, 2]):
            if used[i]:
                continue
            near = (np.abs(pts[:, 0] - pts[i, 0]) < 7) & (np.abs(pts[:, 1] - pts[i, 1]) < 7)
            used |= near
            grp = pts[near]
            if len(grp) < 4:
                continue
            tu, tv = float(grp[:, 0].mean()), float(grp[:, 1].mean())
            side_m = max(5.0, min(10.0, 2 * math.sqrt(len(grp) / math.pi) + 2))
            top = float(grp[:, 2].max())
            body = max(ridge + 4, top - 2.2 * side_m) if top - ridge > 15 else top - 1.0
            x, y, _ = P(tu, tv, 0)
            stone.box(x, y, g - 0.5, side_m, side_m, body + 0.5, ang)
            if top - body > 3:
                n = 8
                base = [(x + side_m * 0.55 * math.cos(2 * math.pi * k / n + ang + math.pi / 8),
                         y + side_m * 0.55 * math.sin(2 * math.pi * k / n + ang + math.pi / 8), g + body) for k in range(n)]
                roof.add(base + [(x, y, g + top)], [[k, (k + 1) % n, n] for k in range(n)] + [list(range(n - 1, -1, -1))])
            for dx in (-1, 1):                                  # corner pinnacles
                for dy in (-1, 1):
                    px = x + (dx * ux + dy * vx) * side_m / 2
                    py = y + (dx * uy + dy * vy) * side_m / 2
                    trim.box(px, py, g + body, 0.8, 0.8, 3.0, ang)
            towers.append({"uv": [round(tu, 1), round(tv, 1)], "side_m": round(side_m, 1), "top_m": round(top, 1)})
            if len(towers) >= 3:
                break
    objs = [stone.object("cathedral_stone", col, "fam_heritage").name, roof.object("cathedral_roofs_spires", col, "roof").name,
            trim.object("cathedral_buttresses_pinnacles", col, "fam_heritage").name]
    return {"module": "cathedral", "objects": objs, "ground_ahd": round(g, 2), "length_m": round(ln, 1),
            "width_m": round(wd, 1), "nave_eave_m": round(eave, 1), "nave_ridge_m": round(ridge, 1),
            "aisle_m": round(aisle_top, 1), "transept": tr, "towers": towers,
            "note": "Massing measured from the LiDAR; plan proportions (nave 42% of the width) are assumed."}
