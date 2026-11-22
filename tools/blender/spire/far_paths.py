"""Footpaths, walkways, bikeways, steps, crossings and paved squares outside the Spire LiDAR box, from OSM
(reference/sites/spire/roads/paths.json, tools/sites/paths_wide.py). Built straight after far_roads, on its ground.

Kerbside footpaths and traffic islands sit a kerb above far_roads' carriageways and have a kerb face down each side;
park paths, bikeways and steps lie on the ground; crossings are two painted lines over the road; squares and malls
are paved slabs. streets.py covers the same things inside the box.
"""
import json
import math
import os

import numpy as np

import layout as L
import common as C
import far_roads as FR

PATHS = os.path.join(L.REF, "roads", "paths.json")
#        lift over the ground, kerb skirt (m), colour
STYLE = {"sidewalk": (0.55, 0.7, "path_paving"), "island": (0.55, 0.7, "path_paving"),
         "pedestrian": (0.5, 0.7, "path_plaza"), "footway": (0.3, 0.0, "path_park"),
         "cycleway": (0.32, 0.0, "path_bike"), "steps": (0.34, 0.0, "path_steps")}
COL = {"path_paving": (0.3, 0.265, 0.235), "path_plaza": (0.36, 0.31, 0.27), "path_park": (0.42, 0.39, 0.34),
       "path_bike": (0.17, 0.17, 0.175), "path_steps": (0.42, 0.41, 0.39), "path_paint": (0.85, 0.85, 0.82),
       "path_pavers": (0.42, 0.3, 0.23), "path_hedge": (0.035, 0.085, 0.025), "path_rail": (0.45, 0.47, 0.48),
       "path_asphalt": (0.085, 0.085, 0.09)}
CROSSING_LIFT = 0.49


def strip(buf, pts, wd, G, lift, skirt=0.0, off=0.0):
    """Ribbon wd wide along pts (centre shifted off m to the left), level across, on the highest ground under it."""
    mid = C.offset_line(pts, off) if off else pts
    left, right = C.offset_line(mid, wd / 2), C.offset_line(mid, -wd / 2)
    a, b, c = np.array(left), np.array(mid), np.array(right)
    z = np.maximum.reduce([G.z(a[:, 0], a[:, 1]), G.z(b[:, 0], b[:, 1]), G.z(c[:, 0], c[:, 1])]) + lift
    n = len(pts)
    verts = [(left[i][0], left[i][1], float(z[i])) for i in range(n)] + [(right[i][0], right[i][1], float(z[i])) for i in range(n)]
    faces = [[i, n + i, n + i + 1, i + 1] for i in range(n - 1)]
    if skirt:
        verts += [(left[i][0], left[i][1], float(z[i]) - skirt) for i in range(n)] + [(right[i][0], right[i][1], float(z[i]) - skirt) for i in range(n)]
        faces += [[2 * n + i, i, i + 1, 2 * n + i + 1] for i in range(n - 1)] + [[n + i, 3 * n + i, 3 * n + i + 1, n + i + 1] for i in range(n - 1)]
    buf.add(verts, faces)


def box(buf, o, u, n, u0, u1, n0, n1, z0, z1):
    """Box in a local frame: origin o, unit axes u (along) and n (across)."""
    c = [(o[0] + u[0] * a + n[0] * b, o[1] + u[1] * a + n[1] * b) for a, b in ((u0, n0), (u1, n0), (u1, n1), (u0, n1))]
    buf.add([(x, y, z0) for x, y in c] + [(x, y, z1) for x, y in c],
            [[0, 3, 2, 1], [4, 5, 6, 7]] + [[i, (i + 1) % 4, 4 + (i + 1) % 4, 4 + i] for i in range(4)])


def north_quay_terrace(bufs):
    """The raised paved terrace along North Quay below Tank St (photo 'North Quay below Queen's Wharf 2024'):
    pink-brown pavers from the building to a steel and glass rail, a clipped hedge below it, then the kerbside
    footpath (OSM) and the road. Sizes read off the photo; the frame is the kerbside footpath's line."""
    o, u, n = (-1108.8, -673.0), (0.829, -0.559), (0.559, 0.829)
    top = 14.35
    box(bufs["path_pavers"], o, u, n, -18.0, 46.0, 5.0, 24.0, 7.0, top)
    box(bufs["path_hedge"], o, u, n, -18.0, 46.0, 1.7, 5.0, 7.0, top - 0.75)
    box(bufs["path_rail"], o, u, n, -18.0, 46.0, 5.0, 5.06, top + 1.02, top + 1.08)
    k = -18.0
    while k <= 46.0:
        box(bufs["path_rail"], o, u, n, k, k + 0.05, 5.0, 5.06, top, top + 1.02)
        k += 1.6
    for k in (2.0, 20.0):                                                    # stone bench blocks by the building
        box(bufs["path_steps"], o, u, n, k, k + 3.0, 9.6, 10.2, top, top + 0.45)


def treasury_corner(bufs, ways, G):
    """William St beside the Treasury (photo 'Treasury Casino, William St and motorcycle park'): a paved footpath
    along the river side of William St with a kerb, and the asphalt of the Queens Wharf Rd parking strip below it,
    where OSM has no ground road and the model showed bare aerial."""
    c = (-790.0, -975.0)
    w = next((w for w in ways if w["name"] == "William Street" and w["cls"] == "busway"
              and min(math.dist(p, c) for p in w["pts"]) < 25), None)
    if not w:
        return 0
    pts = [tuple(p) for p in w["pts"] if math.dist(p, c) < 70]
    if len(pts) < 3:
        return 0
    i = min(range(len(pts)), key=lambda k: math.dist(pts[k], c))
    a, b = pts[max(i - 1, 0)], pts[min(i + 1, len(pts) - 1)]
    side = 1.0 if (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0]) > 0 else -1.0
    strip(bufs["path_paving"], pts, 7.0, G, 0.55, 0.7, off=side * 7.5)
    strip(bufs["path_asphalt"], pts, 16.0, G, 0.4, 0.0, off=side * 19.0)
    return 1


def runs(pts, W):
    """Stretches outside the LiDAR box and off the water."""
    out, cur = [], []
    for p in pts:
        if FR.in_box(p[0], p[1]) or W.at(p[0], p[1]):
            if len(cur) > 1:
                out.append(cur)
            cur = []
        else:
            cur.append(p)
    if len(cur) > 1:
        out.append(cur)
    return out


def build():
    if L.GAME_EXPORT or getattr(L, "ACTIVE_STAGE", None) or not os.path.exists(PATHS) or FR.GROUND is None:
        return {"module": "far_paths", "objects": [], "note": "skipped (game export, stage build or no data)"}
    from mathutils import Vector
    from mathutils.geometry import tessellate_polygon
    d = json.load(open(PATHS))
    G, W = FR.GROUND, FR.Water()
    col = C.collection("far_paths")
    bufs = {k: C.MeshBuf() for k in COL}
    n = {}
    for w in d["ways"]:
        pts = [tuple(p) for p in w["pts"]]
        for run in runs(pts, W):
            if w["cls"] == "crossing":
                for off in (-w["width"] / 2, w["width"] / 2):
                    strip(bufs["path_paint"], run, 0.3, G, CROSSING_LIFT, off=off)
            else:
                lift, skirt, key = STYLE[w["cls"]]
                strip(bufs[key], run, w["width"], G, lift, skirt)
            n[w["cls"]] = n.get(w["cls"], 0.0) + 4.0 * (len(run) - 1)
    squares = 0
    for a in d["areas"]:
        ring = a["ring"]
        cx, cy = sum(p[0] for p in ring) / len(ring), sum(p[1] for p in ring) / len(ring)
        if FR.in_box(cx, cy) or W.at(cx, cy):
            continue
        z = float(np.percentile(G.z([p[0] for p in ring], [p[1] for p in ring]), 80)) + 0.5
        m = len(ring)
        verts = [(p[0], p[1], z) for p in ring] + [(p[0], p[1], z - 0.9) for p in ring]
        faces = [list(t) for t in tessellate_polygon([[Vector((p[0], p[1], 0.0)) for p in ring]])]
        faces += [[i, (i + 1) % m, m + (i + 1) % m, m + i] for i in range(m)]
        bufs["path_plaza"].add(verts, faces)
        squares += 1
    north_quay_terrace(bufs)
    treasury_corner(bufs, json.load(open(FR.ROADS))["ways"], G)
    objs = []
    for k, buf in bufs.items():
        ob = buf.object("far_" + k, col, "road")
        if ob:
            ob.data.materials[0] = C.material_rgb("far_" + k, COL[k])
            objs.append(ob.name)
    return {"module": "far_paths", "objects": objs, "km": {k: round(v / 1000, 1) for k, v in n.items()},
            "paved_squares": squares, "source": "OSM (osm_all): footway, cycleway, pedestrian, steps"}
