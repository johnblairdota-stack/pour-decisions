"""The city outwards from the centre (17 Nov 2026): every OSM building over the whole 2019 LiDAR download
(4 x 4 km) at its measured height and roof shape, with the facade recipes of buildings.py / looks.py, plus
LiDAR trees. Data: reference/sites/spire/wide/ (tools/sites/clean_wide.py). Built after cbd_ext.

- buildings: roof tiers, spires and gables as measured. Houses the LiDAR could not fit a pitch to (trees
  over the roof) get a best-guess gable along the long side (roof_guess); OSM roof:shape=flat is kept flat.
- the made-up far suburbs are removed over the LiDAR area (the real buildings stand there now)
- trees: one crown per LiDAR tree top outside the areas that already have trees
"""
import csv
import json
import math
import os

import numpy as np

import layout as L
import common as C
import shapes as S

WIDE = os.path.join(L.REF, "wide")
HOUSE = {"house", "detached", "semidetached_house", "terrace", "bungalow", "residential", "yes", "garage", "shed", "roof"}


def guess_roofs(recs):
    """Pitched roof for low, small, single-tier buildings with no measured gable (suburban houses)."""
    n = 0
    for b in recs:
        t = b.get("tags", {})
        if b["gable"] or len(b["tiers"]) != 1 or t.get("roof:shape") == "flat" or t.get("building") not in HOUSE:
            continue
        ring = b["tiers"][0]["ring"]
        h = b["tiers"][0]["top_ahd"] - b["base_ahd"]
        area = abs(S.area(ring))
        if not (2.5 < h < 10.5 and 25 < area < 420):
            continue
        cx, cy, ln, wd, ang = S.min_rect(ring)
        if wd < 4:
            continue
        top = b["tiers"][0]["top_ahd"]                     # 75th percentile of the roof returns
        rise = min(0.4 * wd / 2, 2.8)                       # about 22 degrees
        eave = top - 0.6 * rise
        b["tiers"][0]["top_ahd"] = round(eave, 2)
        b["gable"] = {"cx": cx, "cy": cy, "length": ln, "width": wd, "angle": ang, "eave_ahd": round(eave, 2),
                      "ridge_ahd": round(eave + rise, 2), "roof_guess": True}
        n += 1
    return n


def drop_far_suburbs(box, bpy):
    import bmesh
    x0, y0, x1, y1 = box
    out = {}
    for name in ("far_suburbs", "far_suburbs_terracotta", "far_suburbs_trees"):
        o = bpy.data.objects.get(name)
        if o is None or len(o.data.vertices) % 8:
            continue
        co = np.empty(len(o.data.vertices) * 3, "f4")
        o.data.vertices.foreach_get("co", co)
        c = co.reshape(-1, 8, 3)[:, :, :2].mean(1)
        bad = np.nonzero((c[:, 0] > x0 - 10) & (c[:, 0] < x1 + 10) & (c[:, 1] > y0 - 10) & (c[:, 1] < y1 + 10))[0]
        if len(bad):
            bm = bmesh.new()
            bm.from_mesh(o.data)
            bm.verts.ensure_lookup_table()
            bmesh.ops.delete(bm, geom=[bm.verts[8 * int(i) + j] for i in bad for j in range(8)], context="VERTS")
            bm.to_mesh(o.data)
            bm.free()
            o.data.update()
        out[name] = int(len(bad))
    return out


def build_trees(col):
    import trees as T
    import far_roads as FR
    trunks, crowns = C.MeshBuf(), C.MeshBuf()
    n = 0
    with open(os.path.join(WIDE, "tree_points_wide.csv"), encoding="utf-8") as f:
        for r in csv.DictReader(f):
            x, y, h, g = float(r["x_local"]), float(r["y_local"]), float(r["height_m"]), float(r["ground_ahd"])
            if FR.on_road(x, y) or h < 4.0:
                continue
            rr = min(0.32 * h, 7.0) * (0.85 + 0.3 * ((int(x * 3 + y * 7) % 10) / 10))
            T.tube(trunks, (x, y, g - 0.3), (x, y, g + h * 0.55), 0.22, 0.14, 5)
            T.blob(crowns, x, y, g + h - rr * 0.62, rr, rr * 0.62)
            n += 1
    objs = []
    for buf, name, mname, rgb in ((trunks, "wide_tree_trunks", "tree_trunks", (0.11, 0.095, 0.08)),
                                  (crowns, "wide_tree_crowns", "tree_crowns_far", (0.035, 0.075, 0.03))):
        ob = buf.object(name, col, "tree")
        if ob:
            ob.data.materials[0] = C.material_rgb(mname, rgb)
            if "crowns" in name:
                ob.data.materials[0]["shader"] = "canopy"
            for p in ob.data.polygons:
                p.use_smooth = True
            objs.append(ob.name)
    return objs, n


def build():
    import bpy
    if L.GAME_EXPORT or getattr(L, "ACTIVE_STAGE", None) or not os.path.exists(os.path.join(WIDE, "wide.json")):
        return {"module": "city_wide", "objects": [], "note": "skipped (game export, stage build or no data)"}
    import cbd_ext as CE
    m = json.load(open(os.path.join(WIDE, "wide.json")))
    recs = json.load(open(os.path.join(WIDE, "buildings_wide.json")))["buildings"]
    guessed = guess_roofs(recs)
    cranes = 0
    for b in recs:                                          # thin points over 30 m tall are tower cranes in the 2019 LiDAR, not spires
        keep = [sp for sp in b["spires"] if sp["top_ahd"] - sp["base_ahd"] <= 30.0]
        cranes += len(b["spires"]) - len(keep)
        b["spires"] = keep
    box = tuple(m["box_local"])
    res, _ = CE.build_buildings(recs, zone=box, collection="city_wide", suffix="_wide")
    dropped = drop_far_suburbs(box, bpy)
    tobjs, ntrees = build_trees(C.collection("city_wide"))
    return {"module": "city_wide", "objects": res["objects"] + tobjs, "buildings": res["buildings"], "roof_guesses": guessed, "crane_spikes_dropped": cranes,
            "far_suburbs_removed": dropped, "trees": ntrees, "generic_recipes": res.get("generic_recipes"),
            "source": "reference/sites/spire/wide (tools/sites/clean_wide.py): OSM footprints + 2019 LiDAR"}
