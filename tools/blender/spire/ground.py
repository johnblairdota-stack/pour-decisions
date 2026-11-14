"""Ground and river. 2019 LiDAR bare ground over layout.LIDAR_BOX (2 m mesh; 1 m round Howard Smith
Wharves and the Kangaroo Point cliffs), river bed from the old DEM mix, and a water surface."""
import numpy as np

import layout as L
import common as C

STEP = 2
FINE_BOX = (350, -220, 820, 170)      # local x0, y0, x1, y1 at 1 m: HSW strip, its cliffs, the bridge's north pier


def grid_mesh(name, col, g, x0, y1, step, rows, cols, key):
    sub = g[rows, :][:, cols]
    R, Cn = sub.shape
    xs = x0 + cols + 0.5
    ys = y1 - rows - 0.5
    X, Y = np.meshgrid(xs, ys)
    verts = np.stack([X, Y, sub], -1).reshape(-1, 3)
    idx = np.arange(R * Cn).reshape(R, Cn)
    a, b, c, d = idx[:-1, :-1], idx[1:, :-1], idx[1:, 1:], idx[:-1, 1:]
    faces = np.stack([a, b, c, d], -1).reshape(-1, 4)
    ob = C.mesh_fast(name, verts, faces, col, key)
    return ob, len(verts)


def build():
    col = C.collection("ground")
    g = L.lidar("ground").copy()
    # cells with no LiDAR return at all are water: push the filled river bed under the water surface
    wet = (L.lidar("class") == 0) & (g < 3.0)
    g[wet] = np.minimum(g[wet], L.RIVER_LEVEL_AHD - 2.0)
    x0, y0, x1, y1 = L.LIDAR_BOX
    H, W = g.shape
    fx0, fy0, fx1, fy1 = FINE_BOX
    # coarse everywhere, then a 1 m patch (the coarse mesh under it is left; the patch sits 2 cm higher)
    ob, n1 = grid_mesh("ground_lidar2019_2m", col, g, x0, y1, STEP, np.arange(0, H, STEP), np.arange(0, W, STEP), "ground")
    gf = g + 0.02
    rows = np.arange(int(y1 - fy1), int(y1 - fy0))
    cols = np.arange(int(fx0 - x0), int(fx1 - x0))
    ob2, n2 = grid_mesh("ground_lidar2019_1m_hsw_cliffs", col, gf, x0, y1, 1, rows, cols, "ground")
    for o in (ob, ob2):
        o.data.shade_smooth()
    w = C.mesh_object("river_water", [(x0, y0, L.RIVER_LEVEL_AHD), (x1, y0, L.RIVER_LEVEL_AHD),
                                       (x1, y1, L.RIVER_LEVEL_AHD), (x0, y1, L.RIVER_LEVEL_AHD)],
                      [(0, 1, 2, 3)], col, "water")
    return {"module": "ground", "objects": [ob.name, ob2.name, w.name], "box": L.LIDAR_BOX,
            "verts": n1 + n2, "z_min_ahd": round(float(g.min()), 2), "z_max_ahd": round(float(g.max()), 2),
            "spire_ground_ahd": round(L.ground_z(0, 0), 2), "water_level_ahd": L.RIVER_LEVEL_AHD,
            "source": "2019 LiDAR ground (class 2 mean), gaps and river bed from the QldDem default mix"}
