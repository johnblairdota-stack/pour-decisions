"""Roads, rail and bridges outside the LiDAR box (17 Nov 2026), from OSM with bridge decks at their LiDAR
heights. Data: reference/sites/spire/roads/roads.json (tools/sites/roads_wide.py). Built after cbd_ext
(it lays the ground these sit on).

- roads / rail on the ground: ribbons at the OSM width (width tag, else lanes, else class default),
  draped on the far ground; skipped inside layout.LIDAR_BOX (streets.py owns those)
- bridges (OSM bridge=*): deck slab at the LiDAR deck height, parapets, piers every ~35 m to the ground or
  river bed. The Story Bridge (landmarks.py) and bridges wholly inside the box are left alone.
- the river bridges' main structures from published figures (Wikipedia, 17 Nov 2026) laid over the span
  that crosses the traced water: William Jolly (3 arches x 72.5 m, cream), Merivale (steel through arch
  132 m), Goodwill (arch 102 m x 15 m), Kurilpa (20 masts, canopy), Neville Bonner (75 m mast, two 60 m
  arches), Kangaroo Point (single mast; height and position estimated). Box girders (Captain Cook,
  Victoria, Go Between) need no superstructure.
"""
import gzip
import json
import math
import os

import numpy as np

import layout as L
import common as C

ROADS = os.path.join(L.REF, "roads", "roads.json")
SKIP_NAMES = {"Bradfield Highway", "Story Bridge"}
PIER_EVERY = 35.0
COL = {"asphalt": (0.085, 0.085, 0.09), "motorway": (0.13, 0.13, 0.135), "rail": (0.27, 0.24, 0.21),
       "deck": (0.5, 0.49, 0.46), "concrete": (0.6, 0.58, 0.54), "steel_white": (0.86, 0.86, 0.84),
       "jolly_cream": (0.8, 0.74, 0.6), "steel_grey": (0.42, 0.44, 0.46), "canopy": (0.75, 0.75, 0.73), "paint": (0.85, 0.85, 0.82), "pole": (0.5, 0.51, 0.52),
       "lamp": (0.9, 0.88, 0.8), "signal": (0.03, 0.03, 0.03), "lens_red": (0.6, 0.03, 0.02), "lens_amber": (0.7, 0.4, 0.02),
       "lens_green": (0.03, 0.5, 0.15), "sign_green": (0.02, 0.22, 0.11)}


_ROAD_CELLS = None
_DECK_CELLS = set()
GROUND = None                                               # the far ground sampler, set by build()


def on_road(x, y):
    """True within a road, rail line or bridge deck (plus 1.5 m) of roads.json: trees keep off them."""
    global _ROAD_CELLS
    if _ROAD_CELLS is None:
        _ROAD_CELLS = set()
        if os.path.exists(ROADS):
            for w in json.load(open(ROADS))["ways"]:
                if w["kind"] == "path" and not w["bridge"]:
                    continue
                h = w["width"] / 2 + 1.5
                pts = w["pts"]
                for i, (px, py) in enumerate(pts):
                    a, b = pts[max(i - 1, 0)], pts[min(i + 1, len(pts) - 1)]
                    dx, dy = b[0] - a[0], b[1] - a[1]
                    ln = math.hypot(dx, dy) or 1.0
                    nx, ny = -dy / ln, dx / ln
                    k = int(h // 2) + 1
                    for j in range(-k, k + 1):
                        o = h * j / k
                        _ROAD_CELLS.add((int((px + nx * o) // 2), int((py + ny * o) // 2)))
                        if w["bridge"]:
                            _DECK_CELLS.add((int((px + nx * o) // 2), int((py + ny * o) // 2)))
    return (int(x // 2), int(y // 2)) in _ROAD_CELLS


def over_deck(x, y, r):
    """True if a crown of radius r at (x, y) would reach over (or up through) a bridge deck."""
    on_road(x, y)
    for k in (0.5, 1.0):
        for i in range(8):
            a = math.pi * i / 4
            if (int((x + r * k * math.cos(a)) // 2), int((y + r * k * math.sin(a)) // 2)) in _DECK_CELLS:
                return True
    return False


class Ground:
    def __init__(self):
        import cbd_ext as CE
        self.far = CE.GRIDS.get("far")
        self.ext = CE.GRIDS.get("ext")

    @staticmethod
    def _bil(grid, x, y):
        gx, gy, st, Z = grid[:4]
        fx = np.clip((x - gx) / st, 0, Z.shape[1] - 1.001)
        fy = np.clip((gy - y) / st, 0, Z.shape[0] - 1.001)
        j, i = fx.astype(int), fy.astype(int)
        tx, ty = fx - j, fy - i
        return (Z[i, j] * (1 - ty) * (1 - tx) + Z[i, j + 1] * (1 - ty) * tx + Z[i + 1, j] * ty * (1 - tx) + Z[i + 1, j + 1] * ty * tx)

    def z(self, x, y):
        x, y = np.asarray(x, "f8"), np.asarray(y, "f8")
        out = self._bil(self.far, x, y) if self.far else np.full(x.shape, 8.0)
        if self.ext:
            gx, gy, st, Z, cov = self.ext
            j = ((x - gx) / st).astype(int)
            i = ((gy - y) / st).astype(int)
            ok = (j >= 0) & (j < Z.shape[1] - 1) & (i >= 0) & (i < Z.shape[0] - 1)
            ok[ok] &= cov[i[ok], j[ok]]
            if ok.any():
                out = np.where(ok, self._bil(self.ext, x, y), out)
        return out


def in_box(x, y, pad=0.0):
    x0, y0, x1, y1 = L.LIDAR_BOX
    return x0 + pad < x < x1 - pad and y0 + pad < y < y1 - pad


def runs_outside(pts):
    out, cur = [], []
    for p in pts:
        if in_box(p[0], p[1]):
            if len(cur) > 1:
                out.append(cur)
            cur = []
        else:
            cur.append(p)
    if len(cur) > 1:
        out.append(cur)
    return out


def ribbon(buf, pts, wd, G, lift):
    left, right = C.offset_line(pts, wd / 2), C.offset_line(pts, -wd / 2)
    a, b, c = np.array(left), np.array(pts), np.array(right)
    z = np.maximum.reduce([G.z(a[:, 0], a[:, 1]), G.z(b[:, 0], b[:, 1]), G.z(c[:, 0], c[:, 1])]) + lift
    n = len(pts)
    verts = [(left[i][0], left[i][1], float(z[i])) for i in range(n)] + [(right[i][0], right[i][1], float(z[i])) for i in range(n)]
    buf.add(verts, [[i, n + i, n + i + 1, i + 1] for i in range(n - 1)])
    return [float(v) for v in z]


MAJOR = ("motorway", "trunk", "primary", "secondary")


def stripe(buf, pts, zs, off, dashed, w=0.14, lift=0.05):
    """Painted line `off` metres left of the centre line; dashed = 4 m on, 8 m off."""
    a, b = C.offset_line(pts, off + w / 2), C.offset_line(pts, off - w / 2)
    n = len(pts)
    verts = [(a[i][0], a[i][1], zs[i] + lift) for i in range(n)] + [(b[i][0], b[i][1], zs[i] + lift) for i in range(n)]
    buf.add(verts, [[i, n + i, n + i + 1, i + 1] for i in range(n - 1) if not dashed or i % 3 == 0])


def markings(buf, w, pts, zs):
    """Line marking from the OSM class, lanes and oneway (Queensland practice: dashed lane lines, solid
    centre line on main roads, edge lines on motorways). Service roads and lanes under 5.5 m: none."""
    cls, wd = w["cls"], w["width"]
    if cls in ("service", "living_street", "busway") or wd < 5.5 or len(pts) < 3:
        return 0
    lanes = int(w.get("lanes") or 0) or max(1 if w["oneway"] else 2, int(wd // 3.4))
    lw = wd / lanes
    for k in range(1, lanes):
        off = -wd / 2 + k * lw
        centre = (not w["oneway"]) and lanes % 2 == 0 and k == lanes // 2
        if centre and cls.startswith(MAJOR):
            stripe(buf, pts, zs, off + 0.12, False)
            stripe(buf, pts, zs, off - 0.12, False)
        else:
            stripe(buf, pts, zs, off, True)
    if cls.startswith(("motorway", "trunk")):
        stripe(buf, pts, zs, wd / 2 - 0.3, False)
        stripe(buf, pts, zs, -wd / 2 + 0.3, False)
    return lanes


def lights(bufs, w, pts, zs, every=12):
    """Street lights on the main roads: 10.5 m column, 2.5 m outreach, alternate sides every ~48 m (a guess
    at the usual Brisbane spacing; OSM maps almost none)."""
    if not w["cls"].startswith(MAJOR) or len(pts) < every:
        return 0
    n = 0
    start = (w["id"] % every)
    for i in range(start, len(pts) - 1, every):
        tx, ty, nx, ny = frame(pts, i)
        sd = 1 if (i // every + w["id"]) % 2 else -1
        o = w["width"] / 2 + 1.4
        x, y, z = pts[i][0] + nx * o * sd, pts[i][1] + ny * o * sd, zs[i]
        bufs["pole"].beam((x, y, z - 0.5), (x, y, z + 10.5), 0.2)
        hx, hy = x - nx * sd * 2.5, y - ny * sd * 2.5
        bufs["pole"].beam((x, y, z + 10.4), (hx, hy, z + 10.7), 0.12)
        bufs["lamp"].box(hx, hy, z + 10.55, 0.75, 0.3, 0.14, math.atan2(ny, nx))
        n += 1
    return n


def signals(bufs, feats, G, ways):
    """Traffic signals at the OSM signal nodes outside the LiDAR box: a post with a head each side of the
    junction and a mast arm over the road (direction from the nearest road)."""
    pts = np.array([p for w in ways if w["kind"] == "road" and not w["bridge"] for p in w["pts"][::2]] or [(0, 0)])
    n = 0
    for x, y in feats.get("traffic_signals", []):
        if in_box(x, y):
            continue
        d = np.hypot(pts[:, 0] - x, pts[:, 1] - y)
        j = int(np.argmin(d))
        if d[j] > 25:
            continue
        k = int(np.argmin(np.where(np.arange(len(d)) == j, 1e9, d)))
        ang = math.atan2(pts[k][1] - pts[j][1], pts[k][0] - pts[j][0])
        z = float(G.z([x], [y])[0])
        for sd in (1, -1):
            c, s = math.cos(ang), math.sin(ang)
            px, py = x + (-s) * 6.5 * sd + c * 5.0 * sd, y + c * 6.5 * sd + s * 5.0 * sd
            bufs["pole"].beam((px, py, z), (px, py, z + 6.2), 0.16)
            ax, ay = px + s * 4.5 * sd, py - c * 4.5 * sd                      # mast arm out over the road
            bufs["pole"].beam((px, py, z + 6.0), (ax, ay, z + 6.2), 0.12)
            for hx, hy, hz in ((px, py, z + 3.2), (ax, ay, z + 5.6)):
                bufs["signal"].box(hx, hy, hz, 0.36, 0.3, 1.1, ang)
                for q, key in enumerate(("lens_green", "lens_amber", "lens_red")):
                    bufs[key].box(hx - c * 0.17 * sd, hy - s * 0.17 * sd, hz + 0.12 + q * 0.34, 0.06, 0.2, 0.2, ang)
            n += 1
    return n


def gantries(bufs, feats, ways):
    """Green direction-sign gantry across the carriageway at each OSM motorway junction (exit) node."""
    mw = [(p, w, i) for w in ways if w["cls"].startswith(("motorway", "trunk")) for i, p in enumerate(w["pts"])]
    if not mw:
        return 0
    arr = np.array([p for p, _, _ in mw])
    n = 0
    for x, y, ref, name in feats.get("motorway_junctions", []):
        d = np.hypot(arr[:, 0] - x, arr[:, 1] - y)
        j = int(np.argmin(d))
        if d[j] > 30:
            continue
        _, w, i = mw[j]
        back = max(i - 20, 0)                                               # the sign stands ~80 m before the exit
        pts = [tuple(p) for p in w["pts"]]
        if in_box(pts[back][0], pts[back][1]):
            continue
        z = w["deck"][back] if w["bridge"] else GROUND.z([pts[back][0]], [pts[back][1]])[0] + 0.5
        tx, ty, nx, ny = frame(pts, back)
        o = w["width"] / 2 + 1.6
        a = (pts[back][0] + nx * o, pts[back][1] + ny * o)
        b = (pts[back][0] - nx * o, pts[back][1] - ny * o)
        for q in (a, b):
            bufs["pole"].beam((q[0], q[1], z - 0.5), (q[0], q[1], z + 8.2), 0.35)
        for dz in (6.3, 8.0):
            bufs["pole"].beam((a[0], a[1], z + dz), (b[0], b[1], z + dz), 0.25)
        bufs["sign_green"].box(pts[back][0] - tx * 0.3, pts[back][1] - ty * 0.3, z + 6.1, 0.12, min(2 * o - 2.0, 9.0), 2.4, math.atan2(ty, tx))
        n += 1
    return n


def deck(bufs, w, G, piers=True, clear=None):
    """clear = (i0, i1): no generic piers between those points (a named river span whose real piers structures() builds)."""
    pts = [tuple(p) for p in w["pts"]]
    zs = w["deck"]
    wd = w["width"] + (1.0 if w["kind"] == "road" else 0.6)
    th = 0.7 if w["kind"] == "path" else 1.5
    left, right = C.offset_line(pts, wd / 2), C.offset_line(pts, -wd / 2)
    n = len(pts)
    verts = []
    for i in range(n):
        z = zs[i]
        verts += [(left[i][0], left[i][1], z), (right[i][0], right[i][1], z), (right[i][0], right[i][1], z - th), (left[i][0], left[i][1], z - th)]
    faces = []
    for i in range(n - 1):
        a, b = 4 * i, 4 * (i + 1)
        faces += [[a + 1, a, b, b + 1], [a + 3, a + 2, b + 2, b + 3], [a, a + 3, b + 3, b], [a + 2, a + 1, b + 1, b + 2]]
    top = "rail" if w["kind"] == "rail" else ("deck" if w["kind"] == "path" else "asphalt")
    bufs["concrete"].add(verts, [f for k, f in enumerate(faces) if k % 4 != 0])
    bufs[top].add([(v[0], v[1], v[2] + 0.03) for v in verts], [f for k, f in enumerate(faces) if k % 4 == 0])
    ph = 1.1
    for side in (left, right):                                   # parapets / balustrades
        pv = [(x, y, zs[i]) for i, (x, y) in enumerate(side)] + [(x, y, zs[i] + ph) for i, (x, y) in enumerate(side)]
        bufs["concrete" if w["kind"] != "path" else "steel_grey"].add(pv, [[i, i + 1, n + i + 1, n + i] for i in range(n - 1)])
    if not piers:
        return 0
    k = max(1, int(round(PIER_EVERY / 4.0)))
    np_ = 0
    for i in range(k // 2, n, k):
        if clear and clear[0] <= i <= clear[1]:
            continue
        x, y = pts[i]
        g = float(G.z([x], [y])[0])
        g = min(g, zs[i] - th)
        if zs[i] - th - g < 2.5:
            continue
        a = pts[max(i - 1, 0)]
        b = pts[min(i + 1, n - 1)]
        ang = math.atan2(b[1] - a[1], b[0] - a[0])
        bufs["concrete"].box(x, y, g - 1.0, 1.6, max(1.6, wd * 0.45), zs[i] - th - g + 1.0, ang)
        np_ += 1
    return np_


class Water:
    def __init__(self):
        d = os.path.join(L.REF, "river")
        m = json.load(open(os.path.join(d, "river.json")))
        self.x0, self.y1, self.st = m["box_local"][0], m["box_local"][3], m["step_m"]
        self.w = np.frombuffer(gzip.open(os.path.join(d, "water_2m.u8.gz")).read(), "u1").reshape(m["rows"], m["cols"])

    def at(self, x, y):
        c, r = int((x - self.x0) / self.st), int((self.y1 - y) / self.st)
        return 0 <= r < self.w.shape[0] and 0 <= c < self.w.shape[1] and self.w[r, c] > 0

    def span(self, pts):
        """(first, last) index of the points over water, or None."""
        idx = [i for i, p in enumerate(pts) if self.at(p[0], p[1])]
        return (idx[0], idx[-1]) if len(idx) > 3 else None


def frame(pts, i):
    a, b = pts[max(i - 1, 0)], pts[min(i + 1, len(pts) - 1)]
    dx, dy = b[0] - a[0], b[1] - a[1]
    ln = math.hypot(dx, dy) or 1.0
    return dx / ln, dy / ln, -dy / ln, dx / ln


def arch(buf, w, i0, i1, rise, spring, half, sec=1.2, hangers=True, brace=True):
    """Two parabolic ribs over points i0..i1 of way w, half = rib offset from the centre line."""
    pts, zs = w["pts"], w["deck"]
    n = i1 - i0
    if n < 3:
        return
    zd = (zs[i0] + zs[i1]) / 2
    prev = None
    for k in range(n + 1):
        i = i0 + k
        t = k / n
        z = zd - spring + (rise + spring) * 4 * t * (1 - t)
        tx, ty, nx, ny = frame(pts, i)
        x, y = pts[i]
        cur = [(x + nx * half * s, y + ny * half * s, z) for s in (1, -1)]
        if prev:
            for a, b in zip(prev, cur):
                buf.beam(a, b, sec, sec * 1.3)
            if hangers and k % 2 == 0 and z > zs[i] + 1.5:
                for c in cur:
                    buf.beam(c, (c[0], c[1], zs[i]), 0.25)
            if brace and k % 3 == 0 and z > zs[i] + 6.5:
                buf.beam(cur[0], cur[1], 0.5)
        prev = cur


def mast(buf, cables, w, i, height, reach, lean=0.0, side=0.0, r=1.6, every=5):
    """Tapered mast at point i of way w with stay cables to the deck each way along it."""
    import trees as T
    pts, zs = w["pts"], w["deck"]
    tx, ty, nx, ny = frame(pts, i)
    x, y = pts[i][0] + nx * side, pts[i][1] + ny * side
    base = (x, y, zs[i] - 12.0)
    top = (x + tx * lean * height, y + ty * lean * height, zs[i] + height)
    T.tube(buf, base, top, r, r * 0.45, 10)
    k = int(reach / 4.0)
    for j in range(i - k, i + k + 1, every):
        if 0 <= j < len(pts) and abs(j - i) > 3:
            f = 1.0 - 0.35 * abs(j - i) / max(k, 1)
            cables.beam((top[0], top[1], zs[i] + height * f), (pts[j][0], pts[j][1], zs[j] + 0.5), 0.18)
    return top


RIVER_SPANS = {"William Jolly Bridge", "Merivale Bridge", "Goodwill Bridge", "Kurilpa Bridge", "Neville Bonner Bridge",
               "Kangaroo Point Bridge", "Pacific Motorway", "Go Between Bridge"}      # real river piers come from structures()


def pier(buf, w, i, half, thick=2.0, drop=1.2, z0=-3.0):
    """Blade pier across the deck at point i of way w, from the river bed to the deck soffit."""
    pts, zs = w["pts"], w["deck"]
    i = min(max(i, 0), len(pts) - 1)
    tx, ty, nx, ny = frame(pts, i)
    buf.box(pts[i][0], pts[i][1], z0, thick, 2 * half, zs[i] - drop - z0, math.atan2(ty, tx))
    return pts[i]


def nearest(w, p):
    return min(range(len(w["pts"])), key=lambda i: (w["pts"][i][0] - p[0]) ** 2 + (w["pts"][i][1] - p[1]) ** 2)


def girder(buf, w, i0, i1, at, half_top, half_bot, d0, d1, reach):
    """Haunched box girder under points i0..i1: depth d1 over the piers `at`, easing on a parabola to d0 `reach` m away."""
    pts, zs = w["pts"], w["deck"]
    i0, i1 = max(i0, 0), min(i1, len(pts) - 1)
    verts, faces = [], []
    for k, i in enumerate(range(i0, i1 + 1)):
        tx, ty, nx, ny = frame(pts, i)
        m = min(abs(i - q) for q in at) * 4.0
        dp = d0 + (d1 - d0) * max(0.0, 1.0 - m / reach) ** 2
        zt = zs[i] - 0.3
        for sw, zz in ((-half_top, zt), (half_top, zt), (half_bot, zt - dp), (-half_bot, zt - dp)):
            verts.append((pts[i][0] + nx * sw, pts[i][1] + ny * sw, zz))
        if k:
            o = 4 * (k - 1)
            faces += [[o + j, o + (j + 1) % 4, o + 4 + (j + 1) % 4, o + 4 + j] for j in range(4)]
    buf.add(verts, faces)


def structures(bufs, ways, W):
    """Main structures and the real river piers of the named river bridges, on the span over the traced water.
    Span lengths, heights and pier counts: Wikipedia / Structurae / the designers' pages; where a pier position is not
    published it is set out from the published span lengths and noted as estimated in the returned list."""
    import trees as T
    made = []
    by = {}
    for w in ways:
        if w["bridge"] and w["name"]:
            by.setdefault(w["name"], []).append(w)

    def main(name, kind=None):
        c = [w for w in by.get(name, []) if kind is None or w["kind"] == kind]
        c = [(w, W.span(w["pts"])) for w in c]
        c = [(w, s) for w, s in c if s]
        return max(c, key=lambda ws: ws[1][1] - ws[1][0]) if c else (None, None)

    def centred(s, length_m):
        mid = (s[0] + s[1]) // 2
        h = int(length_m / 8.0)
        return mid - h, mid + h

    w, s = main("William Jolly Bridge")
    if w:                                                   # three 72.5 m steel arches cased in concrete, through the deck
        a, _ = centred(s, 217.5)
        k = int(72.5 / 4.0)
        for j in range(3):
            i0, i1 = max(a + j * k, 0), min(a + (j + 1) * k, len(w["pts"]) - 1)
            arch(bufs["jolly_cream"], w, i0, i1, 11.0, 9.0, 10.5, sec=1.5)
            arch(bufs["jolly_cream"], w, i0, i1, 11.0, 9.0, 0.0, sec=1.3, brace=False)
        for j in range(4):                                  # two river piers and the two bank piers the arches spring from
            pier(bufs["jolly_cream"], w, a + j * k, 12.0, thick=5.0, drop=0.5)
        made.append("William Jolly Bridge: 3 x 72.5 m arches on two river piers and two bank piers")
    mv = by.get("Merivale Bridge", [])
    for w in mv[:1]:                                         # steel tied arch, 132 m clear over the river, both tracks
        s = W.span(w["pts"])
        if s:
            i0, i1 = centred(s, 132.0)
            i0, i1 = max(i0, 0), min(i1, len(w["pts"]) - 1)
            o = mv[1] if len(mv) > 1 else w                  # centre the ribs between the two tracks
            j = nearest(o, w["pts"][i0])
            tx, ty, nx, ny = frame(w["pts"], i0)
            off = ((o["pts"][j][0] - w["pts"][i0][0]) * nx + (o["pts"][j][1] - w["pts"][i0][1]) * ny) / 2
            cw = dict(w, pts=[(p[0] + frame(w["pts"], q)[2] * off, p[1] + frame(w["pts"], q)[3] * off) for q, p in enumerate(w["pts"])])
            arch(bufs["steel_white"], cw, i0, i1, 22.0, 2.0, 6.5, sec=1.4)
            for i in (i0, i1):
                pier(bufs["concrete"], cw, i, 8.0, thick=4.0)
            made.append("Merivale Bridge: 132 m tied arch, no river piers")
    w, s = main("Goodwill Bridge")
    if w:                                                   # arch 102 m long, 15 m high, on the South Bank half; pavilion pier mid-river
        pts, zs = w["pts"], w["deck"]
        sb = (pts[0][0] + 420) ** 2 + (pts[0][1] + 2018) ** 2 < (pts[-1][0] + 420) ** 2 + (pts[-1][1] + 2018) ** 2
        d = 1 if sb else -1
        i0 = (s[0] + 2) if sb else (s[1] - 2)
        i1 = i0 + d * 25
        arch(bufs["steel_white"], w, min(i0, i1), max(i0, i1), 15.0, 1.5, 5.0, sec=0.8)
        pier(bufs["concrete"], w, i0, 5.5, thick=2.5)
        pier(bufs["concrete"], w, i1, 6.5, thick=5.0)
        tx, ty, nx, ny = frame(pts, i1)
        px, py = pts[i1][0] + nx * 7.0, pts[i1][1] + ny * 7.0  # the pavilion: a viewing platform with a sail roof beside the deck
        ang = math.atan2(ty, tx)
        bufs["concrete"].box(px, py, zs[i1] - 0.8, 12.0, 9.0, 0.8, ang)
        bufs["canopy"].box(px, py, zs[i1] + 4.2, 13.0, 10.0, 0.25, ang)
        for sx in (-5.0, 5.0):
            bufs["steel_white"].beam((px + tx * sx, py + ty * sx, zs[i1]), (px + tx * sx, py + ty * sx, zs[i1] + 4.2), 0.3)
        end = s[1] if sb else s[0]
        rest = abs(end - i1)
        np_ = max(1, int(round(rest * 4.0 / 45.0)))
        for k in range(1, np_ + 1):                          # city-side girder spans on slim piers (spacing estimated)
            pier(bufs["concrete"], w, i1 + d * int(k * rest / np_), 2.2, thick=1.6)
        made.append("Goodwill Bridge: 102 m arch on the South Bank half, pavilion pier mid-river, %d slim piers to the city bank (spacing estimated)" % np_)
    w, s = main("Kurilpa Bridge")
    if w:                                                   # tensegrity: 20 masts, spars, canopy
        pts, zs = w["pts"], w["deck"]
        n = s[1] - s[0]
        for k in range(10):
            i = s[0] + int((k + 0.5) * n / 10)
            tx, ty, nx, ny = frame(pts, i)
            for sd in (1, -1):
                h = 14.0 + 9.0 * ((k * 7 + (sd > 0) * 3) % 5) / 4
                ln = 0.25 * (((k * 3) % 3) - 1)
                top = (pts[i][0] + nx * sd * (3.2 + 0.35 * h) + tx * ln * h, pts[i][1] + ny * sd * (3.2 + 0.35 * h) + ty * ln * h, zs[i] + h)
                T.tube(bufs["steel_white"], (pts[i][0] + nx * sd * 3.2, pts[i][1] + ny * sd * 3.2, zs[i] - 1.0), top, 0.3, 0.18, 6)
                for dj in (-6, 6):
                    j = min(max(i + dj, 0), len(pts) - 1)
                    bufs["cables"].beam(top, (pts[j][0], pts[j][1], zs[j] + 0.5), 0.1)
            if k < 9:                                       # horizontal spars over the deck
                j = s[0] + int((k + 1.0) * n / 10)
                a_, b_ = pts[i], pts[j]
                bufs["steel_white"].beam((a_[0] + nx * 4, a_[1] + ny * 4, zs[i] + 9.0), (b_[0] - nx * 4, b_[1] - ny * 4, zs[j] + 7.0), 0.25)
        cl = C.offset_line([tuple(p) for p in pts[s[0]:s[1]]], 1.2)
        cr = C.offset_line([tuple(p) for p in pts[s[0]:s[1]]], -3.0)
        m = len(cl)
        bufs["canopy"].add([(cl[i][0], cl[i][1], zs[s[0] + i] + 3.6) for i in range(m)] + [(cr[i][0], cr[i][1], zs[s[0] + i] + 3.4) for i in range(m)],
                           [[i, m + i, m + i + 1, i + 1] for i in range(m - 1)])
        i0, i1 = centred(s, 128.0)                           # 128 m main span between two river piers
        for i in (i0, i1):
            pier(bufs["concrete"], w, i, 3.5, thick=1.8)
        made.append("Kurilpa Bridge: 20 masts + canopy, 128 m main span on two river piers")
    w, s = main("Neville Bonner Bridge")
    if w:                                                   # one river pier; 75 m twin-leg mast leaning to the city; arch to South Bank
        pts, zs = w["pts"], w["deck"]
        n = len(pts)
        sb = (pts[0][0] + 932) ** 2 + (pts[0][1] + 1329) ** 2 < (pts[-1][0] + 932) ** 2 + (pts[-1][1] + 1329) ** 2
        d = 1 if sb else -1                                  # d steps from South Bank toward the city
        land = min(max((s[0] - 2) if sb else (s[1] + 2), 0), n - 1)
        ip = land + d * 36                                   # the pier: 145 m main span from the South Bank landing
        tx, ty, nx, ny = frame(pts, ip)
        cx, cy = tx * d, ty * d                              # unit vector toward the city
        P = pts[ip]
        bufs["concrete"].box(P[0], P[1], -3.0, 7.0, 16.0, 5.5, math.atan2(ty, tx))        # pier cap in the river
        bufs["concrete"].box(P[0], P[1], zs[ip] - 0.8, 14.0, 11.0, 0.8, math.atan2(ty, tx))  # mid-bridge viewing deck
        top = (P[0] + cx * 34.0, P[1] + cy * 34.0, 75.0)
        for sd in (1, -1):                                   # twin legs either side of the deck, meeting at the top
            T.tube(bufs["steel_white"], (P[0] + nx * sd * 6.0, P[1] + ny * sd * 6.0, 2.0), top, 1.3, 0.6, 10)
        city_end = (s[1] if sb else s[0])
        for j in range(ip + d * 5, city_end + d, d * 3):     # fan of stays to the city-side deck
            if 0 <= j < n:
                for sd in (1, -1):
                    jx, jy = frame(pts, j)[2:]
                    bufs["cables"].beam(top, (pts[j][0] + jx * sd * 2.4, pts[j][1] + jy * sd * 2.4, zs[j] + 0.4), 0.16)
        L_ = pts[land]
        for sd in (1, -1):                                   # backstays over the arch to the South Bank abutment
            bufs["cables"].beam(top, (L_[0] + nx * sd * 4.5, L_[1] + ny * sd * 4.5, zs[land] + 0.5), 0.22)
        m = abs(ip - land)
        prev = None
        for k in range(m + 1):                               # the arch: one crown over the path, splitting to straddle it at each end
            i = land + d * k
            t = k / m
            z = (zs[land] - 1.0) * (1 - t) + 2.5 * t + (31.0 - 8.0) * 4 * t * (1 - t)
            half = 0.6 + 4.6 * abs(2 * t - 1) ** 2
            fx, fy = frame(pts, i)[2:]
            cur = [(pts[i][0] + fx * half * sd, pts[i][1] + fy * half * sd, z) for sd in (1, -1)]
            if prev:
                for a_, b_ in zip(prev, cur):
                    bufs["steel_white"].beam(a_, b_, 0.9, 1.2)
                if k % 4 == 0 and z > zs[i] + 4.0:
                    for sd, c_ in zip((1, -1), cur):
                        bufs["cables"].beam(c_, (pts[i][0] + fx * sd * 2.4, pts[i][1] + fy * sd * 2.4, zs[i] + 0.4), 0.14)
            prev = cur
        a0, a1 = min(s[0], s[1]), max(s[0], s[1])            # the shade canopy over one side of the path
        cl = C.offset_line([tuple(p) for p in pts[a0:a1]], 0.4)
        cr = C.offset_line([tuple(p) for p in pts[a0:a1]], -2.6)
        mm = len(cl)
        bufs["canopy"].add([(cl[i][0], cl[i][1], zs[a0 + i] + 3.3) for i in range(mm)] + [(cr[i][0], cr[i][1], zs[a0 + i] + 3.1) for i in range(mm)],
                           [[i, mm + i, mm + i + 1, i + 1] for i in range(mm - 1)])
        made.append("Neville Bonner Bridge: one river pier, 75 m twin-leg mast leaning to the city, 145 m arch to South Bank, stays, canopy (lean and leg spread read off photos)")
    w, s = main("Kangaroo Point Bridge")
    if w:                                                   # single mast cable stay: 95 m mast in the river, 183 m main span
        pts, zs = w["pts"], w["deck"]
        n = len(pts)
        d = 1 if pts[0][0] < pts[-1][0] else -1             # d steps from the city (west) to Kangaroo Point
        c0 = s[0] if d > 0 else s[1]
        im = c0 + d * 23                                     # mast about 90 m off the city bank (estimated)
        ie = im + d * 46                                     # 183 m main span
        tx, ty, nx, ny = frame(pts, im)
        M = pts[im]
        top = (M[0], M[1], 95.0)
        T.tube(bufs["steel_white"], (M[0], M[1], -3.0), top, 2.4, 0.9, 12)
        bufs["concrete"].box(M[0], M[1], -3.0, 9.0, 12.0, 5.0, math.atan2(ty, tx))
        bufs["concrete"].box(M[0], M[1], zs[im] - 0.9, 18.0, 13.0, 0.9, math.atan2(ty, tx))   # the deck widens round the mast
        for j in range(im + d * 5, ie, d * 3):
            f = abs(j - im) / 46.0
            bufs["cables"].beam((top[0], top[1], 95.0 - 30.0 * (1 - f)), (pts[j][0], pts[j][1], zs[j] + 0.5), 0.18)
        for j in range(im - d * 4, c0 - d * 3, -d * 3):       # back stays to the city side span
            if 0 <= j < n:
                f = abs(j - im) / 23.0
                bufs["cables"].beam((top[0], top[1], 95.0 - 30.0 * (1 - min(f, 1.0))), (pts[j][0], pts[j][1], zs[j] + 0.5), 0.18)
        far = s[1] if d > 0 else s[0]
        spots = [im - d * 12, ie] + ([ie + d * (abs(far - ie) // 2)] if abs(far - ie) > 14 else [])
        for i in spots:
            if 0 <= i < n:
                pier(bufs["concrete"], w, i, 3.2, thick=1.8)
        made.append("Kangaroo Point Bridge: 95 m single mast, 183 m main span, %d river piers (mast and pier positions estimated from the span lengths)" % len(spots))
    cc = [(w, W.span(w["pts"])) for w in by.get("Pacific Motorway", [])]
    cc = [(w, s) for w, s in cc if s]
    if cc:                                                  # Captain Cook Bridge: twin haunched concrete box girders, 183 m main span
        w0, s0 = cc[0]
        i0, i1 = centred(s0, 183.0)
        marks = [w0["pts"][min(max(i, 0), len(w0["pts"]) - 1)] for i in (i0, i1)]
        ends = [w0["pts"][s0[0]], w0["pts"][s0[1]]]
        for w, s in cc:
            at = [nearest(w, p) for p in marks]
            e = sorted(nearest(w, p) for p in ends)
            girder(bufs["concrete"], w, e[0] - 6, e[1] + 6, at, w["width"] / 2 + 0.3, w["width"] / 2 - 2.5, 3.0, 9.0, 85.0)
            for i in at:
                pier(bufs["concrete"], w, i, w["width"] / 2 - 2.0, thick=3.0, drop=9.0)
            for i in e:
                pier(bufs["concrete"], w, i, w["width"] / 2 - 2.0, thick=2.0, drop=3.0)
        made.append("Captain Cook Bridge: twin haunched box girders, 183 m main span on two river piers (side spans estimated)")
    gb = [(w, W.span(w["pts"])) for w in by.get("Go Between Bridge", [])]
    gb = [(w, s) for w, s in gb if s]
    rd = [(w, s) for w, s in gb if w["kind"] == "road"]
    if rd:                                                  # Go Between Bridge: haunched box girder, 74 + 117 + 80 m, two river piers
        w0, s0 = rd[0]
        i0, i1 = centred(s0, 117.0)
        marks = [w0["pts"][i0], w0["pts"][i1]]
        for w, s in gb:
            at = [nearest(w, p) for p in marks]
            road = w["kind"] == "road"
            ht = w["width"] / 2 + (0.8 if road else 0.3)
            girder(bufs["concrete"], w, min(s) - 5, max(s) + 5, at, ht, ht * 0.6, 2.4 if road else 1.2, 5.5 if road else 1.2, 55.0)
            for i in at:
                pier(bufs["concrete"], w, i, ht if road else ht * 0.6, thick=2.6, drop=5.5 if road else 1.2)
        made.append("Go Between Bridge: haunched box girder, 117 m main span on two river piers")
    return made


def build():
    import bpy
    if L.GAME_EXPORT or getattr(L, "ACTIVE_STAGE", None) or not os.path.exists(ROADS):
        return {"module": "far_roads", "objects": [], "note": "skipped (game export, stage build or no data)"}
    d = json.load(open(ROADS))
    G, W = Ground(), Water()
    col = C.collection("far_roads")
    global GROUND
    GROUND = G
    bufs = {k: C.MeshBuf() for k in list(COL) + ["cables"]}
    n = {"road_m": 0.0, "rail_m": 0.0, "bridges": 0, "piers": 0, "skipped_in_box": 0, "marked": 0, "lights": 0}
    fp = os.path.join(L.REF, "wide", "features.json")
    feats = json.load(open(fp)) if os.path.exists(fp) else {}
    for w in d["ways"]:
        pts = [tuple(p) for p in w["pts"]]
        if w["bridge"]:
            if w["name"] in SKIP_NAMES or all(in_box(x, y, 5.0) for x, y in pts):
                n["skipped_in_box"] += 1
                continue
            if len(pts) < 2:
                continue
            mp = w["pts"][len(w["pts"]) // 2]                # Victoria Bridge: hero_towers.landmarks builds its girder and two blade piers
            vic = abs((mp[0] + 956.0) * 0.52 - (mp[1] + 1036.5) * 0.854) < 22.0 and abs((mp[0] + 956.0) * 0.854 + (mp[1] + 1036.5) * 0.52) < 140.0
            sp = W.span(w["pts"]) if w["name"] in RIVER_SPANS else None
            n["piers"] += deck(bufs, w, G, piers=not vic, clear=(sp[0] - 4, sp[1] + 4) if sp else None)
            n["bridges"] += 1
            if w["kind"] == "road":
                n["marked"] += 1 if markings(bufs["paint"], w, pts, [z + 0.03 for z in w["deck"]]) else 0
                n["lights"] += lights(bufs, w, pts, w["deck"])
            continue
        if w["kind"] == "path":
            continue
        for run in runs_outside(pts):
            if w["kind"] == "rail":
                ribbon(bufs["rail"], run, 4.2, G, 0.45)
                n["rail_m"] += 4.0 * len(run)
            else:
                key = "motorway" if w["cls"].startswith(("motorway", "trunk")) else "asphalt"
                lift = 0.5 if key == "motorway" else (0.42 if w["cls"] in ("primary", "secondary", "busway") else 0.36)
                zs = ribbon(bufs[key], run, w["width"], G, lift)
                n["road_m"] += 4.0 * len(run)
                n["marked"] += 1 if markings(bufs["paint"], w, run, zs) else 0
                n["lights"] += lights(bufs, w, run, zs)
    made = structures(bufs, d["ways"], W)
    nsig = signals(bufs, feats, G, d["ways"])
    ngan = gantries(bufs, feats, d["ways"])
    objs = []
    for k, buf in bufs.items():
        ob = buf.object("far_roads_" + k, col, "road")
        if ob:
            ob.data.materials[0] = C.material_rgb("far_roads_" + k, COL.get(k, (0.2, 0.2, 0.21)))
            objs.append(ob.name)
    return {"module": "far_roads", "objects": objs, "road_km": round(n["road_m"] / 1000, 1), "rail_km": round(n["rail_m"] / 1000, 1),
            "bridge_ways": n["bridges"], "piers": n["piers"], "ways_with_line_marking": n["marked"],
            "street_lights": n["lights"], "traffic_signal_posts": nsig, "sign_gantries": ngan, "bridge_ways_left_to_the_box": n["skipped_in_box"],
            "structures": made, "source": "OSM (osm_all) + 2019 LiDAR deck heights; bridge figures: Wikipedia"}
