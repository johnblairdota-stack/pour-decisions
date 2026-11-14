"""Measure clean building shapes from OSM footprints + the 2019 LiDAR (no bpy). LiDAR = measuring only.

    <blender python> -I tools/blender/spire/prep_clean.py

Writes reference/sites/spire/lidar/buildings_clean.json, one record per OSM building:
    ring        footprint, simplified to 0.3 m and squared (near-90 deg corners snapped)
    base_ahd    ground under the footprint (min of the LiDAR ground)
    tiers       [{ring, top_ahd}] stepped volumes, bottom tier = the footprint; upper tiers traced from
                the LiDAR cells of each height cluster, simplified (0.8 m) and squared
    gable       {cx, cy, length, width, angle, eave_ahd, ridge_ahd} when the roof is pitched
    spires      [{x, y, r, top_ahd}] small tall points (church spires, masts on roofs)
    family      heritage | brick | concrete | glass (facade look), with the reason
"""
import json
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import layout as L  # noqa: E402
import shapes as S  # noqa: E402
import prep_lidar as PL  # noqa: E402

OUT = os.path.join(L.REF, "lidar", "buildings_clean.json")
GAP_M = 2.0          # height gap that splits two roof tiers
MIN_TIER_CELLS = 12  # m2
HERITAGE_WORDS = ("church", "cathedral", "chapel", "House", "Hall", "Hotel", "Customs", "Deanery", "Shed", "Wharf")


def family(t, h, name):
    b = t.get("building", "")
    if b in ("church", "cathedral", "chapel") or t.get("heritage") or t.get("historic"):
        return "heritage", "OSM tags"
    sd = str(t.get("start_date", ""))[:4]
    if sd.isdigit() and int(sd) < 1940:
        return "heritage", "start_date " + sd
    if h <= 16 and any(w in name for w in HERITAGE_WORDS):
        return "heritage", "low and named like a heritage building"
    if h > 45:
        return "glass", "over 45 m"
    if h > 15:
        return "concrete", "15-45 m"
    return "brick", "low-rise"


def clusters(hs):
    """Split sorted heights into tiers at gaps > GAP_M. Returns list of (lo, hi, count)."""
    s = np.sort(hs)
    cuts = np.nonzero(np.diff(s) > GAP_M)[0]
    out, start = [], 0
    for c in list(cuts) + [len(s) - 1]:
        part = s[start:c + 1]
        out.append([float(part[0]), float(part[-1]), int(len(part))])
        start = c + 1
    # merge small tiers into the one below (or above if first)
    merged = []
    for lo, hi, n in out:
        if merged and n < MIN_TIER_CELLS:
            merged[-1][1], merged[-1][2] = hi, merged[-1][2] + n
        else:
            merged.append([lo, hi, n])
    if len(merged) > 1 and merged[0][2] < MIN_TIER_CELLS:
        merged[1][0], merged[1][2] = merged[0][0], merged[1][2] + merged[0][2]
        merged.pop(0)
    return merged


def gable_fit(ring, cells_xy, hs):
    """Fit h = a - b * |distance from the long axis| over the footprint. Pitched if b > 0.25 and R2 > 0.5."""
    cx, cy, ln, wd, ang = S.min_rect(ring)
    if wd < 4 or len(hs) < 20:
        return None
    nx, ny = -math.sin(ang), math.cos(ang)
    d = np.abs((cells_xy[:, 0] - cx) * nx + (cells_xy[:, 1] - cy) * ny)
    A = np.stack([np.ones_like(d), -d], 1)
    sol, res, *_ = np.linalg.lstsq(A, hs, rcond=None)
    a, b = sol
    pred = A @ sol
    ss = ((hs - hs.mean()) ** 2).sum()
    r2 = 1 - ((hs - pred) ** 2).sum() / ss if ss > 0 else 0
    if b < 0.25 or r2 < 0.5:
        return None
    eave = a - b * wd / 2
    return {"cx": round(cx, 2), "cy": round(cy, 2), "length": round(ln, 2), "width": round(wd, 2),
            "angle": round(ang, 4), "eave_h": round(float(eave), 2), "ridge_h": round(float(a), 2), "r2": round(float(r2), 2)}


def main():
    box = L.LIDAR_BOX
    x0, y0, x1, y1 = box
    dsm, gnd, cls = L.lidar("dsm"), L.lidar("ground"), L.lidar("class")
    o = L.osm()
    out, skipped = [], 0
    for wid, w in o["ways"].items():
        t = w.get("tags", {})
        if "building" not in t or wid == L.SPIRE["osm_way"]:
            continue
        raw = o["line"](w)
        if len(raw) < 4:
            continue
        cx = sum(p[0] for p in raw) / len(raw)
        cy = sum(p[1] for p in raw) / len(raw)
        if not (x0 + 5 < cx < x1 - 5 and y0 + 5 < cy < y1 - 5):
            continue
        ring = S.clean(raw, 0.3)
        m, r0, c0 = PL.ring_mask(ring, box)
        if m is None or m.sum() < 4:
            skipped += 1
            continue
        sub = (slice(r0, r0 + m.shape[0]), slice(c0, c0 + m.shape[1]))
        g_med = float(np.median(gnd[sub][m]))
        base_ahd = float(np.min(gnd[sub][m]))
        hcell = dsm[sub] - g_med
        roofcls = (cls[sub] == 3) | (cls[sub] == 4)
        use = m & roofcls & (hcell > 2.0)
        name = t.get("name", "")
        if use.sum() < max(4, 0.15 * m.sum()):
            h, src = L.building_height(t)
            tiers = [{"ring": ring, "top_ahd": round(g_med + h, 2)}]
            fam = family(t, h, name)
            out.append({"osm": wid, "name": name, "base_ahd": round(base_ahd, 2), "tiers": tiers,
                        "gable": None, "spires": [], "family": fam[0], "family_why": fam[1], "height_src": src})
            continue
        hs = hcell[use]
        cl = clusters(hs)
        # bottom tier: the footprint up to the lowest substantial cluster's 75th percentile
        tiers = []
        rr, cc = np.nonzero(use)
        cells_xy = np.stack([x0 + c0 + cc + 0.5, y1 - r0 - rr - 0.5], 1)
        spires = []
        for k, (lo, hi, n) in enumerate(cl):
            sel = hs >= lo - 0.01
            top = float(np.percentile(hs[(hs >= lo - 0.01) & (hs <= hi + 0.01)], 75))
            if k == 0:
                tiers.append({"ring": ring, "top_ahd": round(g_med + top, 2)})
                continue
            region = np.zeros(m.shape, bool)
            region[rr[sel], cc[sel]] = True
            loops = PL.trace(region, box, r0, c0)
            for lp in loops:
                if len(lp) < 4:
                    continue
                poly = S.ccw(S.square(S.simplify(lp, 0.8)))
                a = abs(S.area(poly))
                if a < 6:
                    continue
                if a < 50 and hi - cl[k - 1][1] > 8:
                    px = sum(p[0] for p in poly) / len(poly)
                    py = sum(p[1] for p in poly) / len(poly)
                    spires.append({"x": round(px, 2), "y": round(py, 2), "r": round(math.sqrt(a / math.pi), 2),
                                   "base_ahd": round(g_med + cl[k - 1][1], 2), "top_ahd": round(g_med + hi, 2)})
                    continue
                if a >= MIN_TIER_CELLS:
                    tiers.append({"ring": [(round(x, 2), round(y, 2)) for x, y in poly], "top_ahd": round(g_med + top, 2)})
        gable = None
        if len(cl) <= 2 and tiers[0]["top_ahd"] - g_med < 25:
            base_sel = (hs >= cl[0][0] - 0.01) & (hs <= cl[0][1] + 0.01)
            gable = gable_fit(ring, cells_xy[base_sel], hs[base_sel])
            if gable:
                gable["eave_ahd"] = round(g_med + gable.pop("eave_h"), 2)
                gable["ridge_ahd"] = round(g_med + gable.pop("ridge_h"), 2)
                tiers[0]["top_ahd"] = gable["eave_ahd"]
        hmax = max(tt["top_ahd"] for tt in tiers) - g_med
        fam = family(t, hmax, name)
        out.append({"osm": wid, "name": name, "base_ahd": round(base_ahd, 2),
                    "tiers": [{"ring": [(round(x, 2), round(y, 2)) for x, y in tt["ring"]], "top_ahd": tt["top_ahd"]}
                              for tt in tiers],
                    "gable": gable, "spires": spires, "family": fam[0], "family_why": fam[1], "height_src": "lidar 2019"})
    json.dump({"note": "Clean shapes measured from OSM footprints + 2019 LiDAR. See prep_clean.py.",
               "buildings": out}, open(OUT, "w"), separators=(",", ":"))
    fams = {}
    for b in out:
        fams[b["family"]] = fams.get(b["family"], 0) + 1
    print("buildings", len(out), "skipped", skipped, "families", fams,
          "gables", sum(1 for b in out if b["gable"]), "spires", sum(len(b["spires"]) for b in out),
          "multi-tier", sum(1 for b in out if len(b["tiers"]) > 1), "size %.1f MB" % (os.path.getsize(OUT) / 1e6))


if __name__ == "__main__":
    main()
