"""Trees from the 2019 LiDAR tree tops (reference/sites/spire/lidar/tree_points.csv): trunk + low-poly
crown sized from the measured height. Council significant-tree overlays are in council_spire.geojson."""
import math

import layout as L
import common as C


def build():
    col = C.collection("trees")
    trunk, crown = C.MeshBuf(), C.MeshBuf()
    n = 0
    for x, y, h, g in L.tree_points():
        if h < 3.0 or h > 40.0:
            continue
        r = max(1.2, 0.33 * h)
        zc = g + h - r
        trunk.box(x, y, g, 0.35, 0.35, max(0.5, zc - g))
        # octahedron-ish crown: 6 points round, top and bottom
        ring = [(x + r * math.cos(a), y + r * math.sin(a), zc) for a in [k * math.pi / 3 for k in range(6)]]
        verts = ring + [(x, y, g + h), (x, y, zc - 0.7 * r)]
        faces = [[i, (i + 1) % 6, 6] for i in range(6)] + [[(i + 1) % 6, i, 7] for i in range(6)]
        crown.add(verts, faces)
        n += 1
    objs = [trunk.object("tree_trunks", col, "column").name, crown.object("tree_crowns", col, "tree").name]
    return {"module": "trees", "objects": objs, "trees": n, "source": "2019 LiDAR vegetation (classes 3-5)"}
