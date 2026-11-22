"""Footpaths, walkways, bikeways, steps, crossings and paved squares outside the Spire LiDAR box, from OSM
(reference/sites/spire/roads/paths.json, tools/sites/paths_wide.py). Built straight after far_roads, on its ground.

Kerbside footpaths and traffic islands sit a kerb above far_roads' carriageways and have a kerb face down each side;
park paths, bikeways and steps lie on the ground; crossings are two painted lines over the road; squares and malls
are paved slabs. streets.py covers the same things inside the box.
"""
import json
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
COL = {"path_paving": (0.36, 0.33, 0.3), "path_plaza": (0.4, 0.36, 0.32), "path_park": (0.45, 0.42, 0.37),
       "path_bike": (0.17, 0.17, 0.175), "path_steps": (0.42, 0.41, 0.39), "path_paint": (0.85, 0.85, 0.82)}
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
    objs = []
    for k, buf in bufs.items():
        ob = buf.object("far_" + k, col, "road")
        if ob:
            ob.data.materials[0] = C.material_rgb("far_" + k, COL[k])
            objs.append(ob.name)
    return {"module": "far_paths", "objects": objs, "km": {k: round(v / 1000, 1) for k, v in n.items()},
            "paved_squares": squares, "source": "OSM (osm_all): footway, cycleway, pedestrian, steps"}
