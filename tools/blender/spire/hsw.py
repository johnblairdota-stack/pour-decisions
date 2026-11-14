"""Howard Smith Wharves (its own level later). As-built from the 2019 LiDAR (captured mid-2019, after the
precinct opened in late 2018): wharf sheds, hotel, lift towers, the riverside boardwalk and the
over-water decks, as a 1 m solid surface. The cliff face is the 1 m ground patch in ground.py; the Story
Bridge above is in landmarks.py. Named OSM features in the zone are listed in the metadata for the
detailed pass. Mid-build 2017-18 state: not built yet (see the README's next steps)."""
import numpy as np

import layout as L
import common as C
import heightfield as HF
from buildings import HSW_ZONE

LOW_DECK_MAX_AHD = 12.0     # boardwalk / bar decks; the Story Bridge deck is far higher


def build():
    col = C.collection("hsw")
    x0, y0, x1, y1 = L.LIDAR_BOX
    hx0, hy0, hx1, hy1 = HSW_ZONE
    rs = slice(int(y1 - hy1), int(y1 - hy0))
    cs = slice(int(hx0 - x0), int(hx1 - x0))
    dsm, gnd, cls = L.lidar("dsm")[rs, cs], L.lidar("ground")[rs, cs], L.lidar("class")[rs, cs]
    built = (cls == 3) | ((cls == 4) & (dsm < LOW_DECK_MAX_AHD))
    over_water = built & (gnd < L.RIVER_LEVEL_AHD + 0.5)
    ob, roofs, walls = HF.heightfield("hsw_lidar_1m", col, dsm, np.maximum(gnd, L.RIVER_LEVEL_AHD - 1.0),
                                      built, hx0, hy1, 1.0, "building")
    o = L.osm()
    named = []
    for wid, w in o["ways"].items():
        t = w.get("tags", {})
        if not t.get("name"):
            continue
        P = o["line"](w)
        if not P:
            continue
        cx = sum(p[0] for p in P) / len(P)
        cy = sum(p[1] for p in P) / len(P)
        if hx0 <= cx <= hx1 and hy0 <= cy <= hy1:
            kind = next((k + "=" + t[k] for k in ("building", "amenity", "highway", "leisure", "man_made", "tourism")
                         if k in t), "")
            named.append({"name": t["name"], "kind": kind, "xy": [round(cx, 1), round(cy, 1)], "osm_way": wid})
    named.sort(key=lambda d: d["xy"][1], reverse=True)
    return {"module": "hsw", "objects": [ob.name], "zone_local": HSW_ZONE, "cells": roofs,
            "over_water_cells": int(over_water.sum()), "named_osm": named[:60],
            "mid_build_2017_18": "not built yet",
            "note": "As-built shell from LiDAR only. Facades, the corten lift towers' detail, Mr Percival's and "
                    "the boardwalk cantilevers need John's photos for the detailed pass."}
