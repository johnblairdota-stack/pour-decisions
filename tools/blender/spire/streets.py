"""Streets from OSM: carriageways with a 2.5 % crown (camber), line marking (dashed centre / lane lines,
edge lines), footpaths with 150 mm kerbs, driveways (OSM service=driveway, no footpath), footways, and
bus stops (council brisbane-bus-stops: pole + sign, shelters at the busy ones)."""
import json
import os
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


CROSSFALL = 0.025
GUTTER = None


def crowned(buf, pts, wd, lift):
    """Carriageway with a crown: centre line raised CROSSFALL x half width over the kerb lines."""
    n = len(pts)
    if n < 2:
        return
    left, right = C.offset_line(pts, wd / 2), C.offset_line(pts, -wd / 2)
    crown = CROSSFALL * wd / 2
    verts = ([(x, y, L.ground_z(x, y) + lift) for x, y in left] + [(x, y, L.ground_z(x, y) + lift + crown) for x, y in pts] +
             [(x, y, L.ground_z(x, y) + lift) for x, y in right])
    faces = [[i, n + i, n + i + 1, i + 1] for i in range(n - 1)] + [[n + i, 2 * n + i, 2 * n + i + 1, n + i + 1] for i in range(n - 1)]
    buf.add(verts, faces)


def dashes(buf, pts, off, z_lift, dash=3.0, gap=6.0, w=0.12, solid=False):
    """Road marking strip `off` metres left of the centre line; dashed unless solid."""
    line = C.offset_line(pts, off)
    acc, on = 0.0, True
    seg = [line[0]]
    for i in range(1, len(line)):
        a, b = line[i - 1], line[i]
        ln = math.dist(a, b)
        acc += ln
        seg.append(b)
        if solid:
            continue
        if acc >= (dash if on else gap):
            if on and len(seg) > 1:
                _strip(buf, seg, w, z_lift)
            on, acc, seg = not on, 0.0, [b]
    if (on or solid) and len(seg) > 1:
        _strip(buf, seg, w, z_lift)


def _strip(buf, seg, w, z_lift):
    n = len(seg)
    l, r = C.offset_line(seg, w / 2), C.offset_line(seg, -w / 2)
    verts = [(x, y, L.ground_z(x, y) + z_lift) for x, y in l] + [(x, y, L.ground_z(x, y) + z_lift) for x, y in r]
    buf.add(verts, [[i, n + i, n + i + 1, i + 1] for i in range(n - 1)])


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
    if GUTTER is not None:                                                      # 0.4 m channel at the road edge
        gut = C.offset_line(inner, -0.4)
        verts = [(x, y, z + 0.035) for (x, y), z in zip(inner, zi)] + [(x, y, z + 0.035) for (x, y), z in zip(gut, zi)]
        GUTTER.add(verts, [[i, n + i, n + i + 1, i + 1] for i in range(n - 1)])


def build():
    o = L.osm()
    col = C.collection("streets")
    roads, paths, walks, lines = C.MeshBuf(), C.MeshBuf(), C.MeshBuf(), C.MeshBuf()
    global GUTTER
    GUTTER = C.MeshBuf()
    n_drive = 0
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
        if len(pts) < 2 or not any(C.in_lidar(x, y) for x, y in pts):
            continue
        wd, src = road_width(t)
        width_src[src] += 1
        lift = ROAD_Z.get(t["highway"], 0.028)
        pts = C.densify(pts)
        crowned(roads, pts, wd, lift)
        n_car += 1
        lanes = int(L.tag_float(t, "lanes") or (2 if t["highway"] in ("primary", "secondary", "tertiary") else 1))
        mz = lift + 0.005                                    # step 7d: 5 mm proud of the surface
        zat = lambda off: mz + CROSSFALL * max(0.0, wd / 2 - abs(off))   # follow the crown
        if t["highway"] != "service":
            oneway = t.get("oneway") == "yes"
            if lanes >= 2 and oneway:
                for k in range(1, lanes):
                    of = -wd / 2 + k * wd / lanes
                    dashes(lines, pts, of, zat(of), dash=3.0, gap=9.0, w=0.12)        # QLD lane line 3 m / 9 m
            elif lanes >= 2:
                dashes(lines, pts, 0.0, zat(0.0), dash=3.0, gap=9.0, w=0.12, solid=lanes >= 4)
                if lanes >= 4:
                    dashes(lines, pts, 0.25, zat(0.25), w=0.12, solid=True)          # double barrier line
            for side in (1, -1):
                of = side * (wd / 2 - 0.35)
                dashes(lines, pts, of, zat(of), solid=True, w=0.12)                   # edge lines
        if t["highway"] == "service" or t.get("sidewalk") == "no":
            n_drive += t.get("service") == "driveway"
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
            if len(pts) < 2 or not any(C.in_lidar(x, y) for x, y in pts):
                continue
            wd = L.ROAD_WIDTH.get(t["highway"], 2.0)
            pts = C.densify(pts)
            ribbon(walks, C.offset_line(pts, wd / 2), C.offset_line(pts, -wd / 2), 0.05)
            n_walk += 1
    objs = [ob.name for ob in (roads.object("roads", col, "road"), paths.object("footpaths_kerbs", col, "footpath"),
                               walks.object("footways", col, "footway"), lines.object("line_marking", col, "line")) if ob]
    og = GUTTER.object("kerb_gutter", col, "road")
    if og:
        og.data.materials[0] = C.material_rgb("kerb_gutter", (0.10, 0.09, 0.08))
        objs.append(og.name)
    stops = bus_stops(col)
    objs += stops["objects"]
    return {"module": "streets", "objects": objs, "car_ways": n_car, "walk_ways": n_walk, "driveways": n_drive,
            "bus_stops": stops["count"], "crossfall": CROSSFALL,
            "width_source": dict(width_src), "footpath_width_m": L.FOOTPATH_WIDTH, "kerb_m": L.KERB_HEIGHT,
            "note": "Footpath widths are a CBD default, not measured. Bridges/tunnels/upper layers left out "
                    "(Story Bridge is in landmarks.py)."}


def bus_stops(col):
    """Council bus stops: a pole with a sign at every stop, a shelter where the stop has one (or is a
    named busy stop on Ann/Queen St)."""
    gj = json.load(open(L.ref("council_spire.geojson"), encoding="utf-8"))
    poles, shelters = C.MeshBuf(), C.MeshBuf()
    n = 0
    for f in gj["features"]:
        if f["properties"].get("layer") != "brisbane-bus-stops" or f["geometry"]["type"] != "Point":
            continue
        lon, lat = f["geometry"]["coordinates"][:2]
        x, y = L.to_local(lat, lon)
        if not C.in_lidar(x, y):
            continue
        z = L.ground_z(x, y) + L.KERB_HEIGHT
        poles.box(x, y, z, 0.1, 0.1, 3.0)
        poles.box(x, y, z + 2.3, 0.05, 0.5, 0.7)
        desc = str(f["properties"].get("description", "")) + str(f["properties"].get("shelter", ""))
        if "shelter" in desc.lower() or "Ann" in desc or "Queen" in desc:
            shelters.box(x + 1.0, y, z + 2.4, 3.8, 1.8, 0.15)          # roof
            shelters.box(x + 1.0, y + 0.8, z, 3.6, 0.08, 2.4)          # back panel
            for dx in (-0.8, 2.8):
                shelters.box(x + dx, y + 0.8, z, 0.1, 0.1, 2.4)
        n += 1
    objs = [ob.name for ob in (poles.object("bus_stop_poles", col, "pole"), shelters.object("bus_shelters", col, "pole")) if ob]
    return {"objects": objs, "count": n}
