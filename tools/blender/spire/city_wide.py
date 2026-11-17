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
RECS = None                                                 # the records as built (city_detail dresses them)
HOUSE = {"house", "detached", "semidetached_house", "terrace", "bungalow", "residential", "yes", "garage", "shed", "roof"}


SHED = {"industrial", "warehouse", "shed", "roof", "garage", "garages", "carport", "service", "transportation",
        "hangar", "grandstand", "stage", "parking", "utility"}
HOMES = {"apartments", "residential", "hotel", "dormitory"}
WORK = {"office", "commercial", "government", "public", "civic"}
SCHOOL = {"school", "university", "college", "kindergarten", "hospital"}
# roof sheet / tile colours, linear RGB: the aerial's median roof pixel is snapped to the nearest
ROOFS = [(0.07, 0.075, 0.08), (0.16, 0.165, 0.17), (0.30, 0.305, 0.31), (0.48, 0.485, 0.48), (0.68, 0.68, 0.66),
         (0.33, 0.12, 0.07), (0.20, 0.07, 0.05)]
ROOF_GAIN = 0.72                                            # the drape renders darker than a plain material of the same value
# best-guess walls (the aerial can't see them): the usual inner-Brisbane mixes, dealt by OSM id
HOUSE_WALLS = ["f0ece2", "e9dfc6", "d7dcd6", "cfd8c8", "c8cfd8", "b98a6a", "8a5a44", "e6c9a8"]
WALKUP = [("94503a", "brick"), ("b0704e", "brick"), ("c9b08a", "brick"), ("e2d6bc", "render"), ("7a4636", "brick")]
SHEDS = ["d9d4c4", "9aa0a4", "c4c8c4", "6f7b84", "b9ad98"]
MID = [("ddd3bf", "5f8f8a", "e9e2d2"), ("c9c2b2", "34424c", "e4dfd2"), ("b7a48a", "3a3026", "d8c9ae"), ("9aa3aa", "26323c", "dfe2e4")]


def roof_index(rgb):
    if rgb is None:
        return 2
    lin = [(c / 255.0) ** 2.2 for c in rgb]
    return min(range(len(ROOFS)), key=lambda i: sum((ROOFS[i][k] - lin[k]) ** 2 for k in range(3)))


def assign_looks(recs):
    """A facade recipe per building from its OSM use, measured height and footprint, with the roof colour
    read off the aerial (roof_colours.json). Named and heritage buildings keep looks.look_for."""
    import looks as LK
    fp = os.path.join(WIDE, "roof_colours.json")
    seen = json.load(open(fp))["roofs"] if os.path.exists(fp) else {}
    out, count = {}, {}
    for b in recs:
        osm, t = b["osm"], b.get("tags", {})
        use = t.get("building", "yes")
        if osm in LK.LOOKS or b["family"] == "heritage" or use in ("church", "cathedral", "chapel", "temple"):
            continue
        h = max(x["top_ahd"] for x in b["tiers"]) - b["base_ahd"]
        area = abs(S.area(b["tiers"][0]["ring"]))
        ri = roof_index(seen.get(str(osm)))
        k = LK.stable(osm, 1000)
        if use in SHED or (use == "yes" and h < 9 and area > 900):
            i = k % len(SHEDS)
            key, rec = "shed%d" % i, {"shader": "render", "wall": LK.hx(SHEDS[i]), "glass": LK.hx("2c3038"), "pattern": "none"}
        elif (use in HOUSE or use == "detached") and h < 10.5 and area < 420:
            i = k % len(HOUSE_WALLS)
            key, rec = "house%d" % i, {"shader": "brick" if i in (5, 6) else "render", "wall": LK.hx(HOUSE_WALLS[i]),
                                       "glass": LK.hx("2c3038"), "pattern": "punched"}
        elif h <= 16:
            if use in HOMES or (use == "yes" and area < 700 and k % 3 == 0):
                i = k % len(WALKUP)
                key, rec = "walkup%d" % i, {"shader": WALKUP[i][1], "wall": LK.hx(WALKUP[i][0]), "glass": LK.hx("2c3038"),
                                            "pattern": "balcony", "band": LK.hx("ece8de"), "balcony": "white_solid"}
            elif use in SCHOOL:
                key, rec = "school", {"shader": "render", "wall": LK.hx("e4dcc8"), "glass": LK.hx("34424c"), "pattern": "strip",
                                      "band": LK.hx("efe9da")}
            else:
                kind = "lowrise_brick" if k % 100 < 45 else "lowrise_render"
                key, rec = kind, dict(LK.GENERIC[kind])
        elif use in WORK or (use in ("yes", "retail") and (h > 45 and k % 100 < 60 or h <= 45 and k % 100 < 35)):
            i = k % len(LK.OFFICE_MIX)
            key, rec = "office%d" % i, dict(LK.GENERIC["office"], **LK.OFFICE_MIX[i])
        elif use in HOMES or h > 45 or k % 100 < 70:
            i = k % len(LK.RES_MIX)
            key, rec = "res%d" % i, dict(LK.GENERIC["modern_res"], **LK.RES_MIX[i])
            if i in (1, 2):
                rec["balcony"] = "white_solid"
        else:
            i = k % len(MID)
            key, rec = "mid%d" % i, dict(LK.GENERIC["precast_80s"], wall=LK.hx(MID[i][0]), glass=LK.hx(MID[i][1]), band=LK.hx(MID[i][2]))
        key = "gen_w_%s_r%d" % (key, ri)
        out[osm] = (key, dict(rec, roof=tuple(c * ROOF_GAIN for c in ROOFS[ri]), src="city_wide.assign_looks (use + height; roof colour from the aerial)"))
        kind = key[6:].split("_r")[0].rstrip("0123456789")
        count[kind] = count.get(kind, 0) + 1
    return out, count


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
    """Delete the made-up far suburbs (boxes and tree masses) that stand inside the box."""
    import bmesh
    x0, y0, x1, y1 = box
    out = {}
    for name in ("far_suburbs", "far_suburbs_terracotta", "far_suburbs_trees"):
        o = bpy.data.objects.get(name)
        if o is None:
            continue
        bm = bmesh.new()
        bm.from_mesh(o.data)
        kill, done = [], set()
        for v0 in bm.verts:                                 # whole mesh islands whose middle is inside
            if v0.index in done:
                continue
            isl, todo = [], [v0]
            done.add(v0.index)
            while todo:
                v = todo.pop()
                isl.append(v)
                for e in v.link_edges:
                    u = e.other_vert(v)
                    if u.index not in done:
                        done.add(u.index)
                        todo.append(u)
            cx = sum(v.co.x for v in isl) / len(isl)
            cy = sum(v.co.y for v in isl) / len(isl)
            if x0 - 10 < cx < x1 + 10 and y0 - 10 < cy < y1 + 10:
                kill.extend(isl)
        out[name] = len(kill)
        if kill:
            bmesh.ops.delete(bm, geom=kill, context="VERTS")
            bm.to_mesh(o.data)
            o.data.update()
        bm.free()
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
            if FR.over_deck(x, y, rr):
                continue
            T.tube(trunks, (x, y, g - 0.3), (x, y, g + h * 0.55), 0.22, 0.14, 5)
            T.blob(crowns, x, y, g + h * 0.62, rr * 0.9, h * 0.38)     # full crown down to near the ground (critics: lollipops)
            n += 1
    objs = []
    for buf, name, mname, rgb in ((trunks, "wide_tree_trunks", "tree_trunks", (0.11, 0.095, 0.08)),
                                  (crowns, "wide_tree_crowns", "tree_crowns_far", (0.06, 0.14, 0.045))):
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
    global RECS
    RECS = recs
    cranes = 0
    for b in recs:                                          # thin points over 30 m tall are tower cranes in the 2019 LiDAR, not spires
        keep = [sp for sp in b["spires"] if sp["top_ahd"] - sp["base_ahd"] <= 30.0]
        cranes += len(b["spires"]) - len(keep)
        b["spires"] = keep
    box = tuple(m["box_local"])
    import buildings as B
    looks, look_count = assign_looks(recs)
    keep = B.look_for
    B.look_for = lambda osm, tags, h, family: looks.get(osm) or keep(osm, tags, h, family)
    try:
        res, _ = CE.build_buildings(recs, zone=box, collection="city_wide", suffix="_wide")
    finally:
        B.look_for = keep
    dropped = drop_far_suburbs(box, bpy)
    tobjs, ntrees = build_trees(C.collection("city_wide"))
    return {"module": "city_wide", "objects": res["objects"] + tobjs, "buildings": res["buildings"], "roof_guesses": guessed, "crane_spikes_dropped": cranes,
            "far_suburbs_removed": dropped, "trees": ntrees, "looks": look_count,
            "source": "reference/sites/spire/wide (tools/sites/clean_wide.py): OSM footprints + 2019 LiDAR"}
