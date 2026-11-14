"""Clean 2D shapes (no bpy): simplify, square corners, minimum-area rectangle. Used to turn OSM
footprints and LiDAR-measured roof tiers into clean geometry."""
import math

import numpy as np


def area(ring):
    return 0.5 * sum(ring[i][0] * ring[(i + 1) % len(ring)][1] - ring[(i + 1) % len(ring)][0] * ring[i][1]
                     for i in range(len(ring)))


def ccw(ring):
    return ring if area(ring) > 0 else ring[::-1]


def dedupe(ring, tol=0.05):
    out = []
    for p in ring:
        if not out or math.dist(p, out[-1]) > tol:
            out.append(tuple(p))
    if len(out) > 1 and math.dist(out[0], out[-1]) <= tol:
        out.pop()
    return out


def rdp(pts, eps):
    if len(pts) < 3:
        return list(pts)
    a, b = np.array(pts[0]), np.array(pts[-1])
    d = b - a
    ln = float(np.hypot(*d))
    if ln < 1e-9:
        dist = [math.dist(p, pts[0]) for p in pts]
    else:
        dist = [abs(d[0] * (p[1] - a[1]) - d[1] * (p[0] - a[0])) / ln for p in pts]
    i = int(np.argmax(dist))
    if dist[i] > eps:
        return rdp(pts[:i + 1], eps)[:-1] + rdp(pts[i:], eps)
    return [pts[0], pts[-1]]


def simplify(ring, eps=0.3):
    ring = dedupe(ring)
    if len(ring) < 4:
        return ring
    k = max(range(len(ring)), key=lambda i: math.dist(ring[i], ring[0]))
    out = rdp(ring[:k + 1], eps)[:-1] + rdp(ring[k:] + [ring[0]], eps)[:-1]
    return dedupe(out)


def dominant_angle(ring):
    """Angle (rad, 0..pi/2) that most edge length agrees with, modulo 90 deg."""
    best, acc = 0.0, {}
    for i in range(len(ring)):
        (x0, y0), (x1, y1) = ring[i], ring[(i + 1) % len(ring)]
        ln = math.hypot(x1 - x0, y1 - y0)
        a = math.atan2(y1 - y0, x1 - x0) % (math.pi / 2)
        k = round(math.degrees(a)) % 90
        for dk in (-2, -1, 0, 1, 2):
            acc[(k + dk) % 90] = acc.get((k + dk) % 90, 0.0) + ln * (1 - abs(dk) / 3)
    if acc:
        best = math.radians(max(acc, key=acc.get))
    return best


def square(ring, tol_deg=12.0, min_edge=0.6):
    """Snap edges within tol of the dominant 0/90 deg directions, then re-intersect neighbours.
    Edges far from both directions keep their own angle (curved and angled facades survive)."""
    ring = dedupe(ring)
    n = len(ring)
    if n < 4:
        return ring
    a0 = dominant_angle(ring)
    lines = []
    for i in range(n):
        p, q = ring[i], ring[(i + 1) % n]
        ang = math.atan2(q[1] - p[1], q[0] - p[0])
        rel = (ang - a0) % (math.pi / 2)
        if rel < math.radians(tol_deg) or rel > math.pi / 2 - math.radians(tol_deg):
            k = round((ang - a0) / (math.pi / 2))
            ang = a0 + k * math.pi / 2
        mx, my = (p[0] + q[0]) / 2, (p[1] + q[1]) / 2
        lines.append((mx, my, math.cos(ang), math.sin(ang), math.dist(p, q)))
    # merge consecutive (near-)parallel lines into the longer one
    merged = []
    for ln in lines:
        if merged and abs(merged[-1][2] * ln[3] - merged[-1][3] * ln[2]) < 0.02:
            if ln[4] > merged[-1][4]:
                merged[-1] = ln
            continue
        merged.append(ln)
    if len(merged) > 2 and abs(merged[0][2] * merged[-1][3] - merged[0][3] * merged[-1][2]) < 0.02:
        merged.pop()
    if len(merged) < 3:
        return ring
    out = []
    m = len(merged)
    for i in range(m):
        x1, y1, dx1, dy1, _ = merged[i - 1]
        x2, y2, dx2, dy2, _ = merged[i]
        det = dx1 * dy2 - dy1 * dx2
        if abs(det) < 1e-6:
            continue
        t = ((x2 - x1) * dy2 - (y2 - y1) * dx2) / det
        out.append((x1 + dx1 * t, y1 + dy1 * t))
    out = dedupe(out, min_edge)
    if len(out) < 3 or abs(area(out)) < 0.5 * abs(area(ring)) or abs(area(out)) > 1.6 * abs(area(ring)):
        return ring                        # squaring went wrong: keep the simplified ring
    return out


def clean(ring, eps=0.3):
    return ccw(square(simplify(ring, eps)))


def min_rect(ring):
    """Minimum-area rectangle: (cx, cy, length, width, angle of the long side)."""
    pts = np.array(ring)
    best = None
    for i in range(len(pts)):
        d = pts[(i + 1) % len(pts)] - pts[i]
        a = math.atan2(d[1], d[0])
        c, s = math.cos(a), math.sin(a)
        R = np.array([[c, s], [-s, c]])
        q = pts @ R.T
        lo, hi = q.min(0), q.max(0)
        ar = (hi - lo).prod()
        if best is None or ar < best[0]:
            mid = (lo + hi) / 2
            cx, cy = R.T @ mid
            L_, W_ = hi - lo
            ang = a if L_ >= W_ else a + math.pi / 2
            best = (ar, cx, cy, max(L_, W_), min(L_, W_), ang)
    return best[1:]


def point_in(x, y, ring):
    inside = False
    n = len(ring)
    for i in range(n):
        x1, y1 = ring[i]
        x2, y2 = ring[(i + 1) % n]
        if (y1 > y) != (y2 > y) and x < (x2 - x1) * (y - y1) / (y2 - y1) + x1:
            inside = not inside
    return inside
