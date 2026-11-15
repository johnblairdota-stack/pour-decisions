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
    # step 7j: far land - a skirt from the LiDAR edge out 6 km (no floating edge, no void under the sky)
    per = ([idx[0, j] for j in range(Cn)] + [idx[i, Cn - 1] for i in range(1, R)] +
           [idx[R - 1, j] for j in range(Cn - 2, -1, -1)] + [idx[i, 0] for i in range(R - 2, 0, -1)])
    per = per[::4]
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    fv, ff = [], []
    rings = ((0, None), (250, 0.5), (1200, 1.0), (6000, 1.0))
    FAR_Z = 8.0
    for d, k in rings:
        for pi in per:
            x, y, z = verts[pi]
            ux, uy = x - cx, y - cy
            s = max(abs(ux) / ((x1 - x0) / 2), abs(uy) / ((y1 - y0) / 2)) or 1.0
            ex, ey = cx + ux / s, cy + uy / s                       # point on the box edge
            l = (ux * ux + uy * uy) ** 0.5 or 1.0
            zz = z - 0.05 if k is None else z + (FAR_Z - z) * k
            fv.append((ex + ux / l * d, ey + uy / l * d, zz))
    n = len(per)
    for r in range(len(rings) - 1):
        for i in range(n):
            a, b = r * n + i, r * n + (i + 1) % n
            ff.append((a, b, b + n, a + n))
    far = C.mesh_object("far_land", fv, ff, col, "ground")
    far.data.materials[0] = C.material_rgb("far_land", (0.10, 0.11, 0.105))
    # far suburbs: low roofs scattered over the skirt so the city does not end in a plateau
    import random
    rnd = random.Random(7)
    fb = C.MeshBuf()
    for _ in range(30000):
        x = rnd.uniform(x0 - 3000, x1 + 3000)
        y = rnd.uniform(y0 - 3000, y1 + 3000)
        if x0 - 20 < x < x1 + 20 and y0 - 20 < y < y1 + 20:
            continue
        d = max(x0 - x, x - x1, y0 - y, y - y1)
        zb = FAR_Z - 1.5 if d > 450 else None
        if zb is None:
            continue                                                    # keep the near skirt clear (it slopes)
        w_, l_ = rnd.uniform(7, 16), rnd.uniform(8, 20)
        h_ = rnd.choice((4, 5, 5, 6, 7, 9)) if rnd.random() > 0.01 else rnd.uniform(15, 45)
        fb.box(x, y, zb - 0.5, w_, l_, h_, rnd.uniform(0, 3.14))
    obf = fb.object("far_suburbs", col, "ground")
    obf.data.materials[0] = C.material_rgb("far_suburbs", (0.30, 0.29, 0.27))
    E = 6000
    w = C.mesh_object("river_water", [(x0 - E, y0 - E, L.RIVER_LEVEL_AHD), (x1 + E, y0 - E, L.RIVER_LEVEL_AHD),
                                       (x1 + E, y1 + E, L.RIVER_LEVEL_AHD), (x0 - E, y1 + E, L.RIVER_LEVEL_AHD)],
                      [(0, 1, 2, 3)], col, "water")
    return {"module": "ground", "objects": [ob.name, w.name, far.name, obf.name], "box": L.LIDAR_BOX, "verts": int(len(verts)),
            "rock_faces": int(steep.sum()), "spire_ground_ahd": round(L.ground_z(0, 0), 2),
            "water_level_ahd": L.RIVER_LEVEL_AHD,
            "source": "2019 LiDAR ground, river pushed under the water, two 5 m box blurs"}
