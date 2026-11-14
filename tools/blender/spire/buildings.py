"""Neighbouring buildings.

- buildings (rendered): the 2019 LiDAR roofscape, every 1 m cell the LiDAR classed as building, solid
  down to the ground. Spire, St John's Cathedral (landmarks.py) and Howard Smith Wharves (hsw.py) are
  cut out and built by their own modules.
- buildings_lod1 (hidden, for the game's far LOD): OSM footprints extruded to the LiDAR height
  (p90 roof - median ground); OSM height/levels only where the LiDAR has nothing."""
from collections import Counter

import numpy as np

import layout as L
import common as C
import heightfield as HF
import prep_lidar as PL

CATHEDRAL_WAY = 26384715
HSW_ZONE = (380, -130, 800, 140)      # local x0, y0, x1, y1 handled by hsw.py: the strip under the cliffs, north bank


def footprints():
    """Yield (id, tags, ring) for every OSM building / building part in the model square."""
    o = L.osm()
    for wid, w in o["ways"].items():
        t = w.get("tags", {})
        if "building" in t or "building:part" in t:
            yield wid, t, C.clean_ring(o["line"](w))
    for r in o["rels"]:
        t = r.get("tags", {})
        if t.get("type") == "multipolygon" and ("building" in t or "building:part" in t):
            for m in r["members"]:
                if m.get("role") == "outer" and m["ref"] in o["ways"]:
                    yield r["id"], t, C.clean_ring(o["line"](o["ways"][m["ref"]]))


def grow(ring, k):
    cx = sum(p[0] for p in ring) / len(ring)
    cy = sum(p[1] for p in ring) / len(ring)
    return [(cx + (x - cx) * k, cy + (y - cy) * k) for x, y in ring]


def cut(mask, ring, box):
    m, r0, c0 = PL.ring_mask(ring, box)
    if m is not None:
        mask[r0:r0 + m.shape[0], c0:c0 + m.shape[1]] &= ~m


def lod1(lidar_h):
    col = C.collection("buildings_lod1")
    col.hide_render = True
    col.hide_viewport = True
    buf = C.MeshBuf()
    src = Counter()
    for oid, t, ring in footprints():
        if len(ring) < 3 or oid == L.SPIRE["osm_way"]:
            continue
        cx = sum(p[0] for p in ring) / len(ring)
        cy = sum(p[1] for p in ring) / len(ring)
        if not C.in_model(cx, cy):
            continue
        if oid in lidar_h and lidar_h[oid] > 1.0:
            h, s = lidar_h[oid], "lidar 2019"
        else:
            h, s = L.building_height(t)
        z0 = min(L.ground_z(x, y) for x, y in ring)
        buf.prism(ring, z0 - 0.5, z0 + h)
        src[s.split(" x ")[0]] += 1
    ob = buf.object("buildings_lod1_lidar_heights", col, "building")
    return ob.name, dict(src)


def build():
    col = C.collection("buildings")
    box = L.LIDAR_BOX
    x0, y0, x1, y1 = box
    cls = L.lidar("class")
    mask = (cls == 3).copy()
    cut(mask, grow(L.spire_podium_outline(), 1.1), box)
    o = L.osm()
    if CATHEDRAL_WAY in o["ways"]:
        cut(mask, grow(o["line"](o["ways"][CATHEDRAL_WAY]), 1.15), box)
    hx0, hy0, hx1, hy1 = HSW_ZONE
    mask[int(y1 - hy1):int(y1 - hy0), int(hx0 - x0):int(hx1 - x0)] = False
    ob, roofs, walls = HF.heightfield("buildings_lidar_roofscape", col, L.lidar("dsm"), L.lidar("ground"),
                                      mask, x0, y1, 1.0, "building")
    lod_name, src = lod1(L.lidar_building_heights())
    return {"module": "buildings", "objects": [ob.name, lod_name], "roof_cells": roofs, "wall_quads": walls,
            "lod1_height_source": src,
            "note": "Rendered buildings are the 2019 LiDAR roofscape (1 m). LOD1 prisms (hidden) use LiDAR "
                    "heights per OSM footprint; OSM tags only where no LiDAR roof was found. The LiDAR is "
                    "2019: buildings finished after mid-2019 are missing, earlier demolitions are gone."}
