"""Make reference/sites/spire/ from the big site download (PourDecisions-sites/data/cbd).

Run once, in Blender (needs bpy only to read and write JPEGs):
    blender -b --factory-startup -P tools/blender/spire/prep_data.py -- C:/Users/John/Documents/PourDecisions-sites/data/cbd

Writes (all cropped to the 800 m square round Spire, see layout.py):
    osm_spire_800m.json.gz      OSM elements (ODbL)
    dem_1m.f32.gz + dem_1m.json  1 m ground heights, metres AHD, local grid (CC BY 4.0 State of Queensland)
    aerial_YYYY_800m_0p5m.jpg    aerials in the local frame, north up (CC BY 4.0 State of Queensland)
    aerial_YYYY_site160m_0p1m.jpg  close crops of the site for 2015-2018
    council_spire.geojson        Brisbane City Council layers near the site (CC BY 4.0 BCC)
Never reads my_photos or commons.
"""
import gzip
import json
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import layout as L  # noqa: E402

HALF = L.DATA_HALF
MARGIN = 40.0


def inside(x, y, half=HALF + MARGIN):
    return abs(x) <= half and abs(y) <= half


def in_lidar(x, y, pad=MARGIN):
    """Step 5: OSM is cropped to the LiDAR box (+ margin) so HSW and the bridge ends are in."""
    x0, y0, x1, y1 = L.LIDAR_BOX
    return x0 - pad <= x <= x1 + pad and y0 - pad <= y <= y1 + pad


# ---------------------------------------------------------------- OSM
def prep_osm(src):
    raw = json.load(gzip.open(os.path.join(src, "osm", "osm_all.json.gz"), "rt", encoding="utf-8"))
    nodes, ways, rels = {}, {}, []
    for el in raw["elements"]:
        if el["type"] == "node":
            nodes[el["id"]] = el
        elif el["type"] == "way":
            ways[el["id"]] = el
        else:
            rels.append(el)
    loc = {nid: L.to_local(n["lat"], n["lon"]) for nid, n in nodes.items()}
    keep_w = set()
    for wid, w in ways.items():
        t = w.get("tags", {})
        pts = [loc[n] for n in w["nodes"] if n in loc]
        if any(in_lidar(*p) for p in pts):
            keep_w.add(wid)
        elif "Story Bridge" in t.get("name", "") and any(inside(*p, half=1500) for p in pts):
            keep_w.add(wid)   # whole bridge, for the skyline line
    keep_r = []
    for r in rels:
        mem = [m for m in r.get("members", []) if m["type"] == "way" and m["ref"] in keep_w]
        if mem:
            r = dict(r)
            r["members"] = mem   # only the members we kept
            keep_r.append(r)
    keep_n = set()
    for wid in keep_w:
        keep_n.update(ways[wid]["nodes"])
    for nid, p in loc.items():
        if in_lidar(*p) and nodes[nid].get("tags"):
            keep_n.add(nid)
    els = []
    for nid in sorted(keep_n):
        if nid in nodes:
            n = nodes[nid]
            e = {"type": "node", "id": nid, "lat": round(n["lat"], 7), "lon": round(n["lon"], 7)}
            if n.get("tags"):
                e["tags"] = n["tags"]
            els.append(e)
    els += [ways[w] for w in sorted(keep_w)]
    els += keep_r
    out = {"note": "OpenStreetMap data (c) OpenStreetMap contributors, ODbL 1.0. Cropped to the LiDAR box "
                   "(local x -640..1040, y -940..540 round Spire Residences, 550 Queen St) + the whole Story Bridge.", "elements": els}
    p = L.ref("osm_spire_800m.json.gz")
    with gzip.open(p, "wt", encoding="utf-8") as f:
        json.dump(out, f, separators=(",", ":"))
    print("osm: %d nodes, %d ways, %d relations -> %s (%.1f MB)" % (len(keep_n), len(keep_w), len(keep_r), p,
                                                                    os.path.getsize(p) / 1e6))


# ---------------------------------------------------------------- DEM
def read_tif(path):
    b = open(path, "rb").read()
    bo = "<" if b[:2] == b"II" else ">"
    import struct
    off = struct.unpack(bo + "I", b[4:8])[0]
    n = struct.unpack(bo + "H", b[off:off + 2])[0]
    tags = {}
    for i in range(n):
        e = b[off + 2 + 12 * i: off + 14 + 12 * i]
        tag, typ, cnt = struct.unpack(bo + "HHI", e[:8])
        size = {1: 1, 2: 1, 3: 2, 4: 4, 5: 8, 11: 4, 12: 8, 16: 8}.get(typ, 1) * cnt
        raw = e[8:12] if size <= 4 else b[struct.unpack(bo + "I", e[8:12])[0]:][:size]
        fmt = {3: "H", 4: "I", 11: "f", 12: "d", 16: "Q"}.get(typ)
        tags[tag] = struct.unpack(bo + fmt * cnt, raw[:size]) if fmt else raw[:size]
    w, h = tags[256][0], tags[257][0]
    assert tags.get(259, (1,))[0] == 1, "compressed TIFF"
    dt = np.dtype(bo + "f4")
    if 322 in tags:
        tw, th = tags[322][0], tags[323][0]
        out = np.zeros((h, w), "f4")
        txn = (w + tw - 1) // tw
        for k, (o, c) in enumerate(zip(tags[324], tags[325])):
            ty, tx = divmod(k, txn)
            blk = np.frombuffer(b[o:o + c], dt).reshape(th, tw)
            hh, ww = min(th, h - ty * th), min(tw, w - tx * tw)
            out[ty * th:ty * th + hh, tx * tw:tx * tw + ww] = blk[:hh, :ww]
        return out
    data = b"".join(b[o:o + c] for o, c in zip(tags[273], tags[279]))
    return np.frombuffer(data[:w * h * 4], dt).reshape(h, w).astype("f4")


def prep_dem(src):
    E0, N0 = L.ORIGIN_MGA56
    d = os.path.join(src, "dem", "default")
    tiles = {}

    def tile(te, tn):
        if (te, tn) not in tiles:
            tiles[(te, tn)] = read_tif(os.path.join(d, "dem_%d_%d.tif" % (te, tn)))
        return tiles[(te, tn)]

    step = 1.0
    xs = np.arange(-HALF, HALF + step / 2, step)
    ys = np.arange(HALF, -HALF - step / 2, -step)
    out = np.zeros((len(ys), len(xs)), "f4")
    for r, y in enumerate(ys):
        N = N0 + y
        for c, x in enumerate(xs):
            E = E0 + x
            # DEM pixel centres sit at (E0+0.5, N-0.5) inside each 1 km tile; bilinear between centres
            fe, fn = E - 0.5, N - 0.5
            e0, n0 = math.floor(fe), math.floor(fn)
            ax, ay = fe - e0, fn - n0
            v = 0.0
            for de, dn, wgt in ((0, 0, (1 - ax) * (1 - ay)), (1, 0, ax * (1 - ay)), (0, 1, (1 - ax) * ay), (1, 1, ax * ay)):
                ee, nn = e0 + de, n0 + dn
                te, tn = int(ee // 1000) * 1000, int(nn // 1000) * 1000
                a = tile(te, tn)
                v += wgt * a[999 - (nn - tn), ee - te]
            out[r, c] = v
    bad = out < -100
    if bad.any():
        out[bad] = 0.0
    with gzip.open(L.ref("dem_1m.f32.gz"), "wb") as f:
        f.write(out.astype("<f4").tobytes())
    json.dump({"rows": out.shape[0], "cols": out.shape[1], "x0": -HALF, "y0": HALF, "step": step,
               "units": "metres AHD", "order": "rows north to south, cols west to east, sample at grid point",
               "nodata_filled": int(bad.sum()),
               "source": "Queensland DEM image service (QldDem, default mix), 1 m tiles, MGA56",
               "credit": "(c) State of Queensland (Department of Resources) 2026, CC BY 4.0"},
              open(L.ref("dem_1m.json"), "w"), indent=1)
    print("dem: %s, %.2f..%.2f m AHD, nodata filled %d" % (out.shape, out.min(), out.max(), bad.sum()))


# ---------------------------------------------------------------- aerials
def load_img(path):
    import bpy
    im = bpy.data.images.load(path)
    w, h = im.size
    a = np.empty(w * h * 4, "f4")
    im.pixels.foreach_get(a)
    bpy.data.images.remove(im)
    return a.reshape(h, w, 4)[::-1, :, :3].copy()   # row 0 = top


def save_img(arr, path, quality=88):
    import bpy
    h, w = arr.shape[:2]
    im = bpy.data.images.new("tmp", w, h, alpha=False)
    rgba = np.ones((h, w, 4), "f4")
    rgba[:, :, :3] = arr
    im.pixels.foreach_set(rgba[::-1].ravel())
    im.filepath_raw = path
    im.file_format = "JPEG" if path.lower().endswith(".jpg") else "PNG"
    try:
        im.save(quality=quality)
    except TypeError:
        im.save()
    bpy.data.images.remove(im)


def bilinear(img, col, row):
    h, w = img.shape[:2]
    col = np.clip(col, 0, w - 1.001)
    row = np.clip(row, 0, h - 1.001)
    c0, r0 = col.astype(int), row.astype(int)
    fc, fr = (col - c0)[..., None], (row - r0)[..., None]
    return ((img[r0, c0] * (1 - fc) + img[r0, c0 + 1] * fc) * (1 - fr)
            + (img[r0 + 1, c0] * (1 - fc) + img[r0 + 1, c0 + 1] * fc) * fr)


def prep_aerials(src):
    lat, lon = L.ORIGIN_LATLON
    k = 1.0 / math.cos(math.radians(lat))
    mx, my = L.to_merc(lon, lat)
    bx0, by0, bx1, by1 = mx - 400 * k, my - 400 * k, mx + 400 * k, my + 400 * k   # as fetch_sites merc_box
    A = L.local_to_merc_affine()
    d = os.path.join(src, "aerial", "spire_c")
    for yr in (2015, 2016, 2017, 2018, 2022):
        n = load_img(os.path.join(d, "aerial_%d_800m_0p2m_n.jpg" % yr))
        s = load_img(os.path.join(d, "aerial_%d_800m_0p2m_s.jpg" % yr))
        img = np.concatenate([n, s], 0)
        H, W = img.shape[:2]
        for spec, tag in ((L.AERIAL_800, "800m_0p5m"), (L.AERIAL_SITE, "site160m_0p1m")):
            if tag.startswith("site") and yr > 2018:
                continue
            px, mpp, half = spec["px"], spec["m_per_px"], spec["half"]
            v = -half + (np.arange(px) + 0.5) * mpp
            X, Y = np.meshgrid(v, -v)          # row 0 = north
            MX = A[0, 0] * X + A[0, 1] * Y + A[0, 2]
            MY = A[1, 0] * X + A[1, 1] * Y + A[1, 2]
            col = (MX - bx0) / (bx1 - bx0) * W - 0.5
            row = (by1 - MY) / (by1 - by0) * H - 0.5
            out = bilinear(img, col, row)
            # the download box is a few metres short at the north edge (Web Mercator y scale): grey, not smeared
            miss = (col < -0.5) | (col > W - 0.5) | (row < -0.5) | (row > H - 0.5)
            out[miss] = 0.5
            p = L.aerial_path(yr, tag)
            save_img(out, p)
            print("aerial %d %s -> %s (%.1f MB)" % (yr, tag, p, os.path.getsize(p) / 1e6))


# ---------------------------------------------------------------- council
COUNCIL = ["commercial-vehicle-loading-zones", "two-minute-passenger-loading-zones", "brisbane-bus-stops",
           "cp14-road-hierarchy-overlay-road-hierarchy", "bikeway-sections", "cp14-bicycle-network-overlay",
           "cp14-significant-landscape-tree-overlay",
           "protected-vegetation-natural-assets-local-law-2003-significant-urban-vegetation",
           "parking-sign-locations", "parking-line-locations", "bicycle-racks", "park-locations",
           "public-toilets-in-brisbane"]


def coords_of(g):
    if g is None:
        return []
    t, c = g["type"], g.get("coordinates")
    if t == "Point":
        return [c]
    if t in ("LineString", "MultiPoint"):
        return c
    if t in ("Polygon", "MultiLineString"):
        return [p for r in c for p in r]
    if t == "MultiPolygon":
        return [p for poly in c for r in poly for p in r]
    if t == "GeometryCollection":
        return [p for gg in g["geometries"] for p in coords_of(gg)]
    return []


def prep_council(src):
    feats, counts = [], {}
    for name in COUNCIL:
        p = os.path.join(src, "council", name + ".geojson")
        if not os.path.exists(p):
            continue
        gj = json.load(open(p, encoding="utf-8"))
        n = 0
        for f in gj.get("features", []):
            pts = coords_of(f.get("geometry"))
            if pts and any(inside(*L.to_local(q[1], q[0])) for q in pts):
                f = dict(f)
                f["properties"] = dict(f.get("properties") or {}, layer=name)
                feats.append(f)
                n += 1
        counts[name] = n
    out = {"type": "FeatureCollection",
           "note": "Brisbane City Council open data (data.brisbane.qld.gov.au), CC BY 4.0. Cropped to 880 m "
                   "square round Spire Residences. 'layer' property = source dataset id.",
           "counts": counts, "features": feats}
    p = L.ref("council_spire.geojson")
    json.dump(out, open(p, "w", encoding="utf-8"), separators=(",", ":"))
    print("council:", counts, "-> %.1f MB" % (os.path.getsize(p) / 1e6))


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    src = argv[0] if argv else r"C:\Users\John\Documents\PourDecisions-sites\data\cbd"
    only = set(argv[1].split(",")) if len(argv) > 1 else {"osm", "dem", "aerial", "council"}
    os.makedirs(L.REF, exist_ok=True)
    if "osm" in only:
        prep_osm(src)
    if "dem" in only:
        prep_dem(src)
    if "council" in only:
        prep_council(src)
    if "aerial" in only:
        prep_aerials(src)


if __name__ == "__main__":
    main()
