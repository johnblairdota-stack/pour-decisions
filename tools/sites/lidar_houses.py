"""Outlines for the buildings the map does not have, traced from the 2019 LiDAR roof points (no bpy).

OpenStreetMap has almost every city building but few suburban houses: at Cannon Hill a 1 km tile is 16 % roof
in the LiDAR and has no outline at all. clean_wide.py calls trace() and shapes what comes back like any other
building, so the height, roof tiers and gable still come from the LiDAR.

How an outline is made: roof cells (LiDAR class 6, 1 m grid) that no map outline covers are cleaned of specks,
grouped into touching patches, and each patch becomes the smallest rectangle that holds it. A patch that fills
its rectangle badly (an L or U shape, a row of touching roofs) is cut along its long side and each part gets its
own rectangle. It is a traced outline, not a surveyed one: records carry tags.outline = "lidar 2019".
"""
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

MIN_AREA = 30.0      # m2: smaller is a shed, a carport or a clipped tree
MIN_HEIGHT = 2.2     # m above the ground: lower is a wall, a tank or a parked truck
MIN_SIDE = 4.5       # m: a narrower rectangle is a sliver beside a mapped building, or a wall
GOOD_FILL = 0.62     # share of its rectangle a patch must fill, or it is cut again
FIRST_ID = -1        # traced buildings get negative ids, so they never clash with a map id


def _map_mask(ways, nodes, shape):
    """Cells under a map building outline, grown 2 m (eaves overhang the mapped wall line)."""
    h, w = shape
    im = Image.new("L", (w, h), 0)
    dr = ImageDraw.Draw(im)
    for wy in ways.values():
        if "building" not in wy.get("tags", {}):
            continue
        ring = [nodes[n] for n in wy["nodes"] if n in nodes]
        if len(ring) < 3:
            continue
        pts = [(x, h - y) for x, y in ring]
        dr.polygon(pts, fill=1)
        dr.line(pts + pts[:1], fill=1, width=5)
    return np.asarray(im, bool)


def _rect(xs, ys):
    """Smallest rectangle around the cell centres (tried every 3 degrees): corners, area, long-axis angle."""
    best = None
    for deg in range(0, 90, 3):
        a = np.radians(deg)
        ca, sa = np.cos(a), np.sin(a)
        u = xs * ca + ys * sa
        v = -xs * sa + ys * ca
        u0, u1, v0, v1 = u.min() - 0.5, u.max() + 0.5, v.min() - 0.5, v.max() + 0.5
        area = (u1 - u0) * (v1 - v0)
        if best is None or area < best[0]:
            best = (area, ca, sa, u0, u1, v0, v1, u, v)
    area, ca, sa, u0, u1, v0, v1, u, v = best
    corners = [(uu * ca - vv * sa, uu * sa + vv * ca) for uu, vv in ((u0, v0), (u1, v0), (u1, v1), (u0, v1))]
    return corners, area, (u, v, u0, u1, v0, v1)


def _pieces(xs, ys, depth=0):
    """One rectangle if the patch fills it, else cut across the long side where the patch is thinnest."""
    corners, area, (u, v, u0, u1, v0, v1) = _rect(xs, ys)
    n = len(xs)
    if n < MIN_AREA:
        return []
    if n / area >= GOOD_FILL or depth >= 4 or n < 2.5 * MIN_AREA:
        return [corners] if n / area >= 0.4 else []
    along, lo, hi = (u, u0, u1) if (u1 - u0) >= (v1 - v0) else (v, v0, v1)
    bins = np.floor(along - lo).astype(int)
    width = np.bincount(bins, minlength=int(hi - lo) + 1).astype(float)
    k = len(width)
    if k < 8:
        return [corners]
    mid = np.arange(k)
    score = width + 0.15 * width.max() * np.abs(mid - k / 2) / (k / 2)   # thin, and not right at an end
    score[:3] = score[-3:] = np.inf
    cut = int(np.argmin(score))
    a = bins < cut
    if a.sum() < MIN_AREA or (~a).sum() < MIN_AREA:
        return [corners]
    return _pieces(xs[a], ys[a], depth + 1) + _pieces(xs[~a], ys[~a], depth + 1)


def trace(bld, gnd, cover, ways, nodes):
    """bld/gnd/cover: the 1 m mosaic (rows north to south). ways/nodes: the map, nodes in mosaic metres
    (x east from the west edge, y north from the south edge). Returns (new_ways, new_nodes, stats)."""
    h, w = bld.shape
    roof = ~np.isnan(bld) & cover & ((bld - gnd) >= MIN_HEIGHT)
    roof_cells = int(roof.sum())
    free = roof & ~_map_mask(ways, nodes, (h, w))
    free = ndimage.binary_opening(free, np.ones((3, 3), bool))
    lab, n = ndimage.label(free)
    new_ways, new_nodes, nid, wid = {}, {}, FIRST_ID, FIRST_ID
    kept_cells = 0
    for i, sl in enumerate(ndimage.find_objects(lab), 1):
        m = lab[sl] == i
        if m.sum() < MIN_AREA:
            continue
        rr, cc = np.nonzero(m)
        xs = cc + sl[1].start + 0.5
        ys = h - (rr + sl[0].start) - 0.5
        for corners in _pieces(xs, ys):
            side = sorted((np.hypot(corners[1][0] - corners[0][0], corners[1][1] - corners[0][1]),
                           np.hypot(corners[2][0] - corners[1][0], corners[2][1] - corners[1][1])))
            if side[0] < MIN_SIDE:
                continue                                    # a sliver beside a mapped building, or a wall
            ids = []
            for x, y in corners:
                new_nodes[nid] = (float(x), float(y))
                ids.append(nid)
                nid -= 1
            kind = "house" if side[1] <= 30 and side[0] * side[1] <= 450 else "yes"
            new_ways[wid] = {"type": "way", "id": wid, "nodes": ids + ids[:1],
                             "tags": {"building": kind, "outline": "lidar 2019"}}
            wid -= 1
        kept_cells += int(m.sum())
    return new_ways, new_nodes, {"roof_ha": round(roof_cells / 1e4, 1), "unmapped_roof_ha": round(int(free.sum()) / 1e4, 1),
                                 "traced_roof_ha": round(kept_cells / 1e4, 1), "traced_buildings": len(new_ways)}
