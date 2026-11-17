"""Every OSM building over the whole 2019 LiDAR download, at its measured height and roof shape (no bpy).

    python3 tools/sites/clean_wide.py <PourDecisions-sites>/data

Mosaics <data>/cbd/elvis/grid2019 (16 x 1 km tiles: dsm, gnd, veg, bld) into Spire's frame and runs
clean_ext.shape_buildings (prep_clean.py's rules: roof tiers from LiDAR height clusters, gables, spires,
facade family) over every OSM building in <data>/cbd/osm/osm_all.json.gz that the scene does not build yet
(buildings_clean.json inside the +-700 m square, ext/buildings_ext.json). Writes reference/sites/spire/wide/:

    wide.json             box, counts, sources
    buildings_wide.json   buildings_clean-format records + tags (building, name, height, levels, roof:shape)
    tree_points_wide.csv  LiDAR tree tops (9 m local maxima of the canopy) outside LIDAR_BOX and the ext box
    features.json         OSM traffic signals, street lamps, motorway junctions (nodes) and parks, pitches,
                          car parks, stadiums (rings), local metres

To go further out: order more Brisbane 2019 LiDAR tiles from ELVIS, grid them with tools/lidar/grid.js into
grid2019/<E>_<N>/ and run this again; it takes whatever tiles are there.
"""
import csv
import gzip
import json
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(REPO, "tools", "blender", "spire"))
sys.path.insert(0, HERE)
import layout as L  # noqa: E402
import clean_ext as CE  # noqa: E402

OUT = os.path.join(L.REF, "wide")


def fill_nan(a):
    """Fill NaN cells from their surroundings (normalised box blurs at growing radii)."""
    a = a.copy()
    for r in (1, 2, 4, 8, 16, 32, 64, 128):
        bad = np.isnan(a)
        if not bad.any():
            break
        v = (~bad).astype("f4")
        num = L.box_blur(np.where(bad, 0, a).astype("f4"), r)
        den = L.box_blur(v, r)
        ok = bad & (den > 0.05)
        a[ok] = num[ok] / den[ok]
    return np.where(np.isnan(a), np.nanmedian(a), a)


def main():
    data = sys.argv[1]
    gdir = os.path.join(data, "cbd", "elvis", "grid2019")
    tiles = []
    for t in sorted(os.listdir(gdir)):
        g = json.load(open(os.path.join(gdir, t, "grid.json")))
        tiles.append((g, os.path.join(gdir, t)))
    E0 = min(g["X0"] for g, _ in tiles)
    E1 = max(g["X0"] + g["W"] for g, _ in tiles)
    N1 = max(g["Y1"] for g, _ in tiles)
    N0 = min(g["Y1"] - g["H"] for g, _ in tiles)
    W, H = E1 - E0, N1 - N0
    dsm = np.full((H, W), np.nan, "f4")
    gnd = np.full((H, W), np.nan, "f4")
    bld = np.full((H, W), np.nan, "f4")
    veg = np.full((H, W), np.nan, "f4")
    cover = np.zeros((H, W), bool)
    for g, d in tiles:
        r0, c0 = N1 - g["Y1"], g["X0"] - E0
        sl = (slice(r0, r0 + g["H"]), slice(c0, c0 + g["W"]))
        for arr, nm in ((dsm, "dsm"), (gnd, "gnd"), (bld, "bld"), (veg, "veg")):
            arr[sl] = np.fromfile(os.path.join(d, nm + ".f32"), "<f4").reshape(g["H"], g["W"])
        cover[sl] = True
    # the mosaic is on whole MGA metres; local = MGA - origin, so the box has a fractional corner
    box = (E0 - L.ORIGIN_MGA56[0], N0 - L.ORIGIN_MGA56[1], E1 - L.ORIGIN_MGA56[0], N1 - L.ORIGIN_MGA56[1])
    ibox = (0, 0, W, H)                                     # shape_buildings works in whole cells: shift the rings
    ox, oy = box[0], box[1]
    gfill = fill_nan(gnd)
    cls = np.where(~np.isnan(bld), 3, np.where(~np.isnan(veg), 2, np.where(~np.isnan(gnd), 1, 0))).astype("u1")
    dsm_f = np.where(np.isnan(dsm), gfill, dsm)

    raw = json.load(gzip.open(os.path.join(data, "cbd", "osm", "osm_all.json.gz"), "rt", encoding="utf-8"))
    nodes, ways, tagged = {}, {}, []
    for el in raw["elements"]:
        if el["type"] == "node":
            x, y = L.to_local(el["lat"], el["lon"])
            nodes[el["id"]] = (x - ox, y - oy)
            if el.get("tags"):
                tagged.append(el)
        elif el["type"] == "way":
            ways[el["id"]] = el
    have = {b["osm"] for b in json.load(open(os.path.join(L.REF, "ext", "buildings_ext.json")))["buildings"]}
    lim = L.MODEL_HALF + CE.MODEL_PAD
    lx0, ly0, lx1, ly1 = L.LIDAR_BOX

    def already(cx, cy):
        x, y = cx + ox, cy + oy
        return lx0 + 5 < x < lx1 - 5 and ly0 + 5 < y < ly1 - 5 and abs(x) <= lim and abs(y) <= lim

    cand = {k: w for k, w in ways.items() if k not in have and k != L.SPIRE["osm_way"]}
    out, skipped, built = CE.shape_buildings(cand, nodes, ibox, gfill, dsm_f, cls, cover, already)
    keep_tags = ("building", "name", "height", "building:levels", "roof:shape", "amenity", "leisure")
    for b in out:                                           # back to Spire local metres
        for t in b["tiers"]:
            t["ring"] = [(round(x + ox, 2), round(y + oy, 2)) for x, y in t["ring"]]
        if b["gable"]:
            b["gable"]["cx"] = round(b["gable"]["cx"] + ox, 2)
            b["gable"]["cy"] = round(b["gable"]["cy"] + oy, 2)
        for sp in b["spires"]:
            sp["x"], sp["y"] = round(sp["x"] + ox, 2), round(sp["y"] + oy, 2)
        wt = ways[b["osm"]].get("tags", {})
        b["tags"] = {k: wt[k] for k in keep_tags if k in wt}
    os.makedirs(OUT, exist_ok=True)
    json.dump({"note": "Every OSM building over the 2019 LiDAR download (tools/sites/clean_wide.py), Spire local metres.",
               "buildings": out}, open(os.path.join(OUT, "buildings_wide.json"), "w"), separators=(",", ":"))

    # ---- tree tops: 9 m local maxima of the canopy height, outside the areas that already have trees
    can = np.where(np.isnan(veg), 0, veg - gfill)
    can = np.where((can > 3.0) & (can < 45.0), can, 0).astype("f4")
    k = 4
    mx = can.copy()
    for d in range(1, k + 1):                               # separable max filter
        mx[:, d:] = np.maximum(mx[:, d:], can[:, :-d])
        mx[:, :-d] = np.maximum(mx[:, :-d], can[:, d:])
    m2 = mx.copy()
    for d in range(1, k + 1):
        m2[d:, :] = np.maximum(m2[d:, :], mx[:-d, :])
        m2[:-d, :] = np.maximum(m2[:-d, :], mx[d:, :])
    rr, cc = np.nonzero((can > 0) & (can >= m2))
    em = json.load(open(os.path.join(L.REF, "ext", "ext.json")))["box_local"]
    trees, seen = [], set()
    for r, c in zip(rr.tolist(), cc.tolist()):
        x, y = box[0] + c + 0.5, box[3] - r - 0.5
        if (lx0 <= x <= lx1 and ly0 <= y <= ly1) or (em[0] <= x <= em[2] and em[1] <= y <= em[3]):
            continue
        key = (int(x // 6), int(y // 6))
        if key in seen:
            continue
        seen.add(key)
        trees.append((round(x, 1), round(y, 1), round(float(can[r, c]), 1), round(float(gfill[r, c]), 2)))
    with open(os.path.join(OUT, "tree_points_wide.csv"), "w", newline="", encoding="utf-8") as f:
        wr = csv.writer(f)
        wr.writerow(["x_local", "y_local", "height_m", "ground_ahd"])
        wr.writerows(trees)

    # ---- street furniture and land use from OSM
    rv = json.load(open(os.path.join(L.REF, "river", "river.json")))["box_local"]
    feats = {"traffic_signals": [], "street_lamps": [], "motorway_junctions": [], "areas": []}
    for el in tagged:
        t = el["tags"]
        x, y = nodes[el["id"]][0] + ox, nodes[el["id"]][1] + oy
        if not (rv[0] < x < rv[2] and rv[1] < y < rv[3]):
            continue
        hw = t.get("highway")
        if hw == "traffic_signals":
            feats["traffic_signals"].append([round(x, 1), round(y, 1)])
        elif hw == "street_lamp":
            feats["street_lamps"].append([round(x, 1), round(y, 1)])
        elif hw == "motorway_junction":
            feats["motorway_junctions"].append([round(x, 1), round(y, 1), t.get("ref", ""), t.get("name", "")])
    for wid, w in ways.items():
        t = w.get("tags", {})
        kind = ("parking" if t.get("amenity") == "parking" and t.get("parking", "surface") == "surface" else
                t.get("leisure") if t.get("leisure") in ("park", "pitch", "stadium", "garden", "playground", "swimming_pool") else None)
        if not kind or "building" in t or w["nodes"][0] != w["nodes"][-1] or not all(n in nodes for n in w["nodes"]):
            continue
        ring = [(nodes[n][0] + ox, nodes[n][1] + oy) for n in w["nodes"][:-1]]
        cx = sum(p[0] for p in ring) / len(ring)
        cy = sum(p[1] for p in ring) / len(ring)
        if rv[0] < cx < rv[2] and rv[1] < cy < rv[3] and len(ring) >= 3:
            feats["areas"].append({"osm": wid, "kind": kind, "name": t.get("name", ""), "sport": t.get("sport", ""),
                                   "ring": [[round(x, 1), round(y, 1)] for x, y in ring]})
    json.dump(feats, open(os.path.join(OUT, "features.json"), "w"), separators=(",", ":"))

    fams, srcs = {}, {}
    for b in out:
        fams[b["family"]] = fams.get(b["family"], 0) + 1
        srcs[b["height_src"]] = srcs.get(b["height_src"], 0) + 1
    meta = {"box_local": [round(v, 2) for v in box], "lidar_tiles": len(tiles), "buildings": len(out),
            "already_in_scene": built + len(have), "skipped": skipped, "families": fams, "height_sources": srcs,
            "gables": sum(1 for b in out if b["gable"]), "multi_tier": sum(1 for b in out if len(b["tiers"]) > 1),
            "spires": sum(len(b["spires"]) for b in out), "trees": len(trees),
            "features": {k: len(v) for k, v in feats.items()},
            "credit": "2019 LiDAR (c) State of Queensland CC BY 4.0; OSM (c) OpenStreetMap contributors ODbL"}
    json.dump(meta, open(os.path.join(OUT, "wide.json"), "w"), indent=1)
    print(json.dumps(meta))
    for b in sorted(out, key=lambda b: -max(t["top_ahd"] for t in b["tiers"]))[:10]:
        print("%11d %-30s top %6.1f tiers %d" % (b["osm"], b["name"][:30], max(t["top_ahd"] for t in b["tiers"]), len(b["tiers"])))


if __name__ == "__main__":
    main()
