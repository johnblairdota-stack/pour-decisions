"""Ground and river (step 5: clean). The 2019 LiDAR ground, smoothed (cars and noise gone, layout
lidar('ground_smooth')), as a 2 m mesh over layout.LIDAR_BOX; faces steeper than 40 deg (the Kangaroo
Point and HSW cliffs) get the rock material. Roads, kerbs and footpaths sit on it (streets.py)."""
import numpy as np

import layout as L
import common as C

STEP = 2
ROCK_SLOPE = 40.0


def build():
    col = C.collection("ground")
    g = L.lidar("ground_smooth")
    x0, y0, x1, y1 = L.LIDAR_BOX
    st = L.hsw_stage()
    if st:                                   # HSW 2017: the basement dig at the hotel footprint
        import prep_lidar as PL
        import shapes as S
        o = L.osm()
        ring = S.clean(o["line"](o["ways"][L.HSW["hotel_way"]]), 0.3)
        m, r0, c0 = PL.ring_mask(ring, L.LIDAR_BOX)
        g = g.copy()
        sub = g[r0:r0 + m.shape[0], c0:c0 + m.shape[1]]
        floor = float(sub[m].min()) - st["dig_depth_m"]
        sub[m] = floor
    H, W = g.shape
    rows, cols = np.arange(0, H, STEP), np.arange(0, W, STEP)
    sub = g[np.ix_(rows, cols)]
    R, Cn = sub.shape
    X, Y = np.meshgrid(x0 + cols + 0.5, y1 - rows - 0.5)
    verts = np.stack([X, Y, sub], -1).reshape(-1, 3)
    idx = np.arange(R * Cn).reshape(R, Cn)
    faces = np.stack([idx[:-1, :-1], idx[1:, :-1], idx[1:, 1:], idx[:-1, 1:]], -1).reshape(-1, 4)
    ob = C.mesh_fast("ground_lidar2019_smooth", verts, faces, col, "ground")
    ob.data.materials.append(C.material("rock"))
    dzx = np.abs(sub[:-1, 1:] - sub[:-1, :-1]) / STEP
    dzy = np.abs(sub[1:, :-1] - sub[:-1, :-1]) / STEP
    steep = (np.degrees(np.arctan(np.hypot(dzx, dzy))) > ROCK_SLOPE).ravel().astype("i4")
    # step 7f: grass where OSM has parks, gardens, lawns (and not too steep)
    import prep_lidar as PL
    mask = np.zeros(g.shape, bool)
    o = L.osm()
    grass_tags = {("leisure", "park"), ("leisure", "garden"), ("landuse", "grass"), ("leisure", "pitch"),
                  ("landuse", "religious"), ("natural", "scrub")}
    for w in o["ways"].values():
        t = w.get("tags", {})
        if not any((k, t.get(k)) in grass_tags for k, _ in grass_tags):
            continue
        ring = o["line"](w)
        if len(ring) < 3:
            continue
        m_, r0, c0 = PL.ring_mask(ring, L.LIDAR_BOX)
        if m_ is not None:
            mask[r0:r0 + m_.shape[0], c0:c0 + m_.shape[1]] |= m_
    cls = L.lidar("class")
    mask &= (cls != 3)                                       # no grass on roofs
    gm = mask[np.ix_(rows, cols)][:-1, :-1].ravel()
    ob.data.materials.append(C.material("grass"))
    mi = np.where(steep > 0, 1, np.where(gm, 2, 0)).astype("i4")
    ob.data.polygons.foreach_set("material_index", mi)
    ob.data.shade_smooth()
    w = C.mesh_object("river_water", [(x0, y0, L.RIVER_LEVEL_AHD), (x1, y0, L.RIVER_LEVEL_AHD),
                                       (x1, y1, L.RIVER_LEVEL_AHD), (x0, y1, L.RIVER_LEVEL_AHD)],
                      [(0, 1, 2, 3)], col, "water")
    return {"module": "ground", "objects": [ob.name, w.name], "box": L.LIDAR_BOX, "verts": int(len(verts)),
            "rock_faces": int(steep.sum()), "spire_ground_ahd": round(L.ground_z(0, 0), 2),
            "water_level_ahd": L.RIVER_LEVEL_AHD,
            "source": "2019 LiDAR ground, river pushed under the water, two 5 m box blurs"}
