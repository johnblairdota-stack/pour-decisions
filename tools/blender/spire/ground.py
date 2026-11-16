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
    hero = not st and not L.GAME_EXPORT      # the HSW render's ground fixes (not in the game's model)
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
    if hero:                                 # HSW round 2: tidal mud flats / pale spits go under the water
        sub = np.where((sub < 1.6) & (sub > L.RIVER_LEVEL_AHD - 2.0), np.minimum(sub, -1.2), sub)
        Xg, Yg = np.meshgrid(x0 + cols + 0.5, y1 - rows - 0.5)
        sub = np.where((Xg > 400) & (Xg < 600) & (Yg > -178) & (Yg < -112) & (sub < 10.0) &
                       ~((Yg < -150) & (Xg > 540)), np.minimum(sub, -1.2), sub)   # HSW r9: boat strip mid-river (p01)
        sub = np.where((Xg > 480) & (Xg < 620) & (Yg > -215) & (Yg < -140) & (sub < 2.6), np.minimum(sub, -1.2), sub)   # mudflat
        sub = np.where((Xg > 530) & (Xg < 620) & (Yg > -195) & (Yg < -140) & (sub < 8.0), np.minimum(sub, -1.2), sub)   # r9: islet (p01)
        for _ in range(3):                   # HSW r6: no lone spikes left standing in the river
            wet_ = sub < 0.0
            nb = (np.roll(wet_, 1, 0).astype(int) + np.roll(wet_, -1, 0) + np.roll(wet_, 1, 1) + np.roll(wet_, -1, 1))
            sub = np.where((sub < 4.0) & (nb >= 3), np.minimum(sub, -1.2), sub)
    R, Cn = sub.shape
    X, Y = np.meshgrid(x0 + cols + 0.5, y1 - rows - 0.5)
    verts = np.stack([X, Y, sub], -1).reshape(-1, 3)
    idx = np.arange(R * Cn).reshape(R, Cn)
    faces = np.stack([idx[:-1, :-1], idx[1:, :-1], idx[1:, 1:], idx[:-1, 1:]], -1).reshape(-1, 4)
    keep = None
    if hero:                                 # HSW round 1: hsw_hero builds a 1 m patch here
        px0, py0, px1, py1 = L.HSW["patch_box"]
        fc = verts[faces[:, 0]]
        keep = ~((fc[:, 0] >= px0 + 1) & (fc[:, 0] < px1 - 1) & (fc[:, 1] >= py0 + 1) & (fc[:, 1] < py1 - 1))
        faces = faces[keep]
    ob = C.mesh_fast("ground_lidar2019_smooth", verts, faces, col, "ground")
    if hero:
        ob.data.materials[0] = C.material_rgb("ground_r3", (0.24, 0.23, 0.20))   # HSW r3: no white city floor
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
    if hero:                                 # HSW round 2: the mangrove island / bank is dark mud under the trees
        ob.data.materials.append(C.material_rgb("mangrove_mud", (0.15, 0.13, 0.09)))   # r7: lighter mud
        mx0, my0, mx1, my1 = L.HSW["mangroves"]["box"]
        fc_ = np.stack([X[:-1, :-1], Y[:-1, :-1], sub[:-1, :-1]], -1).reshape(-1, 3)
        mud = (fc_[:, 0] > mx0) & (fc_[:, 0] < mx1) & (fc_[:, 1] > my0) & (fc_[:, 1] < my1) & (fc_[:, 2] < L.HSW["mangroves"]["z"][1] + 0.5)
        mi = np.where(mud & ~gm, 3, mi).astype("i4")
        hx, hy, hr = L.HSW["trees"]["centre_r"]                 # low riverside land near HSW: grass, not bare
        low = (np.hypot(fc_[:, 0] - hx, fc_[:, 1] - hy) < hr + 200) & (fc_[:, 2] < 5.0) & (fc_[:, 2] > 1.0) & (steep == 0) & ~mud
        mi = np.where(low & (mi == 0), 2, mi).astype("i4")
    if keep is not None:
        mi = mi[keep]
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
    far.data.materials[0] = C.material_rgb("far_land", (0.085, 0.11, 0.06), shader="canopy")   # r4: mottled green
    # far suburbs: low roofs scattered over the skirt so the city does not end in a plateau
    import random
    rnd = random.Random(7)
    fb = C.MeshBuf()
    fbt, fbg = C.MeshBuf(), C.MeshBuf()                               # r3: terracotta roofs and tree clumps
    for _ in range(30000 if L.GAME_EXPORT else 80000):                # r5: denser mixed suburb (game: the old 30k)
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
        if hero and d < 1500 and rnd.random() < 0.25:                          # HSW r8: varied mid-rise near in
            h_ = rnd.uniform(12, 40)
        kind = rnd.random() if hero else 1.0                          # (game: plain roofs only)
        if kind < 0.45:
            fbg.box(x, y, zb - 0.5, w_ * 1.4, l_ * 1.4, rnd.uniform(6, 12), rnd.uniform(0, 3.14))
        elif kind < 0.7:
            fbt.box(x, y, zb - 0.5, w_, l_, h_, rnd.uniform(0, 3.14))
        else:
            fb.box(x, y, zb - 0.5, w_, l_, h_, rnd.uniform(0, 3.14))
    obf = fb.object("far_suburbs", col, "ground")
    obf.data.materials[0] = C.material_rgb("far_suburbs", (0.33, 0.32, 0.30))
    obt = fbt.object("far_suburbs_terracotta", col, "ground") if hero else None
    if obt:
        obt.data.materials[0] = C.material_rgb("far_suburbs_tc", (0.32, 0.22, 0.17))   # HSW r9: desaturated
    obg = fbg.object("far_suburbs_trees", col, "ground") if hero else None
    if obg:
        obg.data.materials[0] = C.material_rgb("far_suburbs_trees", (0.05, 0.08, 0.035))
    E = 6000
    w = C.mesh_object("river_water", [(x0 - E, y0 - E, L.RIVER_LEVEL_AHD), (x1 + E, y0 - E, L.RIVER_LEVEL_AHD),
                                       (x1 + E, y1 + E, L.RIVER_LEVEL_AHD), (x0 - E, y1 + E, L.RIVER_LEVEL_AHD)],
                      [(0, 1, 2, 3)], col, "water")
    return {"module": "ground", "objects": [ob.name, w.name, far.name, obf.name], "box": L.LIDAR_BOX, "verts": int(len(verts)),
            "rock_faces": int(steep.sum()), "spire_ground_ahd": round(L.ground_z(0, 0), 2),
            "water_level_ahd": L.RIVER_LEVEL_AHD,
            "source": "2019 LiDAR ground, river pushed under the water, two 5 m box blurs"}
