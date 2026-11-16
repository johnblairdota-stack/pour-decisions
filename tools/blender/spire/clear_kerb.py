"""Clear the footpaths next to the Spire site in the game's site model.

    python3 tools/blender/spire/clear_kerb.py            (also run at the end of export_game.py)

During a pour the footpath beside the site is the site's: the hoist, the riser's ladder tower, the
pump and the trucks stand there. Everything the street model put on it within CLEAR_M of the lot is
taken out of assets/spire/spire_site.glb (and so is the far footpath of Ann St in front of the site): street trees (trunk and crown), palms, planters, light and
sign poles, signals, bins, bollards, banners, the bus stop. Whole things only: the merged meshes are
split back into their connected pieces and a piece goes if its middle is inside the zone.

Pure Python + numpy (no bpy). The triangles are made degenerate in place, so nothing else in the file
moves. Safe to run twice."""
import json
import os
import struct
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
GLB = os.path.join(REPO, "assets", "spire", "spire_site.glb")
CLEAR_M = 9.5            # m out from the lot (footpath 3.5 m, the kerb lane, and a tree's lean)
PREFIXES = ("tree_", "palm_", "street_", "bus_stop", "bus_shelter", "area_")
KEEP = ("street_art",)   # (painted walls, not footpath furniture)
LOT_FROM = "hoarding"    # the site's hoarding runs round the lot
# Ann St in front of the site, both footpaths: the street crew's camera looks in from over the road,
# so the far kerb's trees go too. (layout.py: the middle of the Ann St boundary, and the way it runs.)
ANN_MID = np.array([-16.0, 14.4])
ANN_ALONG = np.array([0.760, 0.650])
ANN_HALF = 46.0          # m either way along the street
ANN_OUT = 30.0           # m out from the boundary: four lanes and the far footpath


def hull(pts):
    pts = sorted(set(map(tuple, np.round(pts, 2))))
    def half(seq):
        out = []
        for p in seq:
            while len(out) >= 2 and (out[-1][0] - out[-2][0]) * (p[1] - out[-2][1]) - (out[-1][1] - out[-2][1]) * (p[0] - out[-2][0]) <= 0:
                out.pop()
            out.append(p)
        return out[:-1]
    return np.array(half(pts) + half(reversed(pts)))


def dist_to_poly(p, poly):
    """Signed distance (negative inside) from points p (n,2) to a convex polygon (ccw)."""
    n = len(poly)
    best = np.full(len(p), 1e9)
    inside = np.ones(len(p), bool)
    for i in range(n):
        a, b = poly[i], poly[(i + 1) % n]
        ab = b - a
        t = np.clip(((p - a) @ ab) / (ab @ ab), 0, 1)
        d = np.linalg.norm(p - (a + t[:, None] * ab), axis=1)
        best = np.minimum(best, d)
        inside &= (ab[0] * (p[:, 1] - a[1]) - ab[1] * (p[:, 0] - a[0])) >= 0
    return np.where(inside, -best, best)


def main():
    raw = bytearray(open(GLB, "rb").read())
    jlen = struct.unpack_from("<I", raw, 12)[0]
    js = json.loads(raw[20:20 + jlen])
    bin0 = 20 + jlen + 8
    views, accs = js["bufferViews"], js["accessors"]

    def arr(ai, dtype, width):
        a = accs[ai]
        v = views[a["bufferView"]]
        off = bin0 + v.get("byteOffset", 0) + a.get("byteOffset", 0)
        assert "byteStride" not in v or v["byteStride"] == np.dtype(dtype).itemsize * width
        return np.frombuffer(raw, dtype, a["count"] * width, off).reshape(-1, width), off

    lot = None
    for nd in js["nodes"]:
        if nd.get("name") == LOT_FROM:
            pts = [arr(p["attributes"]["POSITION"], "<f4", 3)[0] for p in js["meshes"][nd["mesh"]]["primitives"]]
            pts = np.concatenate(pts)
            lot = hull(np.stack([pts[:, 0], -pts[:, 2]], 1))      # local x east, y north
    assert lot is not None, "no hoarding in the model"
    gone = 0
    for nd in js["nodes"]:
        nm = nd.get("name", "")
        if "mesh" not in nd or not nm.startswith(PREFIXES) or nm.startswith(KEEP):
            continue
        if nm.startswith("area_") and ("translation" in nd or "rotation" in nd or "matrix" in nd):
            continue         # (the Spire area's sign texts: area_hero.py's self-check keeps them out of the zone)
        assert "translation" not in nd and "rotation" not in nd and "matrix" not in nd
        for prim in js["meshes"][nd["mesh"]]["primitives"]:
            pos, _ = arr(prim["attributes"]["POSITION"], "<f4", 3)
            ia = accs[prim["indices"]]
            dt = {5123: "<u2", 5125: "<u4"}[ia["componentType"]]
            idx, ioff = arr(prim["indices"], dt, 1)
            tri = idx.reshape(-1, 3).astype(np.int64)
            # weld by position, then join triangles that share a welded vertex
            _, weld = np.unique(np.round(pos, 3), axis=0, return_inverse=True)
            weld = weld.reshape(-1)
            parent = np.arange(weld.max() + 1)

            def find(x):
                while parent[x] != x:
                    parent[x] = parent[parent[x]]
                    x = parent[x]
                return x
            for t in weld[tri]:
                a, b, c = find(t[0]), find(t[1]), find(t[2])
                parent[b] = a
                parent[c] = a
            root = np.array([find(x) for x in range(len(parent))])
            comp = root[weld[tri[:, 0]]]
            xy = np.stack([pos[:, 0], -pos[:, 2]], 1)
            tc = xy[tri].mean(axis=1)
            ids, inv = np.unique(comp, return_inverse=True)
            cx = np.bincount(inv, tc[:, 0]) / np.bincount(inv)
            cy = np.bincount(inv, tc[:, 1]) / np.bincount(inv)
            cc = np.stack([cx, cy], 1)
            kill = dist_to_poly(cc, lot) < CLEAR_M
            rel = cc - ANN_MID
            along = rel @ ANN_ALONG
            out_m = rel @ np.array([-ANN_ALONG[1], ANN_ALONG[0]])
            kill |= (np.abs(along) < ANN_HALF) & (out_m > -2.0) & (out_m < ANN_OUT)
            dead = kill[inv] & (tri[:, 0] != tri[:, 1])
            if dead.any():
                out = tri.copy()
                out[dead] = out[dead][:, :1]
                raw[ioff:ioff + out.size * np.dtype(dt).itemsize] = out.astype(dt).tobytes()
                gone += int(kill.sum())
                print("  %-28s %4d pieces, %6d triangles" % (nm, int(kill.sum()), int(dead.sum())))
    open(GLB, "wb").write(raw)
    print("clear_kerb: %d things taken off the footpaths within %.1f m of the lot" % (gone, CLEAR_M))


if __name__ == "__main__":
    sys.exit(main())
