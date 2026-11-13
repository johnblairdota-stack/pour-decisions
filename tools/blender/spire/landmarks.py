"""Story Bridge line (from OSM) for the skyline. The river is the water plane in ground.py."""
import math

import layout as L
import common as C

DECK_PEAK_AHD = 32.0     # rough deck height over the main span (blockout only)
TRUSS_TOP_AHD = 80.0     # rough top of the cantilever truss over the two main piers


def build():
    o = L.osm()
    col = C.collection("landmarks")
    deck, truss = C.MeshBuf(), C.MeshBuf()
    lines = []
    for wid, w in o["ways"].items():
        t = w.get("tags", {})
        if "Story Bridge" in t.get("name", ""):      # bridge outlines (man_made=bridge), not the road
            pts = o["line"](w)
            if len(pts) >= 2:
                lines.append(pts)
    if not lines:
        return {"module": "landmarks", "objects": [], "note": "no Story Bridge ways in the OSM crop"}
    # one long axis through all bridge points: farthest pair
    allp = [p for ln in lines for p in ln]
    a, b = max(((p, q) for p in allp for q in allp), key=lambda pq: math.dist(*pq))
    if a[1] < b[1]:
        a, b = b, a          # a = north end (Fortitude Valley side)
    span = math.dist(a, b)
    ux, uy = (b[0] - a[0]) / span, (b[1] - a[1]) / span

    def deck_z(x, y):
        s = ((x - a[0]) * ux + (y - a[1]) * uy) / span
        gz = L.ground_z(x, y) if C.in_model(x, y) else 0.0
        return max(gz + 0.5, DECK_PEAK_AHD * math.sin(math.pi * min(max(s, 0), 1)) ** 0.5)

    axis = [(a[0] + ux * span * i / 40, a[1] + uy * span * i / 40) for i in range(41)]
    n = len(axis)
    left, right = C.offset_line(axis, 12.0), C.offset_line(axis, -12.0)
    verts = [(x, y, deck_z(x, y)) for x, y in left] + [(x, y, deck_z(x, y)) for x, y in right]
    deck.add(verts, [[i, n + i, n + i + 1, i + 1] for i in range(n - 1)])
    # truss silhouette: a thin wall along the axis, up to TRUSS_TOP over the middle half
    k = 24
    wall = []
    for i in range(k + 1):
        s = 0.2 + 0.6 * i / k
        x, y = a[0] + ux * span * s, a[1] + uy * span * s
        top = DECK_PEAK_AHD + (TRUSS_TOP_AHD - DECK_PEAK_AHD) * abs(math.cos(math.pi * (s - 0.2) / 0.3)) ** 2
        wall.append((x, y, deck_z(x, y), top))
    verts = [(x, y, z) for x, y, z, _ in wall] + [(x, y, t) for x, y, _, t in wall]
    truss.add(verts, [[i, i + 1, k + 2 + i, k + 1 + i] for i in range(k)])
    objs = [ob.name for ob in (deck.object("story_bridge_deck", col, "bridge"),
                               truss.object("story_bridge_truss_line", col, "bridge")) if ob]
    return {"module": "landmarks", "objects": objs, "story_bridge_outline_ways": len(lines),
            "axis_from": [round(v, 1) for v in a], "axis_to": [round(v, 1) for v in b], "span_m": round(span, 1),
            "note": "Deck and truss heights are rough placeholders for the skyline; the bridge sits mostly "
                    "outside the 800 m square (SE of Spire)."}
