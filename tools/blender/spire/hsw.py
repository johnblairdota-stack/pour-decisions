"""Howard Smith Wharves (its own level later), clean (step 5).
- Buildings in the HSW strip: the same clean builder as the city (OSM footprints + LiDAR-measured tiers):
  wharf sheds, the hotel (Crystalbrook Vincent), Stanley restaurant and the rest.
- The riverside boardwalk (OSM New Farm Riverwalk) as a clean timber deck on steel cantilever beams and
  headstocks, ~5 m out from the bank (RESEARCH.md: cantilevers on tensioned piles, built from land).
- The cliff is the smoothed LiDAR ground (ground.py), shown in the rock colour here.
Still to do (needs John's photos): corten lift towers, Mr Percival's, facades, the 2017-18 mid-build state."""
import math

import layout as L
import common as C
import buildings as B

DECK_AHD = 3.6
DECK_W = 5.0
CANTILEVER_STEP = 5.0


def build():
    meta = B.build(zone=B.HSW_ZONE, collection="hsw")
    col = C.collection("hsw")
    o = L.osm()
    hx0, hy0, hx1, hy1 = B.HSW_ZONE
    deck, beams = C.MeshBuf(), C.MeshBuf()
    walks = 0
    for wid, w in o["ways"].items():
        t = w.get("tags", {})
        if t.get("highway") not in ("footway", "cycleway", "living_street", "path", "pedestrian"):
            continue
        pts = o["line"](w)
        if len(pts) < 2 or not any(hx0 <= x <= hx1 and hy0 <= y <= hy1 for x, y in pts):
            continue
        near_water = [p for p in pts if L.ground_z(*p) < 2.5]
        if not near_water and "Riverwalk" not in t.get("name", ""):
            continue
        pts = C.densify(pts, 2.0)
        left, right = C.offset_line(pts, DECK_W / 2), C.offset_line(pts, -DECK_W / 2)
        n = len(pts)
        z = [max(DECK_AHD, L.ground_z(*p) + 0.15) for p in pts]
        verts = ([(x, y, zz) for (x, y), zz in zip(left, z)] + [(x, y, zz) for (x, y), zz in zip(right, z)] +
                 [(x, y, zz - 0.35) for (x, y), zz in zip(left, z)] + [(x, y, zz - 0.35) for (x, y), zz in zip(right, z)])
        faces = [[i, n + i, n + i + 1, i + 1] for i in range(n - 1)]
        faces += [[2 * n + i + 1, 3 * n + i + 1, 3 * n + i, 2 * n + i] for i in range(n - 1)]
        faces += [[i, i + 1, 2 * n + i + 1, 2 * n + i] for i in range(n - 1)]
        faces += [[n + i + 1, n + i, 3 * n + i, 3 * n + i + 1] for i in range(n - 1)]
        deck.add(verts, faces)
        acc = 0.0
        for i in range(1, n):
            acc += math.dist(pts[i - 1], pts[i])
            if acc >= CANTILEVER_STEP:
                acc = 0.0
                (lx, ly), (rx, ry) = left[i], right[i]
                beams.beam((lx, ly, z[i] - 0.6), (rx, ry, z[i] - 0.6), 0.45)                 # cantilever beam
                beams.beam(((lx + rx) / 2, (ly + ry) / 2, z[i] - 0.6),
                           ((lx + rx) / 2, (ly + ry) / 2, min(L.ground_z((lx + rx) / 2, (ly + ry) / 2), 0.0) - 1.0), 0.6)
        walks += 1
    objs = meta["objects"]
    for buf, name, key in ((deck, "hsw_boardwalk_deck", "timber"), (beams, "hsw_boardwalk_cantilevers", "steel")):
        ob = buf.object(name, col, key)
        if ob:
            objs.append(ob.name)
    return {"module": "hsw", "objects": objs, "buildings": meta["buildings"], "boardwalk_ways": walks,
            "zone_local": B.HSW_ZONE, "mid_build_2017_18": "not built yet",
            "note": "Lift towers, Mr Percival's and the mid-build state need John's photos (next step)."}
