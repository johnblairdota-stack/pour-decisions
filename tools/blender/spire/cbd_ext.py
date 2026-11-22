"""CBD extension (17 Nov 2026): the city south-west of the model square, so Brisbane Skytower, 1 William St
and the Queen's Wharf site stand in the master scene at their real LiDAR heights on their real ground.

Data: reference/sites/spire/ext/ (tools/sites/clean_ext.py, from the per-tower packs in reference/sites/<id>/):
2019 LiDAR ground + building shapes (same rules as buildings_clean.json), LiDAR tree tops, 2022 aerial.

- ground: 2 m mesh outside layout.LIDAR_BOX (ground.py covers inside it), draped with the 2022 aerial
- far land / far suburbs: cut away where the real ground now is
- buildings: buildings.build() over the extension records (same recipes, looks.py), named looks for the
  two towers from the Commons photos (research-16nov/sheets)
- trees: simple trunks + crowns from the LiDAR tree tops outside LIDAR_BOX

Queen's Wharf's finished towers are not in OSM and the 2019 LiDAR shows the basement dig: the site shows as
the data does (the 2022 aerial over the dig). Built last, after area_hero; touches nothing inside the box.
"""
import csv
import gzip
import json
import math
import os

import numpy as np

import layout as L
import common as C

EXT = os.path.join(L.REF, "ext")
RIVER = os.path.join(L.REF, "river")
GRIDS = {}       # built ground height grids (for far_roads.py): name -> (x of col 0, y of row 0, step, z[, cover])
STEP = 2

TOWER_LOOKS = {   # from the Commons photo sheets (visuals/sites/research-16nov/sheets/*_photos.jpg)
    683336940: {"name": "Brisbane Skytower", "src": "Commons photos 2016-2019", "shader": "glass",
                "wall": (0.11, 0.15, 0.24), "glass": (0.07, 0.11, 0.21), "roof": (0.16, 0.17, 0.20),
                "pattern": "strip", "band": (0.15, 0.19, 0.28), "spandrel": (0.06, 0.08, 0.14)},
    521115344: {"name": "One William Street", "src": "Commons photos 2015-2019", "shader": "glass",
                "wall": (0.36, 0.29, 0.22), "glass": (0.16, 0.20, 0.25), "roof": (0.22, 0.23, 0.25),
                "pattern": "fins", "spandrel": (0.30, 0.24, 0.18)},
}
TOWER_LOOKS[1104813702] = TOWER_LOOKS[521115344]       # 1 William's west crescent (its own OSM outline)


def meta():
    return json.load(open(os.path.join(EXT, "ext.json")))


def ground_grid():
    m = meta()
    H, W = m["rows"], m["cols"]
    g = np.frombuffer(gzip.open(os.path.join(EXT, "ground_1m.f32.gz")).read(), "<f4").reshape(H, W)
    cov = np.frombuffer(gzip.open(os.path.join(EXT, "cover_1m.u8.gz")).read(), "u1").reshape(H, W)
    return m, g, cov


def in_lidar_box(x, y, pad=0.0):
    x0, y0, x1, y1 = L.LIDAR_BOX
    return (x > x0 + pad) & (x < x1 - pad) & (y > y0 + pad) & (y < y1 - pad)


def aerial_material(m, name="cbd_ext_aerial"):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat["look_done"] = True                       # preview.setup_morning leaves it alone
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bs = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bs.inputs["Roughness"].default_value = 0.9
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(os.path.join(EXT, m["aerial"]["file"]), check_existing=True)
    tex.extension = "EXTEND"
    uv = nt.nodes.new("ShaderNodeUVMap")
    uv.uv_map = "aerial"
    nt.links.new(uv.outputs["UV"], tex.inputs["Vector"])
    hsv = nt.nodes.new("ShaderNodeHueSaturation")       # the aerial is a lit photo: tone it into the scene's
    hsv.inputs["Saturation"].default_value = 0.85        # light (the sun already shades the mesh)
    hsv.inputs["Value"].default_value = 0.8
    nt.links.new(tex.outputs["Color"], hsv.inputs["Color"])
    nt.links.new(hsv.outputs["Color"], bs.inputs["Base Color"])
    nt.links.new(bs.outputs["BSDF"], out.inputs["Surface"])
    mat.diffuse_color = (0.35, 0.34, 0.31, 1)
    return mat


def build_ground(col):
    m, g, cov = ground_grid()
    bx0, by0, bx1, by1 = m["box_local"]
    H, W = g.shape
    rows, cols = np.arange(0, H, STEP), np.arange(0, W, STEP)
    sub = g[np.ix_(rows, cols)].astype("f8")
    cs = cov[np.ix_(rows, cols)] > 0
    X, Y = np.meshgrid(bx0 + cols + 0.5, by1 - rows - 0.5)
    sub = np.where((sub < 1.6) & (sub > L.RIVER_LEVEL_AHD - 2.0), np.minimum(sub, -1.2), sub)   # as ground.py: flats go under
    if os.path.exists(os.path.join(RIVER, "river.json")):
        # the traced river is the authority on water: moored boats, pontoons and gap-fill artefacts in the
        # LiDAR ground stood in the river as land masses (John, 17 Nov)
        rm, water, _ = river_data()
        wd = L.box_blur(water.astype("f4"), 3) > 1e-3                    # 6 m out from the traced water
        wr = np.clip(((rm["box_local"][3] - Y) / rm["step_m"]).astype(int), 0, water.shape[0] - 1)
        wc = np.clip(((X - rm["box_local"][0]) / rm["step_m"]).astype(int), 0, water.shape[1] - 1)
        sub = np.where((water[wr, wc] > 0) | (wd[wr, wc] & (sub < 4.5)), -2.0, sub)
    GRIDS["ext"] = (bx0 + 0.5, by1 - 0.5, STEP, sub, cs)
    R, Cn = sub.shape
    verts = np.stack([X, Y, sub], -1).reshape(-1, 3)
    idx = np.arange(R * Cn).reshape(R, Cn)
    faces = np.stack([idx[1:, :-1], idx[1:, 1:], idx[:-1, 1:], idx[:-1, :-1]], -1).reshape(-1, 4)
    fx = (X[:-1, :-1] + STEP / 2).ravel()
    fy = (Y[:-1, :-1] - STEP / 2).ravel()
    ok = (cs[:-1, :-1] & cs[1:, 1:] & cs[1:, :-1] & cs[:-1, 1:]).ravel() & ~in_lidar_box(fx, fy)
    faces = faces[ok]
    ob = C.mesh_fast("cbd_ext_ground", verts, faces, col, "ground")
    # UVs: the aerial is north up over the same box
    lay = ob.data.uv_layers.new(name="aerial")
    li = np.empty(len(ob.data.loops), "i4")
    ob.data.loops.foreach_get("vertex_index", li)
    vx, vy = verts[li, 0], verts[li, 1]
    uv = np.stack([(vx - bx0) / (bx1 - bx0), (vy - by0) / (by1 - by0)], -1).astype("f4")
    lay.data.foreach_set("uv", uv.ravel())
    ob.data.materials[0] = aerial_material(m)
    ob.data.shade_smooth()
    return ob, (bx0, by0, bx1, by1), int(len(faces))


def cut_far(box):
    """Remove far_land / far_suburbs* faces over the extension ground (outside LIDAR_BOX, where a pack has data)."""
    import bmesh
    bx0, by0, bx1, by1 = box
    m, _, cov = ground_grid()

    def covered(x, y, pad=0):
        if not (bx0 - pad < x < bx1 + pad and by0 - pad < y < by1 + pad):
            return False
        c = min(max(int(x - bx0), 0), cov.shape[1] - 1)
        r = min(max(int(by1 - y), 0), cov.shape[0] - 1)
        return bool(cov[r, c]) and not in_lidar_box(x, y)
    removed = {}
    for name in ("far_land", "far_suburbs", "far_suburbs_terracotta", "far_suburbs_trees"):
        ob = bpy.data.objects.get(name)
        if ob is None:
            continue
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        if name == "far_land":                      # big skirt quads: split them on the box edges first
            for co, no in (((bx0, 0, 0), (1, 0, 0)), ((bx1, 0, 0), (1, 0, 0)), ((0, by0, 0), (0, 1, 0)), ((0, by1, 0), (0, 1, 0))):
                geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
                bmesh.ops.bisect_plane(bm, geom=geom, plane_co=co, plane_no=no)
        kill = []
        for f in bm.faces:
            c = f.calc_center_median()
            if covered(c.x, c.y):
                kill.append(f)
        bmesh.ops.delete(bm, geom=kill, context="FACES")
        bm.to_mesh(ob.data)
        bm.free()
        removed[name] = len(kill)
    return removed


def build_buildings(recs=None, zone=None, collection="cbd_ext", suffix="_ext"):
    import buildings as B
    import looks as LK
    if recs is None:
        recs = json.load(open(os.path.join(EXT, "buildings_ext.json")))["buildings"]
    o = L.osm()
    added = []
    for r in recs:                                  # tags for look_for (the Spire OSM crop does not hold these ways)
        if r["osm"] not in o["ways"]:
            o["ways"][r["osm"]] = {"tags": r.get("tags", {}), "nodes": [], "_ext": True}
            added.append(r["osm"])
    for k, v in TOWER_LOOKS.items():
        LK.LOOKS.setdefault(k, v)
    keep = B.records
    B.records = lambda: recs
    if collection == "cbd_ext":                     # the same per-building mixes as city_wide (critic round 1:
        import city_wide as CW                      # the skyline read as a wall of identical white towers)
        mixed, _ = CW.assign_looks(recs)
        plain = B.look_for
        B.look_for = lambda osm, tags, h, family: mixed.get(osm) or plain(osm, tags, h, family)
    try:
        res = B.build(zone=zone or tuple(meta()["box_local"]), collection=collection, only={r["osm"] for r in recs}, suffix=suffix)
    finally:
        B.records = keep
        if collection == "cbd_ext":
            B.look_for = plain
        for k in added:
            o["ways"].pop(k, None)
    return res, len(recs)


def build_trees(col):
    import trees as T
    import far_roads as FR
    import southbank as SB
    trunks, crowns, palms = C.MeshBuf(), C.MeshBuf(), C.MeshBuf()
    n = 0
    with open(os.path.join(EXT, "tree_points_ext.csv"), encoding="utf-8") as f:
        for r in csv.DictReader(f):
            x, y, h, g = float(r["x_local"]), float(r["y_local"]), float(r["height_m"]), float(r["ground_ahd"])
            if FR.on_road(x, y) or h < 3.0 or h > 40.0:
                continue
            if SB.in_zone(x, y):                          # South Bank plants its own (southbank.py)
                continue
            s = T.species(x, y, h)
            if s == "palm":
                T.trunk(trunks, x, y, g, 0.2, h - 1.0, 0)
                for k in range(6):
                    a = 2 * math.pi * k / 6
                    palms.beam((x, y, g + h - 1.2), (x + 3.0 * math.cos(a), y + 3.0 * math.sin(a), g + h - 2.6), 0.5, 0.12)
            else:
                rr = (0.42 if s == "fig" else 0.3) * h
                if FR.over_deck(x, y, rr * 1.25):
                    continue
                T.trunk(trunks, x, y, g, 0.25, h * 0.55, 0)
                T.blob(crowns, x, y, g + h * 0.5, rr * 1.2, h * 0.34)   # full crown down to near the ground (critics: lollipops)
                for k2 in range(4):                           # two side lobes: a ragged clump, not a ball (critic round 6)
                    a2 = (x * 12.9898 + y * 78.233 + k2 * 2.4) % 6.2832
                    T.blob(crowns, x + math.cos(a2) * rr * 0.8, y + math.sin(a2) * rr * 0.8, g + h * (0.34 + 0.07 * k2), rr * (0.55 + 0.12 * k2), h * 0.24)
            n += 1
    objs = []
    for buf, name, key, rgb in ((trunks, "cbd_ext_tree_trunks", "bark", (0.11, 0.095, 0.08)),
                                (crowns, "cbd_ext_tree_crowns", "tree", (0.06, 0.14, 0.045)),
                                (palms, "cbd_ext_palm_fronds", "palm", (0.06, 0.12, 0.04))):
        ob = buf.object(name, col, key)
        if ob:
            mname = {"bark": "tree_trunks", "tree": "tree_crowns_far", "palm": "palm_fronds_far"}[key]
            ob.data.materials[0] = C.material_rgb(mname, rgb)
            if key in ("tree", "palm"):
                ob.data.materials[0]["shader"] = "canopy"
            for p in ob.data.polygons:
                p.use_smooth = True
            objs.append(ob.name)
    return objs, n


# ---------------------------------------------------------------- far ground with the real river (17 Nov)
FAR_STEP = 6.0
FAR_Z = 8.0


def river_data():
    m = json.load(open(os.path.join(RIVER, "river.json")))
    H, W = m["rows"], m["cols"]
    water = np.frombuffer(gzip.open(os.path.join(RIVER, "water_2m.u8.gz")).read(), "u1").reshape(H, W)
    g8 = m["ground_8m"]
    gnd = np.frombuffer(gzip.open(os.path.join(RIVER, "ground_wide_8m.f32.gz")).read(), "<f4").reshape(g8["rows"], g8["cols"])
    return m, water, gnd


def build_far(col):
    """Real ground + the traced river over the wide aerials' box, outside LIDAR_BOX and the CBD extension:
    replaces the far_land skirt there (so the river no longer stops at the LiDAR edge)."""
    import bmesh
    m, water, gnd = river_data()
    x0, y0, x1, y1 = m["box_local"]
    st = m["step_m"]
    k = int(round(FAR_STEP / st))
    xs = np.arange(x0, x1 + 0.01, FAR_STEP)
    ys = np.arange(y1, y0 - 0.01, -FAR_STEP)
    X, Y = np.meshgrid(xs, ys)
    # ground: bilinear from the 8 m grid, NaN (no data) -> FAR_Z
    gs = 2 * st * 2                                                    # 8 m
    fx = np.clip((X - x0) / gs - 0.5, 0, gnd.shape[1] - 1.001)
    fy = np.clip((y1 - Y) / gs - 0.5, 0, gnd.shape[0] - 1.001)
    i0, j0 = fy.astype(int), fx.astype(int)
    ty, tx = fy - i0, fx - j0
    g = np.where(np.isnan(gnd), FAR_Z, gnd)
    Z = (g[i0, j0] * (1 - ty) * (1 - tx) + g[i0, j0 + 1] * (1 - ty) * tx + g[i0 + 1, j0] * ty * (1 - tx) + g[i0 + 1, j0 + 1] * ty * tx)
    Z = L.box_blur(Z.astype("f4"), 1)
    # river: water share round each vertex (2 m mask) -> under the water plane; banks stay a bit above it
    wf = L.box_blur(water.astype("f4"), k)
    wr = np.clip(((y1 - Y) / st).astype(int), 0, water.shape[0] - 1)
    wc = np.clip(((X - x0) / st).astype(int), 0, water.shape[1] - 1)
    share = wf[wr, wc]
    Z = np.where(share > 0.5, -2.0, np.where(share > 0.05, np.maximum(np.minimum(Z, 1.2), L.RIVER_LEVEL_AHD + 0.4), Z))
    GRIDS["far"] = (x0, y1, FAR_STEP, Z)
    R, Cn = Z.shape
    verts = np.stack([X, Y, Z], -1).reshape(-1, 3)
    idx = np.arange(R * Cn).reshape(R, Cn)
    faces = np.stack([idx[1:, :-1], idx[1:, 1:], idx[:-1, 1:], idx[:-1, :-1]], -1).reshape(-1, 4)
    cx = (X[:-1, :-1] + FAR_STEP / 2).ravel()
    cy = (Y[:-1, :-1] - FAR_STEP / 2).ravel()
    keep = ~in_lidar_box(cx, cy)
    em, _, cov = ground_grid()
    ex0, ey0, ex1, ey1 = em["box_local"]
    inext = (cx > ex0) & (cx < ex1) & (cy > ey0) & (cy < ey1)
    er = np.clip((ey1 - cy).astype(int), 0, cov.shape[0] - 1)
    ec = np.clip((cx - ex0).astype(int), 0, cov.shape[1] - 1)
    keep &= ~(inext & (cov[er, ec] > 0))
    faces = faces[keep]
    ob = C.mesh_fast("far_ground_real", verts, faces, col, "ground")
    lay = ob.data.uv_layers.new(name="aerial")
    li = np.empty(len(ob.data.loops), "i4")
    ob.data.loops.foreach_get("vertex_index", li)
    uv = np.stack([(verts[li, 0] - x0) / (x1 - x0), (verts[li, 1] - y0) / (y1 - y0)], -1).astype("f4")
    lay.data.foreach_set("uv", uv.ravel())
    ob.data.materials[0] = aerial_material({"aerial": {"file": os.path.join("..", "river", "aerial_wide.jpg")}}, "far_aerial")
    ob.data.shade_smooth()

    def water_at(x, y):
        c = int((x - x0) / st)
        r = int((y1 - y) / st)
        return 0 <= r < water.shape[0] and 0 <= c < water.shape[1] and water[r, c] > 0

    # far_land: split on the box edges, drop what lies inside the box
    removed = {}
    fl = bpy.data.objects.get("far_land")
    if fl is not None:
        bm = bmesh.new()
        bm.from_mesh(fl.data)
        for co, no in (((x0, 0, 0), (1, 0, 0)), ((x1, 0, 0), (1, 0, 0)), ((0, y0, 0), (0, 1, 0)), ((0, y1, 0), (0, 1, 0))):
            bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=co, plane_no=no)
        kill = [f for f in bm.faces if x0 < f.calc_center_median().x < x1 and y0 < f.calc_center_median().y < y1]
        bmesh.ops.delete(bm, geom=kill, context="FACES")
        bm.to_mesh(fl.data)
        bm.free()
        removed["far_land"] = len(kill)
    # far suburbs: none in the river; the rest stand on the real ground
    for name in ("far_suburbs", "far_suburbs_terracotta", "far_suburbs_trees"):
        o = bpy.data.objects.get(name)
        if o is None or len(o.data.vertices) % 8:
            continue
        n = len(o.data.vertices)
        co = np.empty(n * 3, "f4")
        o.data.vertices.foreach_get("co", co)
        co = co.reshape(-1, 8, 3)
        c = co[:, :, :2].mean(1)
        inbox = (c[:, 0] > x0) & (c[:, 0] < x1) & (c[:, 1] > y0) & (c[:, 1] < y1)
        cfx = np.clip((c[:, 0] - x0) / gs - 0.5, 0, gnd.shape[1] - 1)
        cfy = np.clip((y1 - c[:, 1]) / gs - 0.5, 0, gnd.shape[0] - 1)
        gz = g[cfy.astype(int), cfx.astype(int)]
        dz = np.where(inbox, gz - 0.5 - co[:, :, 2].min(1), 0.0)
        co[:, :, 2] += dz[:, None]
        o.data.vertices.foreach_set("co", co.ravel())
        bad = [i for i in np.nonzero(inbox)[0] if water_at(c[i, 0], c[i, 1])]
        if bad:
            bm = bmesh.new()
            bm.from_mesh(o.data)
            bm.verts.ensure_lookup_table()
            bmesh.ops.delete(bm, geom=[bm.verts[8 * i + j] for i in bad for j in range(8)], context="VERTS")
            bm.to_mesh(o.data)
            bm.free()
        o.data.update()
        removed[name] = len(bad)
    return ob, int(len(faces)), removed


def sink_river_land():
    """No land masses in the river (John, 17 Nov): ground vertices of the master LiDAR ground that stand above
    the water where the aerial trace says open river (4 m in from the banks) go under. They were moored
    boats, pontoons and mud the LiDAR ground kept."""
    ob = bpy.data.objects.get("ground_lidar2019_smooth")
    if ob is None:
        return 0
    rm, water, _ = river_data()
    deep = L.box_blur(water.astype("f4"), 2) > 1 - 1e-3
    n = len(ob.data.vertices)
    co = np.empty(n * 3, "f4")
    ob.data.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    r = np.clip(((rm["box_local"][3] - co[:, 1]) / rm["step_m"]).astype(int), 0, water.shape[0] - 1)
    c = np.clip(((co[:, 0] - rm["box_local"][0]) / rm["step_m"]).astype(int), 0, water.shape[1] - 1)
    bad = deep[r, c] & (co[:, 2] > L.RIVER_LEVEL_AHD - 0.5)
    co[bad, 2] = -2.0
    ob.data.vertices.foreach_set("co", co.ravel())
    ob.data.update()
    return int(bad.sum())


def build():
    global bpy
    import bpy
    if L.GAME_EXPORT or getattr(L, "ACTIVE_STAGE", None) or not os.path.exists(os.path.join(EXT, "ext.json")):
        return {"module": "cbd_ext", "objects": [], "note": "skipped (game export, stage build or no data)"}
    col = C.collection("cbd_ext")
    far = None
    if os.path.exists(os.path.join(RIVER, "river.json")):
        far = build_far(col)
        sunk = sink_river_land()
        print("cbd_ext: river land sunk inside the LiDAR box: %d vertices" % sunk)
    gob, box, nf = build_ground(col)
    cut = cut_far(box)
    res, nrec = build_buildings()
    tobjs, ntrees = build_trees(col)
    return {"module": "cbd_ext", "objects": [gob.name] + res["objects"] + tobjs + ([far[0].name] if far else []),
            "far_ground": {"faces": far[1], "removed": far[2]} if far else None, "ground_faces": nf,
            "far_faces_removed": cut, "buildings": res["buildings"], "records": nrec, "trees": ntrees,
            "named_recipes": res.get("named_recipes"),
            "source": "reference/sites/spire/ext (tools/sites/clean_ext.py): 2019 LiDAR + OSM + 2022 aerial"}
