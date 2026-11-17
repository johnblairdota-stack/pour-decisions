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


def aerial_material(m):
    name = "cbd_ext_aerial"
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


def build_buildings():
    import buildings as B
    import looks as LK
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
    try:
        res = B.build(zone=tuple(meta()["box_local"]), collection="cbd_ext", only={r["osm"] for r in recs}, suffix="_ext")
    finally:
        B.records = keep
        for k in added:
            o["ways"].pop(k, None)
    return res, len(recs)


def build_trees(col):
    import trees as T
    trunks, crowns, palms = C.MeshBuf(), C.MeshBuf(), C.MeshBuf()
    n = 0
    with open(os.path.join(EXT, "tree_points_ext.csv"), encoding="utf-8") as f:
        for r in csv.DictReader(f):
            x, y, h, g = float(r["x_local"]), float(r["y_local"]), float(r["height_m"]), float(r["ground_ahd"])
            if h < 3.0 or h > 40.0:
                continue
            s = T.species(x, y, h)
            if s == "palm":
                T.trunk(trunks, x, y, g, 0.2, h - 1.0, 0)
                for k in range(6):
                    a = 2 * math.pi * k / 6
                    palms.beam((x, y, g + h - 1.2), (x + 3.0 * math.cos(a), y + 3.0 * math.sin(a), g + h - 2.6), 0.5, 0.12)
            else:
                rr = (0.42 if s == "fig" else 0.3) * h
                T.trunk(trunks, x, y, g, 0.25, h * 0.55, 0)
                T.crown(crowns, x, y, g + h - rr * 0.6, rr, 0.6, 4)
            n += 1
    objs = []
    for buf, name, key, rgb in ((trunks, "cbd_ext_tree_trunks", "bark", (0.11, 0.095, 0.08)),
                                (crowns, "cbd_ext_tree_crowns", "tree", (0.035, 0.075, 0.03)),
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


def build():
    global bpy
    import bpy
    if L.GAME_EXPORT or getattr(L, "ACTIVE_STAGE", None) or not os.path.exists(os.path.join(EXT, "ext.json")):
        return {"module": "cbd_ext", "objects": [], "note": "skipped (game export, stage build or no data)"}
    col = C.collection("cbd_ext")
    gob, box, nf = build_ground(col)
    cut = cut_far(box)
    res, nrec = build_buildings()
    tobjs, ntrees = build_trees(col)
    return {"module": "cbd_ext", "objects": [gob.name] + res["objects"] + tobjs, "ground_faces": nf,
            "far_faces_removed": cut, "buildings": res["buildings"], "records": nrec, "trees": ntrees,
            "named_recipes": res.get("named_recipes"),
            "source": "reference/sites/spire/ext (tools/sites/clean_ext.py): 2019 LiDAR + OSM + 2022 aerial"}
