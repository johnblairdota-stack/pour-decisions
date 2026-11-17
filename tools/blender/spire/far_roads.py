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


def deck(bufs, w, G, piers=True):
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


def structures(bufs, ways, W):
    """Main structures of the named river bridges, on the span over the traced water."""
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
        made.append("William Jolly Bridge: 3 x 72.5 m arches")
    for w in by.get("Merivale Bridge", [])[:1]:              # steel through arch, 132 m, both tracks
        s = W.span(w["pts"])
        if s:
            i0, i1 = centred(s, 132.0)
            i0, i1 = max(i0, 0), min(i1, len(w["pts"]) - 1)
            arch(bufs["steel_white"], w, i0, i1, 22.0, 6.0, 7.5, sec=1.4)
            made.append("Merivale Bridge: 132 m through arch")
    w, s = main("Goodwill Bridge")
    if w:                                                   # arch 102 m long, 15 m high, 10 m wide
        i0, i1 = centred(s, 102.0)
        arch(bufs["steel_white"], w, max(i0, 0), min(i1, len(w["pts"]) - 1), 15.0, 1.0, 5.0, sec=0.8)
        made.append("Goodwill Bridge: 102 m arch")
    w, s = main("Kurilpa Bridge")
    if w:                                                   # tensegrity: 20 masts, spars, canopy
        import trees as T
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
        made.append("Kurilpa Bridge: 20 masts + canopy")
    w, s = main("Neville Bonner Bridge")
    if w:                                                   # one 75 m mast on the mid-river pier, two 60 m arches
        mid = (s[0] + s[1]) // 2
        mast(bufs["steel_white"], bufs["cables"], w, mid, 75.0 - w["deck"][mid], 120.0, lean=0.12, side=6.0, r=1.5)
        k = int(60.0 / 4.0)
        for i0 in (mid - k, mid):
            arch(bufs["steel_white"], w, max(i0, 0), min(i0 + k, len(w["pts"]) - 1), 30.0 - w["deck"][mid], 0.5, 3.5, sec=0.7, brace=False)
        made.append("Neville Bonner Bridge: 75 m mast + two 60 m arches")
    w, s = main("Kangaroo Point Bridge")
    if w:                                                   # single-mast cable stay (height + position estimated)
        end0 = w["pts"][0]
        city_first = end0[0] < w["pts"][-1][0]              # the city (Alice St) end is the west end
        f = 0.35 if city_first else 0.65
        i = s[0] + int(f * (s[1] - s[0]))
        mast(bufs["steel_white"], bufs["cables"], w, i, 78.0, 180.0, r=2.0, every=4)
        made.append("Kangaroo Point Bridge: single mast (estimated 78 m, 35 % from the city bank)")
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
            n["piers"] += deck(bufs, w, G)
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
