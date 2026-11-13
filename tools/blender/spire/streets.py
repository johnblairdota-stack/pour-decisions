"""Streets from OSM: carriageways, footpaths with kerbs, and footways. Grey blockout."""
import math
from collections import Counter

import layout as L
import common as C

CAR = {"primary", "secondary", "tertiary", "secondary_link", "tertiary_link", "primary_link",
       "unclassified", "residential", "service", "living_street"}
WALK = {"footway", "pedestrian", "steps", "cycleway", "path"}
ROAD_Z = {"primary": 0.040, "primary_link": 0.040, "secondary": 0.036, "secondary_link": 0.036,
          "tertiary": 0.032, "tertiary_link": 0.032}


def road_width(t):
    w = L.tag_float(t, "width")
    if w:
        return w, "osm width"
    lanes = L.tag_float(t, "lanes")
    if lanes:
        return max(lanes * L.LANE_WIDTH, 3.0), "lanes x %.1f" % L.LANE_WIDTH
    return L.ROAD_WIDTH.get(t["highway"], 6.0), "class default"


def ribbon(buf, left, right, lift):
    """Quad strip between two offset lines draped on the DEM."""
    n = len(left)
    if n < 2:
        return
    verts = [(x, y, L.ground_z(x, y) + lift) for x, y in left] + [(x, y, L.ground_z(x, y) + lift) for x, y in right]
    faces = [[i, n + i, n + i + 1, i + 1] for i in range(n - 1)]
    buf.add(verts, faces)


def kerb_band(buf, inner, outer):
    """Footpath band: top at kerb height, with a kerb face down to the road along `inner`."""
    n = len(inner)
    if n < 2:
        return
    zi = [L.ground_z(x, y) for x, y in inner]
    zo = [L.ground_z(x, y) for x, y in outer]
    top_i = [(x, y, z + L.KERB_HEIGHT) for (x, y), z in zip(inner, zi)]
    top_o = [(x, y, z + L.KERB_HEIGHT) for (x, y), z in zip(outer, zo)]
    low_i = [(x, y, z + 0.01) for (x, y), z in zip(inner, zi)]
    verts = top_i + top_o + low_i
    faces = [[i, i + 1, n + i + 1, n + i] for i in range(n - 1)]               # top
    faces += [[2 * n + i, 2 * n + i + 1, i + 1, i] for i in range(n - 1)]       # kerb face
    buf.add(verts, faces)


def build():
    o = L.osm()
    col = C.collection("streets")
    roads, paths, walks = C.MeshBuf(), C.MeshBuf(), C.MeshBuf()
    # how many car roads meet at each node: footpaths stop short of junctions
    deg = Counter()
    car_ways = []
    for wid, w in o["ways"].items():
        t = w.get("tags", {})
        if t.get("highway") in CAR and t.get("bridge", "no") == "no" and t.get("tunnel", "no") == "no" \
                and t.get("area") != "yes" and str(t.get("layer", "0")) in ("0", "-0"):
            car_ways.append(w)
            deg[w["nodes"][0]] += 1
            deg[w["nodes"][-1]] += 1
    width_src = Counter()
    n_car = n_walk = 0
    for w in car_ways:
        t = w["tags"]
        pts = o["line"](w)
        if len(pts) < 2 or not any(C.in_model(x, y, 20) for x, y in pts):
            continue
        wd, src = road_width(t)
        width_src[src] += 1
        lift = ROAD_Z.get(t["highway"], 0.028)
        pts = C.densify(pts)
        ribbon(roads, C.offset_line(pts, wd / 2), C.offset_line(pts, -wd / 2), lift)
        n_car += 1
        if t["highway"] == "service" or t.get("sidewalk") == "no":
            continue
        cut0 = wd if deg[w["nodes"][0]] > 1 else 0.0
        cut1 = wd if deg[w["nodes"][-1]] > 1 else 0.0
        core = C.trim_line(pts, cut0, cut1)
        if len(core) < 2 or C.line_length(core) < 2:
            continue
        for side in (1, -1):
            inner = C.offset_line(core, side * wd / 2)
            outer = C.offset_line(core, side * (wd / 2 + L.FOOTPATH_WIDTH))
            if side < 0:
                inner, outer = inner[::-1], outer[::-1]
            kerb_band(paths, inner, outer)
    for wid, w in o["ways"].items():
        t = w.get("tags", {})
        if t.get("highway") in WALK and t.get("area") != "yes" and t.get("bridge", "no") == "no" \
                and t.get("tunnel", "no") == "no" and str(t.get("layer", "0")) == "0":
            pts = o["line"](w)
            if len(pts) < 2 or not any(C.in_model(x, y) for x, y in pts):
                continue
            wd = L.ROAD_WIDTH.get(t["highway"], 2.0)
            pts = C.densify(pts)
            ribbon(walks, C.offset_line(pts, wd / 2), C.offset_line(pts, -wd / 2), 0.05)
            n_walk += 1
    objs = [ob.name for ob in (roads.object("roads", col, "road"), paths.object("footpaths_kerbs", col, "footpath"),
                               walks.object("footways", col, "footway")) if ob]
    return {"module": "streets", "objects": objs, "car_ways": n_car, "walk_ways": n_walk,
            "width_source": dict(width_src), "footpath_width_m": L.FOOTPATH_WIDTH, "kerb_m": L.KERB_HEIGHT,
            "note": "Footpath widths are a CBD default, not measured. Bridges/tunnels/upper layers left out "
                    "(Story Bridge is in landmarks.py)."}
