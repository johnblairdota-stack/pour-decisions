"""Hero landmarks from the 2019 LiDAR points.

- Story Bridge: every non-ground LiDAR point over the bridge/water columns of the bridge_hsw box, as
  1 m voxels (deck, cantilever truss, piers, approach spans at their true heights).
- St John's Cathedral: 0.5 m top surface from its voxel box (nave, towers, buttresses, roof), solid to
  the ground."""
import numpy as np

import layout as L
import common as C
import heightfield as HF

CATHEDRAL_WAY = 26384715


def mga_to_local(e, n):
    return e - L.ORIGIN_MGA56[0], n - L.ORIGIN_MGA56[1]


def build():
    col = C.collection("landmarks")
    objs, meta = [], {}
    cls = L.lidar("class")
    gnd = L.lidar("ground")
    x0, y0, x1, y1 = L.LIDAR_BOX
    # ---------------------------------------------------------------- Story Bridge
    v, b = L.lidar_voxels("bridge_hsw")
    E0, N0, Z0, s = b[0], b[1], b[2], b[6]
    X = E0 + (v[:, 0] + 0.5) * s - L.ORIGIN_MGA56[0]
    Y = N0 + (v[:, 1] + 0.5) * s - L.ORIGIN_MGA56[1]
    Z = Z0 + (v[:, 2] + 0.5) * s
    r = np.clip((y1 - Y).astype(int), 0, cls.shape[0] - 1)
    c = np.clip((X - x0).astype(int), 0, cls.shape[1] - 1)
    col_cls = cls[r, c]
    keep = ((col_cls == 4) | (col_cls == 0)) & (Z > gnd[r, c] + 1.0)
    ox, oy = mga_to_local(E0, N0)
    ob, nvox, nf = HF.voxel_mesh("story_bridge_lidar_voxels", col, v[keep], (ox, oy, Z0), s, "bridge")
    objs.append(ob.name)
    meta["story_bridge"] = {"voxels": nvox, "faces": nf, "voxel_m": s, "deck_top_ahd_max": round(float(Z[keep].max()), 1),
                            "rule": "bridge_hsw voxels whose 1 m column top is class 4 (bridge, 17) or empty (water)"}
    # ---------------------------------------------------------------- St John's Cathedral
    v, b = L.lidar_voxels("cathedral")
    E0, N0, Z0, s = b[0], b[1], b[2], b[6]
    nx, ny = int(round((b[3] - E0) / s)), int(round((b[4] - N0) / s))
    top = np.full((ny, nx), np.nan, "f4")
    zz = Z0 + (v[:, 2] + 1) * s
    rows = ny - 1 - v[:, 1]                      # north -> south
    np.fmax.at(top, (rows, v[:, 0]), zz)
    bx0, by1 = mga_to_local(E0, N0 + ny * s)
    o = L.osm()
    ring = o["line"](o["ways"][CATHEDRAL_WAY])
    cx = np.mean([p[0] for p in ring])
    cy = np.mean([p[1] for p in ring])
    ring = [(cx + (x - cx) * 1.15, cy + (y - cy) * 1.15) for x, y in ring]
    XX, YY = np.meshgrid(bx0 + (np.arange(nx) + 0.5) * s, by1 - (np.arange(ny) + 0.5) * s)
    inside = np.zeros(XX.shape, bool)
    for i in range(len(ring)):
        (xa, ya), (xb, yb) = ring[i], ring[(i + 1) % len(ring)]
        if ya != yb:
            inside ^= ((ya > YY) != (yb > YY)) & (XX < (xb - xa) * (YY - ya) / (yb - ya) + xa)
    rr = np.clip((y1 - YY).astype(int), 0, gnd.shape[0] - 1)
    cc = np.clip((XX - x0).astype(int), 0, gnd.shape[1] - 1)
    g = gnd[rr, cc]
    mask = inside & np.isfinite(top) & (top > g + 2.0)
    ob, roofs, walls = HF.heightfield("st_johns_cathedral_lidar_0p5m", col, np.nan_to_num(top), g, mask,
                                      bx0, by1, s, "building")
    objs.append(ob.name)
    meta["cathedral"] = {"cells_0p5m": roofs, "wall_quads": walls, "top_ahd": round(float(np.nanmax(top[mask])), 1),
                         "ground_ahd": round(float(np.median(g[mask])), 1)}
    return {"module": "landmarks", "objects": objs, **meta,
            "note": "Built straight from the 2019 LiDAR. Walls below the eaves and the truss's far faces are where "
                    "the scanner saw them; gaps are real gaps in the point cloud. Photos still needed for windows, "
                    "tracery and colours."}
