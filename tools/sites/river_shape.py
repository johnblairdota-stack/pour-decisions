"""The real Brisbane River shape round the master Spire scene, traced from the aerials (no bpy).

    python3 tools/sites/river_shape.py <PourDecisions-sites>/data

Inputs (raw download on John's PC, staged up): the newest wide aerials of the CBD, Portside and West End areas
(<data>/{cbd,portside,westend}/aerial/area_newest_wide.jpg, EPSG:3857 over fetch_sites.AREAS boxes) and the 2019
LiDAR grids (<data>/cbd/elvis/grid2019/<E>_<N>/dsm.f32; the gridder drops class 9 water, so open water
has no surface at all).

Water = a dark, smooth aerial pixel (outside the LiDAR) or no LiDAR surface on a dark-ish pixel (inside it).
Bridges cut the river into reaches, so a 22 m closing joins them under the decks; reaches under 3 ha go
(ponds, pools, tower shadows). Writes reference/sites/spire/river/:

    river.json          box (Spire local metres), step 2 m, sources, area, reach count
    water_2m.u8.gz      1 = river, rows north to south
    river_outline.json  river banks as closed loops (local metres, simplified 2 m)
    aerial_wide.jpg     both aerials resampled onto the same grid (for draping the far ground)
    ground_wide_8m.f32.gz  LiDAR ground (else QldDem 1 m tiles, else NaN) every 8 m, for the far ground
"""
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
import prep_lidar as PL  # noqa: E402
import shapes as S  # noqa: E402

AREAS = {"cbd": (153.0080, -27.4870, 153.0520, -27.4500),          # fetch_sites.AREAS boxes (w, s, e, n)
         "portside": (153.0540, -27.4530, 153.0860, -27.4250),
         "westend": (152.9870, -27.5010, 153.0280, -27.4660),
         "paddington": (152.98037, -27.46500, 153.00951, -27.44803),
         "gabba": (153.03098, -27.50111, 153.05001, -27.48413),
         "downriver_n": (153.03097, -27.44694, 153.10057, -27.42994),
         "downriver_s": (153.05122, -27.47402, 153.10059, -27.44799),
         "northwest": (152.98037, -27.44694, 153.02975, -27.42994),
         "southeast": (153.05122, -27.50111, 153.10059, -27.47510)}
MUD = {"westend": (93, 85, 67)}                             # that aerial's river is brown flood water, not dark
STEP = 2.0
OUT = os.path.join(L.REF, "river")
MIN_REACH_M2 = 30000
CLOSE_M = 22.0


def merc_fit(box):
    """Quadratic fit local (x, y) -> Web Mercator over a lon/lat box (TM vs Mercator over a few km)."""
    w, s, e, n = box
    rows, rhs = [], []
    for lat in np.linspace(s - 0.01, n + 0.01, 15):
        for lon in np.linspace(w - 0.01, e + 0.01, 15):
            x, y = L.to_local(lat, lon)
            rows.append([1, x, y, x * x, x * y, y * y])
            rhs.append(L.to_merc(lon, lat))
    sol, *_ = np.linalg.lstsq(np.array(rows), np.array(rhs), rcond=None)
    return sol


def merc_of(sol, X, Y):
    F = np.stack([np.ones_like(X), X, Y, X * X, X * Y, Y * Y], -1)
    M = F @ sol
    return M[..., 0], M[..., 1]


def box_local(box):
    w, s, e, n = box
    pts = [L.to_local(la, lo) for la in (s, n) for lo in (w, e)]
    return (min(p[0] for p in pts), min(p[1] for p in pts), max(p[0] for p in pts), max(p[1] for p in pts))


def blur(a, r):
    return L.box_blur(a.astype("f4"), r)


def dilate(m, r):
    return blur(m, r) > 1e-3


def erode(m, r):
    return blur(m, r) > 1 - 1e-3


def label(mask):
    """Connected components (4-neighbour) by min-propagation with pointer jumping. Returns labels (-1 = off)."""
    H, W = mask.shape
    idx = np.arange(H * W).reshape(H, W)
    big = H * W
    lab = np.where(mask, idx, big)
    while True:
        n = lab.copy()
        n[1:, :] = np.minimum(n[1:, :], np.where(mask[:-1, :], lab[:-1, :], big))
        n[:-1, :] = np.minimum(n[:-1, :], np.where(mask[1:, :], lab[1:, :], big))
        n[:, 1:] = np.minimum(n[:, 1:], np.where(mask[:, :-1], lab[:, :-1], big))
        n[:, :-1] = np.minimum(n[:, :-1], np.where(mask[:, 1:], lab[:, 1:], big))
        n = np.where(mask, n, big)
        flat = n.ravel()
        ok = flat < big
        for _ in range(4):                                  # pointer jumping
            flat[ok] = flat[flat[ok]]
        n = flat.reshape(H, W)
        if np.array_equal(n, lab):
            return np.where(mask, lab, -1)
        lab = n


def label_coarse(mask, f=4):
    """label() on f x f blocks (any cell set), mapped back to the fine cells: fast enough in numpy."""
    H, W = mask.shape
    Hc, Wc = (H + f - 1) // f, (W + f - 1) // f
    pad = np.zeros((Hc * f, Wc * f), bool)
    pad[:H, :W] = mask
    mc = pad.reshape(Hc, f, Wc, f).any(axis=(1, 3))
    lc = label(mc)
    fine = np.repeat(np.repeat(lc, f, 0), f, 1)[:H, :W]
    return np.where(mask, fine, -1)


def main():
    data = sys.argv[1]
    boxes = {k: box_local(v) for k, v in AREAS.items()}
    x0 = math.floor(min(b[0] for b in boxes.values()) / 8) * 8
    y0 = math.floor(min(b[1] for b in boxes.values()) / 8) * 8
    x1 = math.ceil(max(b[2] for b in boxes.values()) / 8) * 8
    y1 = math.ceil(max(b[3] for b in boxes.values()) / 8) * 8
    W, H = int((x1 - x0) / STEP), int((y1 - y0) / STEP)
    X, Y = np.meshgrid(x0 + (np.arange(W) + 0.5) * STEP, y1 - (np.arange(H) + 0.5) * STEP)
    rgb = np.zeros((H, W, 3), "u1")
    have = np.zeros((H, W), bool)
    muddy = np.zeros((H, W), bool)                          # pixels from an aerial flown with the river in flood
    for area, box in AREAS.items():
        jpg = os.path.join(data, area, "aerial", "area_newest_wide.jpg")
        if not os.path.exists(jpg):                         # an area listed before its data is fetched
            continue
        im = np.asarray(Image.open(jpg).convert("RGB"))
        h, w = im.shape[:2]
        mx0, my0 = L.to_merc(box[0], box[1])
        mx1, my1 = L.to_merc(box[2], box[3])
        sol = merc_fit(box)
        MX, MY = merc_of(sol, X, Y)
        c = np.floor((MX - mx0) / (mx1 - mx0) * w).astype(int)
        r = np.floor((my1 - MY) / (my1 - my0) * h).astype(int)
        ok = (c >= 0) & (c < w) & (r >= 0) & (r < h) & ~have
        rgb[ok] = im[r[ok], c[ok]]
        have |= ok
        if area in MUD:
            muddy |= ok
    luma = rgb.astype("f4") @ np.array([0.3, 0.59, 0.11], "f4")
    var = np.sqrt(np.maximum(blur(luma * luma, 2) - blur(luma, 2) ** 2, 0))
    dark_smooth = have & (luma < 75) & (var < 9)
    for area, col in MUD.items():                           # brown flood water: smooth and the river's own colour
        d = np.abs(rgb.astype("f4") - np.array(col, "f4")).max(-1)
        dark_smooth |= muddy & (d < 26) & (var < 7)

    # LiDAR: no surface at all = water (the gridder drops class 9)
    gdir = os.path.join(data, "cbd", "elvis", "grid2019")
    nolid = np.zeros((H, W), bool)
    inlid = np.zeros((H, W), bool)
    gnd8 = np.full(((H + 3) // 4, (W + 3) // 4), np.nan, "f4")
    E = X + L.ORIGIN_MGA56[0]
    N = Y + L.ORIGIN_MGA56[1]
    for t in sorted(os.listdir(gdir)):
        g = json.load(open(os.path.join(gdir, t, "grid.json")))
        TE, TN1, TW, TH = g["X0"], g["Y1"], g["W"], g["H"]
        dsm = np.fromfile(os.path.join(gdir, t, "dsm.f32"), "<f4").reshape(TH, TW)
        gnd = np.fromfile(os.path.join(gdir, t, "gnd.f32"), "<f4").reshape(TH, TW)
        c = np.floor(E - TE).astype(int)
        r = np.floor(TN1 - N).astype(int)
        ok = (c >= 0) & (c < TW) & (r >= 0) & (r < TH)
        inlid |= ok
        nolid[ok] = np.isnan(dsm[r[ok], c[ok]])
        g8 = gnd[r[ok], c[ok]]
        rr, cc = np.nonzero(ok)
        sel = (rr % 4 == 0) & (cc % 4 == 0)
        gnd8[rr[sel] // 4, cc[sel] // 4] = g8[sel]
    # gaps in the LiDAR ground: the QldDem 1 m tiles (river bed included), else stay NaN
    import prep_site as PS  # noqa: E402  (tools/sites, for read_tif)
    rr, cc = np.nonzero(np.isnan(gnd8))
    tifs = {}
    for area in AREAS:
        ddir = os.path.join(data, area, "dem", "default")
        for f in sorted(os.listdir(ddir)) if os.path.isdir(ddir) else []:
            if f.endswith(".tif"):
                tifs.setdefault(f, os.path.join(ddir, f))
    for f, path in sorted(tifs.items()):
        TE, TN0 = [int(v) for v in f[4:-4].split("_")]
        a = PS.read_tif(path)
        e_ = E[rr * 4, cc * 4] - TE
        n_ = TN0 + 1000 - N[rr * 4, cc * 4]
        ok = (e_ >= 0) & (e_ < 1000) & (n_ >= 0) & (n_ < 1000)
        gnd8[rr[ok], cc[ok]] = a[n_[ok].astype(int), e_[ok].astype(int)]
    # inside the LiDAR, no surface = water; the aerial only vetoes bright cells, and has thin gaps between areas
    water = np.where(inlid, nolid & (~have | (luma < 110)), dark_smooth)
    water = erode(dilate(water, 1), 1)                       # fill specks (boats, wakes)

    lab = label_coarse(water)
    ids, cnt = np.unique(lab[lab >= 0], return_counts=True)
    keep_ids = ids[cnt * STEP * STEP >= MIN_REACH_M2]
    river = np.isin(lab, keep_ids)
    k = int(round(CLOSE_M / STEP))                           # join reaches under the bridges
    river = erode(dilate(river, k), k) | river
    lab2 = label_coarse(river)
    ids2, cnt2 = np.unique(lab2[lab2 >= 0], return_counts=True)
    river = np.isin(lab2, ids2[cnt2 * STEP * STEP >= MIN_REACH_M2])
    # there are no islands in these reaches: "land" inside the river under 5 ha is a boat, pontoon, wake,
    # bridge pier or shadow the classifier missed, so it is water
    land = label_coarse(~river)
    ids3, cnt3 = np.unique(land[land >= 0], return_counts=True)
    holes = np.isin(land, ids3[cnt3 * STEP * STEP < 50000])
    river |= holes
    print("holes filled (ha)", round(float(holes.sum()) * STEP * STEP / 1e4, 2))

    os.makedirs(OUT, exist_ok=True)
    gzip.open(os.path.join(OUT, "water_2m.u8.gz"), "wb").write(river.astype("u1").tobytes())
    gzip.open(os.path.join(OUT, "ground_wide_8m.f32.gz"), "wb").write(gnd8.astype("<f4").tobytes())
    rgb[~have] = (80, 93, 68)                      # outside both aerials: the far_land green, not black
    Image.fromarray(rgb).save(os.path.join(OUT, "aerial_wide.jpg"), quality=86)
    # outlines at 2 m: trace the cell mask (prep_lidar.trace works on 1 m cells; scale the loops)
    loops = PL.trace(river, (0, 0, W, H))
    out_loops = []
    for lp in loops:
        if len(lp) < 8:
            continue
        pts = [(x0 + px * STEP, y1 - (H - py) * STEP) for px, py in lp]
        pts = S.simplify(pts, 2.0)
        if abs(S.area(pts)) < 2000:
            continue
        out_loops.append([(round(x, 1), round(y, 1)) for x, y in pts])
    json.dump({"note": "Brisbane River banks traced from the aerials + 2019 LiDAR (tools/sites/river_shape.py)",
               "loops": out_loops}, open(os.path.join(OUT, "river_outline.json"), "w"), separators=(",", ":"))
    meta = {"box_local": [x0, y0, x1, y1], "step_m": STEP, "rows": H, "cols": W,
            "ground_8m": {"rows": gnd8.shape[0], "cols": gnd8.shape[1], "step_m": STEP * 4,
                          "order": "rows north to south from y1, cell centres (x0 + (4c+0.5)*2, y1 - (4r+0.5)*2)"},
            "order": "rows north to south, cell centres at (x0+(c+0.5)*step, y1-(r+0.5)*step)",
            "river_area_ha": round(float(river.sum()) * STEP * STEP / 1e4, 1), "reaches_kept": int(len(keep_ids)),
            "loops": len(out_loops), "aerial_cover": round(float(have.mean()), 3),
            "lidar_cover": round(float(inlid.mean()), 3),
            "sources": {"aerial": "Qld AerialOrtho newest (area_newest_wide.jpg, every area in AREAS)",
                        "lidar": "Brisbane 2019 LiDAR grid2019 (dsm NaN = water)", "dem": "QldDem default 1 m"},
            "credit": "(c) State of Queensland (Department of Resources) CC BY 4.0"}
    json.dump(meta, open(os.path.join(OUT, "river.json"), "w"), indent=1)
    print(json.dumps(meta))
    # check image: river in blue over the aerial
    chk = rgb.copy()
    chk[river] = (chk[river] * 0.4 + np.array([30, 90, 200]) * 0.6).astype("u1")
    Image.fromarray(chk).resize((W // 2, H // 2)).save(os.path.join(OUT, "check_river.jpg"), quality=80)


if __name__ == "__main__":
    main()
