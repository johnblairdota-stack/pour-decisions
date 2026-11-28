"""Every OSM building over the whole 2019 LiDAR download, at its measured height and roof shape (no bpy).

    python3 tools/sites/clean_wide.py <PourDecisions-sites>/data

Mosaics <data>/cbd/elvis/grid2019 (every 1 km tile there: dsm, gnd, veg, bld) into Spire's frame and runs
clean_ext.shape_buildings (prep_clean.py's rules: roof tiers from LiDAR height clusters, gables, spires,
facade family) over every OSM building in <data>/cbd/osm/osm_all.json.gz that the scene does not build yet
(buildings_clean.json inside the +-700 m square, ext/buildings_ext.json). Writes reference/sites/spire/wide/:

    wide.json             box, counts, sources
    buildings_wide.json.gz   buildings_clean-format records + tags (building, name, height, levels, roof:shape);
                          outside the LiDAR (wide.json osm_boxes, e.g. West End) the OSM footprint at OSM's
                          own height on the QldDem ground, until those LiDAR tiles are ordered
    tree_points_wide.csv.gz  LiDAR tree tops (9 m local maxima of the canopy) outside LIDAR_BOX and the ext box;
                          outside the LiDAR, dark green 16 m cells of the aerial at a usual height
    features.json         OSM traffic signals, street lamps, motorway junctions (nodes) and parks, pitches,
                          car parks, stadiums (rings), local metres

To go further out: order more Brisbane 2019 LiDAR tiles from ELVIS, grid them with tools/lidar/grid_spire.js into
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
import lidar_houses as LH  # noqa: E402
import prep_clean as PC  # noqa: E402
import river_shape as RS  # noqa: E402
import roads_wide as RW  # noqa: E402
import shapes as S  # noqa: E402

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


# no LiDAR yet: heights for untagged buildings by OSM type (m)
TYPE_HEIGHT = {"house": 5.6, "detached": 5.6, "semidetached_house": 5.6, "terrace": 6.0, "bungalow": 4.2, "residential": 5.8,
               "apartments": 12.8, "hotel": 16.0, "dormitory": 12.8, "office": 12.8, "commercial": 8.0, "retail": 6.5,
               "industrial": 7.5, "warehouse": 7.5, "school": 7.0, "university": 12.0, "hospital": 16.0, "church": 9.0,
               "garage": 2.8, "garages": 2.8, "shed": 2.6, "roof": 3.2, "carport": 2.6, "yes": 5.6,
               "container": 2.6, "chapel": 7.0, "kindergarten": 4.5, "hut": 2.6, "kiosk": 3.0, "toilets": 3.0}


class Dem:
    """QldDem 1 m bare ground tiles of every area (dem_<E>_<N>.tif), read on demand."""

    def __init__(self, data):
        import prep_site as PS
        self.read, self.files, self.cache = PS.read_tif, {}, {}
        for area in sorted(os.listdir(data)):
            d = os.path.join(data, area, "dem", "default")
            for f in sorted(os.listdir(d)) if os.path.isdir(d) else []:
                if f.endswith(".tif"):
                    self.files.setdefault(tuple(int(v) for v in f[4:-4].split("_")), os.path.join(d, f))

    def z(self, x, y):
        E, N = x + L.ORIGIN_MGA56[0], y + L.ORIGIN_MGA56[1]
        key = (int(E // 1000) * 1000, int(N // 1000) * 1000)
        if key not in self.files:
            return None
        if key not in self.cache:
            self.cache[key] = self.read(self.files[key])
        a = self.cache[key]
        v = float(a[min(int(key[1] + 1000 - N), 999), min(int(E - key[0]), 999)])
        return v if np.isfinite(v) else None


def osm_buildings(data, ways, nodes, ox, oy, covered, keep_tags):
    """OSM buildings outside the LiDAR mosaic (West End until its tiles arrive): the footprint at OSM's own
    height (height, else levels, else a usual height for the type) on the QldDem ground."""
    rv = json.load(open(os.path.join(L.REF, "river", "river.json")))["box_local"]
    dem = Dem(data)
    out = []
    for wid, w in ways.items():
        t = w.get("tags", {})
        if "building" not in t or t.get("building") in ("no", "bridge") or (L.tag_float(t, "layer") or 0) < 0:
            continue
        rawr = [(nodes[n][0] + ox, nodes[n][1] + oy) for n in w["nodes"] if n in nodes]
        if len(rawr) < 4 or len(rawr) != len(w["nodes"]) or w["nodes"][0] != w["nodes"][-1]:
            continue
        cx = sum(q[0] for q in rawr) / len(rawr)
        cy = sum(q[1] for q in rawr) / len(rawr)
        if covered(cx, cy):
            continue                                        # the LiDAR pass has it
        if not (rv[0] < cx < rv[2] and rv[1] < cy < rv[3]):
            continue
        ring = S.clean(rawr, 0.3)
        if len(ring) < 3 or abs(S.area(ring)) < 12:
            continue
        zs = [z for z in (dem.z(x, y) for x, y in ring + [(cx, cy)]) if z is not None]
        if not zs:
            continue
        h, src = L.building_height(t)
        if src.startswith("default"):
            h, src = TYPE_HEIGHT.get(t["building"], 6.4), "usual height for the OSM type (no LiDAR yet)"
        name = t.get("name", "")
        fam = PC.family(t, h, name)
        out.append({"osm": wid, "name": name, "base_ahd": round(min(zs), 2),
                    "tiers": [{"ring": [(round(x, 2), round(y, 2)) for x, y in ring], "top_ahd": round(float(np.median(zs)) + h, 2)}],
                    "gable": None, "spires": [], "family": fam[0], "family_why": fam[1], "height_src": src,
                    "tags": {k: t[k] for k in keep_tags if k in t}})
    return out


def lidar_boxes(tiles):
    """The tiles as local boxes, one per run of tiles side by side in a row (the mosaic need not be a rectangle)."""
    rows = {}
    for g, _ in tiles:
        rows.setdefault((g["Y1"] - g["H"], g["Y1"]), []).append((g["X0"], g["X0"] + g["W"]))
    out = []
    for (n0, n1), xs in sorted(rows.items()):
        run = None
        for e0, e1 in sorted(xs):
            if run and e0 == run[1]:
                run[1] = e1
            else:
                run = [e0, e1]
                out.append((run, n0, n1))
    oE, oN = L.ORIGIN_MGA56
    return [[round(r[0] - oE, 2), round(n0 - oN, 2), round(r[1] - oE, 2), round(n1 - oN, 2)] for r, n0, n1 in out]


def aerial_trees(data, recs, covered, zone):
    """Tree spots outside the LiDAR mosaic, read off the aerial (no canopy heights there yet): one per 16 m cell
    that is largely dark green, off the buildings and the river. Heights are a usual 10-17 m."""
    import gzip
    from PIL import Image, ImageDraw
    Image.MAX_IMAGE_PIXELS = None
    rdir = os.path.join(L.REF, "river")
    rv = json.load(open(os.path.join(rdir, "river.json")))
    x0, y0, x1, y1 = rv["box_local"]
    H, W = rv["rows"], rv["cols"]
    im = np.asarray(Image.open(os.path.join(rdir, "aerial_wide.jpg")).convert("RGB")).astype("i2")
    water = np.frombuffer(gzip.open(os.path.join(rdir, "water_2m.u8.gz")).read(), "u1").reshape(H, W) > 0
    r, g, b = im[..., 0], im[..., 1], im[..., 2]
    luma = 0.3 * r + 0.59 * g + 0.11 * b
    veg = (g - r > 1) & (g - b > 6) & (luma < 105) & (luma > 22) & ~water
    mask = Image.new("1", (W, H), 0)
    dr = ImageDraw.Draw(mask)
    for bd in recs:
        dr.polygon([((x - x0) / 2, (y1 - y) / 2) for x, y in bd["tiers"][0]["ring"]], fill=1)
    veg &= ~np.asarray(mask, bool)
    k = 8                                                   # 16 m cells (the cloud render has no room for more)
    share = veg[:H // k * k, :W // k * k].reshape(H // k, k, W // k, k).mean(axis=(1, 3))
    dem = Dem(data)
    out = []
    for rr, cc in zip(*np.nonzero(share > 0.36)):
        hsh = (int(rr) * 7349 + int(cc) * 9151) % 1000 / 1000.0
        x = x0 + (cc + 0.2 + 0.6 * hsh) * 2 * k
        y = y1 - (rr + 0.2 + 0.6 * ((hsh * 7.3) % 1.0)) * 2 * k
        if not (zone[0] < x < zone[2] and zone[1] < y < zone[3]):
            continue
        if covered(x, y):
            continue
        z = dem.z(x, y)
        if z is None or z < 0.6:
            continue
        out.append((round(float(x), 1), round(float(y), 1), round(10.0 + 7.0 * ((hsh * 3.7) % 1.0), 1), round(z, 2)))
    return out


BLOCK = 2000         # m: the mosaic is shaped in blocks this size, four at a time, so memory stays flat as it grows
PAD = 300            # m of neighbouring data around a block (a building is shaped by the block its middle is in)
COVER_CELL = 50
_G = {}              # what main() shares with the block workers


def block(job):
    """Buildings (map outlines and traced ones) and tree tops whose middle is in one block of the mosaic.
    job: the block in mosaic metres (x east from the west edge, y north from the south edge)."""
    bx0, by0, bx1, by1 = job
    G = _G
    px0, py0, px1, py1 = max(0, bx0 - PAD), max(0, by0 - PAD), min(G["W"], bx1 + PAD), min(G["H"], by1 + PAD)
    w, h = px1 - px0, py1 - py0
    dsm, gnd, bld, veg = (np.full((h, w), np.nan, "f4") for _ in range(4))
    cover = np.zeros((h, w), bool)
    for g, d, tx0, ty0 in G["tiles"]:
        ty1 = ty0 + g["H"]
        ix0, ix1, iy0, iy1 = max(px0, tx0), min(px1, tx0 + g["W"]), max(py0, ty0), min(py1, ty1)
        if ix0 >= ix1 or iy0 >= iy1:
            continue
        src = (slice(ty1 - iy1, ty1 - iy0), slice(ix0 - tx0, ix1 - tx0))
        dst = (slice(py1 - iy1, py1 - iy0), slice(ix0 - px0, ix1 - px0))
        for arr, nm in ((dsm, "dsm"), (gnd, "gnd"), (bld, "bld"), (veg, "veg")):
            arr[dst] = np.memmap(os.path.join(d, nm + ".f32"), "<f4", "r", shape=(g["H"], g["W"]))[src]
        cover[dst] = True
    core = (slice(py1 - by1, py1 - by0), slice(bx0 - px0, bx1 - px0))
    none = ([], [], 0, 0, {})
    if not cover[core].any() or np.isnan(gnd).all():
        return none
    gfill = fill_nan(gnd)
    cls = np.where(~np.isnan(bld), 3, np.where(~np.isnan(veg), 2, np.where(~np.isnan(gnd), 1, 0))).astype("u1")
    dsm_f = np.where(np.isnan(dsm), gfill, dsm)

    bb = G["bbox"]
    near = (bb[:, 2] > px0) & (bb[:, 0] < px1) & (bb[:, 3] > py0) & (bb[:, 1] < py1) if len(bb) else []
    ways = {int(k): G["ways"][int(k)] for k in G["bids"][near]}
    nodes = {n: (G["nodes"][n][0] - px0, G["nodes"][n][1] - py0) for wy in ways.values() for n in wy["nodes"] if n in G["nodes"]}
    traced_ways, traced_nodes, st = LH.trace(bld, gfill, cover, ways, nodes, core)     # roofs the map has no outline for
    ways.update(traced_ways)
    nodes.update(traced_nodes)
    ox, oy = G["ox"] + px0, G["oy"] + py0                    # this block's corner in Spire local metres
    lim = L.MODEL_HALF + CE.MODEL_PAD
    lx0, ly0, lx1, ly1 = L.LIDAR_BOX
    built = [0]

    def already(cx, cy):
        if not (bx0 <= cx + px0 < bx1 and by0 <= cy + py0 < by1):
            return True                                     # the neighbouring block shapes it
        x, y = cx + ox, cy + oy
        if lx0 + 5 < x < lx1 - 5 and ly0 + 5 < y < ly1 - 5 and abs(x) <= lim and abs(y) <= lim:
            built[0] += 1
            return True
        return False

    cand = {k: wy for k, wy in ways.items() if k not in G["have"] and k != L.SPIRE["osm_way"]}
    out, skipped, _ = CE.shape_buildings(cand, nodes, (0, 0, w, h), gfill, dsm_f, cls, cover, already)
    for b in out:                                           # back to Spire local metres
        for t in b["tiers"]:
            t["ring"] = [(round(x + ox, 2), round(y + oy, 2)) for x, y in t["ring"]]
        if b["gable"]:
            b["gable"]["cx"] = round(b["gable"]["cx"] + ox, 2)
            b["gable"]["cy"] = round(b["gable"]["cy"] + oy, 2)
        for sp in b["spires"]:
            sp["x"], sp["y"] = round(sp["x"] + ox, 2), round(sp["y"] + oy, 2)
        wt = ways[b["osm"]].get("tags", {})
        b["tags"] = {k: wt[k] for k in G["keep_tags"] if k in wt}

    # tree tops: 9 m local maxima of the canopy height
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
    top = (can > 0) & (can >= m2)
    keep = np.zeros_like(top)
    keep[core] = top[core]
    rr, cc = np.nonzero(keep)
    trees = [(round(ox + c + 0.5, 1), round(oy + h - r - 0.5, 1), round(float(can[r, c]), 1), round(float(gfill[r, c]), 2))
             for r, c in zip(rr.tolist(), cc.tolist())]
    return out, trees, skipped, built[0], st


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
    # the mosaic is on whole MGA metres; local = MGA - origin, so the box has a fractional corner
    box = (E0 - L.ORIGIN_MGA56[0], N0 - L.ORIGIN_MGA56[1], E1 - L.ORIGIN_MGA56[0], N1 - L.ORIGIN_MGA56[1])
    ox, oy = box[0], box[1]
    cover = np.zeros((-(-H // COVER_CELL), -(-W // COVER_CELL)), bool)     # which 50 m cells a tile covers
    for g, _ in tiles:
        c0, r0 = (g["X0"] - E0) // COVER_CELL, (N1 - g["Y1"]) // COVER_CELL
        cover[r0:r0 + g["H"] // COVER_CELL, c0:c0 + g["W"] // COVER_CELL] = True

    raw = RW.load_osm(data)
    nodes, ways, tagged = {}, {}, []
    for el in raw["elements"]:
        if el["type"] == "node":
            x, y = L.to_local(el["lat"], el["lon"])
            nodes[el["id"]] = (x - ox, y - oy)
            if el.get("tags"):
                tagged.append(el)
        elif el["type"] == "way":
            ways[el["id"]] = el
    del raw
    have = {b["osm"] for b in json.load(open(os.path.join(L.REF, "ext", "buildings_ext.json")))["buildings"]}
    keep_tags = ("building", "name", "height", "building:levels", "roof:shape", "amenity", "leisure", "outline")
    bids, bbox = [], []                                     # every map building and the box around it (mosaic metres)
    for k, w in ways.items():
        if "building" not in w.get("tags", {}):
            continue
        pts = [nodes[n] for n in w["nodes"] if n in nodes]
        if len(pts) >= 3:
            bids.append(k)
            bbox.append((min(p[0] for p in pts), min(p[1] for p in pts), max(p[0] for p in pts), max(p[1] for p in pts)))
    _G.update(tiles=[(g, d, g["X0"] - E0, g["Y1"] - g["H"] - N0) for g, d in tiles], W=W, H=H, ox=ox, oy=oy, ways=ways,
              nodes=nodes, have=have, keep_tags=keep_tags, bids=np.array(bids), bbox=np.array(bbox, "f4"))
    jobs = [(x, y, min(x + BLOCK, W), min(y + BLOCK, H)) for y in range(0, H, BLOCK) for x in range(0, W, BLOCK)]
    import multiprocessing as mp
    out, raw_trees, skipped, built, next_id = [], [], 0, 0, LH.FIRST_ID
    traced = {"roof_ha": 0.0, "unmapped_roof_ha": 0.0, "traced_roof_ha": 0.0, "traced_buildings": 0}
    with mp.get_context("fork").Pool(min(4, os.cpu_count() or 1)) as pool:      # the workers share the map by fork
        for i, (recs, tr, sk, bu, st) in enumerate(pool.imap(block, jobs)):
            for b in recs:
                if b["osm"] < 0:                            # traced outlines are numbered per block: renumber
                    b["osm"], next_id = next_id, next_id - 1
            out += recs
            raw_trees += tr
            skipped, built = skipped + sk, built + bu
            for k in st:
                traced[k] = round(traced[k] + st[k], 1)
            print("block %d of %d: %d buildings, %d tree tops" % (i + 1, len(jobs), len(out), len(raw_trees)), flush=True)
    _G.clear()
    print("lidar outlines", traced)
    lx0, ly0, lx1, ly1 = L.LIDAR_BOX
    cand = {k: w for k, w in ways.items() if k not in have and k != L.SPIRE["osm_way"]}
    rj = json.load(open(os.path.join(L.REF, "river", "river.json")))
    wat = np.frombuffer(gzip.open(os.path.join(L.REF, "river", "water_2m.u8.gz")).read(), "u1").reshape(rj["rows"], rj["cols"]) > 0
    wb, ws = rj["box_local"], rj["step_m"]

    def on_water(x, y):
        wc, wr_ = int((x - wb[0]) / ws), int((wb[3] - y) / ws)
        return 0 <= wr_ < rj["rows"] and 0 <= wc < rj["cols"] and bool(wat[wr_, wc])

    def middle(b):
        ring = b["tiers"][0]["ring"]
        return sum(p[0] for p in ring) / len(ring), sum(p[1] for p in ring) / len(ring)

    # a traced outline over the river is a bridge deck, a ferry or a moored boat, not a building
    out = [b for b in out if not (b["osm"] < 0 and on_water(*middle(b)))]
    # ... and one that measures lower than a roof can be (a tank, a stack of pallets, a clipped tree) is not one either
    out = [b for b in out if not (b["osm"] < 0 and max(t["top_ahd"] for t in b["tiers"]) - b["base_ahd"] < LH.MIN_HEIGHT)]
    traced["traced_buildings"] = sum(1 for b in out if b["osm"] < 0)
    for b in out:                                           # the LiDAR could not measure it (over water, new since 2019)
        src = b.get("height_src", "")
        if src.startswith("lidar") or len(b["tiers"]) != 1:
            continue
        if src.startswith("default") or b["tiers"][0]["top_ahd"] - b["base_ahd"] < 2.0:
            kind = b["tags"].get("building", "yes")
            b["tiers"][0]["top_ahd"] = round(b["base_ahd"] + TYPE_HEIGHT.get(kind, 6.4), 2)
            b["height_src"] = "usual height for the OSM type (not measured)"

    def covered(x, y):                                      # inside a LiDAR tile (the mosaic need not be a rectangle)
        c, r = int((x - box[0]) // COVER_CELL), int((box[3] - y) // COVER_CELL)
        return 0 <= r < cover.shape[0] and 0 <= c < cover.shape[1] and bool(cover[r, c])

    osm_only = osm_buildings(data, cand, nodes, ox, oy, covered, keep_tags)
    out += osm_only
    os.makedirs(OUT, exist_ok=True)
    with L.wopen(os.path.join(OUT, "buildings_wide.json.gz")) as f:
        json.dump({"note": "Every OSM building over the 2019 LiDAR download (tools/sites/clean_wide.py), Spire local metres.",
                   "buildings": out}, f, separators=(",", ":"))

    # ---- tree tops (block() found them): outside the areas that already have trees, one per 6 m cell
    em = json.load(open(os.path.join(L.REF, "ext", "ext.json")))["box_local"]
    trees, seen = [], set()
    for x, y, hgt, gz in raw_trees:
        if on_water(x, y):
            continue                                        # a canopy return over the river: a mast, a crane, a bridge
        if (lx0 <= x <= lx1 and ly0 <= y <= ly1) or (em[0] <= x <= em[2] and em[1] <= y <= em[3]):
            continue
        key = (int(x // 6), int(y // 6))
        if key in seen:
            continue
        seen.add(key)
        trees.append((x, y, hgt, gz))
    lidar_trees = len(trees)
    trees += aerial_trees(data, out, covered, RS.box_local(RS.AREAS["westend"]))
    with L.wopen(os.path.join(OUT, "tree_points_wide.csv.gz")) as f:
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
    meta = {"box_local": [round(v, 2) for v in box], "lidar_tiles": len(tiles), "lidar_boxes": lidar_boxes(tiles), "buildings": len(out), "osm_only": len(osm_only),
            "osm_boxes": [[round(v, 1) for v in RS.box_local(RS.AREAS[k])] for k in RW.OSM_AREAS],
            "lidar_outlines": traced,
            "already_in_scene": built + len(have), "skipped": skipped, "families": fams, "height_sources": srcs,
            "gables": sum(1 for b in out if b["gable"]), "multi_tier": sum(1 for b in out if len(b["tiers"]) > 1),
            "spires": sum(len(b["spires"]) for b in out), "trees": len(trees), "trees_from_aerial": len(trees) - lidar_trees,
            "features": {k: len(v) for k, v in feats.items()},
            "credit": "2019 LiDAR (c) State of Queensland CC BY 4.0; OSM (c) OpenStreetMap contributors ODbL"}
    json.dump(meta, open(os.path.join(OUT, "wide.json"), "w"), indent=1)
    print(json.dumps(meta))
    for b in sorted(out, key=lambda b: -max(t["top_ahd"] for t in b["tiers"]))[:10]:
        print("%11d %-30s top %6.1f tiers %d" % (b["osm"], b["name"][:30], max(t["top_ahd"] for t in b["tiers"]), len(b["tiers"])))


if __name__ == "__main__":
    main()
