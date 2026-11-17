"""Spire area, round 1 (thread "Polish the Spire area render"): everything AROUND the Spire site.

Built last (one line in build_all.MODULES). The Spire site is gameplay and hands off: this module adds
nothing within the keep-out zone (the lot + 9.5 m, and the Ann St strip in front of it, same numbers as
clear_kerb.py) and nothing on a carriageway except road surface marks. Its self-check fails the build if a
new piece's centre breaks either rule.

Parts (numbers in layout.AREA):
  car parks   St John's Cathedral car park and the other open-air car parks: asphalt draped on the ground,
              2.6 x 5.4 m bays, white lines, wheel stops, tree islands (trees where the LiDAR has trunks),
              light poles, entry gate and signs, low red-brick retaining wall + grass bank along Ann St
  forecourt   the cathedral's west front: the tree grove goes; bitumen drive loop, rolled kerb, garden beds
              (red cordyline, bromeliads), black tubular rail, noticeboard
  roads       asphalt patches, crack seal, manholes, side-entry pits, concrete gutter strip; a 40 km/h sign,
              a Story Bridge direction blade
  look        light(): sun + Nishita sky per view, half the world fill, warm sun, distance haze on aerials,
              dusk: lit windows and street lamps. restyle(): asphalt, footpaths, leaves, bark, car parks.
"""
import json
import math
import os

import bpy

import layout as L
import common as C
import shapes as S

AREA = getattr(L, "AREA", {})
NEW = []          # (x, y, kind) of every new piece: the self-check reads it


def P(key, default):
    return AREA.get(key, default)


# ---------------------------------------------------------------------------------------------- guards
class Guard:
    """Keep-out zone (Spire site + Ann St strip) and the carriageways."""
    def __init__(self):
        import numpy as np
        import spire
        import trees as T
        self.np = np
        self.lot = S.ccw(spire.osm_lot())
        self.road = T.RoadGuard(pad=0.2)
        self.clear = 9.5
        self.ann_mid = (-16.0, 14.4)
        self.ann_along = (0.760, 0.650)

    def keepout(self, x, y, pad=0.0):
        if S.point_in(x, y, self.lot):
            return True
        d = min(seg_dist(x, y, a, b) for a, b in zip(self.lot, self.lot[1:] + self.lot[:1]))
        if d < self.clear + pad:
            return True
        rx, ry = x - self.ann_mid[0], y - self.ann_mid[1]
        along = rx * self.ann_along[0] + ry * self.ann_along[1]
        out = -rx * self.ann_along[1] + ry * self.ann_along[0]
        return abs(along) < 46.0 + pad and -2.0 - pad < out < 30.0 + pad

    def on_road(self, x, y):
        return self.road.on_road(x, y)

    def ok(self, x, y, road_ok=False, pad=0.0):
        return not self.keepout(x, y, pad) and (road_ok or not self.on_road(x, y))


def seg_dist(x, y, a, b):
    dx, dy = b[0] - a[0], b[1] - a[1]
    l2 = dx * dx + dy * dy or 1e-9
    k = max(0.0, min(1.0, ((x - a[0]) * dx + (y - a[1]) * dy) / l2))
    return math.hypot(a[0] + dx * k - x, a[1] + dy * k - y)


def note(x, y, kind):
    NEW.append((x, y, kind))


def gz(x, y):
    return L.ground_z(x, y)


# ---------------------------------------------------------------------------------------------- helpers
def mat(name, rgb, shader="render", **props):
    m = C.material_rgb("area_" + name, rgb, shader=shader)
    for k, v in props.items():
        m[k] = v
    return m


def put(buf, name, col, m, objs):
    ob = buf.object("area_" + name, col, "roof")
    if ob:
        ob.data.materials[0] = m
        objs.append(ob.name)
    return ob


def drape(buf, ring, lift, cell=1.5, guard=None):
    """Ground-following surface over a polygon: grid cells whose middle is inside."""
    xs = [p[0] for p in ring]
    ys = [p[1] for p in ring]
    x = min(xs)
    n = 0
    while x < max(xs):
        y = min(ys)
        while y < max(ys):
            cx, cy = x + cell / 2, y + cell / 2
            if S.point_in(cx, cy, ring) and (guard is None or not guard.keepout(cx, cy)):
                q = [(x, y), (x + cell, y), (x + cell, y + cell), (x, y + cell)]
                buf.add([(px, py, gz(px, py) + lift) for px, py in q], [[0, 1, 2, 3]])
                n += 1
            y += cell
        x += cell
    return n


def drape_poly(name, ring, lift, col, cell=2.0):
    """r2: ground-following surface with the polygon's exact edge (no saw-tooth): one n-gon cut on a 2 m grid
    with bisect, then every vertex dropped onto the ground."""
    import bmesh
    from mathutils import Vector
    bm = bmesh.new()
    vs = [bm.verts.new((x, y, 0.0)) for x, y in ring]
    bm.faces.new(vs)
    xs = [p[0] for p in ring]
    ys = [p[1] for p in ring]
    for axis, lo, hi in ((0, min(xs), max(xs)), (1, min(ys), max(ys))):
        k = math.floor(lo / cell) * cell + cell
        while k < hi:
            co = Vector((k, 0, 0)) if axis == 0 else Vector((0, k, 0))
            no = Vector((1, 0, 0)) if axis == 0 else Vector((0, 1, 0))
            geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
            bmesh.ops.bisect_plane(bm, geom=geom, plane_co=co, plane_no=no)
            k += cell
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    for v in bm.verts:
        v.co.z = gz(v.co.x, v.co.y) + lift
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        if p.normal.z < 0:
            p.flip()
    ob = bpy.data.objects.new(name, me)
    col.objects.link(ob)
    return ob


def wheel_stop(buf, x, y, ang):
    """Precast concrete wheel stop: 1.8 m bar, trapezoid section 0.24 -> 0.12 m, 0.12 m high."""
    c, s = math.cos(ang), math.sin(ang)
    # r4: each end sits on the ground (a flat bar on the slope read as a diagonal wedge)
    v = []
    for l, w, dz in ((1.8, 0.24, 0.0), (1.74, 0.12, 0.12)):
        for dx, dy in ((-l / 2, -w / 2), (l / 2, -w / 2), (l / 2, w / 2), (-l / 2, w / 2)):
            px, py = x + dx * c - dy * s, y + dx * s + dy * c
            ex, ey = x + math.copysign(0.9, dx) * c, y + math.copysign(0.9, dx) * s
            v.append((px, py, gz(ex, ey) + 0.075 + dz))
    buf.add(v, [[3, 2, 1, 0], [4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]])


def kerb_ring(buf, ring, guard, gap=None):
    """Concrete kerb (0.15 x 0.15) along a polygon edge, following the ground."""
    for a, b in zip(ring, ring[1:] + ring[:1]):
        ln = math.dist(a, b)
        n = max(1, int(ln / 1.0))
        e = math.atan2(b[1] - a[1], b[0] - a[0])
        for i in range(n):
            t = (i + 0.5) / n
            x, y = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t
            if gap and math.dist((x, y), gap[0]) < gap[1]:
                continue
            if guard.ok(x, y):
                buf.box(x, y, gz(x, y) - 0.05, ln / n + 0.02, 0.16, 0.22, e)


def crown_z(crown, x, y):
    """Road surface height with the 2.5 % crown streets.py / streetscape.py use."""
    ax, ay, nx, ny, hw = crown
    v = abs((x - ax) * nx + (y - ay) * ny)
    return gz(x, y) + 0.046 + 0.025 * max(0.0, hw - v) + 0.008


def road_rect(buf, cx, cy, ln, wd, ang, crown, lift, nu=1, nv=1):
    """r2: a mark lying on the crowned road (grid nu x nv so it follows the camber), UV 0..1 for soft edges."""
    ux, uy = math.cos(ang), math.sin(ang)
    vx, vy = -uy, ux
    verts, uvs = [], []
    for j in range(nv + 1):
        for i in range(nu + 1):
            a, b = i / nu - 0.5, j / nv - 0.5
            x, y = cx + ux * a * ln + vx * b * wd, cy + uy * a * ln + vy * b * wd
            verts.append((x, y, crown_z(crown, x, y) + lift))
            uvs.append((i / nu, j / nv))
    faces = [[j * (nu + 1) + i, j * (nu + 1) + i + 1, (j + 1) * (nu + 1) + i + 1, (j + 1) * (nu + 1) + i]
             for j in range(nv) for i in range(nu)]
    buf.add(verts, faces, [[uvs[k] for k in f] for f in faces])


def flat_rect(buf, cx, cy, ln, wd, ang, lift):
    """Thin mark lying on the ground (draped at its four corners)."""
    ux, uy = math.cos(ang), math.sin(ang)
    vx, vy = -uy, ux
    pts = [(cx - ux * ln / 2 - vx * wd / 2, cy - uy * ln / 2 - vy * wd / 2),
           (cx + ux * ln / 2 - vx * wd / 2, cy + uy * ln / 2 - vy * wd / 2),
           (cx + ux * ln / 2 + vx * wd / 2, cy + uy * ln / 2 + vy * wd / 2),
           (cx - ux * ln / 2 + vx * wd / 2, cy - uy * ln / 2 + vy * wd / 2)]
    buf.add([(px, py, gz(px, py) + lift) for px, py in pts], [[0, 1, 2, 3]])


def disc(buf, cx, cy, r, lift, k=14):
    pts = [(cx + r * math.cos(2 * math.pi * i / k), cy + r * math.sin(2 * math.pi * i / k)) for i in range(k)]
    buf.add([(px, py, gz(px, py) + lift) for px, py in pts], [list(range(k))])


def pole(buf, x, y, z0, h, r0=0.09, r1=0.06):
    import trees as T
    T.tube(buf, (x, y, z0), (x, y, z0 + h), r0, r1, 10)


def small_tree(trunks, leaves, x, y, h, seed):
    """Car-park / bed tree: round tapering trunk, curved limbs, clumpy crown (tuckeroo / brush box size)."""
    import trees as T
    g = gz(x, y)
    r = max(1.8, 0.33 * h)
    T.tube(trunks, (x, y, g - 0.2), (x, y, g + h * 0.45), 0.16, 0.11, 10)
    for k in range(4):
        a = seed * 1.3 + k * math.pi / 2
        mid = (x + math.cos(a) * r * 0.18, y + math.sin(a) * r * 0.18, g + h * 0.62)     # r2: limbs end
        tip = (x + math.cos(a) * r * 0.32, y + math.sin(a) * r * 0.32, g + h * 0.74)     # inside the crown
        T.tube(trunks, (x, y, g + h * 0.42), mid, 0.09, 0.06, 7)
        T.tube(trunks, mid, tip, 0.06, 0.03, 6)
    for k in range(5):                                   # clumps, not one ball
        a = seed + k * 2.39
        d = r * (0.15 if k == 0 else 0.5)
        leaves.cloud((x + math.cos(a) * d, y + math.sin(a) * d, g + h - r * (0.75 if k == 0 else 0.9)),
                     (r * 0.66, r * 0.66, r * 0.55), int(420 + 40 * r * r), 0.16, shell=0.25, top_bias=0.2)


# ---------------------------------------------------------------------------------------------- car parks
CARPARK_MAIN = 1243599981           # St John's Cathedral car park (OSM amenity=parking, the L round the north side)
CARPARK_OTHER = (1243599979, 1243599980, 1210507997, 1210662509)
CATHEDRAL_AXIS = math.atan2(-121.0 + 65.7, -50.4 + 90.8)   # west front -> chancel (OSM outline), bays follow it


def carparks(col, guard, objs, report):
    import numpy as np
    import foliage as FO
    import trees as T
    o = L.osm()
    trunks_pts = [(x, y, h) for x, y, h, g in L.tree_points() if 3 <= h <= 30]
    tp = np.array([(x, y) for x, y, h in trunks_pts] or [(1e9, 1e9)])
    asphalt, lines, stops, kerbs, islands, wall, cap, bank = (C.MeshBuf() for _ in range(8))
    poles_b, heads, lamp_glass, signs_b, sign_face, rail = (C.MeshBuf() for _ in range(6))
    trunks = C.MeshBuf()
    leaves = FO.Foliage(seed=301)
    shrubs = FO.Foliage(seed=302)
    nb = ni = nt = 0
    for wid in (CARPARK_MAIN,) + CARPARK_OTHER:
        w = o["ways"].get(wid)
        if not w:
            continue
        ring = S.ccw(C.clean_ring(o["line"](w)))
        if len(ring) < 3:
            continue
        cx0 = sum(p[0] for p in ring) / len(ring)
        cy0 = sum(p[1] for p in ring) / len(ring)
        if guard.keepout(cx0, cy0):
            report.append("car park %d in the keep-out zone: skipped" % wid)
            continue
        ob_ = drape_poly("area_carpark_asphalt_%d" % wid, ring, 0.06, col)    # r2: exact edge, street asphalt
        cpm = bpy.data.materials.get("area_carpark_bitumen")
        if cpm is None:                                             # r14: own copy, so the streets can go darker alone
            src_ = bpy.data.materials.get("clay_road")
            cpm = src_.copy() if src_ else mat("carpark_asphalt", (0.1, 0.1, 0.1))
            cpm.name = "area_carpark_bitumen"
            cpm["asphalt"] = True
            cpm["asphalt_lo"] = [0.026, 0.026, 0.029]               # r13 values: critics call the car park right
            cpm["asphalt_hi"] = [0.058, 0.057, 0.060]
        ob_.data.materials.append(cpm)
        objs.append(ob_.name)
        note(cx0, cy0, "carpark")
        gate_pt = None
        if wid == CARPARK_MAIN:
            ang = CATHEDRAL_AXIS
        else:
            ang = S.min_rect(ring)[4]
        ux, uy = math.cos(ang), math.sin(ang)
        vx, vy = -uy, ux
        us = [p[0] * ux + p[1] * uy for p in ring]
        vs = [p[0] * vx + p[1] * vy for p in ring]
        BW, BD, AISLE = 2.6, 5.4, 6.4
        rows = []                                       # (v of the bay's aisle end, facing +1 / -1)
        v = min(vs) + 0.6
        while v < max(vs):
            rows.append((v + BD, -1))                   # bays from v to v + BD, aisle above
            rows.append((v + BD + AISLE, +1))           # bays from v + BD + AISLE up
            v += 2 * BD + AISLE
        inside = lambda x, y: S.point_in(x, y, ring) and not guard.keepout(x, y, 1.0)
        for va, face in rows:
            vmid = va - face * BD / 2 if face < 0 else va + BD / 2
            u = min(us) + 0.3
            k = 0
            while u + BW < max(us):
                um = u + BW / 2
                cx, cy = ux * um + vx * vmid, uy * um + vy * vmid
                corners = [(ux * (um + a * BW / 2) + vx * (vmid + b * BD / 2), uy * (um + a * BW / 2) + vy * (vmid + b * BD / 2))
                           for a in (-1, 1) for b in (-1, 1)]
                if all(inside(*c) for c in corners + [(cx, cy)]):
                    near = float(np.min(np.hypot(tp[:, 0] - cx, tp[:, 1] - cy)))
                    island = near < 2.2 or k % 9 == 8
                    if island:                                                     # raised island with a tree
                        islands.box(cx, cy, gz(cx, cy) - 0.1, BW - 0.3, BD - 0.4, 0.25, ang)
                        kerbs.box(cx, cy, gz(cx, cy) - 0.1, BW - 0.1, BD - 0.2, 0.18, ang)
                        if near >= 2.2:
                            small_tree(trunks, leaves, cx, cy, 7.0 + (k * 1.7) % 3, k + wid % 7)
                            nt += 1
                        shrubs.tufts((cx, cy, gz(cx, cy) + 0.15), 0.9, 40, 0.6)
                        if k % 18 == 8:                                            # light pole in every 2nd island
                            lx, ly = cx + vx * face * (BD / 2 - 0.6), cy + vy * face * (BD / 2 - 0.6)
                            pole(poles_b, lx, ly, gz(lx, ly), 7.5)
                            hx_, hy_ = lx - vx * face * 0.6, ly - vy * face * 0.6
                            heads.box(hx_, hy_, gz(lx, ly) + 7.3, 0.35, 0.8, 0.14, ang + math.pi / 2)
                            lamp_glass.box(hx_, hy_, gz(lx, ly) + 7.27, 0.3, 0.6, 0.03, ang + math.pi / 2)
                            note(lx, ly, "pole")
                        ni += 1
                        note(cx, cy, "island")
                    else:
                        for a in (-1, 1):                                          # side lines
                            sx_, sy_ = cx + ux * a * BW / 2, cy + uy * a * BW / 2
                            flat_rect(lines, sx_, sy_, BD, 0.1, ang + math.pi / 2, 0.09)
                        bx, by = cx - vx * face * (BD / 2 - 0.05), cy - vy * face * (BD / 2 - 0.05)
                        flat_rect(lines, bx, by, BW, 0.1, ang, 0.09)                # back line
                        wx, wy = cx - vx * face * (BD / 2 - 0.75), cy - vy * face * (BD / 2 - 0.75)
                        wheel_stop(stops, wx, wy, ang)                              # r2: concrete bar
                        nb += 1
                        note(cx, cy, "bay")
                k += 1
                u += BW
        if wid == CARPARK_MAIN:
            # Ann St edge: low red-brick retaining wall with a grass bank (2012 photo), entry with gate posts
            ann = [(-26, 19), (-36, 11), (-55, -6), (-61, -11), (-74, -23), (-87, -34), (-95, -40), (-102, -47)]
            edges = list(zip(ring, ring[1:] + ring[:1]))
            gate_done = False
            for a, b in edges:
                mx, my = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
                da = min(seg_dist(mx, my, p, q) for p, q in zip(ann[:-1], ann[1:]))
                if da > 22 or math.dist(a, b) < 3:
                    continue
                ln = math.dist(a, b)
                e = math.atan2(b[1] - a[1], b[0] - a[0])
                gate_u = ln / 2 if (not gate_done and ln > 9) else None
                steps = max(1, int(ln / 1.0))
                for i in range(steps):
                    t0, t1 = i / steps, (i + 1) / steps
                    tm = (t0 + t1) / 2 * ln
                    if gate_u is not None and abs(tm - gate_u) < 3.2:
                        continue
                    p0 = (a[0] + (b[0] - a[0]) * t0, a[1] + (b[1] - a[1]) * t0)
                    p1 = (a[0] + (b[0] - a[0]) * t1, a[1] + (b[1] - a[1]) * t1)
                    pmx, pmy = (p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2
                    if not guard.ok(pmx, pmy):
                        continue
                    z = min(gz(*p0), gz(*p1))
                    wall.box(pmx, pmy, z - 0.3, ln / steps + 0.01, 0.23, 0.9 + abs(gz(*p0) - gz(*p1)), e)
                    cap.box(pmx, pmy, z + 0.6 + abs(gz(*p0) - gz(*p1)), ln / steps + 0.01, 0.3, 0.06, e)
                    nx_, ny_ = math.sin(e), -math.cos(e)             # outward (ring is ccw: right of the edge)
                    for j in range(2):
                        bxp, byp = pmx + nx_ * (0.6 + 1.0 * j), pmy + ny_ * (0.6 + 1.0 * j)
                        if guard.ok(bxp, byp):
                            bank.add([(bxp + math.cos(e) * ln / steps / 2 - nx_ * 0.5, byp + math.sin(e) * ln / steps / 2 - ny_ * 0.5, gz(bxp, byp) + 0.05),
                                      (bxp + math.cos(e) * ln / steps / 2 + nx_ * 0.5, byp + math.sin(e) * ln / steps / 2 + ny_ * 0.5, gz(bxp, byp) + 0.04),
                                      (bxp - math.cos(e) * ln / steps / 2 + nx_ * 0.5, byp - math.sin(e) * ln / steps / 2 + ny_ * 0.5, gz(bxp, byp) + 0.04),
                                      (bxp - math.cos(e) * ln / steps / 2 - nx_ * 0.5, byp - math.sin(e) * ln / steps / 2 - ny_ * 0.5, gz(bxp, byp) + 0.05)],
                                     [[0, 1, 2, 3]])
                    note(pmx, pmy, "wall")
                if gate_u is not None:
                    gx = a[0] + (b[0] - a[0]) * gate_u / ln
                    gy = a[1] + (b[1] - a[1]) * gate_u / ln
                    if guard.ok(gx, gy):
                        for s in (-1, 1):                                       # gate posts + open swing leaf
                            px_, py_ = gx + math.cos(e) * s * 3.0, gy + math.sin(e) * s * 3.0
                            rail.box(px_, py_, gz(px_, py_), 0.12, 0.12, 1.4, e)
                            lx2 = px_ - math.cos(e) * s * 0.2 - math.sin(e) * 2.6
                            ly2 = py_ - math.sin(e) * s * 0.2 + math.cos(e) * 2.6
                            for zz in (0.25, 1.15):
                                rail.beam((px_, py_, gz(px_, py_) + zz), (lx2, ly2, gz(px_, py_) + zz), 0.05)
                            rail.beam((lx2, ly2, gz(px_, py_) + 0.2), (lx2, ly2, gz(px_, py_) + 1.2), 0.05)
                        sx_, sy_ = gx + math.cos(e) * 4.2 - math.sin(e) * 0.3, gy + math.sin(e) * 4.2 + math.cos(e) * 0.3
                        pole(signs_b, sx_, sy_, gz(sx_, sy_), 2.6, 0.04, 0.04)
                        sign_face.box(sx_, sy_, gz(sx_, sy_) + 1.7, 0.9, 0.04, 0.9, e)
                        C.text_obj(col, "area_carpark_sign_text", "CATHEDRAL\nCAR PARK\nPERMIT\nHOLDERS ONLY",
                                   (sx_ + math.sin(e) * 0.03, sy_ - math.cos(e) * 0.03, gz(sx_, sy_) + 2.15),
                                   (math.pi / 2, 0, e), 0.13, (0.05, 0.12, 0.35))
                        note(gx, gy, "gate")
                        gate_done = True
                        gate_pt = (gx, gy)
        kerb_ring(kerbs, ring, guard, gap=(gate_pt, 3.6) if gate_pt else None)   # r2: kerb, no lawn saw-tooth
    objs_before = len(objs)
    put(lines, "carpark_lines", col, mat("carpark_lines", (0.80, 0.80, 0.76)), objs)
    put(stops, "carpark_wheel_stops", col, mat("wheel_stops", (0.40, 0.39, 0.37)), objs)
    put(kerbs, "carpark_kerbs", col, mat("carpark_kerb", (0.50, 0.48, 0.45)), objs)
    put(islands, "carpark_island_mulch", col, mat("mulch", (0.13, 0.08, 0.05)), objs)
    put(wall, "carpark_brick_wall", col, mat("carpark_brick", (0.36, 0.13, 0.08), shader="brick"), objs)
    put(cap, "carpark_wall_cap", col, mat("wall_cap", (0.55, 0.52, 0.48)), objs)
    put(bank, "carpark_grass_bank", col, bpy.data.materials.get("clay_grass") or mat("grass", (0.12, 0.2, 0.06)), objs)
    put(poles_b, "carpark_light_poles", col, mat("galv", (0.45, 0.46, 0.46)), objs)
    put(heads, "carpark_light_heads", col, mat("lamp_head", (0.18, 0.19, 0.2)), objs)
    put(lamp_glass, "carpark_lamp_glass", col, mat("lamp_glass", (0.9, 0.85, 0.7), lamp=True), objs)
    put(signs_b, "carpark_sign_posts", col, mat("galv", (0.45, 0.46, 0.46)), objs)
    put(sign_face, "carpark_sign_face", col, mat("sign_white", (0.85, 0.85, 0.82)), objs)
    put(rail, "carpark_gate", col, mat("black_rail", (0.02, 0.02, 0.02)), objs)
    put(trunks, "carpark_tree_trunks", col, mat("bark", P("bark_rgb", (0.105, 0.069, 0.045))), objs)
    ob = leaves.object("area_carpark_leaves", col, (0.045, 0.10, 0.035), (0.12, 0.20, 0.06))
    if ob:
        objs.append(ob.name)
    ob = shrubs.object("area_carpark_shrubs", col, (0.05, 0.12, 0.04), (0.14, 0.22, 0.07))
    if ob:
        objs.append(ob.name)
    report.append("car parks: %d bays, %d islands, %d new trees, %d objects" % (nb, ni, nt, len(objs) - objs_before))
    # streets.py's flat car-park slab + bay lines (one level for the whole sloping lot): hide the faces
    # inside these car parks, the draped surface replaces them
    rings = []
    for wid in (CARPARK_MAIN,) + CARPARK_OTHER:
        w = o["ways"].get(wid)
        if w:
            rings.append(S.ccw(C.clean_ring(o["line"](w))))
    for name in ("car_parks", "car_park_bay_lines"):
        drop_faces(bpy.data.objects.get(name), rings)


def in_rings_np(X, Y, rings):
    """Vectorised point-in-polygon for several rings (any of them)."""
    import numpy as np
    hit = np.zeros(len(X), bool)
    for ring in rings:
        ins = np.zeros(len(X), bool)
        n = len(ring)
        for i in range(n):
            (x1, y1), (x2, y2) = ring[i], ring[(i + 1) % n]
            if y1 == y2:
                continue
            c = ((y1 > Y) != (y2 > Y)) & (X < (x2 - x1) * (Y - y1) / (y2 - y1) + x1)
            ins ^= c
        hit |= ins
    return hit


TREE_PREFIX = ("leaves_", "tree_", "blooms_", "palm_")


def clear_trees(rings, guard):
    """Remove whole trees whose trunk is inside the rings: every tree face within the crown radius of such a
    trunk, plus any tree face whose centre is inside the rings (canopy-fill trees, grown 2 m for trunks)."""
    import numpy as np
    pts = [(x, y, h) for x, y, h, g in L.tree_points() if 3.0 <= h <= 40.0]
    gone_ids = {i for i, (x, y, h) in enumerate(pts) if any(S.point_in(x, y, r) for r in rings)}
    # r3: a neighbour whose crown centre sits inside a removed crown would be left as a bare fork: it goes too
    for i, (x, y, h) in enumerate(pts):
        if i not in gone_ids and any(math.hypot(x - pts[j][0], y - pts[j][1]) < 0.3 * pts[j][2] for j in list(gone_ids)):
            gone_ids.add(i)
    cyl = [(pts[i][0], pts[i][1], 0.42 * pts[i][2] + 0.5) for i in gone_ids]
    grown = []
    for r in rings:
        cx = sum(p[0] for p in r) / len(r)
        cy = sum(p[1] for p in r) / len(r)
        grown.append([(x + (x - cx) / max(1e-6, math.hypot(x - cx, y - cy)) * 2.0,
                       y + (y - cy) / max(1e-6, math.hypot(x - cx, y - cy)) * 2.0) for x, y in r])

    def test(X, Y, Z, rr):
        hit = in_rings_np(X, Y, rr)
        for cx, cy, rad in cyl:
            hit |= (X - cx) ** 2 + (Y - cy) ** 2 < rad * rad
        return hit
    gone = 0
    for ob in list(bpy.data.objects):
        if ob.type == "MESH" and ob.name.startswith(TREE_PREFIX):
            rr = grown if ("trunk" in ob.name or "palm" in ob.name) else rings
            gone += drop_where(ob, lambda X, Y, Z, rr=rr: test(X, Y, Z, rr))
    return gone


def drop_where(ob, test):
    """Delete faces whose centre (X, Y, Z arrays) passes test(X, Y, Z) -> bool array."""
    if ob is None or ob.type != "MESH" or not ob.data.polygons:
        return 0
    import numpy as np
    me = ob.data
    cen = np.empty(len(me.polygons) * 3, "f4")
    me.polygons.foreach_get("center", cen)
    cen = cen.reshape(-1, 3)
    dead = np.nonzero(test(cen[:, 0], cen[:, 1], cen[:, 2]))[0]
    if not len(dead):
        return 0
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[bm.faces[int(i)] for i in dead], context="FACES")
    bm.to_mesh(me)
    bm.free()
    me.update()
    return len(dead)


def drop_faces(ob, rings):
    """Delete the faces of an existing merged object whose centre is inside any of the rings."""
    if ob is None or ob.type != "MESH" or not ob.data.polygons:
        return 0
    import numpy as np
    xs = [p[0] for r in rings for p in r]
    ys = [p[1] for r in rings for p in r]
    bb = [ob.matrix_world @ __import__("mathutils").Vector(c) for c in ob.bound_box]
    if max(v.x for v in bb) < min(xs) or min(v.x for v in bb) > max(xs) or \
            max(v.y for v in bb) < min(ys) or min(v.y for v in bb) > max(ys):
        return 0
    me = ob.data
    cen = np.empty(len(me.polygons) * 3, "f4")
    me.polygons.foreach_get("center", cen)
    cen = cen.reshape(-1, 3)
    dead = np.nonzero(in_rings_np(cen[:, 0], cen[:, 1], rings))[0]
    if not len(dead):
        return 0
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[bm.faces[int(i)] for i in dead], context="FACES")
    bm.to_mesh(me)
    bm.free()
    me.update()
    return len(dead)


# ---------------------------------------------------------------------------------------------- forecourt
WEST_FRONT = ((-90.8, -65.7), (-110.7, -83.4))     # OSM outline: the west front wall on the Ann St side


def forecourt_zone():
    """Between the Ann St footpath and the west front (2010 photo: open drive and beds, no grove)."""
    (ax, ay), (bx, by) = WEST_FRONT
    e = math.atan2(by - ay, bx - ax)
    ux, uy = math.cos(e), math.sin(e)
    nx, ny = uy, -ux                                   # away from the church, towards Ann St
    ring = []
    for t, d in ((-4.0, 1.0), (math.dist(WEST_FRONT[0], WEST_FRONT[1]) + 4.0, 1.0),
                 (math.dist(WEST_FRONT[0], WEST_FRONT[1]) + 4.0, 11.0), (-4.0, 11.0)):
        ring.append((ax + ux * t + nx * d, ay + uy * t + ny * d))
    return ring, (ux, uy), (nx, ny), e


def forecourt(col, guard, objs, report):
    import foliage as FO
    ring, (ux, uy), (nx, ny), e = forecourt_zone()
    (ax, ay), (bx, by) = WEST_FRONT
    # 1. the grove goes: leaves, crowns and trunks with their middle in the zone
    # r2: whole trees go (round 1 cut by area and left stumps and bare forks); also the trees in the
    # cathedral_west_front_2010 photo's view, where the photo shows the open drive
    cam = (-156.2, -63.5)
    hd = math.radians(115.5)
    wedge = [(cam[0] + d * math.sin(hd + a), cam[1] + d * math.cos(hd + a))
             for d, a in ((8, -0.56), (8, 0.56), (50, 0.56), (50, 0.0), (50, -0.56))]
    gone = clear_trees([ring, wedge], guard)
    # 2. drive loop: bitumen U from Ann St to the porch and back, rolled kerb both sides
    drive, kerb, beds, rail, board, post = (C.MeshBuf() for _ in range(6))
    red = FO.Foliage(seed=311)
    green = FO.Foliage(seed=312)
    L_ = math.dist(WEST_FRONT[0], WEST_FRONT[1])
    mid = (ax + ux * L_ / 2, ay + uy * L_ / 2)
    path = []
    for i in range(25):                                # U: in at one end, past the porch, out at the other
        t = i / 24
        a = math.pi * t
        along = -L_ * 0.42 * math.cos(a)
        out = 11.0 - 7.0 * math.sin(a)
        path.append((mid[0] + ux * along + nx * out, mid[1] + uy * along + ny * out))
    for p, q in zip(path[:-1], path[1:]):
        c = ((p[0] + q[0]) / 2, (p[1] + q[1]) / 2)
        if not guard.ok(*c):
            continue
        flat_rect(drive, c[0], c[1], math.dist(p, q) + 0.25, 4.0, math.atan2(q[1] - p[1], q[0] - p[0]), 0.07)
        hd = math.atan2(q[1] - p[1], q[0] - p[0])
        for s in (-1, 1):
            kx, ky = c[0] - math.sin(hd) * s * 2.05, c[1] + math.cos(hd) * s * 2.05
            kerb.box(kx, ky, gz(kx, ky) - 0.05, math.dist(p, q) + 0.2, 0.3, 0.17, hd)
        note(c[0], c[1], "drive")
    # 3. beds inside the loop and beside the porch: red cordyline, bromeliads, low shrubs; black tubular rail
    for k, (along, out, rw, rd) in enumerate(((-L_ * 0.22, 7.0, 5.0, 3.2), (L_ * 0.22, 7.0, 5.0, 3.2),
                                               (-L_ * 0.5 - 2.0, 3.0, 3.0, 4.0), (L_ * 0.5 + 2.0, 3.0, 3.0, 4.0))):
        cx = mid[0] + ux * along + nx * out
        cy = mid[1] + uy * along + ny * out
        if not guard.ok(cx, cy):
            continue
        beds.box(cx, cy, gz(cx, cy) - 0.1, rw, rd, 0.32, e)
        g = gz(cx, cy) + 0.22
        for j in range(9):
            px = cx + ux * ((j % 3) - 1) * rw * 0.3 + nx * ((j // 3) - 1) * rd * 0.28
            py = cy + uy * ((j % 3) - 1) * rw * 0.3 + ny * ((j // 3) - 1) * rd * 0.28
            if j in (0, 8):                                              # r4: fewer reds, more green clumps
                red.tufts((px, py, g), 0.3, 16, 1.0)                    # cordyline: red strappy clumps
            else:
                green.tufts((px, py, g), 0.5, 26, 0.6); green.cloud((px, py, g + 0.35), (0.5, 0.5, 0.4), 70, 0.12, shell=0.3)
        green.cloud((cx, cy, g + 0.3), (rw * 0.45, rd * 0.4, 0.35), 260, 0.14, shell=0.4, top_bias=0.6)
        corners = [(cx + ux * a_ * rw / 2 + nx * b_ * rd / 2, cy + uy * a_ * rw / 2 + ny * b_ * rd / 2)
                   for a_, b_ in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
        for p, q in zip(corners, corners[1:] + corners[:1]):           # tubular rail round the bed
            rail.beam((p[0], p[1], gz(*p) + 0.75), (q[0], q[1], gz(*q) + 0.75), 0.05)
            n = max(1, int(math.dist(p, q) / 1.8))
            for i in range(n + 1):
                x_ = p[0] + (q[0] - p[0]) * i / n
                y_ = p[1] + (q[1] - p[1]) * i / n
                rail.beam((x_, y_, gz(x_, y_)), (x_, y_, gz(x_, y_) + 0.78), 0.05)
        note(cx, cy, "bed")
    # 4. noticeboard by the drive entry
    nbx, nby = mid[0] - ux * (L_ * 0.5 + 3.5) + nx * 11.0, mid[1] - uy * (L_ * 0.5 + 3.5) + ny * 11.0
    if guard.ok(nbx, nby):
        for s in (-1, 1):
            post.box(nbx + ux * s * 0.8, nby + uy * s * 0.8, gz(nbx, nby), 0.12, 0.12, 2.1, e)
        board.box(nbx, nby, gz(nbx, nby) + 0.9, 1.8, 0.1, 1.1, e)
        C.text_obj(col, "area_cathedral_noticeboard_text", "ST JOHN'S\nCATHEDRAL", (nbx + nx * 0.06, nby + ny * 0.06, gz(nbx, nby) + 1.55),
                   (math.pi / 2, 0, e + math.pi), 0.2, (0.85, 0.80, 0.62))
        note(nbx, nby, "sign")
    put(drive, "forecourt_drive", col, (bpy.data.materials.get("clay_road") or mat("forecourt_bitumen", (0.12, 0.115, 0.11))), objs)
    put(kerb, "forecourt_rolled_kerb", col, mat("kerb_concrete", (0.52, 0.50, 0.46)), objs)
    put(beds, "forecourt_beds", col, mat("bed_mulch", (0.11, 0.07, 0.045)), objs)
    put(rail, "forecourt_rail", col, mat("black_rail", (0.02, 0.02, 0.02)), objs)
    put(post, "forecourt_board_posts", col, mat("board_post", (0.06, 0.05, 0.045)), objs)
    put(board, "forecourt_board", col, mat("board_face", (0.16, 0.05, 0.05)), objs)
    ob = red.object("area_cordyline", col, (0.20, 0.03, 0.035), (0.36, 0.07, 0.06))
    if ob:
        objs.append(ob.name)
    ob = green.object("area_bed_plants", col, (0.05, 0.12, 0.04), (0.15, 0.25, 0.08))
    if ob:
        objs.append(ob.name)
    report.append("forecourt: %d tree faces removed, drive + %d beds" % (gone, 4))


# ---------------------------------------------------------------------------------------------- roads
def roads(col, guard, objs, report):
    """Wear on the carriageways: asphalt patches, crack seal, manholes, side-entry pits by the kerb;
    concrete gutter strip. Everything lies on the road surface (marks, not props)."""
    import random
    import streetscape as SS
    rnd = random.Random(7)
    patch, crack, manhole, pit, gutter = (C.MeshBuf() for _ in range(5))
    np_ = nm = 0
    o = L.osm()
    for w in o["ways"].values():
        t = w.get("tags", {})
        if t.get("highway") not in SS.CAR or t.get("bridge", "no") != "no" or t.get("tunnel", "no") != "no":
            continue
        pts = o["line"](w)
        if len(pts) < 2 or not any(math.hypot(x, y) < 330 for x, y in pts):
            continue
        hw = SS.road_width(t) / 2
        acc = rnd.uniform(0, 30)
        for (ax, ay), (bx, by) in zip(pts[:-1], pts[1:]):
            ln = math.dist((ax, ay), (bx, by))
            if ln < 1:
                continue
            e = math.atan2(by - ay, bx - ax)
            ux, uy = (bx - ax) / ln, (by - ay) / ln
            nx, ny = -uy, ux
            crown = (ax, ay, nx, ny, hw)
            s = acc
            while s < ln:
                x, y = ax + ux * s, ay + uy * s
                if math.hypot(x, y) < 330 and not guard.keepout(x, y, 2.0):
                    r = rnd.random()
                    off = rnd.uniform(-hw * 0.8, hw * 0.8)
                    px, py = x + nx * off, y + ny * off
                    if r < 0.35:                                         # patch (darker, newer asphalt)
                        road_rect(patch, px, py, rnd.uniform(1.5, 6.0), rnd.uniform(1.0, 2.6), e, crown, 0.012, 6, 3)
                        np_ += 1
                    elif r < 0.6:                                        # crack seal: thin wandering strip
                        q = (px, py)
                        a = e + rnd.uniform(-0.6, 0.6)
                        for _ in range(rnd.randint(4, 9)):
                            q2 = (q[0] + math.cos(a) * 0.9, q[1] + math.sin(a) * 0.9)
                            road_rect(crack, (q[0] + q2[0]) / 2, (q[1] + q2[1]) / 2, 0.95, 0.03, a, crown, 0.016)
                            q = q2
                            a += rnd.uniform(-0.5, 0.5)
                    else:                                                 # manhole
                        disc(manhole, px, py, 0.33, crown_z(crown, px, py) - gz(px, py) + 0.014)
                        nm += 1
                    note(px, py, "roadmark")
                    for sd in (-1, 1):                                    # side-entry pit at each kerb
                        kx, ky = x + nx * sd * (hw - 0.25), y + ny * sd * (hw - 0.25)
                        if rnd.random() < 0.5 and not guard.keepout(kx, ky, 2.0):
                            road_rect(pit, kx, ky, 1.2, 0.35, e, crown, 0.016)
                            note(kx, ky, "roadmark")
                s += rnd.uniform(18, 40)
            acc = s - ln
            # concrete gutter strip (0.35 m) along both kerbs
            for sd in (-1, 1):
                for i in range(int(ln // 4) + 1):
                    s0 = i * 4
                    s1 = min(ln, s0 + 4)
                    if s1 - s0 < 0.5:
                        continue
                    mx, my = ax + ux * (s0 + s1) / 2 + nx * sd * (hw - 0.18), ay + uy * (s0 + s1) / 2 + ny * sd * (hw - 0.18)
                    if math.hypot(mx, my) < 330 and not guard.keepout(mx, my, 1.0):
                        road_rect(gutter, mx, my, s1 - s0, 0.36, e, crown, 0.01, 2, 1)
    # r5 (critics): the patch and crack-seal meshes showed stair-step edges: plain asphalt instead (not built)
    del patch, crack
    put(manhole, "road_manholes", col, mat("manhole", (0.06, 0.055, 0.05), metal=True), objs)
    put(pit, "road_side_pits", col, mat("pit_grate", (0.03, 0.03, 0.03)), objs)
    put(gutter, "road_gutter_strip", col, mat("gutter_concrete", (0.36, 0.35, 0.33)), objs)
    report.append("roads: %d patches, %d manholes" % (np_, nm))


# ---------------------------------------------------------------------------------------------- signs
def signs(col, guard, objs, report):
    """Missing signs from the photos: 40 km/h on Ann St (cathedral side), green Story Bridge direction blade
    on Ann St north-east of Queen St."""
    posts, white, green, red = (C.MeshBuf() for _ in range(4))
    items = P("signs", [
        {"kind": "speed40", "xy": (-114.0, -46.0), "facing_deg": 220.0},
        {"kind": "speed40", "xy": (86.0, 120.0), "facing_deg": 40.0},
        {"kind": "story_bridge", "xy": (90.0, 118.0), "facing_deg": 40.0},
    ])
    n = 0
    for it in items:
        x, y = it["xy"]
        if not guard.ok(x, y, pad=0.0) or guard.road.on_road(x, y):
            spot = None                                     # r2: nearest clear spot just off the kerb (<= 6 m)
            for r_ in (0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 4.0, 5.0, 6.0):
                for k_ in range(16):
                    qx, qy = x + r_ * math.cos(k_ * math.pi / 8), y + r_ * math.sin(k_ * math.pi / 8)
                    if guard.ok(qx, qy) and not guard.road.on_road(qx, qy):
                        spot = (qx, qy)
                        break
                if spot:
                    break
            if spot is None:
                report.append("sign at (%.0f, %.0f) off: keep-out or road" % (x, y))
                continue
            report.append("sign moved (%.0f, %.0f) -> (%.1f, %.1f), off the road" % (x, y, spot[0], spot[1]))
            x, y = spot
        e = math.radians(90.0 - it["facing_deg"])           # the face looks along facing_deg (deg from north)
        z = gz(x, y) + L.KERB_HEIGHT
        pole(posts, x, y, z, 3.0, 0.04, 0.04)
        if it["kind"] == "speed40":
            import trees as T
            k = 20
            ring = [(x + 0.3 * math.cos(2 * math.pi * i / k) * math.cos(e + math.pi / 2), y + 0.3 * math.cos(2 * math.pi * i / k) * math.sin(e + math.pi / 2),
                     z + 2.55 + 0.3 * math.sin(2 * math.pi * i / k)) for i in range(k)]
            red.add([(px + math.cos(e) * 0.05, py + math.sin(e) * 0.05, pz) for px, py, pz in ring], [list(range(k))[::-1]])
            inner = [(x + 0.24 * math.cos(2 * math.pi * i / k) * math.cos(e + math.pi / 2), y + 0.24 * math.cos(2 * math.pi * i / k) * math.sin(e + math.pi / 2),
                      z + 2.55 + 0.24 * math.sin(2 * math.pi * i / k)) for i in range(k)]
            white.add([(px + math.cos(e) * 0.06, py + math.sin(e) * 0.06, pz) for px, py, pz in inner], [list(range(k))[::-1]])
            C.text_obj(col, "area_sign40", "40", (x + math.cos(e) * 0.07, y + math.sin(e) * 0.07, z + 2.55),
                       (math.pi / 2, 0, e + math.pi / 2), 0.26, (0.02, 0.02, 0.02))
        else:
            green.box(x, y, z + 2.4, 1.9, 0.05, 0.45, e + math.pi / 2)
            C.text_obj(col, "area_sign_story_bridge", "STORY BRIDGE  ->", (x + math.cos(e) * 0.04, y + math.sin(e) * 0.04, z + 2.62),
                       (math.pi / 2, 0, e + math.pi / 2), 0.2, (0.95, 0.95, 0.95))
        note(x, y, "sign")
        n += 1
    put(posts, "sign_posts", col, mat("galv", (0.45, 0.46, 0.46)), objs)
    put(white, "sign_white_faces", col, mat("sign_white", (0.85, 0.85, 0.82)), objs)
    put(red, "sign_red_rings", col, mat("sign_red", (0.55, 0.03, 0.03)), objs)
    put(green, "sign_green_blades", col, mat("sign_green", (0.01, 0.17, 0.07)), objs)
    report.append("signs: %d" % n)


# ---------------------------------------------------------------------------------------------- neighbours
def hx(s):
    s = s.lstrip("#")
    return tuple((int(s[i:i + 2], 16) / 255) ** 1.6 for i in (0, 2, 4))     # hex -> between the repo look (raw) and linear


NEIGHBOUR_WALLS = {        # critic round 0 (photos): own albedo per building, sRGB
    568836537: "E3D8BC",   # Mantra on Queen: cream
    26253094: "D8BC94",    # Marriott: buff (r4: a step warmer, photo; r7 critics: a touch more peach)
    236155564: "8C969E",   # Skyline (Meriton): dark glass tower, grey frame
    236155562: "8C969E",
    26253098: "E6DCC4",    # Willahra: off-white (r4, photo; r7 critics: cream)
    186586595: "CFAE8E",   # r10: still too yellow: warm tan, less yellow. Orient Hotel: ochre render (r7, orient_front photo; exception "orient")
    26386571: "E2B9A0", 26386543: "E2B9A0",   # Admiralty I / II: r9 critics: peach-pink #e2b9a0
    224320345: "D9AE88",   # Macrossan: Petrie Bight peach
}
CATHEDRAL_LOOK = {"ashlar": ["9A8A72", "A3927A", "8A8088", "B09C80", "6F6458", "8A8088", "A89070", "C0A88A", "948470", "8A8088"], "dressing": "D6C296",   # r13: dressings / pinnacles read saturated yellow;   # r12: ~30 % grey-mauve #8a8088, pale cream dressings;   # r10: warm golden-tan, grey-brown darks (r9 violet read lilac);   # r8: + a dark and a light block (+/-12 %), same mean;   # r5: r4 + half the step to the 2010 photo wall average #AE9378
                  "tile": "A8452C", "spire": "2E2E33", "slate": "5A5A60"}
HALL_OSM = 1210526673      # brick block in the forecourt view: LiDAR top includes trees; photo shows a low gabled hall


def flush_onto(ob, ring, gap):
    """Pull every vertex of ob standing more than `gap` off the footprint ring back to `gap` off it."""
    if ob is None or ob.type != "MESH":
        return 0
    import numpy as np
    me = ob.data
    co = np.empty(len(me.vertices) * 3, "f4")
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    A = np.array(ring, "f8")
    B = np.roll(A, -1, axis=0)
    D = B - A
    L2 = np.maximum((D ** 2).sum(1), 1e-9)
    P = co[:, None, :2] - A[None]
    t = np.clip((P * D[None]).sum(2) / L2[None], 0, 1)
    Q = A[None] + t[..., None] * D[None]
    dist = np.linalg.norm(co[:, None, :2] - Q, axis=2)
    k = dist.argmin(1)
    near = Q[np.arange(len(co)), k]
    d = dist[np.arange(len(co)), k]
    inside = in_rings_np(co[:, 0], co[:, 1], [ring])
    far = (d > gap) & ~inside
    v = co[far, :2] - near[far]
    v /= np.maximum(np.linalg.norm(v, axis=1, keepdims=True), 1e-9)
    co[far, :2] = near[far] + v * gap
    me.vertices.foreach_set("co", co.ravel())
    me.update()
    return int(far.sum())


def mantra_fin(col, b, rings, stripe_xy, objs, report):
    """r4 (all 3 critics, 3 photos): a ~3 m wide blue stripe #1f7bd0 up the full height of the facade, as real
    geometry 0.35 m proud, sweeping out and up at the top into the blue crest with the white "mantra" sign."""
    # r5 (critics + photos): the stripe runs up the south-east corner, on the face towards Ann St. Found by
    # projecting the tower outline into spire_ann_st_2018 / ann_queen_corner / fly_by_east: that corner is the
    # LEFT edge of Mantra in the first two and the right edge of the face seen in fly_by_east.
    # r6: the three photos do not fit one corner. spire_ann_st_2018 and ann_queen_corner show the blue running down
    # Mantra's LEFT silhouette from the crest (the SE corner, east face); fly_by_east shows a second vertical blue
    # band ~80 % across the north face and the horizontal "mantra" sign at the top of that face. So: two stripes,
    # a wedge crest at the SE corner top, the sign horizontal on the north face. Azure #1E8FD0 (pinned by the critic).
    stripes = P("mantra_stripes", [
        # r8 (ann_queen_corner photo, 3 critics): a THIN blue line runs the full height of that corner, crest to podium
        {"centre": (14.5, 70.9), "along": (0.0, 1.0), "normal": (1.0, 0.0), "crest": True, "full": True, "w": 0.9},
        # r7: spire_ann_st_2018 shows the blue running down Mantra's LEFT edge for about a third of the height from
        # the crest, fly_by_east shows only the crest wing there: so the SE band tapers out ~22 m below the roof
        {"centre": (3.6, 97.5), "along": (-1.0, 0.0), "normal": (0.0, 1.0), "crest": False},   # north face (fly_by_east)
    ])
    top = max(t["top_ahd"] for t in b["tiers"])
    base, W, D, O = 38.8, 2.6, 0.25, 1.0                            # podium roof -> roof; 0.05 m proud of the slab edges
    fin = C.MeshBuf()

    def slab(px, py, ux, uy, nx, ny, z0, z1, out0, out1, w0, w1):
        q = []
        for z, o, w in ((z0, out0, w0), (z1, out1, w1)):
            for s in (-1, 1):
                for dd in (0.0, D):
                    q.append((px + ux * s * w / 2 + nx * (o + dd), py + uy * s * w / 2 + ny * (o + dd), z))
        fin.add(q, [[0, 2, 3, 1], [4, 5, 7, 6], [0, 1, 5, 4], [2, 6, 7, 3], [1, 3, 7, 5], [0, 4, 6, 2]])
    for st in stripes:
        px, py = st["centre"]
        ux, uy = st["along"]
        nx, ny = st["normal"]
        if st.get("full", True):                                    # r8: full height again, own width
            slab(px, py, ux, uy, nx, ny, base, top, O, O, st.get("w", W), st.get("w", W))
        else:                                                       # a tapering band from the crest wing, 22 m down
            for i in range(6):
                f0, f1 = i / 6, (i + 1) / 6
                slab(px, py, ux, uy, nx, ny, top - 22.0 * (1 - f0), top - 22.0 * (1 - f1), O, O, W * (0.25 + 0.75 * f0), W * (0.25 + 0.75 * f1))
        note(px, py, "building")
        if st["crest"]:
            # r11 (fly_by_east zoom, photo vs render): the wing is a flat blue FLAG standing straight out of the
            # corner, widest AT the roof line (~5.5 m, a quarter of the tower width) and tapering to the corner about
            # 4 floors (12 m) down. A fin in the plane of the face normal, 0.35 m thick, flush with the roof line.
            # r12 (critic zooms): from the NE cameras the first ~5 m of the flag hide behind the tower's NE corner,
            # so it read 7.5 % of the tower width against ~20 % in the photo, and its top sat below the parapet:
            # outreach 11 m, top 3 m above the roof plane (the parapet line), concave outer edge
            # r13 (critics): a plane facing one way goes edge-on from the NE and S cameras: it now BISECTS the
            # corner (east + south, 45 deg) so it reads as a broad sheet from every side; top back at the parapet
            # r14 (spire_ann_st_2018 photo vs render): ~5 m out at the roof, a concave edge back to the corner over ~10
            # floors (30 m), not a 3-floor pennant; top flush with the parapet (roof plate 110.6 + parapet)
            fl, hgt, th, lift = P("mantra_crest_flare", 5.5), P("mantra_crest_h", 30.0), 0.4, P("mantra_crest_lift", 1.5)
            ax, ay = px + nx * O, py + ny * O
            dx_, dy_ = P("mantra_crest_dir", (0.7071, -0.7071))
            nx, ny, ux, uy = dx_, dy_, -dy_, dx_
            prof = [(0.0, top - hgt), (0.0, top + lift), (fl, top + lift)]
            for k in range(1, 12):                                  # concave edge back to the corner
                t = k / 12
                prof.append((fl * (1 - t) ** 2.2, top + lift - 0.6 - (hgt + lift - 0.6) * t))
            n_ = len(prof)
            q = []
            for s_ in (-th / 2, th / 2):
                bx, by = ax + ux * s_, ay + uy * s_
                q += [(bx + nx * o_, by + ny * o_, z_) for o_, z_ in prof]
            faces = [[1, 0, k] for k in range(2, n_)] + [[n_ + 1, n_ + k, n_] for k in range(2, n_)]
            faces = [[1, k, k + 1] for k in range(2, n_ - 1)] + [[1, n_ - 1, 0]]
            faces += [[n_ + 1, n_ + k + 1, n_ + k] for k in range(2, n_ - 1)] + [[n_ + 1, n_, n_ + n_ - 1]]
            faces += [[i, (i + 1) % n_, n_ + (i + 1) % n_, n_ + i] for i in range(n_)]
            fin.add(q, faces)
    # r10: dark blue lowercase "mantra" (#1b5fa8); top-floor balcony slabs / rails within 8 m of the sign go
    sx, sy, snx, sny = P("mantra_sign", (11.85, 93.2, 0.506, 0.861))
    put(fin, "mantra_blue_fin", col, mat("mantra_blue", lin(P("mantra_blue_hex", "2E8FD6"))), objs)   # r13: photo #1E78C8, r12 read pale cyan
    # r11 (critics: letters doubled, painted over the windows): a SOLID one-storey cream parapet band on that face,
    # standing in front of the windows, and one text object 2.5 cm proud of it
    band = C.MeshBuf()
    bo = O + 0.9
    slab_band = []
    for z in (top - 3.5, top - 0.4):                                    # r12: band stays under the roof line
        for s_ in (-1, 1):
            for dd in (0.0, 0.3):
                slab_band.append((sx - sny * s_ * 7.0 + snx * (bo + dd), sy + snx * s_ * 7.0 + sny * (bo + dd), z))
    band.add(slab_band, [[0, 2, 3, 1], [4, 5, 7, 6], [0, 1, 5, 4], [2, 6, 7, 3], [1, 3, 7, 5], [0, 4, 6, 2]])
    put(band, "mantra_sign_band", col, mat("mantra_band", hx("E9DFC8")), objs)
    ob = C.text_obj(col, "area_mantra_sign", "mantra", (sx + snx * (bo + 0.3 + 0.015), sy + sny * (bo + 0.3 + 0.015), top - 2.0),
                    (math.pi / 2, 0, math.atan2(snx, -sny)), 2.9, lin("1B5FA8"))
    ob.data.extrude = 0.012
    ob.data.offset = 0.06                                           # r12: bold strokes (photo ~70 % of the band)
    _STATE["mantra_sign"] = (sx, sy, top)
    report.append("Mantra: 2 azure stripes (SE corner + north face) %.0f m, wedge crest, horizontal sign" % (top - base))


def mantra_slabs(col, recs, objs, report):
    """r3 (critic): Mantra's tower has a balcony slab at every floor with a deep shadow under it."""
    import buildings as B
    b = recs.get(189779738) or recs.get(568836537)
    if not b:
        return
    slabs, rails = C.MeshBuf(), C.MeshBuf()
    n = 0
    for t in b["tiers"]:
        if t["top_ahd"] - b["base_ahd"] < 30:
            continue
        ring = S.ccw([tuple(p) for p in t["ring"]])
        out = B.offset(ring, 0.95)
        z = b["base_ahd"] + 12.0
        while z < t["top_ahd"] - 2.0:
            slabs.prism(out, z - 0.22, z)
            B.loop_wall(rails, B.offset(ring, 0.9), z, z + 1.0)        # r4: white balcony rails
            n += 1
            z += 3.1
    import numpy as np
    sg = _STATE.get("mantra_sign")
    put(slabs, "mantra_balcony_slabs", col, mat("mantra_slab", hx("EDE4D0")), objs)
    put(rails, "mantra_balcony_rails", col, mat("mantra_rails", (0.80, 0.80, 0.78)), objs)
    if sg:
        for nm in ("mantra_balcony_slabs", "mantra_balcony_rails"):
            drop_where(bpy.data.objects.get(nm), lambda X, Y, Z: ((X - sg[0]) ** 2 + (Y - sg[1]) ** 2 < 64.0) & (Z > sg[2] - 4.0))
    note(5.0, 87.0, "building")
    report.append("Mantra: %d balcony slabs" % n)


def neighbours(col, guard, objs, report):
    """Per-building wall colours, roofs that are not glaring white, the low brick hall, cathedral colours.
    Material colours only (setup_morning builds the shaders from them afterwards)."""
    n = 0
    for osm, h in NEIGHBOUR_WALLS.items():
        m = bpy.data.materials.get("look_%d_wall" % osm)
        if m:
            m.diffuse_color = (*hx(h), 1)
            n += 1
    for m in bpy.data.materials:
        if m.name.endswith("_roof") and (m.name.startswith("look_") or m.name.startswith("gen_")):
            r, g, b, _ = m.diffuse_color
            lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
            if lum > 0.45:                                                 # flat roofs: weathered membrane grey
                k = 0.42 / lum
                m.diffuse_color = (r * k, g * k, b * k * 0.98, 1)
    # cathedral palette
    cm = bpy.data.materials.get("cathedral_tuff_ashlar")
    if cm:
        pal = [hx(c) for c in CATHEDRAL_LOOK["ashlar"]]
        cm["palette"] = [c for col_ in pal for c in col_]
        cm.diffuse_color = (*pal[0], 1)
    for name, key in (("cathedral_sandstone", "dressing"), ("cathedral_terracotta", "tile"),
                      ("cathedral_spire_slate", "spire"), ("cathedral_slate", "slate")):
        m = bpy.data.materials.get(name)
        if m:
            m.diffuse_color = (*hx(CATHEDRAL_LOOK[key]), 1)
    # r2 (critic): roof read orange (#c8553a) -> photo #7f4535..#8a4a38; dressings read sage -> warm sandstone
    for name, rgb in (("cathedral_terracotta", P("cath_tile_lin", lin("6E3426"))),
                      ("cathedral_sandstone", P("cath_dress_lin", lin("D6C296")))):
        m = bpy.data.materials.get(name)
        if m:
            m.diffuse_color = (*rgb, 1)
    st = bpy.data.objects.get("cathedral_stone")                     # r2: big irregular ashlar blocks, not brick
    if st and st.data.uv_layers.get("facade"):
        import numpy as np
        lay = st.data.uv_layers["facade"].data
        uv = np.empty(len(lay) * 2, "f4")
        lay.foreach_get("uv", uv)
        lay.foreach_set("uv", uv * P("ashlar_uv_scale", 0.72))
    # r3 (critic): r2 overshot to white boxes with dot grids. Cream #e4d8bf render, balcony doors full storey
    # height between slabs (Willahra / Admiralty keep their own balcony bands; Mantra gets slabs below)
    for osm in (568836537, 189779738, 26253098, 26386571, 26386543):   # 189779738: OSM "Hotel Mantra" = tower tiers
        m = bpy.data.materials.get("look_%d_wall" % osm)
        if m:
            m["shader"] = "render"
            if osm in (568836537, 189779738):
                m.diffuse_color = (*hx(P("mantra_cream", "F2DBAE")), 1)     # r8: critics read grey-white; a step warmer (#E9DFC8 target) (Willahra / Admiralty: NEIGHBOUR_WALLS)
            for k, v in (("bay", 3.0), ("win", 2.3), ("sill", 0.06), ("head", 0.86), ("floor", 3.1), ("rough", 0.18)):
                m["win_" + k] = v
            m["win_glass"] = [0.10, 0.14, 0.19]          # r4: blue-grey glass, not charcoal
    # Soleil (Meriton): white diagonals, not a red stripe
    for nm in ("look_224320346_accent",):
        m = bpy.data.materials.get(nm)
        if m:
            m.diffuse_color = (0.85, 0.85, 0.83, 1)
    m = bpy.data.materials.get("look_224320346_wall")
    if m:
        m["diag"] = True
    # Mantra (r3): the roof spike goes; the blue fin and crest STAY (3 photos) and are pulled flush onto the facade
    recs = {b["osm"]: b for b in json.load(open(os.path.join(L.REF, "lidar", "buildings_clean.json")))["buildings"]}
    b = recs.get(568836537)
    if b:
        top = max(t["top_ahd"] for t in b["tiers"])
        rings = [S.ccw([tuple(p) for p in t["ring"]]) for t in b["tiers"]]
        grown = [[(x + (x - sum(p[0] for p in r) / len(r)) * 0.04, y + (y - sum(p[1] for p in r) / len(r)) * 0.04) for x, y in r]
                 for r in rings]
        gone = drop_where(bpy.data.objects.get("bldg_look_568836537_roof"),
                          lambda X, Y, Z: (Z > top + 1.5) & in_rings_np(X, Y, grown))
        # r13 (probe: the "void" in crane_from_nw sits on the 110.6 m roof plate): Mantra's two OSM outlines
        # (568836537 + 189779738) each bring a roof plate at 110.6 m, plus downward-facing box bottoms at the same
        # height; Cycles picks the coplanar back faces and shades them black. Keep one plate (189779738, the
        # bigger outline) and drop every downward face above the roof line.
        import numpy as np
        for nm_ in ("bldg_look_568836537_roof", "bldg_look_189779738_roof"):
            ob_ = bpy.data.objects.get(nm_)
            if ob_ is None or not ob_.data.polygons:
                continue
            nrm = np.empty(len(ob_.data.polygons) * 3, "f4")
            ob_.data.polygons.foreach_get("normal", nrm)
            nz_ = nrm.reshape(-1, 3)[:, 2]
            plate = nm_.startswith("bldg_look_568836537")
            k_ = {"i": 0}

            def dead(X, Y, Z, nz_=nz_, plate=plate):
                ins = in_rings_np(X, Y, grown)
                d = ins & (Z > top + 0.5) & (nz_ < -0.5)
                if plate:
                    d |= ins & (np.abs(Z - (top + 0.9)) < 0.2) & (np.abs(nz_) > 0.9)
                return d
            report.append("Mantra roof: %s %d coplanar / back faces dropped" % (nm_, drop_where(ob_, dead)))
        cap = C.MeshBuf()                                           # r12: the spike drop left a black hole seen from above
        for t in b["tiers"]:
            if t["top_ahd"] >= top - 0.5:
                cap.prism(S.ccw([tuple(p) for p in t["ring"]]), top - 0.3, top + 0.08)
        put(cap, "mantra_roof_cap", col, mat("mantra_roof_cap", hx("8E8A84")), objs)
        acc = bpy.data.objects.get("bldg_look_568836537_accent")
        stripe_xy = None
        if acc is not None and acc.data.vertices:                     # where buildings.py put the blue strip
            import numpy as np
            co = np.empty(len(acc.data.vertices) * 3, "f4")
            acc.data.vertices.foreach_get("co", co)
            co = co.reshape(-1, 3)
            low = co[co[:, 2] < top - 5.0]
            if len(low):
                stripe_xy = (float(low[:, 0].mean()), float(low[:, 1].mean()))
            hair = drop_where(acc, lambda X, Y, Z: np.ones(len(X), bool))  # r4: the hairline prisms go
        mantra_fin(col, b, rings, stripe_xy, objs, report)
        report.append("Mantra: spike dropped (%d faces)" % gone)
    mantra_slabs(col, recs, objs, report)
    for nm in ("look_26253098_accent", "look_26253098_band"):            # r9: Willahra has no orange stripe
        m = bpy.data.materials.get(nm)
        if m:
            m.diffuse_color = (*hx("E6DCC4"), 1)
    # the Deanery (r3): verandahed sandstone house, not a concrete frame: warm sandstone walls, cream verandah posts
    for nm, rgb in (("look_106225770_wall", hx("C49A6C")), ("look_106225770_ground", hx("B78D62")),
                    ("look_106225770_band", (0.62, 0.60, 0.52)), ("look_106225770_roof", (0.16, 0.17, 0.17))):
        m = bpy.data.materials.get(nm)
        if m:
            m.diffuse_color = (*rgb, 1)
    m = bpy.data.materials.get("look_106225770_wall")
    if m:
        m["shader"] = "ashlar"
        m["palette"] = [c for h in ("C49A6C", "B58C60", "CFA878") for c in hx(h)]
    # the low brick hall: drop the tall block's faces, build walls + a steep gable roof on its footprint
    o = L.osm()
    w = o["ways"].get(HALL_OSM)
    if w:
        ring = S.ccw(C.clean_ring(o["line"](w)))
        grown = [(x + (x - sum(p[0] for p in ring) / len(ring)) * 0.3, y + (y - sum(p[1] for p in ring) / len(ring)) * 0.3) for x, y in ring]
        gone = sum(drop_faces(ob, [grown]) for ob in list(bpy.data.objects) if ob.name.startswith("bldg_"))
        cx, cy, ln, wd, ang = S.min_rect(ring)
        g = min(gz(x, y) for x, y in ring)
        walls, roof = C.MeshBuf(), C.MeshBuf()
        walls.box(cx, cy, g - 0.5, ln, wd, 5.0, ang)
        ux, uy, vx, vy = math.cos(ang), math.sin(ang), -math.sin(ang), math.cos(ang)
        eave, ridge = g + 4.5, g + 4.5 + math.tan(math.radians(50)) * (wd / 2 + 0.4)
        c4 = [(cx + ux * a * (ln / 2 + 0.4) + vx * b * (wd / 2 + 0.4), cy + uy * a * (ln / 2 + 0.4) + vy * b * (wd / 2 + 0.4))
              for a, b in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
        r0 = (cx - ux * (ln / 2 + 0.4), cy - uy * (ln / 2 + 0.4))
        r1 = (cx + ux * (ln / 2 + 0.4), cy + uy * (ln / 2 + 0.4))
        roof.add([(*c4[0], eave), (*c4[1], eave), (*r1, ridge), (*r0, ridge)], [[0, 1, 2, 3]])
        roof.add([(*c4[2], eave), (*c4[3], eave), (*r0, ridge), (*r1, ridge)], [[0, 1, 2, 3]])
        e0 = [(cx - ux * ln / 2 + vx * b * wd / 2, cy - uy * ln / 2 + vy * b * wd / 2) for b in (-1, 1)]
        e1 = [(cx + ux * ln / 2 + vx * b * wd / 2, cy + uy * ln / 2 + vy * b * wd / 2) for b in (-1, 1)]
        for ee in (e0, e1):                                               # brick gable ends
            mid = ((ee[0][0] + ee[1][0]) / 2, (ee[0][1] + ee[1][1]) / 2)
            walls.add([(*ee[0], g + 4.5), (*ee[1], g + 4.5), (*mid, ridge - 0.3)], [[0, 1, 2], [2, 1, 0]])
        put(walls, "hall_walls", col, mat("hall_brick", hx("8E4A36"), shader="brick", win_bay=3.2, win_win=1.0,
                                           win_sill=0.25, win_head=0.7, win_glass=list(hx("2A2E33")), win_rough=0.2,
                                           win_floor=4.5), objs)
        put(roof, "hall_roof", col, mat("hall_roof", hx("5E6266")), objs)
        note(cx, cy, "building")
        report.append("brick hall %d rebuilt low and gabled (%d tall faces dropped)" % (HALL_OSM, gone))
    report.append("neighbours: %d wall colours, roofs toned, cathedral palette" % n)


# ---------------------------------------------------------------------------------------------- roofs
def roof_plant(col, guard, objs, report):
    """r2 (critic): flat roofs get plant rooms, AC units and a lift overrun, so they do not read as blank slabs.
    Not on the Spire site, the cathedral, HSW or the HSW crest blocks; not on gabled / hipped roofs."""
    import random
    import buildings as B
    skip = set(B.SKIP) | set(L.hsw_crest_ids()) | {HALL_OSM}
    rooms_v, units = [C.MeshBuf(), C.MeshBuf(), C.MeshBuf()], C.MeshBuf()   # r4: 3 plant colours
    n = 0
    for b in B.records():
        if b["osm"] in skip or b["gable"] or str(b["osm"]) in B._ROOFS:
            continue
        t = b["tiers"][-1]
        ring = S.ccw([tuple(p) for p in t["ring"]])
        cx = sum(p[0] for p in ring) / len(ring)
        cy = sum(p[1] for p in ring) / len(ring)
        x0, y0, x1, y1 = B.HSW_ZONE
        if math.hypot(cx, cy) > 330 or (x0 <= cx <= x1 and y0 <= cy <= y1) or guard.keepout(cx, cy, 5.0):
            continue
        area = abs(C.signed_area(ring))
        if area < 120 or t["top_ahd"] - b["base_ahd"] < 9:
            continue
        rnd = random.Random(b["osm"])
        top = t["top_ahd"] + 0.9                                      # on the parapet cap level
        _, _, ln, wd, ang = S.min_rect(ring)
        ux, uy, vx, vy = math.cos(ang), math.sin(ang), -math.sin(ang), math.cos(ang)
        tries = 0
        placed = 0
        want = 1 + (area > 400) + (area > 900)
        while placed < want and tries < 20:
            tries += 1
            sx, sy = rnd.uniform(3.0, min(8.0, ln * 0.4)), rnd.uniform(2.5, min(6.0, wd * 0.4))
            px = cx + ux * rnd.uniform(-0.25, 0.25) * ln + vx * rnd.uniform(-0.25, 0.25) * wd
            py = cy + uy * rnd.uniform(-0.25, 0.25) * ln + vy * rnd.uniform(-0.25, 0.25) * wd
            corners = [(px + ux * a * sx / 2 + vx * c * sy / 2, py + uy * a * sx / 2 + vy * c * sy / 2) for a in (-1, 1) for c in (-1, 1)]
            if not all(S.point_in(x, y, ring) for x, y in corners):
                continue
            hits = [roof_hit(x, y, top) for x, y in corners + [(px, py)]]   # r3: only on a roof that is drawn there
            if any(hz is None or abs(hz - top) > 1.5 for hz in hits):
                continue
            rooms_v[b["osm"] % 3].box(px, py, top - 0.9, sx, sy, rnd.uniform(2.4, 3.6), ang)
            for k in range(rnd.randint(2, 5)):                         # AC units beside it
                ax_ = px + ux * (sx / 2 + 1.2 + 1.4 * (k // 2)) * (1 if k % 2 else -1)
                ay_ = py + uy * (sx / 2 + 1.2 + 1.4 * (k // 2)) * (1 if k % 2 else -1)
                if S.point_in(ax_, ay_, ring):
                    units.box(ax_, ay_, top - 0.9, 1.1, 1.1, 1.0, ang)
            placed += 1
        if placed:
            note(cx, cy, "roof")
            n += 1
    for i_, rgb_ in enumerate(((0.42, 0.42, 0.41), (0.56, 0.55, 0.51), (0.29, 0.30, 0.31))):
        put(rooms_v[i_], "roof_plant_rooms_%d" % i_, col, mat("plant_room_%d" % i_, rgb_), objs)
    put(units, "roof_ac_units", col, mat("ac_units", (0.55, 0.56, 0.56)), objs)
    report.append("roof plant on %d buildings" % n)


def roof_hit(x, y, z_top):
    """Height of the first building surface straight below (x, y) from z_top + 6, or None."""
    from mathutils import Vector
    dg = bpy.context.evaluated_depsgraph_get()
    hit, loc, _n, _i, ob, _m = bpy.context.scene.ray_cast(dg, Vector((x, y, z_top + 6.0)), Vector((0, 0, -1)), distance=40.0)
    if hit and ob is not None and ob.name.startswith("bldg_"):
        return loc.z
    return None


def floating_masts(report):
    """r3 (critic): mast cones from the LiDAR (buildings.py bldg_spires_masts) that stand on nothing (the tower's
    roof is drawn lower than the LiDAR top): drop the cone if nothing is under its base within 3 m."""
    import numpy as np
    ob = bpy.data.objects.get("bldg_spires_masts")
    if ob is None or not ob.data.polygons:
        return
    me = ob.data
    cen = np.empty(len(me.polygons) * 3, "f4")
    me.polygons.foreach_get("center", cen)
    cen = cen.reshape(-1, 3)
    keys = {}
    for i, (x, y, z) in enumerate(cen):
        keys.setdefault((round(x / 3.0), round(y / 3.0)), []).append(i)
    bad = set()
    from mathutils import Vector
    dg = bpy.context.evaluated_depsgraph_get()
    for k, idx in keys.items():
        x, y = float(cen[idx, 0].mean()), float(cen[idx, 1].mean())
        zb = float(cen[idx, 2].min())
        hit, loc, _n, _i, hob, _m = bpy.context.scene.ray_cast(dg, Vector((x, y, zb - 0.3)), Vector((0, 0, -1)), distance=200.0)
        if not hit or zb - loc.z > 3.0:
            bad.add(k)
    gone = drop_where(ob, lambda X, Y, Z: np.array([(round(a / 3.0), round(b / 3.0)) in bad for a, b in zip(X, Y)]))
    report.append("floating mast cones dropped: %d groups, %d faces" % (len(bad), gone))


def smooth_ground(report):
    """r3 (critic): white shard spikes in the LiDAR ground at the Deanery cliff and the Customs House bank:
    replace heights that stick out > 1 m from their 5 x 5 median, then soften twice, in those two boxes."""
    import numpy as np
    gcol = bpy.data.collections.get("ground")
    meshes = [o for o in gcol.objects if o.type == "MESH"] if gcol else []
    ob = max(meshes, key=lambda o: len(o.data.vertices)) if meshes else None
    if ob is None:
        return
    me = ob.data
    co = np.empty(len(me.vertices) * 3, "f4")
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    xs, ys = np.unique(np.round(co[:, 0], 2)), np.unique(np.round(co[:, 1], 2))
    if len(xs) * len(ys) != len(co):
        report.append("ground smoothing skipped (not a plain grid)")
        return
    ix = np.searchsorted(xs, np.round(co[:, 0], 2))
    iy = np.searchsorted(ys, np.round(co[:, 1], 2))
    Z = np.full((len(ys), len(xs)), np.nan)
    Z[iy, ix] = co[:, 2]
    n = 0
    for x0, y0, x1, y1 in P("ground_smooth_boxes", [(-75, -145, 5, -95), (10, -335, 110, -245)]):
        cx = (xs >= x0) & (xs <= x1)
        cy = (ys >= y0) & (ys <= y1)
        r0, r1 = np.nonzero(cy)[0][[0, -1]]
        c0, c1 = np.nonzero(cx)[0][[0, -1]]
        sub = Z[max(0, r0 - 2):r1 + 3, max(0, c0 - 2):c1 + 3].copy()
        pad = np.pad(sub, 2, mode="edge")
        stack = np.stack([pad[i:i + sub.shape[0], j:j + sub.shape[1]] for i in range(5) for j in range(5)])
        med = np.median(stack, axis=0)
        spike = np.abs(sub - med) > 0.6
        sub[spike] = med[spike]
        n += int(spike.sum())
        for _ in range(P("ground_smooth_passes", 7)):
            pad = np.pad(sub, 1, mode="edge")
            sub = sum(pad[i:i + sub.shape[0], j:j + sub.shape[1]] for i in range(3) for j in range(3)) / 9.0
        Z[max(0, r0 - 2):r1 + 3, max(0, c0 - 2):c1 + 3][2:-2, 2:-2] = sub[2:-2, 2:-2]
    # r4 (critic: shards still visible elsewhere): lone spikes > 1.5 m off their 5 x 5 median everywhere within
    # 400 m, except HSW (x > 370) and 70 m round the Spire site
    pad = np.pad(Z, 2, mode="edge")
    med = np.nanmedian(np.stack([pad[i:i + Z.shape[0], j:j + Z.shape[1]] for i in range(5) for j in range(5)]), axis=0)
    GX, GY = np.meshgrid(xs, ys)
    zone = (np.hypot(GX, GY) < 400) & (GX < 370) & (np.hypot(GX, GY) > 70)
    spike = zone & (np.abs(Z - med) > 1.5)
    Z[spike] = med[spike]
    n2 = int(spike.sum())
    co[:, 2] = Z[iy, ix]
    me.vertices.foreach_set("co", co.ravel())
    me.update()
    report.append("ground: %d spike heights replaced at the Deanery cliff and the Customs House bank, %d elsewhere" % (n, n2))


def deanery_bank(col, guard, objs, report):
    """r4: the pale bank under the Deanery (OSM natural=cliff 186248015): a planted strip, 3.5 m either side of
    the cliff line, with scrub clumps, so it reads as a vegetated bank, not bare ground."""
    import foliage as FO
    o = L.osm()
    w = o["ways"].get(186248015)
    if not w:
        return
    pts = C.densify(o["line"](w), 2.0)
    left, right = C.offset_line(pts, 3.5), C.offset_line(pts, -3.5)
    ring = S.ccw(left + right[::-1])
    if any(guard.keepout(x, y) for x, y in ring):
        report.append("Deanery bank: in the keep-out zone, skipped")
        return
    ob = drape_poly("area_deanery_bank", ring, 0.07, col, cell=1.5)
    ob.data.materials.append(bpy.data.materials.get("clay_grass") or mat("grass", (0.12, 0.2, 0.06)))
    objs.append(ob.name)
    scrub = FO.Foliage(seed=401)
    for x, y in pts[::2]:
        if not guard.on_road(x, y):
            scrub.cloud((x, y, gz(x, y) + 0.7), (1.6, 1.6, 0.8), 160, 0.14, shell=0.3, top_bias=0.4)
            note(x, y, "bed")
    ob2 = scrub.object("area_deanery_scrub", col, (0.06, 0.11, 0.035), (0.17, 0.23, 0.07))
    if ob2:
        objs.append(ob2.name)
    report.append("Deanery bank planted (%d m)" % int(C.line_length(pts)))


def thin_leaves_near(cam_xy, heading_deg, near_m, far_m, half_deg, keep, guard, report, label):
    """r4: thin a leaf wall right in front of a photo camera: keep `keep` of the leaf cards in a wedge."""
    import numpy as np
    hx_, hy_ = math.sin(math.radians(heading_deg)), math.cos(math.radians(heading_deg))
    ch = math.cos(math.radians(half_deg))
    gone = 0
    for ob in list(bpy.data.objects):
        if ob.type != "MESH" or not ob.name.startswith("leaves_"):
            continue
        def test(X, Y, Z):
            dx, dy = X - cam_xy[0], Y - cam_xy[1]
            d = np.hypot(dx, dy)
            inw = (d > near_m) & (d < far_m) & ((dx * hx_ + dy * hy_) / np.maximum(d, 1e-6) > ch)
            rnd = (np.floor(X * 7.3) * 31 + np.floor(Y * 5.1) * 17 + np.floor(Z * 3.7) * 7) % 100
            return inw & (rnd >= keep * 100)
        gone += drop_where(ob, test)
    report.append("%s: thinned the leaves in front of the camera (%d cards)" % (label, gone))


def orphan_crowns(report):
    """r5 (3 critics: floating leaves): every leaf crown (foliage.CLOUDS) must have trunk / branch wood within
    0.5 m of its volume, and no tree may stand inside a building footprint. Crowns that fail lose their leaf
    cards; trees inside a footprint also lose their trunk. Shrubs (crown bottom < 1 m above ground) are skipped."""
    import numpy as np
    import foliage as FO
    import buildings as B
    from mathutils import kdtree
    wood = [o for o in bpy.data.objects if o.type == "MESH" and
            (o.name.startswith("tree_trunks") or o.name.startswith("area_carpark_tree_trunks") or o.name.startswith("palm"))]
    pts = []
    for o in wood:
        co = np.empty(len(o.data.vertices) * 3, "f4")
        o.data.vertices.foreach_get("co", co)
        pts.append(co.reshape(-1, 3))
    pts = np.concatenate(pts) if pts else np.zeros((0, 3), "f4")
    kd = kdtree.KDTree(len(pts))
    for i, p in enumerate(pts):
        kd.insert(p, i)
    kd.balance()
    crowns = [(c, r) for c, r in FO.CLOUDS if c[2] - r[2] > gz(c[0], c[1]) + 1.0]
    C_ = np.array([c for c, r in crowns] or [(0, 0, 0)], "f8")
    footprint = np.zeros(len(crowns), bool)
    for b in B.records():
        ring = b["tiers"][0]["ring"]
        xs = [p[0] for p in ring]
        ys = [p[1] for p in ring]
        sel = (C_[:, 0] > min(xs)) & (C_[:, 0] < max(xs)) & (C_[:, 1] > min(ys)) & (C_[:, 1] < max(ys))
        if sel.any():
            idx = np.nonzero(sel)[0]
            hit = in_rings_np(C_[idx, 0], C_[idx, 1], [ring])
            top = max(t["top_ahd"] for t in b["tiers"])
            # r5: only crowns well inside the building volume (centre >= 1 m in from the wall, below roof - 1 m, building >= 5 m)
            if top - b["base_ahd"] >= 5.0:
                inner = [i for i in idx[hit] if C_[i, 2] < top - 1.0 and min(seg_dist(C_[i, 0], C_[i, 1], p, q) for p, q in zip(ring, ring[1:] + ring[:1])) > 1.0]
                footprint[inner] = True
    orphan = np.array([len(kd.find_range(c, max(r) + 0.5)) == 0 for c, r in crowns], bool) if crowns else np.zeros(0, bool)
    bad = [crowns[i] for i in np.nonzero(orphan | footprint)[0]]
    if not bad:
        report.append("leaf check: 0 orphan crowns, 0 trees in buildings")
        return
    BC = np.array([c for c, r in bad], "f8")
    BR = np.array([r for c, r in bad], "f8") * 1.05
    leaves_gone = 0
    for o in list(bpy.data.objects):
        if o.type != "MESH" or not (o.name.startswith(("leaves_", "blooms_", "area_carpark_leaves"))):
            continue
        def test(X, Y, Z):
            hit = np.zeros(len(X), bool)
            order = np.argsort(X)
            Xs = X[order]
            for (cx, cy, cz), (rx, ry, rz) in zip(BC, BR):
                lo, hi = np.searchsorted(Xs, cx - rx), np.searchsorted(Xs, cx + rx)
                if hi <= lo:
                    continue
                i = order[lo:hi]
                hit[i] |= ((X[i] - cx) / rx) ** 2 + ((Y[i] - cy) / ry) ** 2 + ((Z[i] - cz) / rz) ** 2 < 1.0
            return hit
        leaves_gone += drop_where(o, test)
    fp = [crowns[i] for i in np.nonzero(footprint)[0]]
    trunk_gone = 0
    for o in wood:
        trunk_gone += drop_where(o, lambda X, Y, Z: np.any([(X - c[0]) ** 2 + (Y - c[1]) ** 2 < 1.4 ** 2 for c, r in fp], axis=0)
                                 if fp else np.zeros(len(X), bool))
    report.append("leaf check: %d orphan crowns (no wood within 0.5 m), %d trees inside building footprints; "
                  "%d leaf cards and %d trunk faces dropped" % (int(orphan.sum()), int(footprint.sum()), leaves_gone, trunk_gone))


def low_leaves_on_road(guard, report):
    """r5 (critics: leaf discs scattered over the road at the Customs House and elsewhere): leaf cards less than
    2.5 m above the ground whose centre is over a carriageway are dropped (shrub clouds spilling onto the road)."""
    import numpy as np
    x0, y0, x1, y1 = L.LIDAR_BOX
    grd = L.lidar("ground")
    road = np.zeros(grd.shape, bool)                                   # 1 m raster of the carriageways
    for (ax, ay), (bx, by), h in zip(guard.road.A, guard.road.B, guard.road.H):
        h = h - 0.2
        c0, c1 = int(min(ax, bx) - h - x0), int(max(ax, bx) + h - x0) + 1
        r0, r1 = int(y1 - max(ay, by) - h), int(y1 - min(ay, by) + h) + 1
        c0, r0 = max(c0, 0), max(r0, 0)
        c1, r1 = min(c1, road.shape[1]), min(r1, road.shape[0])
        if c1 <= c0 or r1 <= r0:
            continue
        X, Y = np.meshgrid(x0 + np.arange(c0, c1) + 0.5, y1 - np.arange(r0, r1) - 0.5)
        dx, dy = bx - ax, by - ay
        l2 = max(dx * dx + dy * dy, 1e-9)
        k = np.clip(((X - ax) * dx + (Y - ay) * dy) / l2, 0, 1)
        road[r0:r1, c0:c1] |= (X - ax - dx * k) ** 2 + (Y - ay - dy * k) ** 2 < h * h
    gone = 0
    for o in list(bpy.data.objects):
        if o.type != "MESH" or not o.name.startswith(("leaves_", "street_shrubs", "area_carpark_shrubs")):
            continue
        def test(X, Y, Z):
            c = np.clip((X - x0).astype(int), 0, road.shape[1] - 1)
            r = np.clip((y1 - Y).astype(int), 0, road.shape[0] - 1)
            low = Z - grd[r, c]
            # r5: sparse low shrub clouds read as floating discs: tree leaf objects keep nothing below 2 m
            return (road[r, c] & (low < 2.5)) | (o.name.startswith("leaves_") & (low < 2.0))
        gone += drop_where(o, test)
    # r5: leaf cards inside a building volume (poking through walls, e.g. the Deanery)
    import buildings as B
    inside = 0
    leaf_obs = [o for o in bpy.data.objects if o.type == "MESH" and o.name.startswith(("leaves_", "blooms_"))]
    rings = []
    for b in B.records():
        ring = b["tiers"][0]["ring"]
        cx = sum(p[0] for p in ring) / len(ring)
        cy = sum(p[1] for p in ring) / len(ring)
        if math.hypot(cx, cy) < 360 and not guard.keepout(cx, cy):
            rings.append((ring, max(t["top_ahd"] for t in b["tiers"]) - 0.3))
    for o in leaf_obs:
        def test2(X, Y, Z):
            hit = np.zeros(len(X), bool)
            order = np.argsort(X)
            Xs = X[order]
            for ring, top in rings:
                xs = [p[0] for p in ring]
                lo, hi = np.searchsorted(Xs, min(xs)), np.searchsorted(Xs, max(xs))
                if hi <= lo:
                    continue
                i = order[lo:hi]
                i = i[Z[i] < top]
                if len(i):
                    hit[i] |= in_rings_np(X[i], Y[i], [ring])
            return hit
        inside += drop_where(o, test2)
    report.append("leaf check: %d low leaf cards (over a road, or tree leaves < 2 m up) and %d inside buildings dropped"
                  % (gone, inside))


def round6(guard, report):
    """r6 structural fixes (each checked by crop):
    1. spire_ann_st_2018: the photo shows an open street (brick left, ONE fig right): every tree within 30 m in
       front of that camera goes, except the right-hand side (the fig), outside the keep-out zone only.
    2. Named ghost crowns (rays from the critic's pixels): the Willahra 'lens' (a jacaranda at 71.5, -69) and the
       far crown at the Customs House (-78, -326); then every trunk with no leaves within 2 m of its axis, and every
       far-crown blob with no trunk within 12 m.
    3. Two-tone roads: rays show both tones are the same 'roads' object and material: overlapping crowned ribbons
       of different OSM ways tilt different ways. All road faces now shade with an up normal (one tone).
    4. far_land: the steep slivers 1 km south (the 'yellow light shafts' in the aerial) go.
    5. The Deanery's verandah posts / rails (the 'scaffolding') go: a plain sandstone house."""
    import numpy as np
    # 1. the avenue in front of the 2018 Commons camera
    cam, hd = (167.0, 241.9), math.radians(215.2)
    wedge = [(cam[0] + d * math.sin(hd + a), cam[1] + d * math.cos(hd + a)) for d, a in
             ((3, -0.62), (3, 0.12), (30, 0.12), (30, -0.62))]
    if not any(guard.keepout(x, y) for x, y in wedge):
        n1 = clear_trees([wedge], guard)
        report.append("spire_ann_st_2018: trees cleared in front of the camera, right-hand fig kept (%d faces)" % n1)
    # 2a. named ghost crowns
    named = P("remove_crowns", [(71.5, -69.0, 7.0), (-78.0, -326.0, 7.0)])
    tree_obs = [o for o in bpy.data.objects if o.type == "MESH" and o.name.startswith(TREE_PREFIX)]
    n2 = 0
    for o in tree_obs:
        n2 += drop_where(o, lambda X, Y, Z: np.any([(X - x) ** 2 + (Y - y) ** 2 < r * r for x, y, r in named], axis=0))
    # 2b. pairing check on a 1 m grid: leaves (incl. far crowns, palms) vs wood (trunks)
    x0, y0, x1, y1 = L.LIDAR_BOX
    shape = (int(y1 - y0) + 1, int(x1 - x0) + 1)
    leaf = np.zeros(shape, "i4")
    wood = np.zeros(shape, "i4")
    def cells(o):
        co = np.empty(len(o.data.polygons) * 3, "f4")
        o.data.polygons.foreach_get("center", co)
        co = co.reshape(-1, 3)
        r = np.clip((y1 - co[:, 1]).astype(int), 0, shape[0] - 1)
        c = np.clip((co[:, 0] - x0).astype(int), 0, shape[1] - 1)
        return r, c
    woods = [o for o in tree_obs if "trunk" in o.name] + [o for o in bpy.data.objects if o.name.startswith("area_carpark_tree_trunks")]
    leaves = [o for o in tree_obs if "trunk" not in o.name and "shadow" not in o.name] + \
             [o for o in bpy.data.objects if o.name.startswith("area_carpark_leaves")]
    for o in leaves:
        r, c = cells(o)
        np.add.at(leaf, (r, c), 1)
    for o in woods:
        r, c = cells(o)
        np.add.at(wood, (r, c), 1)
    def box_sum(a, k):
        s = np.pad(a, k).cumsum(0).cumsum(1)
        s = np.pad(s, ((1, 0), (1, 0)))
        n = 2 * k + 1
        return s[n:, n:] - s[:-n, n:] - s[n:, :-n] + s[:-n, :-n]
    leaf_near = box_sum(leaf, 2) > 0                                # any leaf within ~2 m of a trunk cell
    wood_near = box_sum(wood, 12) > 0                               # any trunk within ~12 m of a far-crown cell
    n3 = sum(drop_where(o, lambda X, Y, Z: (X < 370) & ~leaf_near[np.clip((y1 - Y).astype(int), 0, shape[0] - 1),
                                                       np.clip((X - x0).astype(int), 0, shape[1] - 1)]) for o in woods)
    fars = [o for o in tree_obs if o.name.startswith("tree_crowns_far")]
    n4 = sum(drop_where(o, lambda X, Y, Z: (X < 370) & ~wood_near[np.clip((y1 - Y).astype(int), 0, shape[0] - 1),
                                                       np.clip((X - x0).astype(int), 0, shape[1] - 1)]) for o in fars)
    report.append("tree pairing: %d faces of named ghost crowns, %d trunk faces with no crown, %d far-crown faces "
                  "with no trunk dropped" % (n2, n3, n4))
    # 3. roads shade as one surface
    rd = bpy.data.objects.get("roads")
    if rd is not None:
        me = rd.data
        me.polygons.foreach_set("use_smooth", [True] * len(me.polygons))
        me.normals_split_custom_set_from_vertices([(0.0, 0.0, 1.0)] * len(me.vertices))
        report.append("roads: one up normal on all %d faces (no two-tone crown shading)" % len(me.polygons))
    # 4. far_land slivers
    fl = bpy.data.objects.get("far_land")
    if fl is not None:
        nm = np.empty(len(fl.data.polygons) * 3, "f4")
        fl.data.polygons.foreach_get("normal", nm)
        steep = np.abs(nm.reshape(-1, 3)[:, 2]) < 0.5
        k = drop_where(fl, lambda X, Y, Z: steep[:len(X)] if len(X) == len(steep) else np.zeros(len(X), bool))
        report.append("far_land: %d steep sliver faces dropped" % k)
    # 5. the Deanery without its scaffold-like verandah
    k = drop_where(bpy.data.objects.get("bldg_look_106225770_band"), lambda X, Y, Z: np.ones(len(X), bool))
    report.append("Deanery: verandah posts / rails dropped (%d faces): plain sandstone house" % k)
    # 6. ghost pixels: leaf cards within 2.5 m of the camera ray through a pixel the critics marked
    A_ = json.load(open(os.path.join(os.path.dirname(L.HERE), "..", "spire_area", "area_cams.json"), encoding="utf-8"))
    heroes = {h["id"]: h for h in A_["heroes"]}
    k6 = 0
    for hid, px, py, rad in P("ghost_pixels", [("willahra_admiralty", 700, 762, 2.5), ("willahra_admiralty", 680, 752, 2.5),
                                               ("willahra_admiralty", 730, 775, 2.5)]):
        h = heroes.get(hid)
        if not h:
            continue
        pos = np.array([h["pos"][0], h["pos"][1], h["pos"][2] + gz(h["pos"][0], h["pos"][1])])
        look = np.array([h["look_at"][0], h["look_at"][1], h["look_at"][2] + gz(h["look_at"][0], h["look_at"][1])])
        f = (look - pos) / np.linalg.norm(look - pos)
        r = np.cross(f, [0, 0, 1.0])
        r /= np.linalg.norm(r)
        u = np.cross(r, f)
        t = 18.0 / h["lens_mm"]
        d = f + r * (px - 800) / 800 * t + u * (500 - py) / 800 * t
        d /= np.linalg.norm(d)
        for o in tree_obs + leaves:
            if o.name in bpy.data.objects:
                def ray_test(X, Y, Z, pos=pos, d=d, rad=rad):
                    V = np.stack([X - pos[0], Y - pos[1], Z - pos[2]], 1)
                    s = V @ d
                    perp = np.linalg.norm(V - s[:, None] * d[None], axis=1)
                    return (s > 5.0) & (perp < rad)
                k6 += drop_where(o, ray_test)
    report.append("ghost pixels: %d leaf faces on the critics' rays dropped" % k6)


def ray_boxes(report):
    """r7 (critics' boxes, 1600 x 1000 heroes): every tree face (leaves AND trunks) within the radius of a camera
    ray through a grid of points in each box goes. Kills crownless Y / V stumps and floating crowns at once."""
    import numpy as np
    A_ = json.load(open(os.path.join(os.path.dirname(L.HERE), "..", "spire_area", "area_cams.json"), encoding="utf-8"))
    cams = {h["id"]: h for h in A_["heroes"]}
    for c in L.CAMERAS + L.HERO_CAMERAS:
        cams.setdefault({"street_ann_cathedral": "annstcath"}.get(c["id"], c["id"]), c)
    boxes = P("ray_boxes", [
        ("deanery", 655, 485, 95, 85, 3.0),
        ("carpark_eye", 320, 485, 70, 70, 1.5), ("carpark_eye", 425, 520, 40, 60, 1.2),
        ("carpark_eye", 1465, 560, 70, 55, 1.5), ("carpark_eye", 180, 470, 35, 65, 1.2),
        ("annstcath", 165, 480, 30, 80, 1.2), ("annstcath", 320, 480, 70, 80, 1.5), ("annstcath", 425, 480, 15, 80, 1.0),
        ("cathedral_from_carpark", 1260, 250, 110, 595, 2.0),
        ("church_house_webber", 890, 620, 120, 55, 1.5),
        ("orient_hotel", 0, 150, 200, 600, 2.0),                      # the dead Y tree at the left (camera moved r7)
        ("orient_hotel", 750, 330, 70, 360, 1.5),                     # the bare fork at the Orient corner
    ])
    trees = [o for o in bpy.data.objects if o.type == "MESH" and (o.name.startswith(TREE_PREFIX) or
             o.name.startswith("area_carpark_tree_trunks") or o.name.startswith("area_carpark_leaves"))]
    total = 0
    for vid, bx, by, bw, bh, rad in boxes:
        h = cams.get(vid)
        if not h:
            report.append("ray boxes: no camera %s" % vid)
            continue
        pos = np.array([h["pos"][0], h["pos"][1], h["pos"][2] + gz(h["pos"][0], h["pos"][1])])
        look = np.array([h["look_at"][0], h["look_at"][1], h["look_at"][2] + gz(h["look_at"][0], h["look_at"][1])])
        f = (look - pos) / np.linalg.norm(look - pos)
        r = np.cross(f, [0, 0, 1.0])
        r /= np.linalg.norm(r)
        u = np.cross(r, f)
        t = 18.0 / h["lens_mm"]
        dirs = []
        for i in range(4):
            for j in range(5):
                px, py = bx + bw * (i + 0.5) / 4, by + bh * (j + 0.5) / 5
                d = f + r * (px - 800) / 800 * t + u * (500 - py) / 800 * t
                dirs.append(d / np.linalg.norm(d))
        D = np.array(dirs)
        k = 0
        for o in trees:
            if o.name not in bpy.data.objects:
                continue
            def test(X, Y, Z, pos=pos, D=D, rad=rad):
                V = np.stack([X - pos[0], Y - pos[1], Z - pos[2]], 1)
                s = V @ D.T                                           # (faces, rays)
                perp2 = (V * V).sum(1)[:, None] - s * s
                return ((s > 3.0) & (perp2 < rad * rad)).any(1)
            k += drop_where(o, test)
        total += k
        report.append("ray box %s (%d,%d,%d,%d): %d tree faces dropped" % (vid, bx, by, bw, bh, k))
    return total


def pixel_kill(guard, report):
    """r9 (critics' boxes, each with its image size): cast a 6 x 6 grid of camera rays through every box in the real
    render camera (render_area's own camera code) and remove the whole tree (leaves, trunk, proxy) within 3.5 m of
    every tree hit. Run before round8_trees, whose checks then clear any remnant."""
    import numpy as np
    boxes = P("pixel_kill", [
        ("spire_ann_st_2018", 1199, 1600, 630, 770, 215, 295),
        ("cathedral_ann_st_2012", 1200, 1600, 1035, 108, 165, 87), ("cathedral_ann_st_2012", 1200, 1600, 735, 430, 135, 110),
        ("cathedral_ann_st_2012", 1200, 1600, 930, 875, 215, 75), ("cathedral_ann_st_2012", 1200, 1600, 160, 1340, 55, 210),
        ("cathedral_ann_st_2012", 1200, 1600, 0, 1250, 120, 350),
        ("orient_front", 1205, 1600, 0, 715, 50, 85), ("orient_front", 1205, 1600, 940, 1185, 60, 70),
        ("carpark_eye", 1600, 1000, 395, 190, 100, 265), ("cathedral_from_carpark", 1600, 1000, 780, 395, 160, 205),
        ("cathedral_grounds", 1600, 1000, 1355, 430, 30, 50), ("customs_house", 1600, 1000, 1240, 480, 155, 65),
        ("customs_house_river", 1600, 1000, 1090, 250, 370, 470), ("orient", 1067, 1600, 580, 880, 140, 270),
        # own check of the r9 test render: leaf dots left in cathedral_ann_st_2012, the V at the end of carpark_eye
        ("cathedral_ann_st_2012", 1200, 1600, 50, 375, 90, 110), ("cathedral_ann_st_2012", 1200, 1600, 1040, 105, 150, 95),
        ("cathedral_ann_st_2012", 1200, 1600, 905, 505, 190, 95), ("carpark_eye", 1600, 1000, 1010, 180, 70, 370),
        # r11 list (radius, see through walls)
        ("cathedral_ann_st_2012", 1200, 1600, 1040, 100, 160, 90, 6.0), ("cathedral_ann_st_2012", 1200, 1600, 800, 450, 90, 95, 5.0),
        ("cathedral_ann_st_2012", 1200, 1600, 995, 870, 100, 90, 4.0, True), ("cathedral_from_carpark", 1600, 1000, 1220, 0, 380, 120),
        ("cathedral_grounds", 1600, 1000, 180, 90, 280, 160, 3.5, True), ("cathedral_lawn_eye", 1600, 1000, 1220, 60, 380, 140),
        ("customs_house", 1600, 1000, 1240, 480, 90, 60, 5.0),
        # r10 list
        ("cathedral_ann_st_2012", 1200, 1600, 1035, 105, 165, 90), ("cathedral_ann_st_2012", 1200, 1600, 735, 430, 140, 120),
        ("cathedral_ann_st_2012", 1200, 1600, 930, 865, 200, 90), ("carpark_eye", 1600, 1000, 370, 80, 260, 110),
        ("customs_house", 1600, 1000, 1205, 480, 150, 100), ("customs_house_river", 1600, 1000, 275, 715, 85, 115),
        ("orient_hotel", 1600, 1000, 890, 520, 210, 90),
    ])
    here = os.path.join(os.path.dirname(L.HERE), "..", "spire_area")
    src = open(os.path.join(here, "render_area.py"), encoding="utf-8").read().replace("\nmain()\n", "\n")
    ns = {"__name__": "ra_pk", "__file__": os.path.join(here, "render_area.py")}
    exec(compile(src, "render_area", "exec"), ns)
    A_ = json.load(open(os.path.join(here, "area_cams.json"), encoding="utf-8"))
    heroes = {h["id"]: h for h in A_["heroes"]}
    lay = {c["id"]: c for c in L.CAMERAS + L.HERO_CAMERAS}
    show = {h["id"]: h for h in A_["showcase"]}
    pc = {c["id"]: c for c in json.load(open(os.path.join(L.HERE, "photo_cams.json")))["cams"]}
    cc = {c["id"]: c for c in json.load(open(os.path.join(L.HERE, "showcase_cams.json")))["cams"]}
    cd = bpy.data.cameras.new("cam_pk")
    cam = bpy.data.objects.new("cam_pk", cd)
    bpy.context.scene.collection.objects.link(cam)
    sc = bpy.context.scene
    rx, ry = sc.render.resolution_x, sc.render.resolution_y
    is_tree = lambda o: o.name.startswith(TREE_PREFIX) or o.name.startswith(("area_carpark_tree_trunks", "area_carpark_leaves"))
    hits, other = [], {}
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    for bxs in boxes:
        vid, iw, ih, bx, by, bw, bh = bxs[:7]
        brad = bxs[7] if len(bxs) > 7 else P("pixel_kill_r", 3.5)
        thru = bxs[8] if len(bxs) > 8 else False
        v = vid
        if v in show:
            sv = show[v]
            v = sv.get("layout") or sv.get("photo_day")
        if v in heroes or v in lay:
            ns["place_agl"](cam, heroes.get(v) or lay[v])
        elif v in pc or v in cc:
            ns["photo_cam"](cam, pc.get(v) or cc[v])
        else:
            report.append("pixel kill: no camera %s" % vid)
            continue
        sc.render.resolution_x, sc.render.resolution_y = iw, ih
        bpy.context.view_layer.update()
        fr = [cam.matrix_world @ q for q in cam.data.view_frame(scene=sc)]
        o = cam.matrix_world.translation.copy()
        k = 0
        for i in range(10):
            for j in range(10):
                u, w_ = (bx + bw * (i + 0.5) / 10) / iw, (by + bh * (j + 0.5) / 10) / ih
                p_ = fr[3].lerp(fr[0], u).lerp(fr[2].lerp(fr[1], u), w_)
                d = (p_ - o).normalized()
                ok, loc, n, idx, ob, mx = sc.ray_cast(dg, o, d)
                o2 = o
                for _ in range(4 if thru else 0):                      # r11: leaves showing through a wall
                    if not ok or is_tree(ob):
                        break
                    o2 = loc + d * 0.05
                    ok, loc, n, idx, ob, mx = sc.ray_cast(dg, o2, d)
                if ok and is_tree(ob) and not guard.keepout(loc.x, loc.y):
                    hits.append((loc.x, loc.y, brad))
                    k += 1
                elif ok:
                    other[ob.name] = other.get(ob.name, 0) + 1
        report.append("pixel kill %s (%d,%d,%d,%d): %d tree hits; other: %s" % (vid, bx, by, bw, bh, k,
                      ", ".join("%s %d" % kv for kv in sorted(other.items(), key=lambda kv: -kv[1])[:3])))
        other.clear()
    sc.render.resolution_x, sc.render.resolution_y = rx, ry
    bpy.data.objects.remove(cam)
    if not hits:
        return
    H_ = np.unique(np.round(np.array(hits), 0), axis=0)
    n_ = 0
    for o in [o for o in bpy.data.objects if o.type == "MESH" and is_tree(o)]:
        n_ += drop_where(o, lambda X, Y, Z: ((X[:, None] - H_[:, 0]) ** 2 + (Y[:, None] - H_[:, 1]) ** 2 < H_[:, 2] ** 2).any(1))
    report.append("pixel kill: %d spots, %d tree faces dropped" % (len(H_), n_))


def frustum_kill(guard, report):
    """r12 (critic: the sparse outer crowns near the camera are rosettes on hair-thin twigs; rays slip through the
    alpha holes, so pixel_kill misses them): project every tree face centre (leaves, twigs, trunks, proxies) into
    the box's real render camera; any face within dmax of the camera that lands in the box marks its tree, and
    every tree face within 4 m of a mark goes. Trees in the keep-out zone are left alone."""
    import numpy as np
    boxes = P("frustum_kill", [
        ("cathedral_ann_st_2012", 1200, 1600, 985, 60, 215, 200), ("cathedral_ann_st_2012", 1200, 1600, 690, 380, 200, 200),
        ("cathedral_ann_st_2012", 1200, 1600, 880, 820, 300, 200),
        ("queen_st_willahra", 1198, 1600, 100, 930, 145, 110), ("queen_st_willahra", 1198, 1600, 160, 1130, 440, 110),
        ("queen_st_willahra", 1198, 1600, 940, 1190, 160, 120),
        ("carpark_eye", 1600, 1000, 370, 80, 280, 150), ("carpark_eye", 1600, 1000, 390, 185, 100, 195),
        ("customs_house_river", 1600, 1000, 1550, 330, 45, 145), ("queen_st_streetscape", 1600, 1000, 1350, 20, 250, 200),
        ("customs_house", 1600, 1000, 1180, 490, 160, 110), ("cathedral_grounds", 1600, 1000, 840, 640, 25, 360),
        # r13: the cathedral_forecourt box (0,0,60,260) went: it left a bald gap where the photo has a big canopy
        # r14: the r13 ann_st_far boxes took the photo's real fig on Ann St (it fills spire_ann_st_2018 right-middle):
        # gone; the debris trunk there is a named kill instead
        ("cathedral_grounds", 1600, 1000, 1395, 715, 205, 285),
        ("customs_house", 1600, 1000, 1265, 505, 80, 95), ("cathedral_from_carpark", 1600, 1000, 0, 230, 180, 310),
        # r14: the customs_house "plates" are tree_crowns_far lumps ~120 m out (probe), past the default reach
        ("customs_house", 1600, 1000, 1180, 480, 190, 130, 200.0), ("customs_house_river", 1600, 1000, 800, 780, 80, 70),
        ("annstcath", 1600, 1000, 130, 330, 510, 170, 40.0),
    ])
    here = os.path.join(os.path.dirname(L.HERE), "..", "spire_area")
    src = open(os.path.join(here, "render_area.py"), encoding="utf-8").read().replace("\nmain()\n", "\n")
    ns = {"__name__": "ra_fk", "__file__": os.path.join(here, "render_area.py")}
    exec(compile(src, "render_area", "exec"), ns)
    A_ = json.load(open(os.path.join(here, "area_cams.json"), encoding="utf-8"))
    heroes = {h["id"]: h for h in A_["heroes"]}
    lay = {c["id"]: c for c in L.CAMERAS + L.HERO_CAMERAS}
    show = {h["id"]: h for h in A_["showcase"]}
    pc = {c["id"]: c for c in json.load(open(os.path.join(L.HERE, "photo_cams.json")))["cams"]}
    cc = {c["id"]: c for c in json.load(open(os.path.join(L.HERE, "showcase_cams.json")))["cams"]}
    cam = bpy.data.objects.new("cam_fk", bpy.data.cameras.new("cam_fk"))
    bpy.context.scene.collection.objects.link(cam)
    sc = bpy.context.scene
    rx, ry = sc.render.resolution_x, sc.render.resolution_y
    is_tree = lambda o: o.name.startswith(TREE_PREFIX) or o.name.startswith(("area_carpark_tree_trunks", "area_carpark_leaves"))
    trees = [o for o in bpy.data.objects if o.type == "MESH" and is_tree(o) and o.data.polygons]
    cents = []
    for o in trees:
        c = np.empty(len(o.data.polygons) * 3, "f4")
        o.data.polygons.foreach_get("center", c)
        cents.append(c.reshape(-1, 3) + np.array(o.matrix_world.translation, "f4"))
    marks = []
    for bxs in boxes:
        vid, iw, ih, bx, by, bw, bh = bxs[:7]
        dmax = bxs[7] if len(bxs) > 7 else P("frustum_kill_d", 70.0)
        v = vid
        if v in show:
            v = show[v].get("layout") or show[v].get("photo_day")
        if v in heroes or v in lay:
            ns["place_agl"](cam, heroes.get(v) or lay[v])
        elif v in pc or v in cc:
            ns["photo_cam"](cam, pc.get(v) or cc[v])
        else:
            report.append("frustum kill: no camera %s" % vid)
            continue
        sc.render.resolution_x, sc.render.resolution_y = iw, ih
        bpy.context.view_layer.update()
        fr = cam.data.view_frame(scene=sc)
        d = -fr[0].z
        xs, ys = [q.x for q in fr], [q.y for q in fr]
        x0_, x1_, y0_, y1_ = min(xs), max(xs), min(ys), max(ys)
        Mi = np.array(cam.matrix_world.inverted(), "f8")
        k = 0
        for C_ in cents:
            Lc = C_ @ Mi[:3, :3].T + Mi[:3, 3]
            dep = -Lc[:, 2]
            ok = (dep > 0.5) & (dep < dmax)
            if not ok.any():
                continue
            u = (Lc[:, 0] / np.maximum(dep, 1e-3) * d - x0_) / (x1_ - x0_) * iw
            w_ = (y1_ - Lc[:, 1] / np.maximum(dep, 1e-3) * d) / (y1_ - y0_) * ih
            inb = ok & (u >= bx) & (u <= bx + bw) & (w_ >= by) & (w_ <= by + bh)
            if inb.any():
                pts = np.unique(np.round(C_[inb, :2] / 2.0) * 2.0, axis=0)
                pts = [p_ for p_ in pts if not guard.keepout(float(p_[0]), float(p_[1]))]
                marks += pts
                k += len(pts)
        report.append("frustum kill %s (%d,%d,%d,%d): %d marks" % (vid, bx, by, bw, bh, k))
    sc.render.resolution_x, sc.render.resolution_y = rx, ry
    bpy.data.objects.remove(cam)
    if not marks:
        return
    M_ = np.unique(np.array(marks), axis=0)
    rad = P("frustum_kill_r", 4.0)
    n_ = 0
    for o in trees:
        if o.name in bpy.data.objects:
            n_ += drop_where(o, lambda X, Y, Z: ((X[:, None] - M_[:, 0]) ** 2 + (Y[:, None] - M_[:, 1]) ** 2 < rad * rad).any(1))
    report.append("frustum kill: %d marks, %d tree faces dropped" % (len(M_), n_))


def round8_trees(guard, report):
    """r8 (critics' boxes, traced to objects by ray-casting the round 7 cameras):
    1. Named trees go whole (leaves, trunk, shadow proxy): the car park tree the camera of hero_carpark_eye stands
       in, the near crown filling cathedral_ann_st_2012, the car park V by the chancel, the Deanery eucalypts read
       as bare white poles, the river-walk trees standing in the water and the pale trunks at the Customs House,
       the poinciana dots and the second bare trunk in spire_ann_st_2018 (the photo has one low fig), the speckle
       over the west front, the far blob at the Customs House, the forecourt car park trunks, the Willahra fork.
    2. Build check: every trunk piece (mesh island) needs a crown: at least 40 leaf cards within max(2.5 m,
       half its height) of its top. Trunks that fail go.
    3. Build check: leaf cards with no trunk top within 10 m go (speckle)."""
    import numpy as np
    kill = P("r8_tree_kill", [
        (103.5, 171.8, 2.0),            # r14: bare debris trunk in spire_ann_st_2018 / ann_st_far (probe: tree_trunks 110922)
        (-27.0, -61.0, 4.5), (-188.4, -110.9, 6.0), (-45.8, -74.3, 3.5), (-13.6, -107.9, 4.0), (4.6, -90.0, 4.0),
        (47.5, -293.0, 6.0), (56.5, -259.0, 4.5), (150.3, 224.8, 5.0), (144.1, 218.1, 3.0), (-121.7, -54.0, 5.0),
        (-83.2, -330.8, 8.0), (-115.4, -101.7, 3.0), (28.7, -14.5, 1.6), (-64.9, -29.6, 3.0),
        # second probe after the first r8 test render: the V and dots in cathedral_ann_st_2012, the bare fork and dots
        # in spire_ann_st_2018, the river-edge crowns and the tall bare trunks at the Customs House river walk
        (-158.5, -106.3, 3.5), (-165.0, -106.0, 4.0), (-178.5, -104.0, 4.5), (145.9, 220.8, 2.0), (141.0, 214.7, 3.0),
        (148.2, 218.8, 3.0), (54.0, -279.3, 5.0), (53.5, -269.5, 3.0), (50.3, -282.4, 3.0), (50.6, -250.0, 3.0),
        (52.8, -255.2, 3.0), (59.0, -260.8, 4.0)])
    kill = [k for k in kill if not guard.keepout(k[0], k[1])]
    trees = [o for o in bpy.data.objects if o.type == "MESH" and (o.name.startswith(TREE_PREFIX) or
             o.name.startswith(("area_carpark_tree_trunks", "area_carpark_leaves")))]
    K_ = np.array(kill, "f8")
    n1 = 0
    for o in trees:
        n1 += drop_where(o, lambda X, Y, Z: ((X[:, None] - K_[:, 0]) ** 2 + (Y[:, None] - K_[:, 1]) ** 2 < K_[:, 2] ** 2).any(1))
    report.append("r8 named trees: %d spots, %d faces dropped" % (len(kill), n1))
    # leaf density grid (1 m) from every near-leaf object, cards >= 2 m above the ground
    x0, y0, x1, y1 = L.LIDAR_BOX
    shape = (int(y1 - y0) + 1, int(x1 - x0) + 1)
    def rc(X, Y):
        return np.clip((y1 - Y).astype(int), 0, shape[0] - 1), np.clip((X - x0).astype(int), 0, shape[1] - 1)
    leaf_obs = [o for o in trees if o.name.startswith(("leaves_", "area_carpark_leaves")) and "palm" not in o.name]
    leaf = np.zeros(shape, "i4")
    crown_obs = leaf_obs + [o for o in bpy.data.objects if o.type == "MESH" and o.name.startswith(("tree_crowns_far", "palm_fronds_far"))]
    for o in crown_obs:
        c = np.empty(len(o.data.polygons) * 3, "f4")
        o.data.polygons.foreach_get("center", c)
        c = c.reshape(-1, 3)
        np.add.at(leaf, rc(c[:, 0], c[:, 1]), 1)
    s_ = np.pad(leaf, ((1, 0), (1, 0))).cumsum(0).cumsum(1)
    def disc_sum(r_, c_, k):                                          # box sum (2k+1)^2 around each cell
        r0, r1 = np.clip(r_ - k, 0, shape[0]), np.clip(r_ + k + 1, 0, shape[0])
        c0, c1 = np.clip(c_ - k, 0, shape[1]), np.clip(c_ + k + 1, 0, shape[1])
        return s_[r1, c1] - s_[r0, c1] - s_[r1, c0] + s_[r0, c0]
    tops = []
    n2 = n2i = 0
    for o in [t for t in trees if t.name.startswith(("tree_trunks", "area_carpark_tree_trunks"))]:
        me = o.data
        nv = len(me.vertices)
        if not nv or not me.polygons:
            continue
        co = np.empty(nv * 3, "f4")
        me.vertices.foreach_get("co", co)
        co = co.reshape(-1, 3) + np.array(o.matrix_world.translation, "f4")
        lv = np.empty(len(me.loops), "i4")
        me.loops.foreach_get("vertex_index", lv)
        ls = np.empty(len(me.polygons), "i4")
        me.polygons.foreach_get("loop_start", ls)
        lab = np.arange(nv)
        for _ in range(400):                                           # islands by min-label propagation
            pl = np.minimum.reduceat(lab[lv], ls)
            new = lab.copy()
            np.minimum.at(new, lv, np.repeat(pl, np.diff(np.append(ls, len(lv)))))
            if (new == lab).all():
                break
            lab = new
        u, inv = np.unique(lab, return_inverse=True)
        zmin = np.full(len(u), np.inf); np.minimum.at(zmin, inv, co[:, 2])
        zmax = np.full(len(u), -np.inf); np.maximum.at(zmax, inv, co[:, 2])
        top = co[:, 2] > (zmin + 0.75 * (zmax - zmin))[inv]
        tx = np.bincount(inv[top], co[top, 0], len(u)) / np.maximum(np.bincount(inv[top], None, len(u)), 1)
        ty = np.bincount(inv[top], co[top, 1], len(u)) / np.maximum(np.bincount(inv[top], None, len(u)), 1)
        h = zmax - zmin
        r_, c_ = rc(tx, ty)
        k = np.clip(np.maximum(2.5, 0.5 * h).astype(int), 2, 8)
        cnt = np.array([disc_sum(a, b, kk) for a, b, kk in zip(r_, c_, k)])
        bad = (((cnt < P("r8_min_leaves", 40)) & (h > 1.5)) | (zmin < P("r8_min_base_ahd", 1.2))) & (tx < 370)
        tops += [(x, y) for x, y, b in zip(tx, ty, bad) if not b]
        if bad.any():
            badv = bad[inv]
            pl_bad = np.maximum.reduceat(badv[lv].astype("i1"), ls).astype(bool)
            n2 += drop_where(o, lambda X, Y, Z, m=pl_bad: m[:len(X)] if len(X) == len(m) else np.zeros(len(X), bool))
            n2i += int(bad.sum())
    report.append("r8 trunk check: %d trunk pieces without a crown dropped (%d faces)" % (n2i, n2))
    # speckle: leaf cards with no trunk top within 10 m
    wood = np.zeros(shape, "i4")
    if tops:
        T_ = np.array(tops)
        np.add.at(wood, rc(T_[:, 0], T_[:, 1]), 1)
    for o in bpy.data.objects:
        if o.type == "MESH" and (o.name.startswith("palm") or ("trunk" in o.name and "palm" in o.name)):
            c = np.empty(len(o.data.vertices) * 3, "f4")
            o.data.vertices.foreach_get("co", c)
            c = c.reshape(-1, 3)
            if len(c):
                np.add.at(wood, rc(c[:, 0], c[:, 1]), 1)
    ws = np.pad(wood, ((1, 0), (1, 0))).cumsum(0).cumsum(1)
    def wood_near(X, Y, k=10):
        r_, c_ = rc(X, Y)
        r0, r1 = np.clip(r_ - k, 0, shape[0]), np.clip(r_ + k + 1, 0, shape[0])
        c0, c1 = np.clip(c_ - k, 0, shape[1]), np.clip(c_ + k + 1, 0, shape[1])
        return (ws[r1, c1] - ws[r0, c1] - ws[r1, c0] + ws[r0, c0]) > 0
    n3 = sum(drop_where(o, lambda X, Y, Z: (X < 370) & ~wood_near(X, Y)) for o in leaf_obs)
    report.append("r8 speckle check: %d leaf faces with no trunk within 10 m dropped" % n3)


def ann_2018_brick(report):
    """r7 (critics + spire_ann_st_2018 photo): the white box at the left of that view is OSM 236155563 as one
    block. The photo shows a tall red-brick building nearest the camera and the white "lawler" building further
    down Ann St. Rays from the camera: the near part is x > 121 m. Its faces get a red-brick material."""
    import numpy as np
    k = 0
    for nm in ("bldg_look_236155563_walls", "bldg_look_236155563_ground"):
        ob = bpy.data.objects.get(nm)
        if ob is None or ob.type != "MESH" or not ob.data.materials:
            continue
        src = ob.data.materials[0]                                  # a copy of the facade material (keeps the windows)
        brick = bpy.data.materials.get(src.name.replace("236155563", "2361555630"))
        if brick is None:
            brick = src.copy()
            brick.name = src.name.replace("236155563", "2361555630")
        brick.diffuse_color = (*hx(P("ann_brick_hex", "AE8658")), 1)
        import bmesh
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        x0 = P("ann_brick_x", 121.0) - ob.matrix_world.translation.x
        bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(x0, 0, 0), plane_no=(1, 0, 0))
        bm.to_mesh(ob.data)
        bm.free()
        me = ob.data
        if brick.name not in [m.name for m in me.materials if m]:
            me.materials.append(brick)
        slot = [m.name if m else "" for m in me.materials].index(brick.name)
        cen = np.empty(len(me.polygons) * 3, "f4")
        me.polygons.foreach_get("center", cen)
        cen = cen.reshape(-1, 3)
        mi = np.empty(len(me.polygons), "i4")
        me.polygons.foreach_get("material_index", mi)
        near = cen[:, 0] > P("ann_brick_x", 121.0)
        mi[near] = slot
        me.polygons.foreach_set("material_index", mi)
        me.update()
        k += int(near.sum())
    report.append("Ann St 2018 view: near part of OSM 236155563 in red brick (%d faces), the far part stays white" % k)


def smooth_surfaces(report):
    """r4 (critic: hard tone edges cut streets in half): smooth shading on the crowned road and the draped car
    park / drive surfaces, so their triangles do not show as flat tone patches."""
    n = 0
    for ob in bpy.data.objects:
        if ob.type == "MESH" and (ob.name in ("roads", "car_parks", "kerb_gutter") or ob.name.startswith(("area_carpark_asphalt", "area_forecourt_drive"))):
            ob.data.polygons.foreach_set("use_smooth", [True] * len(ob.data.polygons))
            n += 1
    report.append("smooth shading on %d road / car-park surfaces" % n)


def round_poles(col, guard, objs, report):
    """r3 (critic): street light / sign poles were square slabs: every tall thin box in street_poles becomes a
    round tapered galvanised pole at the same spot (outside the Spire keep-out zone)."""
    import numpy as np
    import trees as T
    ob = bpy.data.objects.get("street_poles")
    if ob is None or len(ob.data.vertices) % 8:
        return
    me = ob.data
    co = np.empty(len(me.vertices) * 3, "f4")
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 8, 3)
    lo, hi = co.min(1), co.max(1)
    w = np.maximum(hi[:, 0] - lo[:, 0], hi[:, 1] - lo[:, 1])
    h = hi[:, 2] - lo[:, 2]
    cx, cy = (lo[:, 0] + hi[:, 0]) / 2, (lo[:, 1] + hi[:, 1]) / 2
    pick = (h > 3.0) & (w < 0.6) & np.array([not guard.keepout(x, y, 1.0) for x, y in zip(cx, cy)])
    if not pick.any():
        return
    tubes = C.MeshBuf()
    for i in np.nonzero(pick)[0]:
        r = max(0.06, min(0.16, w[i] * 0.55))
        T.tube(tubes, (float(cx[i]), float(cy[i]), float(lo[i, 2])), (float(cx[i]), float(cy[i]), float(hi[i, 2])), r, r * 0.6, 12)
    keep = ~pick
    newv = co[keep].reshape(-1, 3)
    nb = int(keep.sum())
    faces = []
    for k in range(nb):
        o = 8 * k
        faces += [[o + 3, o + 2, o + 1, o + 0], [o + 4, o + 5, o + 6, o + 7]] + [[o + i, o + (i + 1) % 4, o + 4 + (i + 1) % 4, o + 4 + i] for i in range(4)]
    m0 = me.materials[0] if me.materials else None
    me.clear_geometry()
    me.from_pydata([tuple(v) for v in newv], [], faces)
    me.update()
    ob2 = tubes.object("area_street_poles_round", col, "pole")
    if ob2 and m0:
        ob2.data.materials[0] = m0
        for p in ob2.data.polygons:
            p.use_smooth = True
        objs.append(ob2.name)
    report.append("street poles: %d square poles replaced by round tapered ones" % int(pick.sum()))


CUSTOMS_OSM = 26253545


def customs_house(col, guard, objs, report):
    """r2 (critic + Commons photos from the river): Corinthian colonnade of 6 columns with entablature and
    pediment on the river front, the copper dome above it in verdigris green."""
    import trees as T
    o = L.osm()
    w = o["ways"].get(CUSTOMS_OSM)
    m = bpy.data.materials.get("look_%d_accent" % CUSTOMS_OSM)
    if m:
        m.diffuse_color = (0.09, 0.20, 0.15, 1)
    if not w:
        return
    ring = S.ccw(C.clean_ring(o["line"](w)))
    cx = sum(p[0] for p in ring) / len(ring)
    cy = sum(p[1] for p in ring) / len(ring)
    tx, ty = 80.0 - cx, -310.0 - cy                                 # towards the river
    tl = math.hypot(tx, ty)
    best = None
    for a, b in zip(ring, ring[1:] + ring[:1]):
        ln = math.dist(a, b)
        nx, ny = (b[1] - a[1]) / ln, -(b[0] - a[0]) / ln             # outward (ccw ring)
        score = (nx * tx + ny * ty) / tl * ln
        if best is None or score > best[0]:
            best = (score, a, b, nx, ny, ln)
    _, a, b, nx, ny, ln = best
    ux, uy = (b[0] - a[0]) / ln, (b[1] - a[1]) / ln
    mx, my = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
    g = min(gz(*a), gz(*b))
    cols_, stone = C.MeshBuf(), C.MeshBuf()
    span = min(ln * 0.55, 16.0)
    H, R = 9.5, 0.45
    for i in range(6):
        u = -span / 2 + span * i / 5
        px, py = mx + ux * u + nx * 2.2, my + uy * u + ny * 2.2
        T.tube(cols_, (px, py, g + 1.0), (px, py, g + 1.0 + H), R, R * 0.86, 14)
        cols_.box(px, py, g + 0.4, 1.2, 1.2, 0.6, math.atan2(uy, ux))             # base
        cols_.box(px, py, g + 1.0 + H - 0.1, 1.15, 1.15, 0.7, math.atan2(uy, ux))  # capital block
    e = math.atan2(uy, ux)
    ex, ey = mx + nx * 1.6, my + ny * 1.6
    stone.box(ex, ey, g - 0.2, span + 2.4, 4.0, 1.2, e)                          # podium / steps
    stone.box(ex, ey, g + 1.0 + H + 0.6, span + 2.0, 3.6, 1.4, e)               # entablature
    zp = g + 1.0 + H + 2.0
    l2 = (span + 2.0) / 2
    tri = [(ex - ux * l2 + nx * 1.8, ey - uy * l2 + ny * 1.8, zp), (ex + ux * l2 + nx * 1.8, ey + uy * l2 + ny * 1.8, zp),
           (ex + nx * 1.8, ey + ny * 1.8, zp + 2.6),
           (ex - ux * l2 - nx * 1.8, ey - uy * l2 - ny * 1.8, zp), (ex + ux * l2 - nx * 1.8, ey + uy * l2 - ny * 1.8, zp),
           (ex - nx * 1.8, ey - ny * 1.8, zp + 2.6)]
    stone.add(tri, [[0, 1, 2], [5, 4, 3], [0, 2, 5, 3], [1, 4, 5, 2], [0, 3, 4, 1]])  # pediment
    if not guard.ok(mx + nx * 2.2, my + ny * 2.2):
        report.append("Customs House portico off: keep-out or road")
        return
    note(mx + nx * 2.2, my + ny * 2.2, "building")
    wall = bpy.data.materials.get("look_%d_wall" % CUSTOMS_OSM)
    ston = mat("customs_sandstone", tuple(wall.diffuse_color)[:3] if wall else (0.62, 0.52, 0.36))
    put(cols_, "customs_columns", col, ston, objs)
    put(stone, "customs_portico", col, ston, objs)
    report.append("Customs House: 6-column portico + pediment on the river front, copper dome green")


# ---------------------------------------------------------------------------------------------- self-check
# John, 16 Nov 2026 03:00 UTC, in the project thread: "Yes, PC may add the Orient and Ann/Queen exception to the
# Spire area build, render only." Named exceptions only: anything else in the keep-out zone still fails the build,
# nothing may be on the Spire lot or within 1 m of it, and area_hero is skipped for the game export (game_l6).
AREA_ZONE_EXCEPTIONS = {"orient", "annqueen_signals"}       # "annqueen_marks": not used yet


_SITE = {}


def near_lot(guard, x, y, m):
    """On the Spire lot, within m of its line, or within 1 m of any Spire site object (hoarding, gate, gantry,
    truck bay, cones, crane, booms, hoist, sheds: collections spire / core / logistics / site_plant)."""
    lot = guard.lot
    if S.point_in(x, y, lot) or min(seg_dist(x, y, a, b) for a, b in zip(lot, lot[1:] + lot[:1])) < m:
        return True
    if "kd" not in _SITE:
        import numpy as np
        from mathutils import kdtree
        pts = []
        for cname in ("spire", "core", "logistics", "site_plant"):
            colx = bpy.data.collections.get(cname)
            for o in (colx.all_objects if colx else []):
                if o.type == "MESH":
                    co = np.empty(len(o.data.vertices) * 3, "f4")
                    o.data.vertices.foreach_get("co", co)
                    pts.append(co.reshape(-1, 3)[:, :2])
        P2 = np.concatenate(pts) if pts else np.zeros((0, 2), "f4")
        kd = kdtree.KDTree(len(P2))
        for i, p in enumerate(P2):
            kd.insert((float(p[0]), float(p[1]), 0.0), i)
        kd.balance()
        _SITE["kd"] = kd
        _SITE["n"] = len(P2)
    if _SITE["n"] == 0:
        return False
    return _SITE["kd"].find((x, y, 0.0))[2] < 1.0


def self_check(guard, report):
    bad_zone = [(round(x, 1), round(y, 1), k) for x, y, k in NEW
                if guard.keepout(x, y) and (k not in AREA_ZONE_EXCEPTIONS or near_lot(guard, x, y, 1.0))]
    bad_road = [(round(x, 1), round(y, 1), k) for x, y, k in NEW if k not in ("roadmark",) and guard.on_road(x, y)]
    if bad_zone or bad_road:
        raise RuntimeError("area_hero self-check failed: in the Spire keep-out zone %s; on a carriageway %s"
                           % (bad_zone[:10], bad_road[:10]))
    exc = {}
    for x, y, k in NEW:
        if k in AREA_ZONE_EXCEPTIONS and guard.keepout(x, y):
            exc[k] = exc.get(k, 0) + 1
    report.append("self-check: %d new pieces; in the keep-out zone only the named exceptions %s (none on the lot or "
                  "within 1 m of it); none on a carriageway" % (len(NEW), exc or "{}"))


ORIENT_OSM = 186586595


def orient(col, guard, objs, report):
    """Exception "orient" (render only, John 16 Nov): the Orient Hotel's two-level verandah on its two street
    fronts (cast-iron posts, upper deck with a white lace balustrade, corrugated awning roof) and HOTEL ORIENT
    lettering. Posts on the footpath, never on the road, never within 3 m of the Spire lot."""
    import trees as T
    o = L.osm()
    w = o["ways"].get(ORIENT_OSM)
    if not w:
        return
    ring = S.ccw(C.clean_ring(o["line"](w)))
    cx = sum(p[0] for p in ring) / len(ring)
    cy = sum(p[1] for p in ring) / len(ring)
    posts, deck, lace, roof = C.MeshBuf(), C.MeshBuf(), C.MeshBuf(), C.MeshBuf()
    n, best = 0, None
    for a, b in zip(ring, ring[1:] + ring[:1]):
        ln = math.dist(a, b)
        if ln < 6.0:
            continue
        ux, uy = (b[0] - a[0]) / ln, (b[1] - a[1]) / ln
        nx, ny = uy, -ux
        if ((a[0] + b[0]) / 2 - cx) * nx + ((a[1] + b[1]) / 2 - cy) * ny < 0:
            nx, ny = -nx, -ny
        mx, my = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
        if near_lot(guard, mx + nx * 2.6, my + ny * 2.6, 3.0) or \
                not any(guard.on_road(mx + nx * d, my + ny * d) for d in (5.0, 7.0, 9.0)):
            continue                                                # street fronts only, not the side on the lot
        if best is None or ln > best[0]:
            best = (ln, a, b, ux, uy, nx, ny)
        g = min(gz(*a), gz(*b))
        k = max(1, int(ln / 3.2))
        run = []
        for i in range(k + 1):
            x = a[0] + (b[0] - a[0]) * i / k + nx * 2.6
            y = a[1] + (b[1] - a[1]) * i / k + ny * 2.6
            if near_lot(guard, x, y, 3.0) or guard.on_road(x, y):
                continue
            # r7: the orient_front photo (2026) shows cantilevered awnings: no posts on the footpath
            note(x, y, "orient")
            run.append((x, y))
            n += 1
        if len(run) < 2:
            continue
        p0, p1 = run[0], run[-1]
        f0, f1 = (p0[0] - nx * 2.6, p0[1] - ny * 2.6), (p1[0] - nx * 2.6, p1[1] - ny * 2.6)
        e0, e1 = (p0[0] + nx * 0.15, p0[1] + ny * 0.15), (p1[0] + nx * 0.15, p1[1] + ny * 0.15)
        # r7: two cantilevered hoods from the photo: the shop awning (2.6 m out, deep fascia) and a slim hood
        # over the first floor (0.9 m out) with the HOTEL ORIENT letters on the wall above it
        for zd, out_, th in ((g + 3.6, 1.0, 0.45), (g + 7.0, 0.55, 0.3)):     # r8: the first-floor hood is deep (photo)
            e0_ = (f0[0] + (p0[0] - f0[0]) * out_ + nx * 0.15 * out_, f0[1] + (p0[1] - f0[1]) * out_ + ny * 0.15 * out_)
            e1_ = (f1[0] + (p1[0] - f1[0]) * out_ + nx * 0.15 * out_, f1[1] + (p1[1] - f1[1]) * out_ + ny * 0.15 * out_)
            deck.add([(*f0, zd), (*f1, zd), (*e1_, zd), (*e0_, zd), (*f0, zd + th), (*f1, zd + th), (*e1_, zd + th), (*e0_, zd + th)],
                     [[3, 2, 1, 0], [4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]])
    if best:
        ln, a, b, ux, uy, nx, ny = best                              # HOTEL ORIENT on the longest street front
        mx, my = (a[0] + b[0]) / 2 + nx * 0.12, (a[1] + b[1]) / 2 + ny * 0.12
        C.text_obj(col, "area_orient_lettering", "HOTEL ORIENT", (mx, my, gz(mx, my) + 7.35),
                   (math.pi / 2, 0, math.atan2(nx, -ny)), 0.6, (0.55, 0.50, 0.36))   # r7: raised letters in the render
        note(mx, my, "orient")
    # r8 (orient_front photo, 3 critics): no crenellated parapet; a dark projecting cornice and a hipped
    # corrugated roof (#4A4C4E) over the whole footprint, round the curved corner
    import numpy as np
    import buildings as B
    acc = bpy.data.objects.get("bldg_look_%d_accent" % ORIENT_OSM)
    k_acc = drop_where(acc, lambda X, Y, Z: np.ones(len(X), bool)) if acc is not None else 0
    wl = bpy.data.objects.get("bldg_look_%d_walls" % ORIENT_OSM)
    if wl is not None and wl.data.vertices:
        zt = max((wl.matrix_world @ v.co).z for v in wl.data.vertices)
        cor, hip = C.MeshBuf(), C.MeshBuf()
        out_r = B.offset(ring, 0.55)
        cor.prism(out_r, zt - 0.45, zt)
        inner = B.offset(ring, -P("orient_hip_in", 3.0))          # r10: r9 read as a thin visor: ~32 deg
        zr = zt + P("orient_hip_rise", 1.9)
        nr = len(out_r)
        if len(inner) == nr:
            vs = [(x, y, zt) for x, y in out_r] + [(x, y, zr) for x, y in inner]
            fs = [[i, (i + 1) % nr, nr + (i + 1) % nr, nr + i] for i in range(nr)] + [list(range(nr, 2 * nr))]
            hip.add(vs, fs)
        put(cor, "orient_cornice", col, mat("orient_cornice", hx("6B6458")), objs)
        put(hip, "orient_hip_roof", col, mat("orient_hip_roof", hx("4A4C4E")), objs)
        report.append("Orient: crenellations dropped (%d faces), cornice + hipped roof at %.1f-%.1f m" % (k_acc, zt, zr))
    rm = bpy.data.materials.get("look_%d_roof" % ORIENT_OSM)              # r7: dark tin roof (photo)
    if rm is not None:
        rm.diffuse_color = (*hx("4A4D4F"), 1)
    put(deck, "orient_verandah_deck", col, mat("orient_deck", (0.29, 0.29, 0.27)), objs)
    put(lace, "orient_verandah_lace", col, mat("orient_lace", (0.82, 0.82, 0.78)), objs)
    put(roof, "orient_verandah_roof", col, mat("orient_roof", (0.20, 0.27, 0.25)), objs)
    report.append("Orient Hotel (exception, render only): cantilevered shop awning + first-floor hood (%d bays), HOTEL ORIENT" % n)


def annqueen_poles(col, guard, objs, report):
    """Exception "annqueen_signals" (render only): the square signal / light poles left in the keep-out strip at
    Ann/Queen become round tapered galvanised poles too, except within 1.5 m of the Spire lot (work zone)."""
    import numpy as np
    import trees as T
    ob = bpy.data.objects.get("street_poles")
    if ob is None or len(ob.data.vertices) % 8:
        return
    me = ob.data
    co = np.empty(len(me.vertices) * 3, "f4")
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 8, 3)
    lo, hi = co.min(1), co.max(1)
    w = np.maximum(hi[:, 0] - lo[:, 0], hi[:, 1] - lo[:, 1])
    h = hi[:, 2] - lo[:, 2]
    cx, cy = (lo[:, 0] + hi[:, 0]) / 2, (lo[:, 1] + hi[:, 1]) / 2
    pick = (h > 3.0) & (w < 0.6) & np.array([guard.keepout(x, y) and not near_lot(guard, x, y, 1.5) for x, y in zip(cx, cy)])
    if not pick.any():
        report.append("Ann/Queen: no square poles to replace")
        return
    tubes = C.MeshBuf()
    for i in np.nonzero(pick)[0]:
        r = max(0.06, min(0.16, w[i] * 0.55))
        T.tube(tubes, (float(cx[i]), float(cy[i]), float(lo[i, 2])), (float(cx[i]), float(cy[i]), float(hi[i, 2])), r, r * 0.6, 12)
        note(float(cx[i]), float(cy[i]), "annqueen_signals")
    keep = ~pick
    newv = co[keep].reshape(-1, 3)
    faces = []
    for k in range(int(keep.sum())):
        o = 8 * k
        faces += [[o + 3, o + 2, o + 1, o + 0], [o + 4, o + 5, o + 6, o + 7]] + [[o + i, o + (i + 1) % 4, o + 4 + (i + 1) % 4, o + 4 + i] for i in range(4)]
    m0 = me.materials[0] if me.materials else None
    me.clear_geometry()
    me.from_pydata([tuple(v) for v in newv], [], faces)
    me.update()
    ob2 = tubes.object("area_annqueen_poles_round", col, "pole")
    if ob2 and m0:
        ob2.data.materials[0] = m0
        objs.append(ob2.name)
    report.append("Ann/Queen (exception, render only): %d square poles replaced by round tapered ones" % int(pick.sum()))


def build():
    NEW.clear()
    _STATE.clear()
    _SITE.clear()
    if L.ACTIVE_STAGE is not None and L.ACTIVE_STAGE is L.STAGES.get("game_l6"):
        return {"module": "area_hero", "objects": [], "note": "render-only: skipped for the game export"}
    col = C.collection("area_hero")
    guard = Guard()
    objs, report = [], []
    neighbours(col, guard, objs, report)
    nb = 0
    for ob in bpy.data.objects:                       # "BUS C": half the words sank under the crowned red lane
        if ob.name.startswith("busonly") and not guard.keepout(ob.location.x, ob.location.y):
            ob.location.z += 0.035                    # r2: flat paint decal (no extrusion), just above the crown
            ob.rotation_euler.y = 0.0
            # r6: the r3 180 deg flip is undone: cameras facing along the one-way (SW) traffic read it upside-down
            # (annqueen 215 deg, annstcath 229, church_house_webber 188, carpark_raised 239): streetscape.py had it right
            if ob.type == "FONT":
                ob.data.extrude = 0.0
            nb += 1
    report.append("BUS ONLY words lifted and levelled (orientation as streetscape.py): %d" % nb)
    carparks(col, guard, objs, report)
    forecourt(col, guard, objs, report)
    roads(col, guard, objs, report)
    signs(col, guard, objs, report)
    customs_house(col, guard, objs, report)
    smooth_ground(report)
    round_poles(col, guard, objs, report)
    bpy.context.view_layer.update()
    roof_plant(col, guard, objs, report)
    floating_masts(report)
    deanery_bank(col, guard, objs, report)
    round6(guard, report)
    ray_boxes(report)
    ann_2018_brick(report)
    orphan_crowns(report)
    low_leaves_on_road(guard, report)
    pixel_kill(guard, report)
    frustum_kill(guard, report)
    round8_trees(guard, report)
    smooth_surfaces(report)
    orient(col, guard, objs, report)
    annqueen_poles(col, guard, objs, report)
    pb = bpy.data.objects.get("street_banners_p")                  # r10 (critics): the pink banners are invented
    if pb is not None:
        bpy.data.objects.remove(pb)
        report.append("pink street banners removed")
    tb = bpy.data.materials.get("street_target_boards")           # r7: photos (orient_front, ann_queen_corner): black
    if tb is not None:                                              # lantern backs, no yellow boards; heads read smaller
        tb.diffuse_color = (*hx("1E1F21"), 1)
        report.append("signal target boards: black (photos), not yellow")
    self_check(guard, report)
    for r in report:
        print("  area_hero:", r)
    return {"module": "area_hero", "objects": objs, "report": report}


# ---------------------------------------------------------------------------------------------- look
_STATE = {}


def restyle():
    """Once per scene, after preview.setup_morning: the area's material fixes (critic round 0)."""
    if _STATE.get("styled"):
        return
    _STATE["styled"] = True
    dusk_nodes = []
    for m in bpy.data.materials:
        if not m.use_nodes or m.node_tree is None:
            continue
        nt = m.node_tree
        bsdf = nt.nodes.get("Principled BSDF")
        if bsdf is None:
            continue
        if m.name == "clay_grass":                                  # r10 (critics: lawns near-black): #4f7a35-#6b8f45
            lk = next((l for l in nt.links if l.to_socket == bsdf.inputs["Base Color"]), None)
            if lk is not None and lk.from_node.bl_idname == "ShaderNodeValToRGB":
                el = lk.from_node.color_ramp.elements
                el[0].color = (*lin(P("lawn_lo", "4F7A35")), 1)
                el[-1].color = (*lin(P("lawn_hi", "6B8F45")), 1)
        if m.get("asphalt") or m.name in ("clay_road",):
            asphalt(m, bsdf)
        if m.name in ("clay_road", "street_red") or m.get("asphalt"):
            flat_up(nt, bsdf)
        if m.name == "area_road_patch":
            soft_edges(m, nt, bsdf)
        if m.name in ("clay_footpath", "clay_footway"):
            br = next((n for n in nt.nodes if n.bl_idname == "ShaderNodeTexBrick"), None)
            if br is not None:                                           # warm grey concrete, not cold pavers
                c0 = P("footpath_rgb", (0.40, 0.375, 0.34))
                br.inputs["Color1"].default_value = (*c0, 1)
                br.inputs["Color2"].default_value = (c0[0] * 0.93, c0[1] * 0.93, c0[2] * 0.92, 1)
        if m.get("shader") == "leaf":                                    # smaller leaves: more cells per card
            for n in nt.nodes:
                if n.bl_idname == "ShaderNodeTexVoronoi":
                    n.inputs["Scale"].default_value = P("leaf_cells", 7.0)
                if n.bl_idname == "ShaderNodeMix" and n.data_type == "RGBA":   # r3: warmer greens, less teal
                    for k_ in (6, 7):
                        if not n.inputs[k_].is_linked:
                            c_ = n.inputs[k_].default_value
                            if n.blend_type == "MULTIPLY":
                                n.inputs[k_].default_value = (0.52, 0.47, 0.33, 1)
                            else:
                                n.inputs[k_].default_value = (c_[0] * 1.25 + 0.01, c_[1] * 1.05, c_[2] * 0.65, 1)
        if m.get("shader") == "canopy":                                  # far crowns: warmer olive
            for n in nt.nodes:
                if n.bl_idname == "ShaderNodeValToRGB":
                    for e_ in n.color_ramp.elements:
                        c_ = e_.color
                        e_.color = (c_[0] * 1.3 + 0.005, c_[1] * 1.05, c_[2] * 0.6, 1)
        if m.name == "street_red":                                       # r3: bus lane #A8433A with wear
            wear(nt, bsdf, lin("8F3A2E"), 0.12)                    # r4: deeper brick red
        if m.name == "area_carpark_lines":
            bsdf.inputs["Base Color"].default_value = (*lin("D8D6C8"), 1)
        if m.name == "cathedral_leadlight":
            leading(nt, bsdf)
        if m.name in ("tree_trunks", "area_bark") or m.name.startswith("tree_trunks"):
            if m.name != "tree_trunks_eucalypt":
                bsdf.inputs["Base Color"].default_value = (*P("bark_rgb", (0.105, 0.069, 0.045)), 1)
        if m.get("lamp"):
            bsdf.inputs["Emission Color"].default_value = (1.0, 0.78, 0.5, 1)
            v = nt.nodes.new("ShaderNodeValue")
            v.name = "AREA_DUSK"
            v.outputs[0].default_value = 0.0
            mul = nt.nodes.new("ShaderNodeMath")
            mul.operation = "MULTIPLY"
            mul.inputs[1].default_value = 40.0
            nt.links.new(v.outputs[0], mul.inputs[0])
            nt.links.new(mul.outputs[0], bsdf.inputs["Emission Strength"])
            dusk_nodes.append(v)
        if m.get("win_bay") or m.name.startswith("bldg_") or "_wall" in m.name:
            v = lit_windows(m, nt, bsdf)
            if v is not None:
                dusk_nodes.append(v)
            window_frames(m, nt, bsdf)
        if m.name.endswith("_roof") and m.name.startswith(("look_", "gen_")):
            roof_tones(nt, bsdf)
        if m.name == "cathedral_terracotta":
            tile_courses(nt, bsdf)
        if m.get("diag"):
            diag_stripes(nt, bsdf)
        if m.name == "cathedral_spire_slate":
            bsdf.inputs["Base Color"].default_value = (*lin("2E2E33"), 1)
            slate_scales(nt, bsdf)                                        # r13: fine fish-scale slates
        elif m.name == "cathedral_slate":
            tile_courses(nt, bsdf, course=0.22, dark=0.7)
        if m.name == "cathedral_slate" and not bsdf.inputs["Base Color"].is_linked:
            bsdf.inputs["Base Color"].default_value = (*lin("3C3C42"), 1)   # r12: crossing tower roof read pale grey
        if m.name == "cathedral_spire_slate" and not bsdf.inputs["Base Color"].is_linked:
            bsdf.inputs["Base Color"].default_value = (*lin("2E2E33"), 1)   # r11: near-black, not brown-grey
        if m.name == "cathedral_sandstone":                          # r11: matt sandstone, not lemon plastic
            bsdf.inputs["Roughness"].default_value = 0.8
            if not bsdf.inputs["Base Color"].is_linked:
                bsdf.inputs["Base Color"].default_value = (*lin("D6C296"), 1)   # r13: 30 % less yellow
        if m.name == "cathedral_tuff_ashlar" and not m.get("r11_joints"):
            m["r11_joints"] = True                                    # r11: dark recessed joints that shadow
            for n_ in nt.nodes:
                if n_.bl_idname == "ShaderNodeMix" and n_.data_type == "RGBA" and not n_.inputs[7].is_linked and \
                        abs(n_.inputs[7].default_value[0] - 0.62) < 0.01:
                    n_.inputs[7].default_value = (*lin("4A4440"), 1)
                if n_.bl_idname == "ShaderNodeBump":
                    n_.inputs["Strength"].default_value = 0.8
            bsdf.inputs["Roughness"].default_value = 0.85
    for name in ("street_heads", "street_lanterns"):                     # street lamps at dusk
        ob = bpy.data.objects.get(name)
        if ob and name == "street_heads" and ob.data.materials:
            m = ob.data.materials[0]
            if m.use_nodes and not m.node_tree.nodes.get("AREA_DUSK"):
                b = m.node_tree.nodes.get("Principled BSDF")
                if b:
                    b.inputs["Emission Color"].default_value = (1.0, 0.75, 0.45, 1)
                    v = m.node_tree.nodes.new("ShaderNodeValue")
                    v.name = "AREA_DUSK"
                    mul = m.node_tree.nodes.new("ShaderNodeMath")
                    mul.operation = "MULTIPLY"
                    mul.inputs[1].default_value = 25.0
                    m.node_tree.links.new(v.outputs[0], mul.inputs[0])
                    m.node_tree.links.new(mul.outputs[0], b.inputs["Emission Strength"])
                    dusk_nodes.append(v)
    _STATE["dusk"] = dusk_nodes


def window_frames(m, nt, bsdf):
    """r4 (critic: frameless windows): a 60 mm aluminium frame round every window of the facade grid and a
    centre mullion in windows wider than 1.4 m. Grid numbers from the material (looks.PATTERNS / FACADES)."""
    import preview as PV
    spec = PV.FACADES.get(m.name) or ({k: m["win_" + k] for k in ("bay", "win", "sill", "head") if "win_" + k in m}
                                      if m.get("win_bay") else None)
    if not spec or not all(k in spec for k in ("bay", "win", "sill", "head")) or not bsdf.inputs["Base Color"].is_linked:
        return
    uv = next((n for n in nt.nodes if n.bl_idname == "ShaderNodeUVMap"), None)
    if uv is None:
        return
    bay, win = float(spec["bay"]), float(spec["win"])
    flo = float(m.get("win_floor", spec.get("floor", L.LEVEL_HEIGHT)))
    sill, head = float(spec["sill"]), float(spec["head"])
    fw = 0.06
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(uv.outputs["UV"], sep.inputs[0])

    def op(o_, a, b=None):
        n = nt.nodes.new("ShaderNodeMath")
        n.operation = o_
        for k, v in enumerate((a, b)):
            if v is None:
                continue
            if isinstance(v, (int, float)):
                n.inputs[k].default_value = v
            else:
                nt.links.new(v, n.inputs[k])
        return n.outputs[0]
    du = op("ABSOLUTE", op("SUBTRACT", op("FRACT", op("DIVIDE", sep.outputs["X"], bay)), 0.5))
    fv = op("FRACT", op("DIVIDE", sep.outputs["Y"], flo))
    half = win / bay / 2
    outer = op("MULTIPLY", op("LESS_THAN", du, half), op("MULTIPLY", op("GREATER_THAN", fv, sill), op("LESS_THAN", fv, head)))
    inner = op("MULTIPLY", op("LESS_THAN", du, half - fw / bay),
               op("MULTIPLY", op("GREATER_THAN", fv, sill + fw / flo), op("LESS_THAN", fv, head - fw / flo)))
    frame = op("SUBTRACT", outer, inner)
    if win > 1.4:
        frame = op("MAXIMUM", frame, op("MULTIPLY", inner, op("LESS_THAN", du, 0.03 / bay)))
    src = bsdf.inputs["Base Color"].links[0].from_socket
    mx = nt.nodes.new("ShaderNodeMix")
    mx.data_type = "RGBA"
    nt.links.new(frame, mx.inputs["Factor"])
    nt.links.new(src, mx.inputs[6])
    mx.inputs[7].default_value = (0.40, 0.41, 0.42, 1)
    nt.links.new(mx.outputs[2], bsdf.inputs["Base Color"])


def wear(nt, bsdf, rgb, amount):
    """Base colour with worn patches (lighter, greyer where tyres run) on world position."""
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    nz = nt.nodes.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = 0.45
    nz.inputs["Detail"].default_value = 5.0
    nt.links.new(geo.outputs["Position"], nz.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (*rgb, 1)
    ramp.color_ramp.elements[0].position = 0.45
    g = sum(rgb) / 3
    ramp.color_ramp.elements[1].color = (rgb[0] * (1 - amount) + g * amount + 0.03, rgb[1] * (1 - amount) + g * amount + 0.03,
                                         rgb[2] * (1 - amount) + g * amount + 0.03, 1)
    nt.links.new(nz.outputs["Fac"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.85


def leading(nt, bsdf):
    """r3: cathedral windows: dark leaded glass (lead cames on a 0.3 x 0.45 m grid, panes in deep tones)."""
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    br = nt.nodes.new("ShaderNodeTexBrick")
    nt.links.new(geo.outputs["Position"], br.inputs["Vector"])
    br.inputs["Scale"].default_value = 1.0
    br.inputs["Brick Width"].default_value = 0.3
    br.inputs["Row Height"].default_value = 0.45
    br.inputs["Mortar Size"].default_value = 0.025
    br.offset = 0.0
    br.inputs["Color1"].default_value = (*lin("1B222C"), 1)          # r14: read flat black: #1b222c, glossy
    br.inputs["Color2"].default_value = (*lin("232C38"), 1)
    br.inputs["Mortar"].default_value = (0.012, 0.012, 0.012, 1)
    nt.links.new(br.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.1
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.4
    nt.links.new(br.outputs["Fac"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])


def soft_edges(m, nt, bsdf):
    """r2: road patches fade out over their outer 20 % (UV 0..1), so they read as worn repairs, not tiles."""
    uv = nt.nodes.new("ShaderNodeUVMap")
    uv.uv_map = "facade"
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(uv.outputs["UV"], sep.inputs[0])
    edge = None
    for comp in ("X", "Y"):
        a = nt.nodes.new("ShaderNodeMath")
        a.operation = "SUBTRACT"
        a.inputs[0].default_value = 1.0
        nt.links.new(sep.outputs[comp], a.inputs[1])
        mn = nt.nodes.new("ShaderNodeMath")
        mn.operation = "MINIMUM"
        nt.links.new(sep.outputs[comp], mn.inputs[0])
        nt.links.new(a.outputs[0], mn.inputs[1])
        if edge is None:
            edge = mn.outputs[0]
        else:
            m2 = nt.nodes.new("ShaderNodeMath")
            m2.operation = "MINIMUM"
            nt.links.new(edge, m2.inputs[0])
            nt.links.new(mn.outputs[0], m2.inputs[1])
            edge = m2.outputs[0]
    mr = nt.nodes.new("ShaderNodeMapRange")
    nt.links.new(edge, mr.inputs["Value"])
    mr.inputs["From Min"].default_value = 0.0
    mr.inputs["From Max"].default_value = 0.4                     # r3: wider fade
    mr.inputs["To Max"].default_value = 0.6
    nt.links.new(mr.outputs["Result"], bsdf.inputs["Alpha"])
    try:
        m.surface_render_method = "DITHERED"
    except AttributeError:
        m.blend_method = "HASHED"


def diag_stripes(nt, bsdf):
    """r2: Soleil's white diagonal bands over the facade (UV: u metres round, v metres up)."""
    src = bsdf.inputs["Base Color"].links[0].from_socket if bsdf.inputs["Base Color"].is_linked else None
    uv = next((n for n in nt.nodes if n.bl_idname == "ShaderNodeUVMap"), None)
    if uv is None:
        return
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(uv.outputs["UV"], sep.inputs[0])
    add = nt.nodes.new("ShaderNodeMath")
    add.operation = "ADD"
    nt.links.new(sep.outputs["X"], add.inputs[0])
    nt.links.new(sep.outputs["Y"], add.inputs[1])
    div = nt.nodes.new("ShaderNodeMath")
    div.operation = "DIVIDE"
    nt.links.new(add.outputs[0], div.inputs[0])
    div.inputs[1].default_value = 22.0
    fr = nt.nodes.new("ShaderNodeMath")
    fr.operation = "FRACT"
    nt.links.new(div.outputs[0], fr.inputs[0])
    lt = nt.nodes.new("ShaderNodeMath")
    lt.operation = "LESS_THAN"
    nt.links.new(fr.outputs[0], lt.inputs[0])
    lt.inputs[1].default_value = 0.07
    mx = nt.nodes.new("ShaderNodeMix")
    mx.data_type = "RGBA"
    nt.links.new(lt.outputs[0], mx.inputs["Factor"])
    if src is not None:
        nt.links.new(src, mx.inputs[6])
    else:
        mx.inputs[6].default_value = bsdf.inputs["Base Color"].default_value
    mx.inputs[7].default_value = (0.86, 0.86, 0.84, 1)
    nt.links.new(mx.outputs[2], bsdf.inputs["Base Color"])


def roof_tones(nt, bsdf):
    """r2: flat roofs in mixed membrane tones (pale, mid and warm grey patches ~40 m across) with fine grime."""
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    big = nt.nodes.new("ShaderNodeTexNoise")
    big.inputs["Scale"].default_value = 0.045
    big.inputs["Detail"].default_value = 1.0
    nt.links.new(geo.outputs["Position"], big.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    el = ramp.color_ramp.elements
    el[0].position, el[0].color = 0.3, (0.15, 0.155, 0.16, 1)        # r3: wider spread of greys
    el[1].position, el[1].color = 0.7, (0.44, 0.43, 0.40, 1)
    e3 = el.new(0.5)
    e3.color = (0.27, 0.25, 0.22, 1)
    nt.links.new(big.outputs["Fac"], ramp.inputs["Fac"])
    fine = nt.nodes.new("ShaderNodeTexNoise")
    fine.inputs["Scale"].default_value = 1.5
    nt.links.new(geo.outputs["Position"], fine.inputs["Vector"])
    mx = nt.nodes.new("ShaderNodeMix")
    mx.data_type = "RGBA"
    mx.blend_type = "MULTIPLY"
    mx.inputs["Factor"].default_value = 0.35
    nt.links.new(ramp.outputs["Color"], mx.inputs[6])
    nt.links.new(fine.outputs["Color"], mx.inputs[7])
    nt.links.new(mx.outputs[2], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.9


def slate_scales(nt, bsdf):
    """r13 (critics): spires read as flat dark cones: fine fish-scale slates, rounded tails, staggered courses."""
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(geo.outputs["Position"], sep.inputs[0])
    ang = nt.nodes.new("ShaderNodeMath")                                # u round the cone in metres-ish
    ang.operation = "ADD"
    nt.links.new(sep.outputs["X"], ang.inputs[0])
    nt.links.new(sep.outputs["Y"], ang.inputs[1])
    cv = nt.nodes.new("ShaderNodeCombineXYZ")
    nt.links.new(ang.outputs[0], cv.inputs[0])
    nt.links.new(sep.outputs["Z"], cv.inputs[1])
    br = nt.nodes.new("ShaderNodeTexBrick")
    br.offset = 0.5
    br.offset_frequency = 2
    nt.links.new(cv.outputs[0], br.inputs["Vector"])
    br.inputs["Scale"].default_value = 1.0
    br.inputs["Brick Width"].default_value = 0.24
    br.inputs["Row Height"].default_value = 0.16
    br.inputs["Mortar Size"].default_value = 0.018
    br.inputs["Mortar Smooth"].default_value = 0.6
    br.inputs["Bias"].default_value = 0.0
    br.inputs["Color1"].default_value = (*lin("2E2E33"), 1)
    br.inputs["Color2"].default_value = (*lin("323237"), 1)   # r14: back to near-black #2e2e33, joints kept
    br.inputs["Mortar"].default_value = (*lin("17171A"), 1)
    nt.links.new(br.outputs["Color"], bsdf.inputs["Base Color"])
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.6
    nt.links.new(br.outputs["Fac"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    bsdf.inputs["Roughness"].default_value = 0.55


def tile_courses(nt, bsdf, course=0.28, dark=0.72):
    """r2: visible tile / slate courses (horizontal lines every course in world z) and tile-to-tile tone."""
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(geo.outputs["Position"], sep.inputs[0])
    dv = nt.nodes.new("ShaderNodeMath")
    dv.operation = "DIVIDE"
    nt.links.new(sep.outputs["Z"], dv.inputs[0])
    dv.inputs[1].default_value = course
    fr = nt.nodes.new("ShaderNodeMath")
    fr.operation = "FRACT"
    nt.links.new(dv.outputs[0], fr.inputs[0])
    lt = nt.nodes.new("ShaderNodeMath")
    lt.operation = "LESS_THAN"
    nt.links.new(fr.outputs[0], lt.inputs[0])
    lt.inputs[1].default_value = 0.18
    wn = nt.nodes.new("ShaderNodeTexNoise")
    wn.inputs["Scale"].default_value = 3.5
    nt.links.new(geo.outputs["Position"], wn.inputs["Vector"])
    base = tuple(bsdf.inputs["Base Color"].default_value)
    m1 = nt.nodes.new("ShaderNodeMix")
    m1.data_type = "RGBA"
    nt.links.new(wn.outputs["Fac"], m1.inputs["Factor"])
    m1.inputs[6].default_value = (base[0] * 0.85, base[1] * 0.85, base[2] * 0.85, 1)
    m1.inputs[7].default_value = (min(1, base[0] * 1.12), min(1, base[1] * 1.1), min(1, base[2] * 1.08), 1)
    m2 = nt.nodes.new("ShaderNodeMix")
    m2.data_type = "RGBA"
    m2.blend_type = "MULTIPLY"
    nt.links.new(lt.outputs[0], m2.inputs["Factor"])
    nt.links.new(m1.outputs[2], m2.inputs[6])
    m2.inputs[7].default_value = (dark, dark, dark, 1)
    nt.links.new(m2.outputs[2], bsdf.inputs["Base Color"])
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.3
    nt.links.new(lt.outputs[0], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])


def flat_up(nt, bsdf):
    """r8 probe (hero_ann_st_streetscape, 11:30): the stepped light/dark patch on Ann St is two families of road
    faces (overlapping ribbons of two OSM ways) tilted ~3 deg apart, both lit, no shadow: the r6 custom normals do
    not reach the render. The road shaders now shade with a world-up normal (through any bump), so every road face
    takes the same light whatever its tilt."""
    if nt.nodes.get("AREA_FLAT_UP"):
        return
    up = nt.nodes.new("ShaderNodeCombineXYZ")
    up.name = "AREA_FLAT_UP"
    up.inputs[2].default_value = 1.0
    lk = next((l for l in nt.links if l.to_socket == bsdf.inputs["Normal"]), None)
    if lk is not None and lk.from_node.bl_idname == "ShaderNodeBump":
        nt.links.new(up.outputs[0], lk.from_node.inputs["Normal"])
    else:
        nt.links.new(up.outputs[0], bsdf.inputs["Normal"])


def asphalt(m, bsdf):
    """Mid-grey worn asphalt (critic: too dark and blue): recolour the ramp / base, keep the speckle."""
    nt = m.node_tree
    lo, hi = P("asphalt_lo", (0.013, 0.013, 0.015)), P("asphalt_hi", (0.030, 0.030, 0.032))   # r14: streets still #666-#80 in sun; photos #3a3a40-#45484c
    if m.get("asphalt_lo"):
        lo, hi = tuple(m["asphalt_lo"]), tuple(m["asphalt_hi"])
    else:
        # r14: halving the albedo only moved the sunlit street #7b -> #6c: the rest is grazing-angle specular
        # sheen of the sky. Bitumen is matt: little specular, fully rough
        si = bsdf.inputs.get("Specular IOR Level") or bsdf.inputs.get("Specular")
        if si is not None:
            si.default_value = P("asphalt_spec", 0.12)
        bsdf.inputs["Roughness"].default_value = 0.97
    # r14: the first ramp in the tree is not always the one on Base Color (streets stayed #6c6964 while the
    # car park copy went dark): only reuse the ramp that actually feeds Base Color
    lk_ = next((l for l in nt.links if l.to_socket == bsdf.inputs["Base Color"]), None)
    ramp = lk_.from_node if lk_ is not None and lk_.from_node.bl_idname == "ShaderNodeValToRGB" else None
    if ramp is not None:
        ramp.color_ramp.elements[0].color = (*lo, 1)
        ramp.color_ramp.elements[1].color = (*hi, 1)
        return
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    nz = nt.nodes.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = 0.35
    nt.links.new(geo.outputs["Position"], nz.inputs["Vector"])
    sp = nt.nodes.new("ShaderNodeTexNoise")
    sp.inputs["Scale"].default_value = 45.0
    nt.links.new(geo.outputs["Position"], sp.inputs["Vector"])
    add = nt.nodes.new("ShaderNodeMath")
    add.operation = "MULTIPLY_ADD"
    nt.links.new(sp.outputs["Fac"], add.inputs[0])
    add.inputs[1].default_value = 0.5
    nt.links.new(nz.outputs["Fac"], add.inputs[2])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    base = tuple(m.diffuse_color)[:3]
    ramp.color_ramp.elements[0].color = (base[0] * 0.75, base[1] * 0.75, base[2] * 0.75, 1)
    ramp.color_ramp.elements[1].color = (min(1, base[0] * 1.35), min(1, base[1] * 1.35), min(1, base[2] * 1.35), 1)
    ramp.color_ramp.elements[0].color = (*lo, 1)
    ramp.color_ramp.elements[1].color = (*hi, 1)
    nt.links.new(add.outputs[0], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.92


def lit_windows(m, nt, bsdf):
    """Dusk: about half the windows lit warm. The window mask is the Mix whose Factor feeds from the grid."""
    mix = None
    for n in nt.nodes:
        if n.bl_idname == "ShaderNodeMix" and n.data_type == "RGBA" and n.inputs["Factor"].is_linked \
                and not n.inputs[7].is_linked and n.inputs[6].is_linked:
            src = n.inputs["Factor"].links[0].from_node
            if src.bl_idname == "ShaderNodeMath" and src.operation == "MULTIPLY":
                mix = n
                break
    if mix is None:
        return None
    mask = mix.inputs["Factor"].links[0].from_socket
    uv = next((n for n in nt.nodes if n.bl_idname == "ShaderNodeUVMap"), None)
    if uv is None:
        return None
    bay = float(m.get("win_bay", 3.0))
    flo = float(m.get("win_floor", L.LEVEL_HEIGHT))
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(uv.outputs["UV"], sep.inputs[0])

    def op(o_, a, b):
        n = nt.nodes.new("ShaderNodeMath")
        n.operation = o_
        for k, v in enumerate((a, b)):
            if v is None:
                continue
            if isinstance(v, (int, float)):
                n.inputs[k].default_value = v
            else:
                nt.links.new(v, n.inputs[k])
        return n.outputs[0]
    # r2: lit windows come in floor runs (a flat = 3-6 windows on one floor), ~15 % lit, 3 colour temperatures
    run = op("FLOOR", op("DIVIDE", op("DIVIDE", sep.outputs["X"], bay), P("window_run", 1.6)), None)
    cv = op("FLOOR", op("DIVIDE", sep.outputs["Y"], flo), None)
    comb = nt.nodes.new("ShaderNodeCombineXYZ")
    nt.links.new(run, comb.inputs[0])
    nt.links.new(cv, comb.inputs[1])
    wn = nt.nodes.new("ShaderNodeTexWhiteNoise")
    wn.noise_dimensions = "3D"
    nt.links.new(comb.outputs[0], wn.inputs["Vector"])
    sepc = nt.nodes.new("ShaderNodeSeparateColor")                      # two independent randoms per run
    nt.links.new(wn.outputs["Color"], sepc.inputs[0])
    on = op("GREATER_THAN", wn.outputs["Value"], P("window_off", 0.865))
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.interpolation = "CONSTANT"
    el = ramp.color_ramp.elements
    el[0].position, el[0].color = 0.0, (1.0, 0.66, 0.36, 1)            # warm incandescent
    el[1].position, el[1].color = 0.45, (1.0, 0.76, 0.50, 1)           # r4: warm, no white
    e3 = el.new(0.8)
    e3.color = (1.0, 0.78, 0.52, 1)                                     # r3: warm only (no cold white blocks)
    nt.links.new(sepc.outputs[0], ramp.inputs["Fac"])
    v = nt.nodes.new("ShaderNodeValue")
    v.name = "AREA_DUSK"
    v.outputs[0].default_value = 0.0
    dim = op("MULTIPLY_ADD", sepc.outputs[1], 0.6)                       # brightness 0.4-1.0 per run
    nt.nodes[dim.node.name].inputs[2].default_value = 0.4
    strength = op("MULTIPLY", op("MULTIPLY", op("MULTIPLY", op("MULTIPLY", mask, on), v.outputs[0]), dim), P("window_gain", 0.8))
    nt.links.new(ramp.outputs["Color"], bsdf.inputs["Emission Color"])
    nt.links.new(strength, bsdf.inputs["Emission Strength"])
    return v


SKY_DAY = [(0.0, "DCE6EE"), (0.07, "C4D8EA"), (0.25, "8FB5DE"), (1.0, "2F6FC0")]   # r3: pale horizon band
SKY_MODE = None    # r8: per view (area_cams.json "sky"): "deep" clear blue or "pale" grey-white, matched to its photo
SKY_DEEP = [(0.0, "B6D0EC"), (0.12, "8FB8E0"), (0.42, "4F86C8"), (1.0, "1F5FB0")]   # r10: a real gradient
SKY_NAVY = [(0.0, "A4C0E2"), (0.12, "7AA2D6"), (0.42, "3466B4"), (1.0, "1A3F8F")]
SKY_PALEBLUE = [(0.0, "EEF1F3"), (0.15, "D8E2EC"), (0.45, "B4C8DE"), (1.0, "8AA8CE")]
SKY_PALEDUSK = [(0.0, "B4C0D6"), (0.3, "9EAECA"), (0.6, "8496BA"), (1.0, "6E84AA")]   # r14: measured from the photo: #b1bdd3 low -> #798dae top (r13 read neutral #c0c8d2)
SKY_PALE = [(0.0, "E2E5E8"), (0.10, "D3DAE2"), (0.35, "B9C6D4"), (1.0, "8FA8C8")]
SKY_DUSK = [(0.0, "E8A890"), (0.16, "E8A890"), (0.30, "9C7CA8"), (0.62, "6E73A0"), (1.0, "4E5C8E")]   # r5 PINNED: peach band #e8a890 under lilac #9c7ca8


def lin(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


def sky(dusk):
    """r2: the camera sees a painted gradient sky with a few soft cumulus; lighting still comes from the
    Nishita sky (Light Path 'Is Camera Ray' picks one or the other)."""
    w = bpy.context.scene.world
    nt = w.node_tree
    out = nt.nodes.get("World Output")
    bg = nt.nodes.get("Background")
    if not nt.nodes.get("AREA_SKY_MIX"):
        tc = nt.nodes.new("ShaderNodeTexCoord")
        sep = nt.nodes.new("ShaderNodeSeparateXYZ")
        nt.links.new(tc.outputs["Generated"], sep.inputs[0])
        cl = nt.nodes.new("ShaderNodeMath")
        cl.operation = "MAXIMUM"
        nt.links.new(sep.outputs["Z"], cl.inputs[0])
        cl.inputs[1].default_value = 0.0
        pw = nt.nodes.new("ShaderNodeMath")
        pw.operation = "POWER"
        nt.links.new(cl.outputs[0], pw.inputs[0])
        pw.inputs[1].default_value = 0.7
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        ramp.name = "AREA_SKY_RAMP"
        nt.links.new(pw.outputs[0], ramp.inputs["Fac"])
        # clouds: noise on the direction projected onto a cloud deck, only above ~5 deg, sparse
        dv = nt.nodes.new("ShaderNodeVectorMath")
        dv.operation = "DIVIDE"
        nt.links.new(tc.outputs["Generated"], dv.inputs[0])
        cz = nt.nodes.new("ShaderNodeCombineXYZ")
        mz = nt.nodes.new("ShaderNodeMath")
        mz.operation = "MAXIMUM"
        nt.links.new(sep.outputs["Z"], mz.inputs[0])
        mz.inputs[1].default_value = 0.06
        for i in range(3):
            nt.links.new(mz.outputs[0], cz.inputs[i])
        nt.links.new(cz.outputs[0], dv.inputs[1])
        nz = nt.nodes.new("ShaderNodeTexNoise")
        nz.name = "AREA_CLOUD_NOISE"
        nz.noise_dimensions = "4D"                                      # r3: W changes per view (no repeated puff)
        nz.inputs["Scale"].default_value = P("cloud_scale", 0.6)
        nz.inputs["Detail"].default_value = 6.0
        nz.inputs["Roughness"].default_value = 0.55
        nt.links.new(dv.outputs[0], nz.inputs["Vector"])
        cr = nt.nodes.new("ShaderNodeMapRange")
        cr.name = "AREA_CLOUD"
        nt.links.new(nz.outputs["Fac"], cr.inputs["Value"])
        cr.inputs["From Min"].default_value = P("cloud_from", 0.53)
        cr.inputs["From Max"].default_value = P("cloud_from", 0.53) + 0.12
        fade = nt.nodes.new("ShaderNodeMapRange")                       # no clouds near the horizon
        nt.links.new(sep.outputs["Z"], fade.inputs["Value"])
        fade.inputs["From Min"].default_value = 0.06
        fade.inputs["From Max"].default_value = 0.3
        cf = nt.nodes.new("ShaderNodeMath")
        cf.operation = "MULTIPLY"
        nt.links.new(cr.outputs["Result"], cf.inputs[0])
        nt.links.new(fade.outputs["Result"], cf.inputs[1])
        cmix = nt.nodes.new("ShaderNodeMix")
        cmix.data_type = "RGBA"
        cmix.name = "AREA_CLOUD_MIX"
        nt.links.new(cf.outputs[0], cmix.inputs["Factor"])
        nt.links.new(ramp.outputs["Color"], cmix.inputs[6])
        cbg = nt.nodes.new("ShaderNodeBackground")
        cbg.name = "AREA_SKY_BG"
        nt.links.new(cmix.outputs[2], cbg.inputs["Color"])
        lp = nt.nodes.new("ShaderNodeLightPath")
        ms = nt.nodes.new("ShaderNodeMixShader")
        ms.name = "AREA_SKY_MIX"
        nt.links.new(lp.outputs["Is Camera Ray"], ms.inputs["Fac"])
        nt.links.new(bg.outputs[0], ms.inputs[1])
        nt.links.new(cbg.outputs[0], ms.inputs[2])
        nt.links.new(ms.outputs[0], out.inputs["Surface"])
        # r3: shadows read navy (car park, street canyons): the light from the Nishita sky is desaturated
        skyt = nt.nodes.get("SKY_morning")
        if skyt is not None:
            hs = nt.nodes.new("ShaderNodeHueSaturation")
            hs.name = "AREA_FILL_DESAT"
            hs.inputs["Saturation"].default_value = P("fill_saturation", 0.45)
            nt.links.new(skyt.outputs["Color"], hs.inputs["Color"])
            nt.links.new(hs.outputs["Color"], bg.inputs["Color"])
    _STATE["view"] = _STATE.get("view", 0) + 1
    nt.nodes["AREA_CLOUD_NOISE"].inputs["W"].default_value = 3.7 * _STATE["view"]
    ramp = nt.nodes["AREA_SKY_RAMP"].color_ramp
    stops = SKY_DUSK if dusk else {"deep": SKY_DEEP, "pale": SKY_PALE, "navy": SKY_NAVY, "paleblue": SKY_PALEBLUE, "paledusk": SKY_PALEDUSK}.get(SKY_MODE, SKY_DAY)
    el = ramp.elements
    while len(el) > 1:                                              # r4: rebuild exactly, one element per stop
        el.remove(el[-1])
    el[0].position, el[0].color = stops[0][0], (*lin(stops[0][1]), 1)
    for pos, h in stops[1:]:
        e = el.new(pos)
        e.color = (*lin(h), 1)
    cm_ = nt.nodes["AREA_CLOUD_MIX"]
    if not cm_.inputs[7].is_linked:                                 # r4: heaped cumulus: grey bases, white tops
        sh = nt.nodes.new("ShaderNodeValToRGB")
        sh.name = "AREA_CLOUD_SHADE"
        sh.color_ramp.elements[0].position, sh.color_ramp.elements[0].color = 0.5, (0.58, 0.62, 0.70, 1)
        sh.color_ramp.elements[1].position, sh.color_ramp.elements[1].color = 0.78, (1.0, 1.0, 1.0, 1)
        nt.links.new(nt.nodes["AREA_CLOUD_NOISE"].outputs["Fac"], sh.inputs["Fac"])
        nt.links.new(sh.outputs["Color"], cm_.inputs[7])
    sh = nt.nodes["AREA_CLOUD_SHADE"].color_ramp.elements
    sh[1].color = (1.0, 0.86, 0.80, 1) if dusk else (1.0, 1.0, 1.0, 1)
    nt.nodes["AREA_CLOUD"].inputs["To Max"].default_value = 0.55 if dusk else {"deep": 0.55, "pale": 0.25, "navy": 0.3, "paleblue": 0.95, "paledusk": 0.15}.get(SKY_MODE, P("cloud_cover", 0.97))   # r14: daylight pairs milky vs cobalt photos
    nt.nodes["AREA_SKY_BG"].inputs["Strength"].default_value = P("sky_cam_dusk", 1.3) if dusk else P("sky_cam_day", 1.55)


def far_ridge(dusk):
    """r5 (pinned): a low far ridge round the horizon (3 km out, 30-120 m) so aerials end in hills, not an olive
    carpet; dusk colour #5b6e8c, day a hazy blue-grey. Emission-only, so the colour is not relit."""
    ob = bpy.data.objects.get("area_far_ridge")
    if ob is None:
        n, R = 720, 3000.0
        verts, faces = [], []
        for i in range(n):
            a = 2 * math.pi * i / n
            h = 30 + 90 * (0.5 + 0.5 * (0.5 * math.sin(3 * a + 1.1) + 0.3 * math.sin(7 * a + 0.4) + 0.2 * math.sin(17 * a + 2.0)))
            verts += [(R * math.cos(a), R * math.sin(a), -5.0), (R * math.cos(a), R * math.sin(a), h)]
        for i in range(n):
            j = (i + 1) % n
            faces.append((2 * i, 2 * j, 2 * j + 1, 2 * i + 1))
        me = bpy.data.meshes.new("area_far_ridge")
        me.from_pydata(verts, [], faces)
        ob = bpy.data.objects.new("area_far_ridge", me)
        bpy.context.scene.collection.objects.link(ob)
        m = bpy.data.materials.new("area_far_ridge")
        m.use_nodes = True
        nt = m.node_tree
        for nd in list(nt.nodes):
            if nd.bl_idname != "ShaderNodeOutputMaterial":
                nt.nodes.remove(nd)
        em = nt.nodes.new("ShaderNodeEmission")
        em.name = "RIDGE"
        nt.links.new(em.outputs[0], nt.nodes["Material Output"].inputs["Surface"])
        ob.data.materials.append(m)
        ob.visible_shadow = False
    em = ob.data.materials[0].node_tree.nodes["RIDGE"]
    em.inputs["Color"].default_value = (*lin("5B6E8C" if dusk else "9DAEC2"), 1)
    em.inputs["Strength"].default_value = P("ridge_k_dusk", 0.9) if dusk else P("ridge_k_day", 1.6)


def mist(on, start=250.0, depth=2600.0, strength=0.42, rgb=(0.62, 0.68, 0.76)):
    """Distance haze for aerial views (compositor mist pass, as in tools/hsw/render_hsw.horizon)."""
    sc = bpy.context.scene
    sc.view_layers[0].use_pass_mist = True
    ms = sc.world.mist_settings
    ms.start, ms.depth, ms.falloff = start, depth, "LINEAR"
    sc.use_nodes = True
    nt = sc.node_tree
    if not nt.nodes.get("AREA_MIX"):
        for nd in list(nt.nodes):
            nt.nodes.remove(nd)
        rl = nt.nodes.new("CompositorNodeRLayers")
        comp = nt.nodes.new("CompositorNodeComposite")
        lt = nt.nodes.new("CompositorNodeMath")
        lt.operation = "LESS_THAN"
        lt.inputs[1].default_value = 0.999
        nt.links.new(rl.outputs["Mist"], lt.inputs[0])
        mul = nt.nodes.new("CompositorNodeMath")
        mul.operation = "MULTIPLY"
        nt.links.new(rl.outputs["Mist"], mul.inputs[0])
        nt.links.new(lt.outputs[0], mul.inputs[1])
        mul2 = nt.nodes.new("CompositorNodeMath")
        mul2.operation = "MULTIPLY"
        mul2.name = "AREA_MIST_K"
        nt.links.new(mul.outputs[0], mul2.inputs[0])
        mix = nt.nodes.new("CompositorNodeMixRGB")
        mix.name = "AREA_MIX"
        nt.links.new(mul2.outputs[0], mix.inputs[0])
        nt.links.new(rl.outputs["Image"], mix.inputs[1])
        nt.links.new(mix.outputs[0], comp.inputs["Image"])
    nt.nodes["AREA_MIST_K"].inputs[1].default_value = strength if on else 0.0
    nt.nodes["AREA_MIX"].inputs[2].default_value = (*rgb, 1)


def light(az, el, dusk, kind):
    """Per view, after preview.apply_light: warm sun with a 0.5 deg disc, half the sky fill, AgX MHC,
    haze for aerials, dusk lamps and windows."""
    restyle()
    sc = bpy.context.scene
    sun = bpy.data.objects.get("SUN_morning")
    w = sc.world
    bg = w.node_tree.nodes.get("Background")
    if not dusk:
        if sun:
            sun.data.color = P("sun_rgb", (1.0, 0.915, 0.77))      # r7: warmer, #FFE9C4 (critics); gain unchanged
            sun.data.angle = math.radians(0.5)
            sun.data.energy = sun.data.energy * P("sun_gain", 1.6)
            try:                                                    # r6: stair-stepped shadow edges on the roads
                sun.data.shadow_filter_radius = P("shadow_filter", 2.5)
                sun.data.shadow_maximum_resolution = P("shadow_res", 0.006)
            except AttributeError:
                pass
        if bg:
            bg.inputs["Strength"].default_value *= P("sky_fill_gain", 0.42)
        sc.view_settings.exposure += P("exposure_add_day", 0.7)          # r2: +0.6 EV on round 1
    else:
        if bg:
            bg.inputs["Strength"].default_value *= 0.8
    try:
        sc.view_settings.look = "AgX - Medium High Contrast"
    except TypeError:
        pass
    for v in _STATE.get("dusk", []):
        v.outputs[0].default_value = 1.0 if dusk else 0.0
    sky(dusk)
    far_ridge(dusk)
    # r2: blue-grey haze (#8fa3b8 at display), not khaki; dusk a lilac-grey
    mist(kind == "aerial", strength=P("haze_k_dusk", 0.26) if dusk else P("haze_k", 0.45),
         rgb=P("haze_dusk", lin("7A86A8")) if dusk else P("haze_day", (0.42, 0.55, 0.76)))
