"""Extend the master Spire scene south-west over the CBD towers (no bpy).

    python3 tools/sites/clean_ext.py

Reads the per-tower packs made by prep_site.py (reference/sites/{william1,skytower,queenswharf}/), moves
them into Spire's frame (same MGA56 grid, so a pure shift), and writes reference/sites/spire/ext/:

    ext.json             box (Spire local metres), sources, counts
    ground_1m.f32.gz     2019 LiDAR ground (pack mosaic, nearest pack wins), smoothed like ground_smooth
    cover_1m.u8.gz       1 where a pack has data
    buildings_ext.json   buildings_clean.json-format records for every OSM building in the box that the
                         master scene does not build yet (outside LIDAR_BOX or outside the +-700 m model square)
    tree_points_ext.csv  LiDAR tree tops outside LIDAR_BOX
    aerial_2022_ext.jpg  2022 aerial mosaic over the box, 0.5 m/px, north up

The shapes use prep_clean.py's own rules (tiers from LiDAR height clusters, gables, spires, families).
"""
import csv
import gzip
import json
import math
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(REPO, "tools", "blender", "spire"))
import layout as L  # noqa: E402
import shapes as S  # noqa: E402
import prep_lidar as PL  # noqa: E402
import prep_clean as PC  # noqa: E402

PACKS = ["skytower", "william1", "queenswharf"]
OUT = os.path.join(L.REF, "ext")
AERIAL_YEAR = 2022
MODEL_PAD = 300          # buildings.build keeps |x|, |y| <= MODEL_HALF + 300


def pack_dir(p):
    return os.path.join(REPO, "reference", "sites", p)


def load_pack(p):
    d = pack_dir(p)
    site = json.load(open(os.path.join(d, "site.json")))
    o = site["origin"]
    off = (o["mga56_E"] - L.ORIGIN_MGA56[0], o["mga56_N"] - L.ORIGIN_MGA56[1])
    lj = json.load(open(os.path.join(d, "lidar", "lidar.json")))
    R, Cn = lj["rows"], lj["cols"]

    def arr(fn, dt):
        return np.frombuffer(gzip.open(os.path.join(d, "lidar", fn)).read(), dt).reshape(R, Cn)
    return {"id": p, "off": off, "box": lj["box_local"], "dsm": arr("dsm_1m.f32.gz", "<f4"),
            "gnd": arr("ground_1m.f32.gz", "<f4"), "cls": arr("class_1m.u8.gz", "u1"), "dir": d}


def already_built(cx, cy):
    """The master scene builds this one itself (buildings_clean.json + buildings.build's model square)."""
    x0, y0, x1, y1 = L.LIDAR_BOX
    lim = L.MODEL_HALF + MODEL_PAD
    return x0 + 5 < cx < x1 - 5 and y0 + 5 < cy < y1 - 5 and abs(cx) <= lim and abs(cy) <= lim


def shape_buildings(ways, nodes, box, gnd, dsm, cls, cover, already_built):
    """prep_clean.py's rules over any LiDAR mosaic: one record per OSM building (tiers, gable, spires, family).
    ways {id: OSM way}, nodes {id: (x, y) local}; gnd/dsm/cls/cover are 1 m grids over box."""
    bx0, by0, bx1, by1 = box
    out, skipped, built_already = [], 0, 0
    for wid, w in ways.items():
        t = w.get("tags", {})
        if "building" not in t:
            continue
        rawr = [nodes[n] for n in w["nodes"] if n in nodes]
        if len(rawr) < 4 or len(rawr) != len(w["nodes"]):
            continue
        cx = sum(q[0] for q in rawr) / len(rawr)
        cy = sum(q[1] for q in rawr) / len(rawr)
        if not (bx0 + 5 < cx < bx1 - 5 and by0 + 5 < cy < by1 - 5):
            continue
        if already_built(cx, cy):
            built_already += 1
            continue
        ring = S.clean(rawr, 0.3)
        m, r0, c0 = PL.ring_mask(ring, box)
        if m is None or m.sum() < 4:
            skipped += 1
            continue
        sub = (slice(r0, r0 + m.shape[0]), slice(c0, c0 + m.shape[1]))
        if cover[sub][m].mean() < 0.8:
            skipped += 1
            continue
        g_med = float(np.median(gnd[sub][m & cover[sub]]))
        base_ahd = float(np.min(gnd[sub][m & cover[sub]]))
        hcell = dsm[sub] - g_med
        use = m & (cls[sub] == 3) & (hcell > 2.0)
        name = t.get("name", "")
        if use.sum() < max(4, 0.15 * m.sum()):
            # (no building returns: Queen's Wharf in 2019 was a basement pit; keep OSM's own height)
            h, src = L.building_height(t)
            fam = PC.family(t, h, name)
            out.append({"osm": wid, "name": name, "base_ahd": round(base_ahd, 2),
                        "tiers": [{"ring": [(round(x, 2), round(y, 2)) for x, y in ring], "top_ahd": round(g_med + h, 2)}],
                        "gable": None, "spires": [], "family": fam[0], "family_why": fam[1], "height_src": src,
                        "tags": {k: t[k] for k in ("building", "name", "height", "building:levels") if k in t}})
            continue
        hs = hcell[use]
        cl = PC.clusters(hs)
        tiers, spires = [], []
        rr, cc = np.nonzero(use)
        cells_xy = np.stack([bx0 + c0 + cc + 0.5, by1 - r0 - rr - 0.5], 1)
        for k, (lo, hi, n) in enumerate(cl):
            sel = hs >= lo - 0.01
            top = float(np.percentile(hs[(hs >= lo - 0.01) & (hs <= hi + 0.01)], 75))
            if k == 0:
                tiers.append({"ring": ring, "top_ahd": round(g_med + top, 2)})
                continue
            region = np.zeros(m.shape, bool)
            region[rr[sel], cc[sel]] = True
            for lp in PL.trace(region, box, r0, c0):
                if len(lp) < 4:
                    continue
                poly = S.ccw(S.square(S.simplify(lp, 0.8)))
                a = abs(S.area(poly))
                if a < 6:
                    continue
                if a < 50 and hi - cl[k - 1][1] > 8:
                    px = sum(q[0] for q in poly) / len(poly)
                    py = sum(q[1] for q in poly) / len(poly)
                    spires.append({"x": round(px, 2), "y": round(py, 2), "r": round(math.sqrt(a / math.pi), 2),
                                   "base_ahd": round(g_med + cl[k - 1][1], 2), "top_ahd": round(g_med + hi, 2)})
                    continue
                if a >= PC.MIN_TIER_CELLS:
                    tiers.append({"ring": poly, "top_ahd": round(g_med + top, 2)})
        gable = None
        if len(cl) <= 2 and tiers[0]["top_ahd"] - g_med < 25:
            base_sel = (hs >= cl[0][0] - 0.01) & (hs <= cl[0][1] + 0.01)
            gable = PC.gable_fit(ring, cells_xy[base_sel], hs[base_sel])
            if gable:
                gable["eave_ahd"] = round(g_med + gable.pop("eave_h"), 2)
                gable["ridge_ahd"] = round(g_med + gable.pop("ridge_h"), 2)
                tiers[0]["top_ahd"] = gable["eave_ahd"]
        # a mast or crown point well above the top tier that the clusters folded in (1 William St's mast)
        dm = np.where(m & cover[sub], dsm[sub], -999)
        ri, ci = np.unravel_index(int(np.argmax(dm)), dm.shape)
        peak = float(dm[ri, ci])
        ttop = max(tt["top_ahd"] for tt in tiers)
        if peak - ttop > 10 and not spires:
            spires.append({"x": round(bx0 + c0 + ci + 0.5, 2), "y": round(by1 - r0 - ri - 0.5, 2), "r": 1.2,
                           "base_ahd": round(ttop, 2), "top_ahd": round(peak, 2)})
        hmax = max(tt["top_ahd"] for tt in tiers) - g_med
        fam = PC.family(t, hmax, name)
        out.append({"osm": wid, "name": name, "base_ahd": round(base_ahd, 2), "_mask": (r0, c0, m),
                    "tiers": [{"ring": [(round(x, 2), round(y, 2)) for x, y in tt["ring"]], "top_ahd": tt["top_ahd"]}
                              for tt in tiers],
                    "gable": gable, "spires": spires, "family": fam[0], "family_why": fam[1], "height_src": "lidar 2019",
                    "tags": {k: t[k] for k in ("building", "name", "height", "building:levels") if k in t}})
    # overlapping OSM outlines (1 William St is mapped twice: the tower part and the whole lot): the smaller
    # outline keeps its LiDAR tiers, the larger one is cut down to its lowest tier (the podium)
    cut = 0
    recs = [b for b in out if "_mask" in b]
    for i, a in enumerate(recs):
        for b in recs[i + 1:]:
            (ra, ca, ma), (rb, cb, mb) = a["_mask"], b["_mask"]
            r0_, r1_ = max(ra, rb), min(ra + ma.shape[0], rb + mb.shape[0])
            c0_, c1_ = max(ca, cb), min(ca + ma.shape[1], cb + mb.shape[1])
            if r1_ <= r0_ or c1_ <= c0_:
                continue
            ov = (ma[r0_ - ra:r1_ - ra, c0_ - ca:c1_ - ca] & mb[r0_ - rb:r1_ - rb, c0_ - cb:c1_ - cb]).sum()
            small, big = (a, b) if ma.sum() <= mb.sum() else (b, a)
            if ov > 0.3 * min(ma.sum(), mb.sum()) and len(big["tiers"]) > 1:
                low = min(small["tiers"][0]["top_ahd"], big["tiers"][0]["top_ahd"])
                big["tiers"] = [dict(big["tiers"][0], top_ahd=low)]
                big["spires"] = []
                big["overlap_cut_by"] = small["osm"]
                cut += 1
    for b in out:
        b.pop("_mask", None)
    print("overlap cuts", cut)
    return out, skipped, built_already


def main():
    packs = [load_pack(p) for p in PACKS]
    # box: the union of the packs in Spire local metres, whole metres
    bx0 = min(math.floor(p["off"][0] + p["box"][0]) for p in packs)
    by0 = min(math.floor(p["off"][1] + p["box"][1]) for p in packs)
    bx1 = max(math.ceil(p["off"][0] + p["box"][2]) for p in packs)
    by1 = max(math.ceil(p["off"][1] + p["box"][3]) for p in packs)
    box = (bx0, by0, bx1, by1)
    H, W = by1 - by0, bx1 - bx0
    cx_ = bx0 + np.arange(W) + 0.5
    cy_ = by1 - np.arange(H) - 0.5
    X, Y = np.meshgrid(cx_, cy_)
    gnd = np.full((H, W), np.nan, "f4")
    dsm = np.full((H, W), np.nan, "f4")
    cls = np.zeros((H, W), "u1")
    best = np.full((H, W), np.inf)
    for p in packs:                                   # nearest pack origin wins (its own data is most central)
        ox, oy = p["off"]
        px0, py0, px1, py1 = p["box"]
        lx, ly = X - ox, Y - oy
        c = np.floor(lx - px0).astype(int)
        r = np.floor(py1 - ly).astype(int)
        ok = (c >= 0) & (c < px1 - px0) & (r >= 0) & (r < py1 - py0)
        d = np.hypot(lx, ly)
        take = ok & (d < best)
        rr, cc = r[take], c[take]
        gnd[take] = p["gnd"][rr, cc]
        dsm[take] = p["dsm"][rr, cc]
        cls[take] = p["cls"][rr, cc]
        best[take] = d[take]
    cover = np.isfinite(gnd)
    g = np.where(cover, gnd, np.nanmedian(gnd))
    # the river: no LiDAR return (class 0) on low ground is water; the gap fill put its surface at +1.6 to
    # +3.6 m, above the scene's water plane, so it goes under (as ground.py does for the mud flats)
    water = cover & (cls == 0) & (g < 5.0)
    water = L.box_blur(water.astype("f4"), 2) > 0.5           # no single-cell specks
    g = np.where(water, -2.0, g)
    gs =L.box_blur(L.box_blur(g, 2), 2).astype("f4")      # same smoothing idea as lidar('ground_smooth')
    os.makedirs(OUT, exist_ok=True)
    gzip.open(os.path.join(OUT, "ground_1m.f32.gz"), "wb").write(gs.astype("<f4").tobytes())
    gzip.open(os.path.join(OUT, "cover_1m.u8.gz"), "wb").write(cover.astype("u1").tobytes())

    # ---- buildings (OSM from every pack, merged by way id)
    nodes, ways = {}, {}
    for p in packs:
        ox, oy = p["off"]
        raw = json.load(gzip.open(os.path.join(p["dir"], "osm_%s_800m.json.gz" % p["id"]), "rt", encoding="utf-8"))
        for el in raw["elements"]:
            if el["type"] == "node" and el["id"] not in nodes:
                x, y = L.to_local(el["lat"], el["lon"])
                nodes[el["id"]] = (x, y)
            elif el["type"] == "way":
                ways.setdefault(el["id"], el)
    out, skipped, built_already = shape_buildings(ways, nodes, box, gnd, dsm, cls, cover, already_built)
    json.dump({"note": "CBD extension of buildings_clean.json (same rules, prep_clean.py), Spire local metres. "
                       "Made by tools/sites/clean_ext.py from the prep_site.py packs.", "buildings": out},
              open(os.path.join(OUT, "buildings_ext.json"), "w"), separators=(",", ":"))

    # ---- trees outside the LiDAR box (the master scene's trees.py covers inside it)
    lx0, ly0, lx1, ly1 = L.LIDAR_BOX
    seen, trees = set(), []
    for p in packs:
        ox, oy = p["off"]
        with open(os.path.join(p["dir"], "lidar", "tree_points.csv"), encoding="utf-8") as f:
            for r in csv.DictReader(f):
                x, y = float(r["x_local"]) + ox, float(r["y_local"]) + oy
                if lx0 <= x <= lx1 and ly0 <= y <= ly1:
                    continue
                key = (round(x / 2), round(y / 2))
                if key in seen:
                    continue
                seen.add(key)
                trees.append((round(x, 2), round(y, 2), float(r["height_m"]), float(r["ground_ahd"])))
    with open(os.path.join(OUT, "tree_points_ext.csv"), "w", newline="", encoding="utf-8") as f:
        wr = csv.writer(f)
        wr.writerow(["x_local", "y_local", "height_m", "ground_ahd"])
        wr.writerows(trees)

    # ---- aerial mosaic (0.5 m/px, north up), nearest pack first
    k = 2
    AH, AW = H * k, W * k
    img = np.zeros((AH, AW, 3), "u1")
    have = np.zeros((AH, AW), bool)
    ax = bx0 + (np.arange(AW) + 0.5) / k
    ay = by1 - (np.arange(AH) + 0.5) / k
    AX, AY = np.meshgrid(ax, ay)
    order = sorted(packs, key=lambda p: 0)
    dist = np.stack([np.hypot(AX - p["off"][0], AY - p["off"][1]) for p in order])
    rank = np.argsort(dist, 0)
    for pri in range(len(order)):
        for i, p in enumerate(order):
            fn = os.path.join(p["dir"], "aerial_%d_800m_0p5m.jpg" % AERIAL_YEAR)
            if not os.path.exists(fn):
                continue
            a = np.asarray(Image.open(fn).convert("RGB"))
            n = a.shape[0]
            c = np.floor((AX - p["off"][0] + 400) * n / 800).astype(int)
            r = np.floor((400 - (AY - p["off"][1])) * n / 800).astype(int)
            ok = (rank[pri] == i) & ~have & (c >= 0) & (c < n) & (r >= 0) & (r < n)
            px = a[r.clip(0, n - 1), c.clip(0, n - 1)]
            ok &= px.sum(-1) > 0
            ok &= ~((np.abs(px[..., 0].astype(int) - 128) < 3) & (np.abs(px[..., 1].astype(int) - 128) < 3)
                    & (np.abs(px[..., 2].astype(int) - 128) < 3))           # prep_site's grey = not covered
            img[ok] = px[ok]
            have |= ok
    img[~have] = (86, 90, 76)                          # no aerial: a muted ground colour, not black
    Image.fromarray(img).save(os.path.join(OUT, "aerial_%d_ext.jpg" % AERIAL_YEAR), quality=88)

    meta = {"box_local": list(box), "rows": H, "cols": W, "step_m": 1.0,
            "order": "rows north to south, cols west to east; cell centres at (x0+c+0.5, y1-r-0.5)",
            "packs": {p["id"]: {"offset_local": [round(p["off"][0], 2), round(p["off"][1], 2)]} for p in packs},
            "aerial": {"file": "aerial_%d_ext.jpg" % AERIAL_YEAR, "m_per_px": 1.0 / k, "cover": round(float(have.mean()), 3)},
            "buildings": len(out), "already_in_scene": built_already, "skipped": skipped, "trees": len(trees),
            "lidar_cover": round(float(cover.mean()), 3),
            "rule": "build buildings whose OSM centroid is outside buildings_clean.json's reach (LIDAR_BOX) or "
                    "outside buildings.build's +-%d m square; ground only outside LIDAR_BOX" % (L.MODEL_HALF + MODEL_PAD),
            "credit": "2019 LiDAR (c) State of Queensland CC BY 4.0; OSM (c) OpenStreetMap contributors ODbL; "
                      "aerial (c) State of Queensland / Brisbane City Council (see reference/sites/<pack>/CREDITS.md)"}
    json.dump(meta, open(os.path.join(OUT, "ext.json"), "w"), indent=1)
    print(json.dumps({k_: v for k_, v in meta.items() if k_ not in ("credit", "rule")}))
    tall = sorted(out, key=lambda b: -max(t["top_ahd"] for t in b["tiers"]))[:12]
    for b in tall:
        print("%10d %-34s top %6.1f AHD tiers %d spires %d %s" % (b["osm"], b["name"][:34], max(t["top_ahd"] for t in b["tiers"]),
                                                             len(b["tiers"]), len(b["spires"]), b["height_src"]))


if __name__ == "__main__":
    main()
