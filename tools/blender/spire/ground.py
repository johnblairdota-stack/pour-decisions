"""DEM ground (2 m mesh, metres AHD) and the river water plane."""
import layout as L
import common as C

STEP = 2   # DEM samples per mesh vertex (DEM is 1 m)


def build():
    a, x0, y0, s = L.dem()
    col = C.collection("ground")
    sub = a[::STEP, ::STEP]
    rows, cols = sub.shape
    d = s * STEP
    verts = [(x0 + c * d, y0 - r * d, float(sub[r, c])) for r in range(rows) for c in range(cols)]
    faces = [(r * cols + c, (r + 1) * cols + c, (r + 1) * cols + c + 1, r * cols + c + 1)
             for r in range(rows - 1) for c in range(cols - 1)]
    g = C.mesh_object("ground_dem", verts, faces, col, "ground")
    for p in g.data.polygons:
        p.use_smooth = True
    h = L.DATA_HALF
    w = C.mesh_object("river_water", [(-h, -h, L.RIVER_LEVEL_AHD), (h, -h, L.RIVER_LEVEL_AHD),
                                       (h, h, L.RIVER_LEVEL_AHD), (-h, h, L.RIVER_LEVEL_AHD)],
                      [(0, 1, 2, 3)], col, "water")
    wet = int((a < L.RIVER_LEVEL_AHD).sum())
    return {"module": "ground", "objects": [g.name, w.name], "mesh_step_m": d, "verts": len(verts),
            "z_min_ahd": round(float(a.min()), 2), "z_max_ahd": round(float(a.max()), 2),
            "spire_ground_ahd": round(L.ground_z(0, 0), 2), "water_level_ahd": L.RIVER_LEVEL_AHD,
            "dem_cells_under_water_level": wet, "source": "reference/sites/spire/dem_1m.f32.gz"}
